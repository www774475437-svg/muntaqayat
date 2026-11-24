import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data.dart';
import '../main.dart';
import '../services/cloud.dart';
import '../ui.dart';
import 'cloud_ui.dart';
import 'lists.dart';

// «المنتدى»: one page where the developer talks with the members and they with one another.
//
// Kept light on the database: the messages of a day are stored together in one record
// (a second one after 150 messages), so opening the forum reads a couple of records, not
// one per message. Nothing here is older than thirty days.
//
//   forum/state        who may send, the gap, the rules, the pinned line, the banned
//   forum/d<day>_<k>   the messages of a day
//   forum/pending      messages of watched members, waiting for a supervisor
//   forum/sus          copies of doubtful messages (long numbers, listed words)
//   forum/log          every warning, freeze, ban and rejection
//   forum/staff        the «مخالف» marks, seen by supervisors only
//   forum_notes/<uid>  what concerns one member: strikes, freeze, private notes

const forumGold = Color(0xFFB08A3E);
const forumGreen = Color(0xFF2E7D32);
const forumRed = Color(0xFFB3261E);

const defaultForumRules = '''١. الكلام بأدب واحترام، فلا سبّ ولا سخرية من أحد.
٢. موضوع المنتدى الشعر والأدب واللغة العربية.
٣. لا تنسب بيتاً إلى قائل إلا متثبّتاً، واذكر المصدر إن استطعت.
٤. لا يُنشر شعر فاحش ولا هجاء مقذع ولا ما يخالف الشرع.
٥. من نشر رابطاً خارجياً أو رقم هاتفه حُظر.
٦. لا إعلانات، ولا يُطلب مال ولا تبرعات.
٧. لا جدال ولا خصومات، ومن اختلف مع أخيه فبالحسنى.
٨. لا تكرّر الرسالة الواحدة.
٩. لا تُنشر معلومات شخصية، لا لك ولا لغيرك.
١٠. الكتابة بالعربية، والفصحى أولى.
١١. من نقل كلاماً أو شرحاً لغيره فلينسبه إلى صاحبه.
١٢. من رأى مخالفة فليضغط «بلاغ» ولا يردّ عليها بنفسه.
١٣. قرار المشرف يُحترم، ومن عنده اعتراض فليراسل المطوّر.
١٤. من خالف نُبّه، فإن عاد أُوقف، فإن عاد حُظر.''';

class Forum extends ChangeNotifier {
  Forum._();
  static final i = Forum._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('forum');
  SharedPreferences? _p;

  Doc state = {};
  Doc notes = {};
  Doc staffDoc = {};
  bool loaded = false;

  /// Could not read the forum at all: the database rules for it are not published yet.
  bool blocked = false;

  /// Days loaded so far (newest first is today), each with its messages.
  final Map<int, List<Doc>> days = {};
  int oldestDay = today;
  int _part = 0;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Future<void>? _peek;

  static int get _now => DateTime.now().millisecondsSinceEpoch;
  static int get today => _now ~/ 86400000;
  static const _perPart = 150;
  static const keepDays = 30;

  bool get isDev => Cloud.i.isDev;
  bool get isStaff => Cloud.i.can('منتدى');

  /// The developer hides the forum until he has tried it: then only he and the supervisors see it.
  bool get visible => Cloud.i.ready && (isStaff || (Store.i.features['forum'] ?? false));

  String get who {
    final w = '${state['who'] ?? 'dev'}';
    return _now < _n(state['openUntil']) ? w : 'dev';
  }

  /// Sending is open to someone besides the developer.
  bool get open => who != 'dev';
  int get gap => _n(state['gap']);
  String get rules => '${state['rules'] ?? ''}'.trim().isEmpty ? defaultForumRules : '${state['rules']}';
  int get rulesV => _n(state['rulesV']);
  String get pin => '${state['pin'] ?? ''}'.trim();
  List<String> get words => [for (final w in state['words'] as List? ?? []) '$w'];
  List<String> get banned => [for (final w in state['banned'] as List? ?? []) '$w'];
  Map<String, dynamic> get flagged => Map<String, dynamic>.from(staffDoc['flagged'] as Map? ?? {});
  int get frozenUntil => _n(notes['frozenUntil']);
  bool get frozen => frozenUntil > _now;
  bool get notify => _p?.getBool('forumNotify') ?? true;
  void setNotify(bool v) {
    _p?.setBool('forumNotify', v);
    notifyListeners();
  }

  static int _n(dynamic v) => v is num ? v.toInt() : 0;

  List<Doc> get messages {
    final keys = days.keys.toList()..sort();
    final limit = _now - keepDays * 86400000;
    return [
      for (final k in keys)
        for (final m in days[k]!)
          if (_n(m['at']) > limit) m
    ];
  }

  String get role => isDev ? 'dev' : (isStaff ? 'mod' : (Cloud.i.plus ? 'plus' : ''));

  // ---------------------------------------------------------------- reading

  int get _seenAt => _p?.getInt('forumSeen:${Cloud.i.uid}') ?? 0;

  /// New messages since the member last opened the forum (of what is loaded).
  int get fresh => messages.where((m) => _n(m['at']) > _seenAt && m['uid'] != Cloud.i.uid).length;

  /// Replies to my messages that I have not seen: these reach the bell even with forum notices off.
  List<Doc> get repliesToMe => [
        for (final m in messages)
          if (_n(m['at']) > _seenAt && (m['re'] as Map?)?['uid'] == Cloud.i.uid && Cloud.i.uid.isNotEmpty) m
      ];

  /// Private notes from the supervisors that I have not seen.
  List<Map> get newNotes => [
        for (final n in notes['notes'] as List? ?? [])
          if (_n((n as Map)['at']) > _n(notes['seen'])) n
      ];

  void markSeen() {
    _p?.setInt('forumSeen:${Cloud.i.uid}', _now);
    notifyListeners();
  }

  /// A light look when the app opens: the state and today's messages (two reads), for the button and the bell.
  Future<void> peek() => _peek ??= _load().whenComplete(() => _peek = null);

  Future<void> refresh() => _load();

  Future<void> _load() async {
    _p ??= await SharedPreferences.getInstance();
    if (!visible) return;
    try {
      final s = await _col.doc('state').get();
      state = s.data() ?? {};
      blocked = false;
      if (!s.exists && isDev) await _create();
      await _loadDay(today);
      if (Cloud.i.signedIn) {
        final n = await _db.collection('forum_notes').doc(Cloud.i.uid).get();
        notes = n.data() ?? {};
      }
      if (isStaff) {
        final f = await _col.doc('staff').get();
        staffDoc = f.data() ?? {};
      }
      loaded = true;
    } catch (_) {
      blocked = !loaded;
    }
    notifyListeners();
  }

