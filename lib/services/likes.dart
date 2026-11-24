import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Public like counts of poems.
/// A like is counted on the phone at once. The changes are sent together, in one batch,
/// every three hours while the app is open, and the new totals come back with it.
/// So a member's like shows on his own screen at once, and on others' screens at the next batch.
class LikeCounts extends ChangeNotifier {
  static final LikeCounts i = LikeCounts._();
  LikeCounts._();

  static const period = Duration(hours: 3);
  static const _maxWatched = 200;

  /// Changes not yet sent, poem id → +1 or -1 (summed).
  final Map<String, int> _pending = {};

  /// Last totals read from the server.
  final Map<String, int> _totals = {};

  /// Poems on screen or liked, whose totals are read at each batch.
  final List<String> _watched = [];

  SharedPreferences? _p;
  Timer? _timer;
  bool _sending = false;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p!.getString('likeDelta');
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      m.forEach((k, v) => _pending[k] = (v as num).toInt());
    }
    final last = _p!.getInt('likeLast') ?? 0;
    final due = DateTime.now().millisecondsSinceEpoch - last >= period.inMilliseconds;
    _timer = Timer.periodic(period, (_) => flush());
    if (due && _pending.isNotEmpty) flush();
  }

  /// Number to show: the last total from the server, plus this member's own unsent likes.
  int count(String id) => (_totals[id] ?? 0) + (_pending[id] ?? 0);

  /// Called when a like is pressed or taken back.
  void add(String id, bool on) {
    _pending[id] = (_pending[id] ?? 0) + (on ? 1 : -1);
    if (_pending[id] == 0) _pending.remove(id);
    _save();
    notifyListeners();
  }

  /// Makes sure this poem's total is read at the next batch.
  void watch(String id) {
    if (_watched.contains(id)) return;
    _watched.add(id);
    if (_watched.length > _maxWatched) _watched.removeAt(0);
  }

  Future<void> flush() async {
    final p = _p;
    if (p == null || _sending) return;
    _sending = true;
    final sent = Map<String, int>.from(_pending);
    try {
      final db = FirebaseFirestore.instance;
      if (sent.isNotEmpty) {
        final batch = db.batch();
        sent.forEach((id, d) => batch.set(db.collection('likeCounts').doc(id), {'n': FieldValue.increment(d)}, SetOptions(merge: true)));
        await batch.commit();
        // Remove only what was sent; likes pressed during the send stay pending.
        sent.forEach((id, d) {
          final left = (_pending[id] ?? 0) - d;
          if (left == 0) {
            _pending.remove(id);
          } else {
            _pending[id] = left;
          }
        });
      }
      final ids = {..._watched, ...sent.keys}.toList();
      final snaps = await Future.wait(ids.map((id) => db.collection('likeCounts').doc(id).get()));
      for (var k = 0; k < ids.length; k++) {
        _totals[ids[k]] = ((snaps[k].data()?['n']) as num? ?? 0).toInt();
      }
      await p.setInt('likeLast', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // No network or no permission: keep the likes pending and try at the next batch.
    } finally {
      _save();
      _sending = false;
      notifyListeners();
    }
  }

  void _save() {
    _p?.setString('likeDelta', jsonEncode(_pending));
  }
}
