import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data.dart';

typedef Doc = Map<String, dynamic>;

/// Accounts and shared data (Firebase project «muntaqayat»).
/// Every call is safe offline: it fails quietly and the app keeps working.
class Cloud extends ChangeNotifier {
  Cloud._();
  static final i = Cloud._();

  static const devEmail = 'www774475437@gmail.com';
  static const _webClient = '581548975960-gohqhrnvuu7o9ukiiulhu4b8bm66rp26.apps.googleusercontent.com';
  static const _key = 'AIzaSyDGy7PPhEtyp5J5PNn9f2waBwEblfD1Ntg';
  static const _web = FirebaseOptions(
    apiKey: _key,
    appId: '1:581548975960:web:321cc335d4bc68ae78e72d',
    messagingSenderId: '581548975960',
    projectId: 'muntaqayat',
    authDomain: 'muntaqayat.firebaseapp.com',
    storageBucket: 'muntaqayat.firebasestorage.app',
  );
  static const _android = FirebaseOptions(
    apiKey: _key,
    appId: '1:581548975960:android:41e1d8c25995696a78e72d',
    messagingSenderId: '581548975960',
    projectId: 'muntaqayat',
    storageBucket: 'muntaqayat.firebasestorage.app',
  );

  bool ready = false;
  User? user;
  Doc profile = {};
  late SharedPreferences _p;
  Future<void>? _profileJob;
  Timer? _pushTimer;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  bool get signedIn => ready && user != null;
  bool get isDev => signedIn && user!.email == devEmail && user!.emailVerified;
  String get uid => user?.uid ?? '';
  String get publicId => '${profile['publicId'] ?? ''}';
  bool get banned => profile['banned'] == true;
  String get name {
    final n = '${profile['name'] ?? ''}'.trim();
    if (n.isNotEmpty) return n;
    final m = '${Store.i.majlis['name'] ?? ''}'.trim();
    if (m.isNotEmpty) return m;
    return (user?.displayName ?? '').trim().isEmpty ? 'قارئ' : user!.displayName!.trim();
  }

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    try {
      await Firebase.initializeApp(options: kIsWeb ? _web : _android);
      ready = true;
      Store.cloudPush = _schedulePush;
      FirebaseAuth.instance.authStateChanges().listen(_onUser);
      unawaited(pullConfig());
    } catch (_) {
      ready = false;
    }
    notifyListeners();
  }

  Future<void> _onUser(User? u) async {
    user = u;
    if (u == null) {
      profile = {};
      notifyListeners();
      return;
    }
    await _ensureProfile();
    if (isDev) {
      if (!Store.i.developer) Store.i.setDeveloper(true);
      await pullConfig(force: true);
    }
    unawaited(dailySync());
    notifyListeners();
  }

  // ------------------------------------------------------------ sign in

  /// Returns an Arabic error text, or null when signed in.
  Future<String?> signIn() async {
    if (!ready) return 'تعذّر الاتصال بالخادم. تحقّق من الإنترنت ثم أعد فتح التطبيق.';
    try {
      if (kIsWeb) {
        // Always show the list of Google accounts to choose from.
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}));
      } else {
        final g = GoogleSignIn(serverClientId: _webClient, scopes: const ['email']);
        try {
          await g.signOut();
        } catch (_) {}
        final acc = await g.signIn();
        if (acc == null) return 'أُلغي الدخول.';
        final a = await acc.authentication;
        await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: a.idToken, accessToken: a.accessToken));
      }
      user = FirebaseAuth.instance.currentUser;
      await _ensureProfile();
      notifyListeners();
      return user == null ? 'لم يكتمل الدخول.' : null;
    } catch (e) {
      return 'تعذّر الدخول بحساب جوجل.\n$e';
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb) await GoogleSignIn().signOut();
    } catch (_) {}
  }

  Future<void> _ensureProfile() => _profileJob ??= _loadProfile().whenComplete(() => _profileJob = null);

  Future<void> _loadProfile() async {
    if (user == null) return;
    final cached = _p.getString('profile:$uid');
    if (cached != null) {
      profile = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      notifyListeners();
      // Refreshed from the server at most every six hours.
      if (_now - (_p.getInt('profileAt:$uid') ?? 0) < 6 * 3600 * 1000) return;
    }
    try {
      final ref = _db.collection('users').doc(uid);
      final snap = await ref.get();
      if (snap.exists) {
        profile = snap.data()!;
      } else {
        await _createProfile();
      }
      _cacheProfile();
    } catch (_) {}
  }

  void _cacheProfile() {
    _p.setString('profile:$uid', jsonEncode(profile));
    _p.setInt('profileAt:$uid', _now);
  }

  /// A fixed personal number of seven digits, unique among all readers.
  Future<void> _createProfile() async {
    final rnd = Random.secure();
    for (var attempt = 0; attempt < 8; attempt++) {
      final id = '${1000000 + rnd.nextInt(9000000)}';
      final idRef = _db.collection('ids').doc(id);
      final data = <String, dynamic>{
        'name': name,
        'publicId': id,
        'joined': _now,
        'joinedDay': Store.today,
        'lastDay': Store.today,
      };
      try {
        final ok = await _db.runTransaction<bool>((tx) async {
          if ((await tx.get(idRef)).exists) return false;
          tx.set(idRef, {'uid': uid});
          tx.set(_db.collection('users').doc(uid), data);
          return true;
        });
        if (ok) {
          profile = data;
          return;
        }
      } catch (_) {
        return;
      }
    }
  }

  Future<bool> setName(String v) async {
    v = v.trim();
    if (v.isEmpty || !signedIn) return false;
    try {
      await _db.collection('users').doc(uid).update({'name': v});
      profile['name'] = v;
      _cacheProfile();
      notifyListeners();
      unawaited(pushBoard());
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ daily sync (one write a day)

  Map<String, dynamic> get _days => (Store.i.majlis['days'] as Map<String, dynamic>?) ?? {};
  int _sum(int fromDay) {
    var s = 0;
    _days.forEach((k, v) {
      if ((int.tryParse(k) ?? 0) >= fromDay) s += ((v as List)[0] as num).toInt();
    });
    return s;
  }

  int get _weekStart => Store.today - ((DateTime.now().weekday + 1) % 7);
  int get _monthStart => Store.today - (DateTime.now().day - 1);
  int get _streak {
    var n = 0;
    var d = Store.today;
    if (_days['$d'] == null) d--;
    while (_days['$d'] != null) {
      n++;
      d--;
    }
    return n;
  }

  Future<void> dailySync() async {
    if (!signedIn || profile.isEmpty) return;
    if (_p.getInt('syncDay:$uid') == Store.today) return;
    final s = Store.i;
    final data = <String, dynamic>{
      'lastDay': Store.today,
      'likes': s.likes.length,
      'memo': s.memorized.values.fold<int>(0, (a, b) => a + b.length),
      'days': s.days.length,
      'points': _sum(0),
      'streak': _streak,
    };
    try {
      await _db.collection('users').doc(uid).update(data);
      profile.addAll(data);
      _cacheProfile();
      _p.setInt('syncDay:$uid', Store.today);
    } catch (_) {}
  }

  // ------------------------------------------------------------ leaderboard

  List<String> get boardFields => ['w$_weekStart', 'm$_monthStart', 'total'];

  /// Sent after the daily challenge: one write a day.
  Future<void> pushBoard() async {
    if (!signedIn || banned) return;
    try {
      await _db.collection('board').doc(uid).set({
        'name': name,
        'publicId': publicId,
        'total': _sum(0),
        'w$_weekStart': _sum(_weekStart),
        'm$_monthStart': _sum(_monthStart),
        'streak': _streak,
        'at': _now,
      });
    } catch (_) {}
  }

  /// The top readers. Read from the server once a day for each range.
  Future<List<Doc>> board(int range, {bool refresh = false}) async {
    final field = boardFields[range];
    final key = 'board:$field';
    var list = <Doc>[];
    final cached = _p.getString(key);
    if (!refresh && cached != null && _p.getInt('$key:day') == Store.today) {
      list = [for (final x in jsonDecode(cached) as List) Map<String, dynamic>.from(x as Map)];
    } else if (ready) {
      try {
        final q = await _db.collection('board').orderBy(field, descending: true).limit(20).get();
        list = [
          for (final d in q.docs) {'uid': d.id, 'name': d.data()['name'], 'publicId': d.data()['publicId'], 'pts': d.data()[field], 'streak': d.data()['streak']}
        ];
        _p.setString(key, jsonEncode(list));
        _p.setInt('$key:day', Store.today);
      } catch (_) {
        if (cached != null) list = [for (final x in jsonDecode(cached) as List) Map<String, dynamic>.from(x as Map)];
      }
    }
    // The reader's own row is always up to date.
    if (signedIn) {
      final mine = [_sum(_weekStart), _sum(_monthStart), _sum(0)][range];
      list.removeWhere((x) => x['uid'] == uid);
      if (mine > 0) list.add({'uid': uid, 'name': name, 'publicId': publicId, 'pts': mine, 'streak': _streak});
    }
    list.sort((a, b) => ((b['pts'] ?? 0) as num).compareTo((a['pts'] ?? 0) as num));
    return list;
  }

  // ------------------------------------------------------------ developer marks and settings (for everyone)

  Future<void> pullConfig({bool force = false}) async {
    if (!ready) return;
    if (!force && _now - (_p.getInt('cfgAt') ?? 0) < 6 * 3600 * 1000) return;
    try {
      final dirty = _p.getBool('cfgDirty') ?? false;
      if (dirty && isDev) {
        await _push();
        return;
      }
      final app = await _db.collection('config').doc('app').get();
      final marks = await _db.collection('config').doc('marks').get();
      _p.setInt('cfgAt', _now);
      if (!marks.exists && !app.exists) {
        if (isDev) await _push();
        return;
      }
      final a = app.data() ?? {}, m = marks.data() ?? {};
      Store.i.applyCloud(
        verified: marks.exists ? List<String>.from(m['verified'] as List? ?? []) : null,
        hidden: marks.exists ? List<String>.from(m['hidden'] as List? ?? []) : null,
        deleted: marks.exists ? List<String>.from(m['deleted'] as List? ?? []) : null,
        plus: a['plusOn'] as bool?,
        payLink: a['payLink'] as String?,
        shuruh: a['shuruh'] is String ? jsonDecode(a['shuruh'] as String) as Map<String, dynamic> : null,
      );
    } catch (_) {}
  }

  void _schedulePush() {
    _p.setBool('cfgDirty', true);
    if (!isDev) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(milliseconds: 1500), _push);
  }

  Future<void> _push() async {
    if (!isDev) return;
    final s = Store.i;
    try {
      await _db.collection('config').doc('marks').set({
        'verified': s.verified.toList(),
        'hidden': s.hidden.toList(),
        'deleted': s.deleted.toList(),
        'at': _now,
      });
      await _db.collection('config').doc('app').set({'plusOn': s.plusOn, 'payLink': s.payLink, 'shuruh': jsonEncode(s.shuruh), 'at': _now});
      _p.setBool('cfgDirty', false);
      _p.setInt('cfgAt', _now);
    } catch (_) {}
  }

  // ------------------------------------------------------------ quotes

  List<Doc>? _feed;
  int _count(String k) => _p.getInt('$k:${Store.today}') ?? 0;
  void _bump(String k) => _p.setInt('$k:${Store.today}', _count(k) + 1);
  int get quotesLeft => 10 - _count('q');
  bool get plus => profile['plus'] == true;

  /// One message a day for free, twenty for subscribers.
  int get messagesLimit => plus ? 20 : 1;
  int get messagesLeft => isDev ? 99 : messagesLimit - _count('msg');
  Set<String> get likedQuotes => (_p.getStringList('likedQ') ?? []).toSet();

  static List<Doc> _docs(QuerySnapshot<Map<String, dynamic>> q) => [
        for (final d in q.docs) {...d.data(), 'id': d.id}
      ]..sort((a, b) => ((b['at'] ?? 0) as num).compareTo((a['at'] ?? 0) as num));

  Future<List<Doc>> quotes({String? of, bool refresh = false}) async {
    if (!ready) return [];
    try {
      if (of != null) return _docs(await _db.collection('quotes').where('uid', isEqualTo: of).limit(60).get());
      if (_feed != null && !refresh) return _feed!;
      return _feed = _docs(await _db.collection('quotes').orderBy('at', descending: true).limit(30).get());
    } catch (_) {
      return _feed ?? [];
    }
  }

  Future<String?> publishQuote(Poem p, int verse) async {
    if (!signedIn) return 'ادخل بحسابك أولاً.';
    if (banned) return 'حسابك موقوف عن النشر.';
    if (quotesLeft <= 0) return 'نشرت عشرة اقتباسات اليوم. عُد غداً.';
    final l = p.lines[verse];
    try {
      final data = <String, dynamic>{
        'uid': uid,
        'name': name,
        'publicId': publicId,
        'poem': p.id,
        'v': verse,
        'a': l[0],
        'b': l.length > 1 ? l[1] : '',
        'poet': p.poet,
        'likes': 0,
        'at': _now,
      };
      final ref = await _db.collection('quotes').add(data);
      _bump('q');
      _feed?.insert(0, {...data, 'id': ref.id});
      notifyListeners();
      return null;
    } catch (_) {
      return 'تعذّر النشر. تحقّق من الإنترنت.';
    }
  }

  Future<void> likeQuote(Doc q) async {
    if (!signedIn) return;
    final liked = likedQuotes;
    final on = !liked.contains(q['id']);
    on ? liked.add(q['id'] as String) : liked.remove(q['id']);
    _p.setStringList('likedQ', liked.toList());
    q['likes'] = ((q['likes'] ?? 0) as num).toInt() + (on ? 1 : -1);
    notifyListeners();
    try {
      await _db.collection('quotes').doc(q['id'] as String).update({'likes': FieldValue.increment(on ? 1 : -1)});
    } catch (_) {}
  }

  Future<bool> deleteQuote(String id) async {
    try {
      await _db.collection('quotes').doc(id).delete();
      _feed?.removeWhere((x) => x['id'] == id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ reports

  Future<bool> report(String kind, String target, String text, {String ofUid = ''}) async {
    if (!signedIn) return false;
    try {
      await _db.collection('reports').add({'kind': kind, 'target': target, 'text': text, 'ofUid': ofUid, 'by': uid, 'byName': name, 'at': _now});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Doc>> reports() async {
    try {
      return _docs(await _db.collection('reports').orderBy('at', descending: true).limit(50).get());
    } catch (_) {
      return [];
    }
  }

  Future<void> closeReport(String id) async {
    try {
      await _db.collection('reports').doc(id).delete();
    } catch (_) {}
  }

  Future<bool> setBanned(String userUid, bool on) async {
    try {
      await _db.collection('users').doc(userUid).update({'banned': on});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ messages to the developer

  Future<String?> sendMessage(String text, {String kind = 'message'}) async {
    if (!signedIn) return 'ادخل بحسابك أولاً.';
    if (text.trim().isEmpty) return 'اكتب رسالتك أولاً.';
    final counter = kind == 'message' ? 'msg' : 'msg$kind';
    if (!isDev && _count(counter) >= (kind == 'message' ? messagesLimit : 1)) {
      return plus ? 'أرسلت عشرين رسالة اليوم. عُد غداً.' : 'المجاني رسالة واحدة في اليوم. عُد غداً، أو اشترك لتراسل عشرين مرة في اليوم.';
    }
    try {
      await _db.collection('messages').add({'uid': uid, 'name': name, 'publicId': publicId, 'text': text.trim(), 'kind': kind, 'reply': '', 'at': _now});
      _bump(counter);
      notifyListeners();
      return null;
    } catch (_) {
      return 'تعذّر الإرسال. تحقّق من الإنترنت.';
    }
  }

  Future<List<Doc>> myMessages() async {
    if (!signedIn) return [];
    try {
      return _docs(await _db.collection('messages').where('uid', isEqualTo: uid).limit(40).get());
    } catch (_) {
      return [];
    }
  }

  Future<List<Doc>> allMessages() async {
    try {
      return _docs(await _db.collection('messages').orderBy('at', descending: true).limit(300).get());
    } catch (_) {
      return [];
    }
  }

  Future<bool> reply(String id, String text) async {
    try {
      await _db.collection('messages').doc(id).update({
        'reply': text.trim(),
        'replyAt': _now,
        'replies': FieldValue.arrayUnion([
          {'text': text.trim(), 'at': _now}
        ]),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteMessage(String id) async {
    try {
      await _db.collection('messages').doc(id).delete();
    } catch (_) {}
  }

  // ------------------------------------------------------------ people

  /// The account behind a personal number, or null.
  Future<Doc?> findUser(String id) async {
    if (!signedIn) return null;
    try {
      final x = await _db.collection('ids').doc(id.trim()).get();
      if (!x.exists) return null;
      final u = await _db.collection('users').doc(x.data()!['uid'] as String).get();
      return u.exists ? {...u.data()!, 'uid': u.id} : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> get following => Map<String, String>.from(jsonDecode(_p.getString('following') ?? '{}') as Map);
  void follow(String id, String name, bool on) {
    final f = following;
    on ? f[id] = name : f.remove(id);
    _p.setString('following', jsonEncode(f));
    notifyListeners();
  }

  // ------------------------------------------------------------ teacher tests by personal number

  bool get testSentToday => _count('test') > 0;

  /// Returns (error, how many students were found).
  Future<(String?, int)> sendTest({required List<String> ids, required String matn, required String title, required int from, required int to, required int mode}) async {
    if (!signedIn) return ('ادخل بحسابك أولاً.', 0);
    if (testSentToday && !isDev && profile['plus'] != true) return ('المجاني اختبار واحد بالأرقام في اليوم. أرسل الباقي بالرابط، أو اطلب اختباراً آخر.', 0);
    try {
      final uids = <String>[];
      for (final id in ids.take(30)) {
        final x = await _db.collection('ids').doc(id).get();
        if (x.exists) uids.add(x.data()!['uid'] as String);
      }
      if (uids.isEmpty) return ('لم أجد حساباً بهذه الأرقام. تأكد من أرقام طلابك.', 0);
      await _db.collection('tests').add({
        'teacher': uid,
        'teacherName': name,
        'students': uids,
        'matn': matn,
        'title': title,
        'from': from,
        'to': to,
        'mode': mode,
        'results': <String, dynamic>{},
        'at': _now,
      });
      _bump('test');
      return (null, uids.length);
    } catch (_) {
      return ('تعذّر الإرسال. تحقّق من الإنترنت.', 0);
    }
  }

  /// Tests sent to me (as a student).
  Future<List<Doc>> myTests() async {
    if (!signedIn) return [];
    try {
      return _docs(await _db.collection('tests').where('students', arrayContains: uid).limit(30).get());
    } catch (_) {
      return [];
    }
  }

  /// Tests I sent (as a teacher), with the students' results.
  Future<List<Doc>> sentTests() async {
    if (!signedIn) return [];
    try {
      return _docs(await _db.collection('tests').where('teacher', isEqualTo: uid).limit(30).get());
    } catch (_) {
      return [];
    }
  }

  Future<bool> submitResult(String testId, int right, int total) async {
    if (!signedIn) return false;
    try {
      await _db.collection('tests').doc(testId).update({
        'results.$uid': {'name': name, 'publicId': publicId, 'r': right, 't': total, 'at': _now}
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ book design orders and subscribers

  Future<String?> orderDesign(String note) async {
    if (!signedIn) return 'ادخل بحسابك أولاً.';
    try {
      await _db.collection('orders').add({'uid': uid, 'name': name, 'publicId': publicId, 'note': note.trim(), 'status': 'جديد', 'at': _now});
      return null;
    } catch (_) {
      return 'تعذّر الإرسال. تحقّق من الإنترنت.';
    }
  }

  Future<List<Doc>> orders() async {
    try {
      return _docs(await _db.collection('orders').orderBy('at', descending: true).limit(60).get());
    } catch (_) {
      return [];
    }
  }

  Future<void> setOrderStatus(String id, String status) async {
    try {
      await _db.collection('orders').doc(id).update({'status': status});
    } catch (_) {}
  }

  Future<List<Doc>> subscribers() async {
    try {
      final q = await _db.collection('users').where('plus', isEqualTo: true).limit(200).get();
      return [
        for (final d in q.docs) {...d.data(), 'uid': d.id}
      ];
    } catch (_) {
      return [];
    }
  }

  /// Redraws the screens that listen to the cloud.
  void touch() => notifyListeners();

  /// Fresh from the server (after the developer changed my subscription, for example).
  Future<void> refreshProfile() async {
    if (!signedIn) return;
    try {
      final snap = await _db.collection('users').doc(uid).get();
      if (snap.exists) {
        profile = snap.data()!;
        _cacheProfile();
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Readers who were subscribers and are not any more.
  Future<List<Doc>> formerSubscribers() async {
    try {
      final q = await _db.collection('users').where('plus', isEqualTo: false).limit(200).get();
      return [
        for (final d in q.docs) {...d.data(), 'uid': d.id}
      ];
    } catch (_) {
      return [];
    }
  }

  /// [kind]: «هدية» (granted by the developer) or «مدفوع» (paid).
  Future<bool> setPlus(String userUid, bool on, {String kind = 'هدية'}) async {
    try {
      await _db.collection('users').doc(userUid).update({'plus': on, if (on) 'plusKind': kind, if (on) 'plusAt': _now else 'plusEnded': _now});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ statistics (developer)

  /// [all readers, today, this week, new this week, subscribers] — five cheap counts.
  Future<List<int>?> stats() async {
    if (!isDev) return null;
    try {
      final u = _db.collection('users');
      Future<int> c(Query<Map<String, dynamic>> q) async => (await q.count().get()).count ?? 0;
      return [
        await c(u),
        await c(u.where('lastDay', isEqualTo: Store.today)),
        await c(u.where('lastDay', isGreaterThanOrEqualTo: Store.today - 6)),
        await c(u.where('joinedDay', isGreaterThanOrEqualTo: Store.today - 6)),
        await c(u.where('plus', isEqualTo: true)),
      ];
    } catch (_) {
      return null;
    }
  }
}