  /// First opening by the developer: the records the members later add to must exist.
  Future<void> _create() async {
    state = {'who': 'dev', 'openUntil': 0, 'auto': true, 'gap': 60, 'rules': defaultForumRules, 'rulesV': 1, 'pin': '', 'words': <String>[], 'banned': <String>[], 'newbie': false};
    await _col.doc('state').set(state);
    for (final id in ['pending', 'sus', 'log']) {
      await _col.doc(id).set({'msgs': []}, SetOptions(merge: true));
    }
    await _col.doc('staff').set({'flagged': {}}, SetOptions(merge: true));
  }

  Future<void> _loadDay(int day) async {
    final list = <Doc>[];
    var k = 0;
    while (true) {
      final d = await _col.doc('d${day}_$k').get();
      final part = [for (final m in d.data()?['msgs'] as List? ?? []) Map<String, dynamic>.from(m as Map)..['part'] = k];
      list.addAll(part);
      if (part.length < _perPart) break;
      k++;
    }
    if (day == today) _part = k;
    list.sort((a, b) => _n(a['at']).compareTo(_n(b['at'])));
    days[day] = list;
    oldestDay = min(oldestDay, day);
  }

  bool get hasOlder => oldestDay > today - keepDays;

  /// One more day back (one read for a quiet day).
  Future<void> loadOlder() async {
    if (!hasOlder) return;
    try {
      await _loadDay(oldestDay - 1);
    } catch (_) {}
    notifyListeners();
  }

  /// While the page is open, today's record is watched so new messages arrive by themselves.
  void watch() {
    _sub?.cancel();
    final day = today;
    final part = _part;
    _sub = _col.doc('d${day}_$part').snapshots().listen((d) {
      final fresh = [for (final m in d.data()?['msgs'] as List? ?? []) Map<String, dynamic>.from(m as Map)];
      final ids = {for (final m in fresh) m['id']};
      // Keep the earlier parts of the day, replace this part.
      final kept = [
        for (final m in days[day] ?? <Doc>[])
          if (_n(m['part']) != part && !ids.contains(m['id'])) m
      ];
      for (final m in fresh) {
        m['part'] = part;
      }
      days[day] = [...kept, ...fresh]..sort((a, b) => _n(a['at']).compareTo(_n(b['at'])));
      if (fresh.length >= _perPart && part == _part) {
        _part = part + 1;
        watch();
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void unwatch() {
    _sub?.cancel();
    _sub = null;
  }

  // ---------------------------------------------------------------- sending

  static String _digits(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩', fa = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final c in s.split('')) {
      final i = ar.indexOf(c), j = fa.indexOf(c);
      b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : c));
    }
    return b.toString();
  }

  static final _link = RegExp(
      r'(https?://\S+|www\.\S+|\b(t|wa)\.me/\S*|\b[a-z0-9-]+\.(com|net|org|io|me|co|app|info|xyz|ly|sa|ye|tv|cc|link|site|online|store|gg|ai|dev|live|shop)\b\S*)',
      caseSensitive: false);
  static final _intl = RegExp(r'(\+|\b00)[\s\-]?[0-9][0-9\s\-]{6,}');
  static final _longNumber = RegExp(r'[0-9](?:[\s\-]?[0-9]){6,}');

  /// A link out of the app, or a phone number with a country code: these are never sent.
  static String? forbiddenPart(String text) {
    final t = _digits(text);
    for (final m in _link.allMatches(t)) {
      if (!m.group(0)!.toLowerCase().contains('muntaqayat.com')) return m.group(0);
    }
    return _intl.firstMatch(t)?.group(0);
  }

  /// The text with links and coded numbers taken out, so the member may send the rest.
  static String stripForbidden(String text) {
    var t = _digits(text);
    t = t.replaceAllMapped(_link, (m) => m.group(0)!.toLowerCase().contains('muntaqayat.com') ? m.group(0)! : '');
    return t.replaceAll(_intl, '').replaceAll(RegExp(r' {2,}'), ' ').trim();
  }

  /// Sent like any other, but also listed for the supervisors: a long number, or a listed word.
  String? doubt(String text) {
    final t = _digits(text);
    if (_longNumber.hasMatch(t)) return 'رقم طويل';
    for (final w in words) {
      if (w.trim().isNotEmpty && text.contains(w.trim())) return 'كلمة: ${w.trim()}';
    }
    return null;
  }

  /// Why this account cannot send now, or null when it can.
  String? get cannot {
    final c = Cloud.i;
    if (blocked) return 'المنتدى لم يُفتح بعد.';
    if (isDev) return null;
    if (!c.signedIn) return 'ادخل بحسابك لتكتب.';
    if (c.banned || banned.contains(c.uid)) return 'حسابك محظور من المنتدى.';
    if (frozen) return 'حسابك مجمَّد في المنتدى حتى ${_clock(frozenUntil)}.';
    final w = who;
    if (w == 'dev') return 'الإرسال مغلق الآن. تستطيع القراءة.';
    if (isStaff) return null;
    if (w == 'mods') return 'الإرسال الآن للمشرفين فقط.';
    if (w == 'plus' && !c.plus) return 'الإرسال الآن للمشتركين فقط.';
    if (state['newbie'] == true && _now - _n(c.profile['joined']) < 86400000) return 'العضو الجديد يقرأ فقط في يومه الأول.';
    return null;
  }

  static String _clock(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final left = d.difference(DateTime.now());
    return left.inHours >= 1 ? 'بعد ${Ar.num(left.inHours + 1)} ساعة' : 'بعد ${Ar.num(max(1, left.inMinutes))} دقيقة';
  }

  /// Seconds left before this member may send again.
  int get waitLeft {
    if (isStaff) return 0;
    final last = _p?.getInt('forumLast:${Cloud.i.uid}') ?? 0;
    return max(0, gap - (_now - last) ~/ 1000);
  }

  static String _id() {
    final r = Random.secure();
    return List.generate(12, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[r.nextInt(36)]).join();
  }

  Doc _message(String text, {Doc? reply, Poem? poem, int verse = 0}) {
    final c = Cloud.i;
    return {
      'id': _id(),
      'uid': c.uid,
      'name': c.name,
      'pid': c.publicId,
      'role': role,
      'text': text,
      'at': _now,
      if (reply != null)
        're': {
          'id': reply['id'],
          'uid': reply['uid'],
          'name': reply['name'],
          'text': _short('${reply['text'] ?? ''}'.isEmpty ? '${reply['a'] ?? ''}' : '${reply['text']}'),
        },
      if (poem != null) ...{
        'poem': poem.id,
        'v': verse,
        'a': poem.lines[verse][0],
        'b': poem.lines[verse].length > 1 ? poem.lines[verse][1] : '',
        'poet': poem.poet,
      },
    };
  }

  static String _short(String s) => s.length > 70 ? '${s.substring(0, 70)}…' : s;

  /// Sends a message. Returns a line to show the member, or null when it went through as usual.
  Future<String?> send(String text, {Doc? reply, Poem? poem, int verse = 0}) async {
    text = text.trim();
    if (text.isEmpty && poem == null) return 'اكتب رسالتك.';
    if (text.length > 500) return 'الرسالة طويلة: خمسمئة حرف على الأكثر.';
    final no = cannot;
    if (no != null) return no;
    final w = waitLeft;
    if (w > 0) return 'انتظر ${Ar.num(w)} ثانية ثم أرسل.';
    final m = _message(text, reply: reply, poem: poem, verse: verse);
    try {
      if (!isStaff && notes['review'] == true) {
        await _col.doc('pending').update({
          'msgs': FieldValue.arrayUnion([m])
        });
        _p?.setInt('forumLast:${Cloud.i.uid}', _now);
        return 'رسالتك تنتظر موافقة المشرف.';
      }
      await _col.doc('d${today}_$_part').set({
        'msgs': FieldValue.arrayUnion([m])
      }, SetOptions(merge: true));
      _p?.setInt('forumLast:${Cloud.i.uid}', _now);
      (days[today] ??= []).removeWhere((x) => x['id'] == m['id']);
      days[today]!.add({...m, 'part': _part});
      final why = isStaff ? null : doubt(text);
      if (why != null) {
        _col.doc('sus').update({
          'msgs': FieldValue.arrayUnion([
            {...m, 'why': why}
          ])
        }).catchError((_) {});
      }
      notifyListeners();
      return null;
    } catch (_) {
      // The state may have changed since it was read (closed, banned): read it again for the reason.
      try {
        state = (await _col.doc('state').get()).data() ?? state;
        notifyListeners();
      } catch (_) {}
      return cannot ?? 'تعذّر الإرسال. تحقّق من الإنترنت.';
    }
  }

  /// A link or a coded number was written: the first time warns, the second freezes for five hours.
  /// Returns what to tell the member.
  Future<String> strike(String text, String part) async {
    final c = Cloud.i;
    final n = _n(notes['strikes']) + 1;
    final freeze = n >= 2;
    final until = freeze ? _now + 5 * 3600 * 1000 : frozenUntil;
    final note = freeze
        ? 'جُمِّد حسابك في المنتدى خمس ساعات لتكرار إرسال رابط خارجي أو رقم هاتف. إن تكرر ذلك فقد تُحظر.'
        : 'خالفتَ قواعد المنتدى بإرسال رابط خارجي أو رقم هاتف، فحُذف. إن كررتَ ذلك جُمِّد حسابك.';
    notes = {
      ...notes,
      'name': c.name,
      'strikes': n,
      'frozenUntil': until,
      'notes': [
        ...(notes['notes'] as List? ?? []),
        {'text': note, 'at': _now, 'by': 'النظام'}
      ],
      'seen': _now,
    };
    notifyListeners();
    try {
      await _db.collection('forum_notes').doc(c.uid).set(notes, SetOptions(merge: true));
    } catch (_) {}
    _log(freeze ? 'تجميد تلقائي ٥ ساعات' : 'تنبيه تلقائي', c.uid, c.name, 'رابط خارجي أو رقم برمز دولة: $part', text, by: 'النظام');
    return note;
  }

  void _log(String kind, String uid, String name, String reason, String msg, {String? by}) {
    _col.doc('log').update({
      'msgs': FieldValue.arrayUnion([
        {'id': _id(), 'at': _now, 'kind': kind, 'uid': uid, 'name': name, 'reason': reason, 'msg': _short(msg), 'by': by ?? Cloud.i.name}
      ])
    }).catchError((_) {});
  }

  // ---------------------------------------------------------------- deleting

  Future<bool> delete(Doc m) async {
    final day = _n(m['at']) ~/ 86400000;
    try {
      var k = 0;
      while (k < 40) {
        final ref = _col.doc('d${day}_$k');
        final done = await _db.runTransaction<int>((tx) async {
          final d = await tx.get(ref);
          final list = [for (final x in d.data()?['msgs'] as List? ?? []) x as Map];
          if (!list.any((x) => x['id'] == m['id'])) return list.length < _perPart ? -1 : 0;
          tx.update(ref, {
            'msgs': [
              for (final x in list)
                if (x['id'] != m['id']) x
            ]
          });
          return 1;
        });
        if (done != 0) break;
        k++;
      }
      days[day]?.removeWhere((x) => x['id'] == m['id']);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Supervisors clear what passed thirty days, once a day, when they open the forum.
  Future<void> sweep() async {
    if (!isStaff || _p?.getInt('forumSweep') == today) return;
    _p?.setInt('forumSweep', today);
    for (var d = today - keepDays - 1; d > today - keepDays - 8; d--) {
      for (var k = 0; k < 3; k++) {
        _col.doc('d${d}_$k').delete().catchError((_) {});
      }
    }
    // The lists keep only their recent entries.
    for (final id in ['log', 'sus']) {
      try {
        final doc = await _col.doc(id).get();
        final list = [for (final x in doc.data()?['msgs'] as List? ?? []) x as Map];
        final limit = _now - keepDays * 86400000;
        final kept = [
          for (final x in list)
            if (_n(x['at']) > limit) x
        ];
        if (kept.length != list.length) await _col.doc(id).update({'msgs': kept});
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------- supervising

  Future<bool> setState(Doc change) async {
    try {
      await _col.doc('state').set(change, SetOptions(merge: true));
      state = {...state, ...change};
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Who may send. Opening starts the twenty-four hours after which it closes by itself (when that switch is on).
  Future<bool> setWho(String w) => setState({
        'who': w,
        'openUntil': w == 'dev' ? 0 : (state['auto'] == false ? _now + 3650 * 86400000 : _now + 86400000),
      });

  Future<bool> setAuto(bool on) => setState({
        'auto': on,
        if (open) 'openUntil': on ? _now + 86400000 : _now + 3650 * 86400000,
      });

  Future<List<Doc>> list(String id) async {
    try {
      final d = await _col.doc(id).get();
      return [for (final x in d.data()?['msgs'] as List? ?? []) Map<String, dynamic>.from(x as Map)]..sort((a, b) => _n(b['at']).compareTo(_n(a['at'])));
    } catch (_) {
      return [];
    }
  }

  Future<void> _removeFrom(String id, Doc m) async {
    final ref = _col.doc(id);
    await _db.runTransaction((tx) async {
      final d = await tx.get(ref);
      tx.update(ref, {
        'msgs': [
          for (final x in d.data()?['msgs'] as List? ?? [])
            if ((x as Map)['id'] != m['id']) x
        ]
      });
    });
  }

  Future<void> dropDoubt(Doc m) => _removeFrom('sus', m).catchError((_) {});

  Future<bool> _note(String uid, String name, Doc change, {String? text}) async {
    try {
      await _db.collection('forum_notes').doc(uid).set({
        ...change,
        'name': name,
        if (text != null && text.isNotEmpty)
          'notes': FieldValue.arrayUnion([
            {'text': text, 'at': _now, 'by': isDev ? 'المطوّر' : 'المشرف'}
          ]),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Doc> notesOf(String uid) async {
    try {
      return (await _db.collection('forum_notes').doc(uid).get()).data() ?? {};
    } catch (_) {
      return {};
    }
  }

  /// A waiting message is let into the forum.
  Future<bool> approve(Doc m) async {
    try {
      final msg = {...m, 'at': _now}..remove('why');
      await _col.doc('d${today}_$_part').set({
        'msgs': FieldValue.arrayUnion([msg])
      }, SetOptions(merge: true));
      await _removeFrom('pending', m);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// A waiting message is refused: its writer is told, with a private line only he sees.
  Future<bool> reject(Doc m, String note) async {
    try {
      await _removeFrom('pending', m);
      await _note('${m['uid']}', '${m['name']}', {}, text: 'رفض المشرف رسالتك: «${_short('${m['text']}')}».${note.isEmpty ? '' : '\n$note'}');
      _log('رفض رسالة', '${m['uid']}', '${m['name']}', note, '${m['text']}');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> warn(Doc m, String reason) async {
    final ok = await _note('${m['uid']}', '${m['name']}', {}, text: 'تنبيه من المشرف: $reason');
    if (ok) _log('تنبيه', '${m['uid']}', '${m['name']}', reason, '${m['text'] ?? m['a'] ?? ''}');
    return ok;
  }

  Future<bool> freeze(Doc m, int hours, String reason) async {
    final ok = await _note('${m['uid']}', '${m['name']}', {'frozenUntil': hours == 0 ? 0 : _now + hours * 3600000},
        text: hours == 0 ? 'رُفع التجميد عن حسابك في المنتدى.' : 'جُمِّد حسابك في المنتدى ${Ar.num(hours)} ساعة.${reason.isEmpty ? '' : '\nالسبب: $reason'}');
    if (ok) _log(hours == 0 ? 'رفع التجميد' : 'تجميد ${Ar.num(hours)} ساعة', '${m['uid']}', '${m['name']}', reason, '${m['text'] ?? m['a'] ?? ''}');
    return ok;
  }

  Future<bool> ban(Doc m, bool on, String reason) async {
    try {
      await _col.doc('state').update({
        'banned': on ? FieldValue.arrayUnion([m['uid']]) : FieldValue.arrayRemove([m['uid']])
      });
      final b = banned;
      on ? b.add('${m['uid']}') : b.remove('${m['uid']}');
      state = {...state, 'banned': b};
      await _note('${m['uid']}', '${m['name']}', {}, text: on ? 'حُظر حسابك من المنتدى.${reason.isEmpty ? '' : '\nالسبب: $reason'}' : 'رُفع الحظر عن حسابك في المنتدى.');
      _log(on ? 'حظر' : 'رفع الحظر', '${m['uid']}', '${m['name']}', reason, '${m['text'] ?? m['a'] ?? ''}');
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// His messages wait for a supervisor before they appear.
  Future<bool> review(Doc m, bool on) async {
    final ok = await _note('${m['uid']}', '${m['name']}', {'review': on}, text: on ? 'رسائلك في المنتدى تمرّ على المشرف قبل ظهورها.' : 'عادت رسائلك تظهر في المنتدى مباشرة.');
    if (ok) _log(on ? 'مراقبة الرسائل' : 'رفع المراقبة', '${m['uid']}', '${m['name']}', '', '${m['text'] ?? m['a'] ?? ''}');
    return ok;
  }

  /// The «مخالف» mark, seen by the developer and the supervisors only.
  Future<bool> flag(Doc m, bool on) async {
    try {
      final f = flagged;
      on ? f['${m['uid']}'] = '${m['name']}' : f.remove('${m['uid']}');
      await _col.doc('staff').set({'flagged': f});
      staffDoc = {'flagged': f};
      _log(on ? 'علامة «مخالف»' : 'رفع علامة «مخالف»', '${m['uid']}', '${m['name']}', '', '${m['text'] ?? m['a'] ?? ''}');
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The member has read the private notes sent to him.
  void notesSeen() {
    if (newNotes.isEmpty || !Cloud.i.signedIn) return;
    notes = {...notes, 'seen': _now};
    _db.collection('forum_notes').doc(Cloud.i.uid).set({'seen': _now}, SetOptions(merge: true)).catchError((_) {});
    notifyListeners();
  }
}

// ------------------------------------------------------------------ the button

/// «المنتدى» in the top row of «اليوم», beside the bell: red while sending is open.
class ForumChip extends StatefulWidget {
  const ForumChip({super.key});
  @override
  State<ForumChip> createState() => _ForumChipState();
}

class _ForumChipState extends State<ForumChip> {
  @override
  void initState() {
    super.initState();
    Forum.i.peek();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Forum.i, Cloud.i, Store.i]),
        builder: (context, _) {
          final f = Forum.i;
          if (!f.visible) return const SizedBox.shrink();
          final on = f.open;
          final color = on ? forumRed : C.muted(context);
          final n = f.notify ? f.fresh : 0;
          return Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: Material(
              color: C.bar(context),
              borderRadius: BorderRadius.circular(30),
              elevation: 3,
              shadowColor: Colors.black12,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => push(context, const ForumScreen()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.forum_outlined, color: color, size: 20),
                    const SizedBox(width: 6),
                    Text('المنتدى', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color)),
                    if (n > 0) ...[
                      const SizedBox(width: 6),
                      Text(n > 99 ? '+٩٩' : Ar.num(n), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
                    ],
                  ]),
                ),
              ),
            ),
          );
        },
      );
}

// ------------------------------------------------------------------ small helpers

Future<String?> _askText(BuildContext context, String title, {String initial = '', String hint = '', int lines = 1, bool allowEmpty = false}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctl, autofocus: true, minLines: lines, maxLines: max(lines, 6), decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(c, (ctl.text.trim().isEmpty && !allowEmpty) ? null : ctl.text.trim()), child: const Text('حفظ')),
      ],
    ),
  );
}

Future<void> _tell(BuildContext context, String title, String text) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(text, style: const TextStyle(height: 1.7))),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('حسناً'))],
      ),
    );

/// The mark beside a name: gold for the developer, green for a supervisor, blue for a subscriber.
class RoleMark extends StatelessWidget {
  final String role;
  const RoleMark(this.role, {super.key});
  @override
  Widget build(BuildContext context) {
    if (role.isEmpty) return const SizedBox.shrink();
    final color = role == 'dev' ? forumGold : (role == 'mod' ? forumGreen : verifiedBlue);
    final label = role == 'dev' ? 'المطوّر' : (role == 'mod' ? 'المشرف' : '');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(width: 4),
      Icon(Icons.verified_rounded, size: 15, color: color),
      if (label.isNotEmpty) ...[
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ the page

class ForumScreen extends StatefulWidget {
  /// A verse brought from a poem, ready to be sent.
  final Poem? poem;
  final int verse;
  const ForumScreen({super.key, this.poem, this.verse = 0});
  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final f = Forum.i;
  final ctl = TextEditingController();
  final scroll = ScrollController();
  Doc? reply;
  Poem? poem;
  bool busy = false, loadingOlder = false;
  late Future<void> job;

  @override
  void initState() {
    super.initState();
    poem = widget.poem;
    job = _open();
  }

  Future<void> _open() async {
    await f.refresh();
    if (!mounted || f.blocked) return;
    if (f.days.length < 2) await f.loadOlder();
    f.watch();
    f.sweep();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notes());
  }

  /// Private notes from the supervisors are shown once, to their owner alone.
  Future<void> _notes() async {
    if (!mounted) return;
    final n = f.newNotes;
    if (n.isEmpty) return;
    await _tell(context, 'رسالة خاصة من الإشراف', n.map((x) => '• ${x['text']}').join('\n\n'));
    f.notesSeen();
  }

  @override
  void dispose() {
    f.unwatch();
    f.markSeen();
    ctl.dispose();
    scroll.dispose();
    super.dispose();
  }

  bool get _rulesOk => f.isStaff || (f._p?.getInt('forumRules:${Cloud.i.uid}') ?? -1) == f.rulesV;

  Future<bool> _acceptRules() async {
    if (_rulesOk) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('قواعد المنتدى'),
        content: SingleChildScrollView(child: Text(f.rules, style: const TextStyle(height: 1.8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('أوافق عليها')),
        ],
      ),
    );
    if (ok == true) f._p?.setInt('forumRules:${Cloud.i.uid}', f.rulesV);
    return ok == true;
  }

  Future<void> _send() async {
    if (busy) return;
    if (!await needAccount(context, 'تكتب في المنتدى باسمك ورقمك الشخصي.')) return;
    if (!mounted) return;
    if (!f.loaded) await f.refresh();
    if (!mounted || !await _acceptRules()) return;
    final text = ctl.text.trim();
    if (text.isEmpty && poem == null) return;
    if (!f.isStaff) {
      final bad = Forum.forbiddenPart(text);
      if (bad != null && f.cannot == null) {
        setState(() => busy = true);
        final note = await f.strike(text, bad);
        if (!mounted) return;
        setState(() {
          busy = false;
          ctl.text = Forum.stripForbidden(text);
        });
        await _tell(context, 'مخالفة', note);
        return;
      }
    }
    setState(() => busy = true);
    final r = await f.send(text, reply: reply, poem: poem, verse: widget.verse);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r == null || r.startsWith('رسالتك تنتظر')) {
        ctl.clear();
        reply = null;
        poem = null;
      }
    });
    if (r != null) toast(context, r);
    if (r == null && scroll.hasClients) scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([f, Cloud.i, Store.i]),
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('المنتدى'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: (f.open ? forumRed : C.muted(context)).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(f.open ? 'مفتوح' : 'مغلق', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: f.open ? forumRed : C.muted(context))),
              ),
            ]),
            actions: [
              IconButton(
                tooltip: f.notify ? 'إيقاف إشعارات المنتدى' : 'تشغيل إشعارات المنتدى',
                onPressed: () {
                  f.setNotify(!f.notify);
                  toast(context, f.notify ? 'يظهر لك عدد الرسائل الجديدة على زر المنتدى.' : 'أُوقف عدد الرسائل الجديدة. الردود عليك تصلك في الجرس دائماً.');
                },
                icon: Icon(f.notify ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
              ),
              IconButton(tooltip: 'قواعد المنتدى', onPressed: () => _tell(context, 'قواعد المنتدى', f.rules), icon: const Icon(Icons.gavel_rounded)),
              if (f.isStaff) IconButton(tooltip: 'الإشراف', onPressed: () => push(context, const ForumStaffScreen()), icon: const Icon(Icons.admin_panel_settings_outlined)),
            ],
          ),
          body: FutureBuilder<void>(
            future: job,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done && !f.loaded) return const Center(child: CircularProgressIndicator());
              if (f.blocked) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(f.isDev ? 'المنتدى جاهز في التطبيق، لكنه لا يعمل حتى تُنشر قواعد قاعدة البيانات الخاصة به.' : 'المنتدى لم يُفتح بعد.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.8, color: C.muted(context))),
                  ),
                );
              }
              final list = f.messages.reversed.toList();
              return Column(children: [
                if (f.pin.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: forumGold.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.push_pin_outlined, size: 17, color: forumGold)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f.pin, style: TextStyle(height: 1.6, color: C.ink(context)))),
                    ]),
                  ),
                Expanded(
                  child: list.isEmpty && !f.hasOlder
                      ? Center(child: Text('لا رسائل بعد.', style: TextStyle(color: C.muted(context))))
                      : ListView.builder(
                          controller: scroll,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          itemCount: list.length + 1,
                          itemBuilder: (context, i) {
                            if (i == list.length) {
                              if (!f.hasOlder) return Padding(padding: const EdgeInsets.all(14), child: Center(child: Text('تُحفظ رسائل ثلاثين يوماً فقط.', style: TextStyle(fontSize: 12.5, color: C.muted(context)))));
                              return Center(
                                child: TextButton(
                                  onPressed: loadingOlder
                                      ? null
                                      : () async {
                                          setState(() => loadingOlder = true);
                                          await f.loadOlder();
                                          if (mounted) setState(() => loadingOlder = false);
                                        },
                                  child: Text(loadingOlder ? 'يحمّل…' : (list.isEmpty ? 'لا رسائل اليوم. اعرض الأقدم' : 'اعرض الأقدم')),
                                ),
                              );
                            }
                            return _bubble(context, list[i]);
                          },
                        ),
                ),
                _composer(context),
              ]);
            },
          ),
        ),
      );

  Widget _bubble(BuildContext context, Doc m) {
    final mine = m['uid'] == Cloud.i.uid && Cloud.i.uid.isNotEmpty;
    final re = m['re'] as Map?;
    final hasVerse = m['a'] != null && '${m['a']}'.isNotEmpty;
    final marked = f.isStaff && f.flagged.containsKey(m['uid']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
          child: Material(
            color: mine ? C.soft(context) : C.card(context),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onLongPress: () => _menu(context, m),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  InkWell(
                    onTap: () => _openUser(m),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(child: Text('${m['name'] ?? 'قارئ'}', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: m['role'] == 'dev' ? forumGold : C.accent(context)))),
                      RoleMark('${m['role'] ?? ''}'),
                      if (marked) ...[
                        const SizedBox(width: 6),
                        const Text('مخالف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: forumRed)),
                      ],
                    ]),
                  ),
                  if (re != null)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: C.accent(context), width: 3)), color: C.bg(context).withValues(alpha: 0.5)),
                      child: Text('${re['name']}: ${re['text']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
                    ),
                  if (hasVerse)
                    InkWell(
                      onTap: () {
                        final p = Library.byId[m['poem']];
                        if (p != null) openPoem(context, p);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          VerseLines(['${m['a']}', if ('${m['b'] ?? ''}'.isNotEmpty) '${m['b']}'], size: 19),
                          if ('${m['poet'] ?? ''}'.isNotEmpty)
                            InkWell(
                              onTap: () => push(context, PoetScreen(name: '${m['poet']}')),
                              child: Padding(padding: const EdgeInsets.only(top: 2), child: Text('${m['poet']}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.accent(context)))),
                            ),
                        ]),
                      ),
                    ),
                  if ('${m['text'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${m['text']}', style: TextStyle(fontSize: 15.5, height: 1.6, color: C.ink(context)))),
                  const SizedBox(height: 3),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(ago(m['at']), style: TextStyle(fontSize: 11, color: C.muted(context))),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => setState(() => reply = m),
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2), child: Text('ردّ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.accent(context)))),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUser(Doc m) async {
    if (!await needAccount(context)) return;
    final u = await Cloud.i.userByUid('${m['uid']}');
    if (u != null && mounted) push(context, UserScreen(user: u));
  }

  Widget _composer(BuildContext context) {
    final no = f.cannot;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        decoration: BoxDecoration(color: C.bg(context), border: Border(top: BorderSide(color: C.line(context)))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (reply != null) _chipLine(context, Icons.reply_rounded, 'ردّ على ${reply!['name']}: ${'${reply!['text'] ?? ''}'.isEmpty ? '${reply!['a'] ?? ''}' : reply!['text']}', () => setState(() => reply = null)),
          if (poem != null) _chipLine(context, Icons.format_quote_rounded, poem!.lines[widget.verse].join('   '), () => setState(() => poem = null)),
          if (no != null && Cloud.i.signedIn)
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(no, textAlign: TextAlign.center, style: TextStyle(color: C.muted(context), fontSize: 14.5)))
          else
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: ctl,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: Cloud.i.signedIn ? 'اكتب رسالتك' : 'ادخل بحسابك لتكتب',
                    counterText: '',
                    filled: true,
                    fillColor: C.card(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : _send,
                style: FilledButton.styleFrom(shape: const CircleBorder(), minimumSize: const Size(46, 46), padding: EdgeInsets.zero),
                child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 20),
              ),
            ]),
        ]),
      ),
    );
  }

  Widget _chipLine(BuildContext context, IconData icon, String text, VoidCallback onClose) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: C.accent(context)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: C.muted(context)))),
          InkWell(onTap: onClose, child: Icon(Icons.close_rounded, size: 18, color: C.muted(context))),
        ]),
      );

  void _menu(BuildContext context, Doc m) {
    final mine = m['uid'] == Cloud.i.uid && Cloud.i.uid.isNotEmpty;
    final body = '${m['text'] ?? ''}'.isEmpty ? '${m['a'] ?? ''}\n${m['b'] ?? ''}'.trim() : '${m['text']}';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('ردّ'),
              onTap: () {
                Navigator.pop(c);
                setState(() => reply = m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('نسخ'),
              onTap: () {
                Navigator.pop(c);
                Clipboard.setData(ClipboardData(text: '$body\n\n— من منتدى «منتقيات الشعر»'));
                toast(context, 'نُسخت الرسالة');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('صفحة صاحبها'),
              onTap: () {
                Navigator.pop(c);
                _openUser(m);
              },
            ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('بلاغ'),
                onTap: () async {
                  Navigator.pop(c);
                  if (!await needAccount(context)) return;
                  if (!context.mounted) return;
                  final why = await _askText(context, 'سبب البلاغ', hint: 'ما المخالفة؟', lines: 2);
                  if (why == null) return;
                  final ok = await Cloud.i.report('منتدى', '${m['id']}', '$why\n— الرسالة: $body\n— صاحبها: ${m['name']} (${m['pid']})', ofUid: '${m['uid']}');
                  if (context.mounted) toast(context, ok ? 'وصل بلاغك إلى المشرفين.' : 'تعذّر الإرسال.');
                },
              ),
            if (mine || f.isStaff)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: forumRed),
                title: const Text('حذف الرسالة', style: TextStyle(color: forumRed)),
                onTap: () async {
                  Navigator.pop(c);
                  final ok = await f.delete(m);
                  if (ok && !mine) f._log('حذف رسالة', '${m['uid']}', '${m['name']}', '', body);
                  if (context.mounted) toast(context, ok ? 'حُذفت.' : 'تعذّر الحذف.');
                },
              ),
            if (f.isStaff && !mine) ...staffTiles(context, c, m),
          ]),
        ),
      ),
    );
  }
}

/// What a supervisor may do to the writer of a message (also used from the doubtful and waiting lists).
List<Widget> staffTiles(BuildContext context, BuildContext sheet, Doc m) {
  final f = Forum.i;
  final isBanned = f.banned.contains(m['uid']);
  final isFlagged = f.flagged.containsKey(m['uid']);
  Future<void> run(Future<bool> Function() job) async {
    final ok = await job();
    if (context.mounted) toast(context, ok ? 'تم.' : 'تعذّر ذلك. تحقّق من الإنترنت أو من صلاحيتك.');
  }

  return [
    const Divider(),
    ListTile(
      leading: const Icon(Icons.warning_amber_rounded),
      title: const Text('تنبيه صاحبها (رسالة خاصة)'),
      onTap: () async {
        Navigator.pop(sheet);
        final r = await _askText(context, 'نص التنبيه', hint: 'لا يراه غيره', lines: 2);
        if (r != null) await run(() => f.warn(m, r));
      },
    ),
    ListTile(
      leading: const Icon(Icons.ac_unit_rounded),
      title: const Text('تجميده مدة'),
      onTap: () async {
        Navigator.pop(sheet);
        final h = await showDialog<int>(
          context: context,
          builder: (c) => SimpleDialog(title: const Text('مدة التجميد'), children: [
            for (final x in const [5, 24, 48, 72, 168]) SimpleDialogOption(onPressed: () => Navigator.pop(c, x), child: Text(x < 48 ? '${Ar.num(x)} ساعة' : '${Ar.num(x ~/ 24)} أيام')),
            SimpleDialogOption(onPressed: () => Navigator.pop(c, 0), child: const Text('رفع التجميد')),
          ]),
        );
        if (h == null || !context.mounted) return;
        final r = h == 0 ? '' : (await _askText(context, 'سبب التجميد', hint: 'يصله في رسالة خاصة', lines: 2, allowEmpty: true) ?? '');
        await run(() => f.freeze(m, h, r));
      },
    ),
    ListTile(
      leading: const Icon(Icons.fact_check_outlined),
      title: const Text('رسائله تمرّ على المشرف أولاً'),
      subtitle: const Text('اضغط مرة أخرى على «رفع المراقبة» من السجل أو من هنا'),
      onTap: () async {
        Navigator.pop(sheet);
        final n = await f.notesOf('${m['uid']}');
        await run(() => f.review(m, n['review'] != true));
      },
    ),
    ListTile(
      leading: Icon(isFlagged ? Icons.label_off_outlined : Icons.label_important_outline_rounded),
      title: Text(isFlagged ? 'رفع علامة «مخالف»' : 'علامة «مخالف» (يراها الإشراف فقط)'),
      onTap: () async {
        Navigator.pop(sheet);
        await run(() => f.flag(m, !isFlagged));
      },
    ),
    ListTile(
      leading: Icon(isBanned ? Icons.lock_open_rounded : Icons.block_rounded, color: forumRed),
      title: Text(isBanned ? 'رفع الحظر عنه' : 'حظره من المنتدى', style: const TextStyle(color: forumRed)),
      onTap: () async {
        Navigator.pop(sheet);
        final r = isBanned ? '' : await _askText(context, 'سبب الحظر', hint: 'يصله في رسالة خاصة', lines: 2, allowEmpty: true);
        if (r == null) return;
        await run(() => f.ban(m, !isBanned, r));
      },
    ),
  ];
}

// ------------------------------------------------------------------ supervision

class ForumStaffScreen extends StatelessWidget {
  const ForumStaffScreen({super.key});

  static const _who = {'all': 'الجميع', 'plus': 'المشتركون والمشرفون', 'mods': 'المشرفون فقط', 'dev': 'أنا وحدي (مغلق)'};
  static const _gaps = {0: 'بلا فاصل', 30: '٣٠ ثانية', 50: '٥٠ ثانية', 60: 'دقيقة', 120: 'دقيقتان', 300: '٥ دقائق', 600: '١٠ دقائق'};

  @override
  Widget build(BuildContext context) {
    final f = Forum.i;
    return ListenableBuilder(
      listenable: Listenable.merge([f, Store.i]),
      builder: (context, _) {
        Future<void> run(Future<bool> job) async {
          final ok = await job;
          if (!ok && context.mounted) toast(context, 'لم يُحفظ. تحقّق من الإنترنت أو من صلاحيتك.');
        }

        final left = f.open && f.state['auto'] != false ? Forum._n(f.state['openUntil']) - Forum._now : 0;
        return Scaffold(
          appBar: AppBar(title: const Text('إشراف المنتدى')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
            const SectionTitle('المراجعة'),
            _row(context, Icons.hourglass_top_rounded, 'بانتظار الموافقة', 'رسائل من وُضعوا تحت المراقبة', () => push(context, const ForumListScreen(id: 'pending', title: 'بانتظار الموافقة'))),
            _row(context, Icons.help_outline_rounded, 'مشكوك فيها', 'أُرسلت، وفيها رقم طويل أو كلمة من القائمة', () => push(context, const ForumListScreen(id: 'sus', title: 'مشكوك فيها'))),
            _row(context, Icons.receipt_long_outlined, 'سجلّ التنبيهات والحظر', 'من نُبّه أو جُمّد أو حُظر، ومن فعل ذلك، ولماذا', () => push(context, const ForumListScreen(id: 'log', title: 'السجلّ'))),
            _row(context, Icons.label_important_outline_rounded, 'المعلَّمون «مخالف»', Ar.num(f.flagged.length), () => _tell(context, 'المعلَّمون «مخالف»', f.flagged.isEmpty ? 'لا أحد.' : f.flagged.values.map((n) => '• $n').join('\n'))),
            const SectionTitle('المحتوى'),
            _row(context, Icons.push_pin_outlined, 'الرسالة المثبّتة', f.pin.isEmpty ? 'لا شيء' : f.pin, () async {
              final t = await _askText(context, 'الرسالة المثبّتة', initial: f.pin, hint: 'إعلان أو موضوع اليوم. اتركها فارغة لإزالتها', lines: 3, allowEmpty: true);
              if (t != null) await run(f.setState({'pin': t}));
            }),
            _row(context, Icons.gavel_rounded, 'قواعد المنتدى', 'من عدّلها وافق الأعضاء عليها من جديد', () async {
              final t = await _askText(context, 'قواعد المنتدى', initial: f.rules, lines: 6);
              if (t != null) await run(f.setState({'rules': t, 'rulesV': f.rulesV + 1}));
            }),
            _row(context, Icons.spellcheck_rounded, 'كلمات تُعرض في «مشكوك فيها»', f.words.isEmpty ? 'لا كلمات' : f.words.join('، '), () async {
              final t = await _askText(context, 'الكلمات', initial: f.words.join('، '), hint: 'افصل بينها بفاصلة. الرسالة تُرسل وتُعرض لكم فقط', lines: 3, allowEmpty: true);
              if (t != null) await run(f.setState({'words': [for (final w in t.split(RegExp('[،,\n]'))) if (w.trim().isNotEmpty) w.trim()]}));
            }),
            if (f.isDev) ...[
              const SectionTitle('التحكم (للمطوّر وحده)'),
              SoftCard(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Row(children: [
                      Expanded(child: Text('من يستطيع الإرسال', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context)))),
                      if (left > 0) Text('يُغلق بعد ${Ar.num(max(1, left ~/ 3600000))} ساعة', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
                    ]),
                  ),
                  for (final e in _who.entries)
                    RadioListTile<String>(
                      dense: true,
                      value: e.key,
                      groupValue: f.who,
                      onChanged: (v) => run(f.setWho(v!)),
                      title: Text(e.value, style: const TextStyle(fontSize: 15.5)),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              SoftCard(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                child: Column(children: [
                  SwitchListTile(
                    value: f.state['auto'] != false,
                    onChanged: (v) => run(f.setAuto(v)),
                    title: const Text('يُغلق الإرسال تلقائياً بعد ٢٤ ساعة'),
                    subtitle: const Text('إن نسيته مفتوحاً رجع إليك وحدك حتى تفتحه'),
                  ),
                  SwitchListTile(
                    value: !(Store.i.features['forum'] ?? false),
                    onChanged: (v) => Store.i.setFeature('forum', !v),
                    title: const Text('إخفاء المنتدى عن الجميع'),
                    subtitle: const Text('لا يراه إلا أنت والمشرفون'),
                  ),
                  SwitchListTile(
                    value: f.state['newbie'] == true,
                    onChanged: (v) => run(f.setState({'newbie': v})),
                    title: const Text('العضو الجديد يقرأ فقط في يومه الأول'),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              SoftCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الفاصل بين رسالتين للعضو', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final e in _gaps.entries) ChoiceChip(label: Text(e.value), selected: f.gap == e.key, onSelected: (_) => run(f.setState({'gap': e.key}))),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
              Text('مشرفو المنتدى تضيفهم من صفحة «المشرفون» بصلاحية «منتدى».', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
            ],
          ]),
        );
      },
    );
  }

  Widget _row(BuildContext context, IconData icon, String title, String sub, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SoftCard(
          onTap: onTap,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, color: C.accent(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context))),
                if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: C.muted(context))),
              ]),
            ),
            Icon(Icons.chevron_left_rounded, color: C.muted(context)),
          ]),
        ),
      );
}

/// The waiting list, the doubtful list, or the log.
class ForumListScreen extends StatefulWidget {
  final String id, title;
  const ForumListScreen({super.key, required this.id, required this.title});
  @override
  State<ForumListScreen> createState() => _ForumListScreenState();
}

class _ForumListScreenState extends State<ForumListScreen> {
  late Future<List<Doc>> job = Forum.i.list(widget.id);
  void _reload() => setState(() => job = Forum.i.list(widget.id));

  @override
  Widget build(BuildContext context) {
    final f = Forum.i;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [IconButton(tooltip: 'تحديث', onPressed: _reload, icon: const Icon(Icons.refresh_rounded))]),
      body: FutureBuilder<List<Doc>>(
        future: job,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final list = snap.data ?? [];
          if (list.isEmpty) return Center(child: Text('لا شيء هنا.', style: TextStyle(color: C.muted(context))));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  padding: const EdgeInsets.all(14),
                  child: widget.id == 'log' ? _logItem(context, m) : _msgItem(context, f, m),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Widget _logItem(BuildContext context, Doc m) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${m['kind']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context)))),
          Text(ago(m['at']), style: TextStyle(fontSize: 12, color: C.muted(context))),
        ]),
        const SizedBox(height: 4),
        Text('العضو: ${m['name']}', style: TextStyle(color: C.ink(context), height: 1.6)),
        Text('بواسطة: ${m['by']}', style: TextStyle(color: C.ink(context), height: 1.6)),
        if ('${m['reason'] ?? ''}'.isNotEmpty) Text('السبب: ${m['reason']}', style: TextStyle(color: C.ink(context), height: 1.6)),
        if ('${m['msg'] ?? ''}'.isNotEmpty) Text('الرسالة: ${m['msg']}', style: TextStyle(color: C.muted(context), height: 1.6)),
      ]);

  Widget _msgItem(BuildContext context, Forum f, Doc m) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${m['name']} · ${m['pid'] ?? ''}', style: TextStyle(fontWeight: FontWeight.w700, color: C.accent(context)))),
          Text(ago(m['at']), style: TextStyle(fontSize: 12, color: C.muted(context))),
        ]),
        if ('${m['why'] ?? ''}'.isNotEmpty) Text('السبب: ${m['why']}', style: const TextStyle(fontSize: 12.5, color: forumRed)),
        const SizedBox(height: 4),
        Text('${m['text'] ?? ''}'.isEmpty ? '${m['a'] ?? ''}  ${m['b'] ?? ''}' : '${m['text']}', style: TextStyle(fontSize: 15.5, height: 1.6, color: C.ink(context))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          if (widget.id == 'pending') ...[
            FilledButton(
              onPressed: () async {
                final ok = await f.approve(m);
                if (context.mounted) toast(context, ok ? 'نُشرت في المنتدى.' : 'تعذّر ذلك.');
                _reload();
              },
              child: const Text('قبول'),
            ),
            OutlinedButton(
              onPressed: () async {
                final note = await _askText(context, 'رفض الرسالة', hint: 'رسالة خاصة لصاحبها، لا يراها غيره', lines: 3, allowEmpty: true);
                if (note == null) return;
                final ok = await f.reject(m, note);
                if (context.mounted) toast(context, ok ? 'رُفضت، ووصله الخبر.' : 'تعذّر ذلك.');
                _reload();
              },
              child: const Text('رفض'),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: () async {
                final ok = await f.delete(m);
                if (ok) f._log('حذف رسالة', '${m['uid']}', '${m['name']}', '${m['why'] ?? ''}', '${m['text'] ?? ''}');
                await f.dropDoubt(m);
                if (context.mounted) toast(context, ok ? 'حُذفت من المنتدى.' : 'تعذّر الحذف.');
                _reload();
              },
              child: const Text('حذف الرسالة'),
            ),
            TextButton(
              onPressed: () async {
                await f.dropDoubt(m);
                _reload();
              },
              child: const Text('سليمة'),
            ),
          ],
          TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (c) => SafeArea(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: staffTiles(context, c, m).skip(1).toList()))),
            ),
            child: const Text('صاحبها…'),
          ),
        ]),
      ]);
}
