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

  static const _iosClient = '581548975960-c9fut35d4qqov4qqe4pgs3mad1h8qam3.apps.googleusercontent.com';
  static const _ios = FirebaseOptions(
    apiKey: _key,
    appId: '1:581548975960:ios:9e3553fd9d33da2678e72d',
    messagingSenderId: '581548975960',
    projectId: 'muntaqayat',
    storageBucket: 'muntaqayat.firebasestorage.app',
    iosBundleId: 'com.muntaqayat.muntaqayat',
    iosClientId: _iosClient,
  );

  static String get signInLabel => onApple ? 'ادخل بحسابك' : 'ادخل بحساب جوجل';

  /// On an iPhone or iPad: «الدخول بحساب Apple» is offered beside Google.
  static bool get onApple => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

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
      await Firebase.initializeApp(options: kIsWeb ? _web : (onApple ? _ios : _android));
      ready = true;
      Store.cloudPush = _schedulePush;
      Store.isDevAccount = () => isDev;
      Store.cloudHidden = _hiddenChanged;
      FirebaseAuth.instance.authStateChanges().listen(_onUser);
      unawaited(pullConfig());
    } catch (_) {
      ready = false;
    }
    notifyListeners();
  }

  Future<void> _onUser(User? u) async {
    user = u;
    // Developer mode belongs to the developer's account only: off for anyone else on this device.
    if (!isDev) Store.i.setDeveloper(false);
    Store.i.accountChanged();
    if (u == null) {
      profile = {};
      Store.plusUser = false;
      notifyListeners();
      return;
    }
    await _ensureProfile();
    // Signing in as the developer opens nothing by itself: his tools stay out of sight
    // until he taps the version line fifteen times in the settings.
    if (isDev) await pullConfig(force: true);
    await _restore();
    unawaited(syncSoon());
    notifyListeners();
  }

  // ------------------------------------------------------------ sign in

  /// Returns an Arabic error text, or null when signed in.
  Future<String?> signIn({bool apple = false}) async {
    if (!ready) return 'تعذّر الاتصال بالخادم. تحقّق من الإنترنت ثم أعد فتح التطبيق.';
    try {
      if (apple) {
        // Apple's own sheet; the reader may hide his email, and the app asks for nothing else.
        await FirebaseAuth.instance.signInWithProvider(AppleAuthProvider()
          ..addScope('email')
          ..addScope('name'));
      } else if (kIsWeb) {
        // Always show the list of Google accounts to choose from.
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}));
      } else {
        final g = GoogleSignIn(clientId: onApple ? _iosClient : null, serverClientId: _webClient, scopes: const ['email']);
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
      if ('$e'.contains('canceled') || '$e'.contains('cancelled')) return 'أُلغي الدخول.';
      return 'تعذّر الدخول بحساب ${apple ? 'Apple' : 'جوجل'}.\n$e';
    }
  }

  /// «احذف حسابي»: the request reaches the developer, the public figures go at once, then the reader is signed out.
  Future<bool> requestDeletion() async {
    if (!signedIn) return false;
    try {
      await _db.collection('messages').add({'uid': uid, 'name': name, 'publicId': publicId, 'text': 'طلب حذف الحساب وكل بياناته', 'kind': 'delete', 'reply': '', 'at': _now});
      try {
        await _db.collection('board').doc(uid).delete();
      } catch (_) {}
      await signOut();
      return true;
    } catch (_) {
      return false;
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
      Store.plusUser = plus || isDev;
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
      // The developer's account carries the golden mark for everyone to see.
      if (isDev && grants['dev'] != true) {
        await ref.update({'grants.dev': true});
        profile['grants'] = {...grants, 'dev': true};
        _cacheProfile();
      }
    } catch (_) {}
  }

  void _cacheProfile() {
    Store.plusUser = plus || isDev;
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
        'lastAt': _now,
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

  /// A phone id made once (a reinstall makes a new one).
  String get deviceId {
    var d = _p.getString('device');
    if (d == null) {
      d = '$_now${Random().nextInt(1 << 30)}';
      _p.setString('device', d);
    }
    return d;
  }

  /// Everything is kept on the phone first, then sent to the account at most
  /// four times a day (one slot every six hours), all at once.
  Future<void> syncSoon({bool force = false}) async {
    if (!signedIn || profile.isEmpty) return;
    // Never overwrite the saved copy before it was brought back to this phone.
    if (_p.getBool('restored:$uid') != true && '${profile['saveId'] ?? ''}'.isNotEmpty) return;
    final slot = '${Store.today}:${DateTime.now().hour ~/ 6}';
    if (!force && _p.getString('syncSlot:$uid') == slot) return;
    final s = Store.i;
    final data = <String, dynamic>{
      'lastDay': Store.today,
      'lastAt': _now,
      'likes': s.likes.length,
      'memo': s.memorized.values.fold<int>(0, (a, b) => a + b.length),
      'days': s.days.length,
      'points': _sum(0),
      'streak': _streak,
      'poets': s.followed.length,
      'device': deviceId,
    };
    try {
      // The full copy (likes, collections, memorised verses, levels) in one private document.
      final save = {'teacher': uid, 'students': <String>[], 'kind': 'save', 'data': jsonEncode(s.exportAll()), 'at': _now};
      var id = '${profile['saveId'] ?? ''}';
      if (id.isEmpty) {
        id = (await _db.collection('tests').add(save)).id;
        data['saveId'] = id;
      } else {
        await _db.collection('tests').doc(id).update({'data': save['data'], 'at': _now});
      }
      await _db.collection('users').doc(uid).update(data);
      profile.addAll(data);
      _cacheProfile();
      _p.setString('syncSlot:$uid', slot);
      _p.setBool('restored:$uid', true);
    } catch (_) {}
  }

  Future<void> dailySync() => syncSoon();

  /// On a new phone: bring back what the account saved, once.
  Future<void> _restore() async {
    if (!signedIn || _p.getBool('restored:$uid') == true) return;
    final id = '${profile['saveId'] ?? ''}';
    try {
      if (id.isEmpty) {
        // Maybe the cached profile is old: look once.
        final snap = await _db.collection('users').doc(uid).get();
        if (snap.exists) profile = snap.data()!;
        _cacheProfile();
      }
      final sid = '${profile['saveId'] ?? ''}';
      if (sid.isNotEmpty) {
        final doc = await _db.collection('tests').doc(sid).get();
        final raw = doc.data()?['data'];
        if (raw is String) {
          final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          var cloudXp = 0;
          try {
            final days = (jsonDecode('${m['majlis'] ?? '{}'}') as Map)['days'] as Map? ?? {};
            for (final v in days.values) {
              cloudXp += ((v as List)[0] as num).toInt();
            }
          } catch (_) {}
          final localEmpty = Store.i.likes.isEmpty && Store.i.collections.isEmpty && _sum(0) == 0;
          if (localEmpty || cloudXp > _sum(0)) await Store.i.importAll(m);
        }
      }
      _p.setBool('restored:$uid', true);
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
        'titles': grants['titles'] ?? [],
        'at': _now,
      }, SetOptions(merge: true));
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
          for (final d in q.docs) {'uid': d.id, 'name': d.data()['name'], 'publicId': d.data()['publicId'], 'pts': d.data()[field], 'total': d.data()['total'], 'streak': d.data()['streak'], 'titles': d.data()['titles'] ?? []}
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
      if (mine > 0) list.add({'uid': uid, 'name': name, 'publicId': publicId, 'pts': mine, 'total': _sum(0), 'streak': _streak});
    }
    list.sort((a, b) => ((b['pts'] ?? 0) as num).compareTo((a['pts'] ?? 0) as num));
    return list;
  }

  /// Writes my own totals to the shared board. Only these numbers leave the device.
  Future<void> publishStats(Map<String, num> stats) async {
    if (!signedIn) return;
    try {
      await _db.collection('board').doc(uid).set({'name': name, 'publicId': publicId, ...stats}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// One ranking by a single field. Read from the server once a day, like [board].
  Future<List<Doc>> statBoard(String field) async {
    final key = 'stat:$field';
    final cached = _p.getString(key);
    List<Doc> fromCache() => cached == null ? [] : [for (final x in jsonDecode(cached) as List) Map<String, dynamic>.from(x as Map)];
    if (cached != null && _p.getInt('$key:day') == Store.today) return fromCache();
    if (!ready) return fromCache();
    try {
      final q = await _db.collection('board').orderBy(field, descending: true).limit(20).get();
      final list = [
        for (final d in q.docs)
          if (((d.data()[field] ?? 0) as num) > 0) {'uid': d.id, 'name': d.data()['name'], 'publicId': d.data()['publicId'], 'v': d.data()[field]}
      ];
      await _p.setString(key, jsonEncode(list));
      await _p.setInt('$key:day', Store.today);
      return list;
    } catch (_) {
      return fromCache();
    }
  }

  /// Puts the reader's own fresh score into the saved ranking, which is read from the server
  /// only once a day, so he sees himself in it right after playing.
  Future<void> noteOwnStat(String field, num value) async {
    if (!signedIn || value <= 0) return;
    final key = 'stat:$field';
    final cached = _p.getString(key);
    final list = <Doc>[if (cached != null) for (final x in jsonDecode(cached) as List) Map<String, dynamic>.from(x as Map)];
    list.removeWhere((d) => d['uid'] == uid);
    list.add({'uid': uid, 'name': name, 'publicId': publicId, 'v': value});
    list.sort((x, y) => ((y['v'] ?? 0) as num).compareTo((x['v'] ?? 0) as num));
    await _p.setString(key, jsonEncode(list.take(20).toList()));
  }

  /// Counts one answered question of the proverb quiz and publishes the totals.
  Future<void> countQuizAnswer(bool correct) async {
    final a = (_p.getInt('quiz:answered') ?? 0) + 1;
    final c = (_p.getInt('quiz:correct') ?? 0) + (correct ? 1 : 0);
    await _p.setInt('quiz:answered', a);
    await _p.setInt('quiz:correct', c);
    await publishStats({'quizAnswered': a, 'quizCorrect': c});
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
      // The corrections («تحرير») stand in a record of their own, so a supervisor's change is one small write.
      Map<String, dynamic>? edits;
      try {
        final e = await _db.collection('config').doc('edits').get();
        if (e.exists) {
          // On the server a correction keeps its verses as one text ('l'), since a list within a list is not stored.
          edits = {};
          final m = e.data()?['m'];
          if (m is Map) {
            for (final x in m.entries) {
              final v = x.value;
              if (v is! Map) continue;
              edits['${x.key}'] = {
                if (v['poet'] is String) 'poet': v['poet'],
                if (v['l'] is String) 'lines': jsonDecode(v['l'] as String),
              };
            }
          }
        }
      } catch (_) {}
      _p.setInt('cfgAt', _now);
      if (!marks.exists && !app.exists) {
        if (isDev) await _push();
        return;
      }
      final a = app.data() ?? {}, m = marks.data() ?? {};
      if (app.exists) {
        _p.setStringList('bannedDevices', List<String>.from(a['bannedDevices'] as List? ?? []));
        _p.setString('mods', a['mods'] is String ? a['mods'] as String : '{}');
        _p.setString('modNames', a['modNames'] is String ? a['modNames'] as String : '{}');
        if (a['mutedReporters'] is List) _p.setStringList('mutedReporters', List<String>.from(a['mutedReporters'] as List));
        if (a['acceptedSharh'] is List) _p.setStringList('acceptedSharh', List<String>.from(a['acceptedSharh'] as List));
      }
      if (marks.exists) Store.i.setModHidden(List<String>.from(m['modHidden'] as List? ?? []));
      Store.i.applyCloud(
        verified: marks.exists ? List<String>.from(m['verified'] as List? ?? []) : null,
        shShown: marks.exists && m['shShown'] is List ? List<String>.from(m['shShown'] as List) : null,
        shHidden: marks.exists && m['shHidden'] is List ? List<String>.from(m['shHidden'] as List) : null,
        hidden: marks.exists ? List<String>.from(m['hidden'] as List? ?? []) : null,
        deleted: marks.exists ? List<String>.from(m['deleted'] as List? ?? []) : null,
        plus: (a['plusShow'] as bool?) ?? false,
        payLink: a['payLink'] as String?,
        shuruh: a['shuruh'] is String ? jsonDecode(a['shuruh'] as String) as Map<String, dynamic> : null,
        features: a['features'] is Map ? Map<String, dynamic>.from(a['features'] as Map) : null,
        diwan: a['diwan'] is String ? jsonDecode(a['diwan'] as String) as Map<String, dynamic> : null,
        edits: edits,
        browse: a['browse'] is String ? jsonDecode(a['browse'] as String) as Map<String, dynamic> : null,
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
        'hidden': s.hidden.difference(s.modHidden).toList(),
        'deleted': s.deleted.toList(),
        'at': _now,
        // The cited verses' lists are left as they are: each change to them is sent on its own (setShahid).
      }, SetOptions(merge: true));
      await _db.collection('config').doc('app').set({
        'plusShow': s.plusOn,
        'payLink': s.payLink,
        'shuruh': jsonEncode(s.shuruh),
        'diwan': jsonEncode(s.diwan),
        'browse': jsonEncode({'order': s.browseOrder, 'hidden': s.browseHidden.toList()}),
        'features': s.features,
        'bannedDevices': bannedDevices,
        'mods': jsonEncode(mods),
        'modNames': jsonEncode(modNames),
        'mutedReporters': mutedReporters,
        'acceptedSharh': acceptedSharh,
        'at': _now,
      });
      // The supervisors as a map, for the server rules to read.
      await _db.collection('config').doc('mods').set({'list': mods, 'at': _now});
      _p.setBool('cfgDirty', false);
      _p.setInt('cfgAt', _now);
    } catch (_) {}
  }

  // ------------------------------------------------------------ quotes

  List<Doc>? _feed;
  // Daily counters belong to the account, not to the phone: each account has its own.
  String _dayKey(String k) => '$k:${uid.isEmpty ? 'guest' : uid}:${Store.today}';
  int _count(String k) => _p.getInt(_dayKey(k)) ?? 0;
  void _bump(String k) => _p.setInt(_dayKey(k), _count(k) + 1);
  int get quotesLeft => 10 - _count('q');
  bool get plus => profile['plus'] == true;

  /// Subscribers may remove the closing mark «،.🪶» when copying. Stored on the account.
  bool get noMark => plus && profile['noMark'] == true;

  Future<bool> setNoMark(bool v) async {
    if (!signedIn || !plus) return false;
    try {
      await _db.collection('users').doc(uid).update({'noMark': v});
      profile['noMark'] = v;
      _cacheProfile();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

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
      if (of != null) return _docs(await _db.collection('quotes').where('uid', isEqualTo: of).limit(60).get()).where(_notSharh).toList();
      if (_feed != null && !refresh) return _feed!;
      return _feed = _docs(await _db.collection('quotes').orderBy('at', descending: true).limit(30).get()).where(_notSharh).toList();
    } catch (_) {
      return _feed ?? [];
    }
  }

  // Readers' explanations live beside the quotes, marked «sharh», and stay out of the quote lists.
  static bool _notSharh(Doc d) => d['kind'] != 'sharh';

  /// Whether this account carries a badge (the developer carries them all).
  bool hasTitle(String t) => isDev || ((grants['titles'] as List?)?.contains(t) ?? false);

  /// An explanation of one verse, by a reader who carries «الشارح».
  /// While he also carries «تحت التجربة», only he and the developer see it.
  Future<String?> publishSharh(Poem p, int verse, String text) async {
    if (!signedIn) return 'ادخل بحسابك أولاً.';
    if (!hasTitle('الشارح')) return 'الشرح لمن يحمل شارة «الشارح».';
    if (!canPost) return 'حسابك موقوف عن النشر.';
    if (text.trim().length < 10) return 'اكتب شرحاً أوفى.';
    final l = p.lines[verse];
    try {
      await _db.collection('quotes').add({
        'kind': 'sharh',
        'uid': uid,
        'name': name,
        'publicId': publicId,
        'poem': p.id,
        'v': verse,
        'a': l[0],
        'b': l.length > 1 ? l[1] : '',
        'poet': p.poet,
        'text': text.trim(),
        'trial': !isDev && hasTitle('تحت التجربة'),
        'hue': profile['hue'] ?? 0,
        'mark': mark,
        'titles': grants['titles'] ?? [],
        'likes': 0,
        'at': _now,
      });
      return null;
    } catch (_) {
      return 'تعذّر النشر. تحقّق من الإنترنت.';
    }
  }

  /// Trial explanations the developer accepted (kept with the app's settings, which everyone reads).
  List<String> get acceptedSharh => _p.getStringList('acceptedSharh') ?? [];
  bool sharhOnTrial(Doc x) => x['trial'] == true && !acceptedSharh.contains(x['id']);
  List<Doc> _visibleSharh(List<Doc> l) => [for (final x in l) if (!sharhOnTrial(x) || isDev || x['uid'] == uid) x];

  Future<List<Doc>> sharhOf(int poemId) async {
    if (!ready) return [];
    try {
      return _visibleSharh(_docs(await _db.collection('quotes').where('kind', isEqualTo: 'sharh').where('poem', isEqualTo: poemId).limit(60).get()));
    } catch (_) {
      return [];
    }
  }

  Future<List<Doc>> sharhBy(String userUid) async {
    if (!ready) return [];
    try {
      return _visibleSharh(_docs(await _db.collection('quotes').where('kind', isEqualTo: 'sharh').where('uid', isEqualTo: userUid).limit(100).get()));
    } catch (_) {
      return [];
    }
  }

  /// The developer accepts a trial explanation: everyone sees it from then on.
  void acceptSharh(String id) {
    _p.setStringList('acceptedSharh', {...acceptedSharh, id}.toList());
    notifyListeners();
    _schedulePush();
  }

  Future<String?> publishQuote(Poem p, int verse) async {
    if (!signedIn) return 'ادخل بحسابك أولاً.';
    if (!canPost) return banned ? 'حسابك محظور عن النشر.${blockReason.isEmpty ? '' : '\nالسبب: $blockReason'}' : 'حسابك موقوف مؤقتاً عن النشر.${blockReason.isEmpty ? '' : '\nالسبب: $blockReason'}';
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
        'hue': profile['hue'] ?? 0,
        'mark': mark,
        'titles': grants['titles'] ?? [],
        'likes': 0,
        'at': _now,
      };
      final ref = await _db.collection('quotes').add(data);
      _bump('q');
      _feed?.insert(0, {...data, 'id': ref.id});
      _wall?.insert(0, {...data, 'id': ref.id});
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
      _wall?.removeWhere((x) => x['id'] == id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ «قوافي»: the wall of verses

  List<Doc>? _wall;
  DocumentSnapshot<Map<String, dynamic>>? _wallLast;
  bool wallEnd = false;

  /// The newest posts (quotes and members' own poems), forty at a time.
  Future<List<Doc>> wall({bool refresh = false, bool more = false}) async {
    if (!ready) return _wall ?? [];
    if (_wall != null && !refresh && !more) return _wall!;
    if (more && wallEnd) return _wall ?? [];
    try {
      var q = _db.collection('quotes').orderBy('at', descending: true).limit(40);
      if (more && _wallLast != null) q = q.startAfterDocument(_wallLast!);
      final snap = await q.get();
      final docs = [
        for (final d in snap.docs)
          if (d.data()['kind'] != 'sharh') {...d.data(), 'id': d.id}
      ];
      if (snap.docs.isNotEmpty) _wallLast = snap.docs.last;
      wallEnd = snap.docs.length < 40;
      _wall = more ? [...?_wall, ...docs] : docs;
      return _wall!;
    } catch (_) {
      return _wall ?? [];
    }
  }

  /// Two poems of one's own a day (the developer has no limit).
  /// A verified poet may post five of his own poems a day, others two.
  int get ownMax => isDev ? 99 : (hasTitle('شاعر موثّق') ? 5 : 2);
  int get ownLeft => ownMax - _count('own');

  Future<String?> publishOwn({required String title, required List<List<String>> lines, String meter = '', String purpose = ''}) async {
    if (!signedIn) return 'ادخل بحسابك أولاً.';
    if (!canPost) return banned ? 'حسابك محظور عن النشر.' : 'حسابك موقوف مؤقتاً عن النشر.';
    if (ownLeft <= 0) return 'تنشر قصيدتين في اليوم. عُد غداً.';
    try {
      final data = <String, dynamic>{
        'uid': uid,
        'name': name,
        'publicId': publicId,
        'kind': 'own',
        'title': title.trim(),
        'lines': [
          for (final l in lines) {'a': l[0].trim(), 'b': l.length > 1 ? l[1].trim() : ''}
        ],
        'a': lines.first[0].trim(),
        'b': lines.first.length > 1 ? lines.first[1].trim() : '',
        'poet': name,
        'hue': profile['hue'] ?? 0,
        'mark': mark,
        'titles': grants['titles'] ?? [],
        'meter': meter,
        'purpose': purpose,
        'likes': 0,
        'at': _now,
      };
      final ref = await _db.collection('quotes').add(data);
      _bump('own');
      final doc = {...data, 'id': ref.id};
      _feed?.insert(0, doc);
      _wall?.insert(0, doc);
      notifyListeners();
      return null;
    } catch (_) {
      return 'تعذّر النشر. تحقّق من الإنترنت.';
    }
  }

  void forgetPost(String id) {
    _wall?.removeWhere((x) => x['id'] == id);
    _feed?.removeWhere((x) => x['id'] == id);
    notifyListeners();
  }

  /// What the reader writes on his own page: bio, country, poets, verse, colour.
  Future<bool> setProfile(Map<String, dynamic> data) async {
    if (!signedIn) return false;
    try {
      await _db.collection('users').doc(uid).update(data);
      profile.addAll(data);
      _cacheProfile();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Doc?> userByUid(String id) async {
    if (!signedIn || id.isEmpty) return null;
    if (id == uid) return {...profile, 'uid': uid};
    try {
      final u = await _db.collection('users').doc(id).get();
      return u.exists ? {...u.data()!, 'uid': u.id} : null;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ reports

  Future<bool> report(String kind, String target, String text, {String ofUid = ''}) async {
    if (!signedIn) return false;
    try {
      await _db.collection('reports').add({'kind': kind, 'target': target, 'text': text, 'ofUid': ofUid, 'by': uid, 'byName': name, 'byTitles': grants['titles'] ?? [], 'at': _now});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Doc>> reports() async {
    try {
      return _docs(await _db.collection('reports').orderBy('at', descending: true).limit(200).get());
    } catch (_) {
      return [];
    }
  }

  /// Closing a report moves it to the archive; it is deleted only from there.
  Future<void> closeReport(String id, {bool closed = true}) async {
    try {
      await _db.collection('reports').doc(id).update({'closed': closed, 'closedAt': _now});
    } catch (_) {}
  }

  Future<void> deleteReport(String id) async {
    try {
      await _db.collection('reports').doc(id).delete();
    } catch (_) {}
  }

  /// Readers whose reports no longer reach the main list (false reports).
  List<String> get mutedReporters => _p.getStringList('mutedReporters') ?? [];
  void muteReporter(String userUid, bool on) {
    if (userUid.isEmpty) return;
    final l = mutedReporters;
    on ? l.add(userUid) : l.remove(userUid);
    _p.setStringList('mutedReporters', l.toSet().toList());
    notifyListeners();
    _schedulePush();
  }

  /// Members whose posts this reader chose not to see (kept on this phone).
  List<String> get hiddenAuthors => _p.getStringList('hiddenAuthors') ?? [];
  void hideAuthor(String userUid, bool on) {
    if (userUid.isEmpty) return;
    final l = hiddenAuthors;
    on ? l.add(userUid) : l.remove(userUid);
    _p.setStringList('hiddenAuthors', l.toSet().toList());
    notifyListeners();
  }

  /// One reader's numbers on the shared board (golden verses, quiz, duels).
  Future<Doc> boardOf(String userUid) async {
    try {
      return (await _db.collection('board').doc(userUid).get()).data() ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Everyone who carries a badge.
  Future<List<Doc>> usersWithTitle(String title) async {
    try {
      return _docs(await _db.collection('users').where('grants.titles', arrayContains: title).limit(100).get());
    } catch (_) {
      return [];
    }
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
    if (grants['noMsg'] == true) return 'أُوقفت مراسلتك للمطوّر.';
    // Counted on the account itself, whatever phone it is opened from.
    final now = DateTime.now(), dayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final sent = (await myMessages()).where((m) => (m['kind'] ?? 'message') == kind && ((m['at'] ?? 0) as num) >= dayStart).length;
    _p.setInt(_dayKey(counter), sent);
    if (!isDev && sent >= (kind == 'message' ? messagesLimit : 1)) {
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

  /// The messages of one reader (for the developer's conversation with him).
  Future<List<Doc>> messagesOf(String uid) async {
    // Same query the developer's list uses, filtered here by the reader's id.
    final all = await allMessages();
    return [for (final m in all) if ('${m['uid']}' == uid) m];
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
  void follow(String id, String name, bool on, {String ofUid = ''}) {
    final f = following;
    on ? f[id] = name : f.remove(id);
    _p.setString('following', jsonEncode(f));
    notifyListeners();
    if (signedIn && ofUid.isNotEmpty) {
      _db.collection('users').doc(uid).update({
        'following': on ? FieldValue.arrayUnion([ofUid]) : FieldValue.arrayRemove([ofUid])
      }).then((_) {
        final l = [...(profile['following'] as List? ?? [])];
        on ? l.add(ofUid) : l.remove(ofUid);
        profile['following'] = l.toSet().toList();
        _cacheProfile();
      }).catchError((_) {});
    }
  }

  /// How many readers follow this account.
  Future<int> followersCount(String ofUid) async {
    try {
      return (await _db.collection('users').where('following', arrayContains: ofUid).count().get()).count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Doc>> followers(String ofUid) async {
    try {
      final q = await _db.collection('users').where('following', arrayContains: ofUid).limit(100).get();
      return [
        for (final d in q.docs) {...d.data(), 'uid': d.id}
      ];
    } catch (_) {
      return [];
    }
  }

  Future<List<Doc>> usersByUid(List<String> uids) async {
    final out = <Doc>[];
    try {
      for (var i = 0; i < uids.length && i < 90; i += 30) {
        final q = await _db.collection('users').where(FieldPath.documentId, whereIn: uids.sublist(i, min(i + 30, uids.length))).get();
        out.addAll([
          for (final d in q.docs) {...d.data(), 'uid': d.id}
        ]);
      }
    } catch (_) {}
    return out;
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
      return _docs(await _db.collection('tests').where('students', arrayContains: uid).limit(40).get()).where((t) => t['kind'] == null).toList();
    } catch (_) {
      return [];
    }
  }

  /// Tests I sent (as a teacher), with the students' results.
  Future<List<Doc>> sentTests() async {
    if (!signedIn) return [];
    try {
      return _docs(await _db.collection('tests').where('teacher', isEqualTo: uid).limit(40).get()).where((t) => t['kind'] == null).toList();
    } catch (_) {
      return [];
    }
  }

  /// [errors]: where the student went wrong, for the teacher: [{v, w, c}] (verse, written, correct).
  Future<bool> submitResult(String testId, int right, int total, {List<Map<String, dynamic>>? errors}) async {
    if (!signedIn) return false;
    try {
      await _db.collection('tests').doc(testId).update({
        'results.$uid': {'name': name, 'publicId': publicId, 'r': right, 't': total, 'at': _now, if (errors != null) 'errors': errors.take(40).toList()}
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

  /// The registered readers for the developer's statistics page, sorted by [field]
  /// (joined = newest first, lastAt / lastDay = last seen first, points = most active first).
  Future<List<Doc>> members(String field, {int limit = 100}) async {
    if (!isDev) return [];
    try {
      final q = await _db.collection('users').orderBy(field, descending: true).limit(limit).get();
      return [
        for (final d in q.docs) {...d.data(), 'uid': d.id}
      ];
    } catch (_) {
      return [];
    }
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
        await c(u.where('lastDay', isGreaterThanOrEqualTo: Store.today - 29)),
        await c(u.where('joinedDay', isEqualTo: Store.today)),
        await c(u.where('joinedDay', isGreaterThanOrEqualTo: Store.today - 29)),
      ];
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ warnings, suspension and bans

  Map<String, dynamic> get grants => Map<String, dynamic>.from(profile['grants'] as Map? ?? {});
  bool get suspended => ((grants['until'] ?? 0) as num) > _now;
  bool get canPost => !banned && !suspended;
  String get blockReason => '${grants['reason'] ?? ''}';
  List<Map> get warns => [for (final w in grants['warns'] as List? ?? []) w as Map];
  List<String> get bannedDevices => _p.getStringList('bannedDevices') ?? [];
  bool get deviceBanned => ready && bannedDevices.contains(deviceId);

  /// Supervisors: email → what they may do («حظر», «رسائل», «مراجعة», «توثيق»).
  Map<String, dynamic> get mods => Map<String, dynamic>.from(jsonDecode(_p.getString('mods') ?? '{}') as Map);
  /// May this account show and hide the verses a scholar cited? Either for every scholar or for this one.
  bool canShahid(String scholar) => isDev || (Library.verseBooks.containsKey(scholar) ? can('كتب الشعر') : (can('شواهد') || can('شواهد: $scholar')));

  /// Shows a cited verse to readers (1), puts it away (-1) or returns it to the draft (0).
  /// Sent as one small change, so two supervisors working together do not undo each other.
  Future<bool> setShahid(String id, int state) async {
    final before = Store.i.shShown.contains(id) ? 1 : (Store.i.shHidden.contains(id) ? -1 : 0);
    Store.i.setShahid(id, state);
    try {
      await _db.collection('config').doc('marks').update({
        'shShown': state > 0 ? FieldValue.arrayUnion([id]) : FieldValue.arrayRemove([id]),
        'shHidden': state < 0 ? FieldValue.arrayUnion([id]) : FieldValue.arrayRemove([id]),
      }).timeout(const Duration(seconds: 15));
      logMod(state > 0 ? 'إظهار' : (state < 0 ? 'إخفاء مقطع' : 'إعادة إلى المسودة'), 's:$id', _pieceText(id));
      return true;
    } catch (_) {
      Store.i.setShahid(id, before);
      return false;
    }
  }

  /// A supervisor is known by his email, or by his account when the developer chose him from his page.
  bool can(String what) {
    if (isDev) return true;
    if (!signedIn) return false;
    final m = mods;
    return ((m[user!.email] as List?)?.contains(what) ?? false) || ((m[uid] as List?)?.contains(what) ?? false);
  }

  /// Whether the editing tools show here: the developer with his tools opened, or a supervisor given this power.
  bool modCan(String what) => Store.i.developer || (!isDev && can(what));

  /// The names of the supervisors chosen from their pages: account → name.
  Map<String, dynamic> get modNames => Map<String, dynamic>.from(jsonDecode(_p.getString('modNames') ?? '{}') as Map);

  /// [who] is an email, or an account id (then [name] is kept to show beside it).
  void setMod(String who, List<String>? perms, {String? name}) {
    final key = who.contains('@') ? who.trim().toLowerCase() : who.trim();
    final m = mods;
    perms == null ? m.remove(key) : m[key] = perms;
    _p.setString('mods', jsonEncode(m));
    final n = modNames;
    if (perms == null) n.remove(key);
    if (perms != null && name != null && name.isNotEmpty) n[key] = name;
    _p.setString('modNames', jsonEncode(n));
    notifyListeners();
    _schedulePush();
  }

  // ------------------------------------------------------------ corrections, hiding, and the supervisors' log

  String _pieceText(String shahidId) {
    final x = Library.shahidOf(shahidId);
    return x == null || x.lines.isEmpty ? '' : x.lines.first.join(' … ');
  }

  /// Saves a correction of a piece (or takes it back when both are null) for every reader.
  /// One small write, so the developer and the supervisors do not undo each other.
  Future<bool> setEdit(String key, {String? poet, List<List<String>>? lines, String note = ''}) async {
    final before = Store.i.edits[key];
    Store.i.setEdit(key, poet: poet, lines: lines);
    try {
      final doc = _db.collection('config').doc('edits');
      if (poet == null && lines == null) {
        await doc.update({FieldPath(['m', key]): FieldValue.delete(), 'at': _now}).timeout(const Duration(seconds: 15));
      } else {
        // A list within a list is not stored by the server: the verses go as one text.
        await doc.set({
          'm': {
            key: {'poet': poet ?? '', 'l': jsonEncode(lines ?? const [])}
          },
          'at': _now,
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
      }
      logMod(poet == null && lines == null ? 'إرجاع الأصل' : 'تحرير', key, note);
      return true;
    } catch (_) {
      before == null ? Store.i.setEdit(key) : Store.i.setEdit(key, poet: before['poet'] as String?, lines: Store.linesOf(before['lines']));
      return false;
    }
  }

  /// A verse was hidden or shown again: the supervisor's own list on the server follows.
  void _hiddenChanged(String key, bool on, bool wasMod) {
    if (!ready || !signedIn) return;
    final mod = !isDev && can('إخفاء');
    if (!mod && !(isDev && !on && wasMod)) return;
    if (mod && on) Store.i.setModHidden({...Store.i.modHidden, key});
    _db.collection('config').doc('marks').update({'modHidden': on ? FieldValue.arrayUnion([key]) : FieldValue.arrayRemove([key])}).then((_) {}, onError: (_) {});
    if (mod) {
      final part = key.split(':');
      final p = part.length == 3 ? Library.byId[int.tryParse(part[1])] : null;
      final v = part.length == 3 ? (int.tryParse(part[2]) ?? 0) : 0;
      logMod(on ? 'إخفاء بيت' : 'إظهار بيت', key, p != null && v >= 1 && v <= p.lines.length ? p.lines[v - 1].join(' … ') : '');
    }
  }

  /// One line in the supervisors' log, for the developer to read. The developer's own work is not logged.
  void logMod(String what, String key, String text) {
    if (isDev || !signedIn) return;
    _db.collection('modlog').add({'uid': uid, 'email': user?.email ?? '', 'name': name, 'what': what, 'key': key, 'text': text.length > 160 ? text.substring(0, 160) : text, 'at': _now}).then((_) {}, onError: (_) {});
  }

  Future<List<Doc>> modLog() async {
    try {
      return _docs(await _db.collection('modlog').orderBy('at', descending: true).limit(400).get());
    } catch (_) {
      return [];
    }
  }

  void banDevice(String device, bool on) {
    if (device.isEmpty) return;
    final l = bannedDevices;
    on ? l.add(device) : l.remove(device);
    _p.setStringList('bannedDevices', l.toSet().toList());
    notifyListeners();
    _schedulePush();
  }

  Future<bool> _mod(String userUid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(userUid).update(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Badges the developer gives a reader («الشارح», «المقتبس»…). Kept in
  /// «grants», which only the developer and the supervisors may change.
  Future<bool> setTitles(String userUid, List<String> titles) => _mod(userUid, {'grants.titles': titles});

  /// «gold» for the developer, «blue» for a subscriber, '' otherwise.
  String get mark => isDev ? 'gold' : (plus ? 'blue' : '');

  /// A written warning: it reaches the reader in his messages.
  Future<bool> warnUser(String userUid, String text) => _mod(userUid, {
        'grants.warns': FieldValue.arrayUnion([
          {'text': text, 'at': _now}
        ]),
        'grants.nWarn': FieldValue.increment(1),
        'grants.inbox': FieldValue.arrayUnion([
          {'text': 'إنذار: $text', 'at': _now}
        ]),
      });
  Future<bool> suspendUser(String userUid, int days, String reason) =>
      _mod(userUid, {'grants.until': days <= 0 ? 0 : _now + days * 86400000, 'grants.reason': reason, 'grants.at': _now});
  Future<bool> banUser(String userUid, bool on, String reason) =>
      _mod(userUid, {'banned': on, 'grants.reason': reason, 'grants.at': _now, if (!on) 'grants.until': 0});
  Future<bool> setNoMsg(String userUid, bool on) => _mod(userUid, {'grants.noMsg': on});

  /// The developer writes first: it lands in the reader's messages.
  Future<bool> inboxSend(String userUid, String text) => _mod(userUid, {
        'grants.inbox': FieldValue.arrayUnion([
          {'text': text.trim(), 'at': _now}
        ])
      });

  /// 0 banned, 1 suspended now, 2 warned.
  Future<List<Doc>> flagged(int kind) async {
    try {
      final u = _db.collection('users');
      final q = await [
        u.where('banned', isEqualTo: true),
        u.where('grants.until', isGreaterThan: _now),
        u.where('grants.nWarn', isGreaterThan: 0),
      ][kind]
          .limit(200)
          .get();
      return [
        for (final d in q.docs) {...d.data(), 'uid': d.id}
      ];
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------ duels

  /// Creates a duel: both play the same five verses. Returns its id.
  Future<String?> newDuel(Doc opponent, List<(Poem, int)> picks) async {
    if (!signedIn) return null;
    try {
      final ref = await _db.collection('tests').add({
        'teacher': uid,
        'teacherName': name,
        'teacherPublicId': publicId,
        'students': ['${opponent['uid']}'],
        'oppName': '${opponent['name'] ?? 'قارئ'}',
        'oppPublicId': '${opponent['publicId'] ?? ''}',
        'kind': 'duel',
        'picks': [
          for (final x in picks) '${x.$1.id}:${x.$2}'
        ],
        'results': <String, dynamic>{},
        'at': _now,
      });
      return ref.id;
    } catch (_) {
      return null;
    }
  }

  Future<List<Doc>> duels() async {
    if (!signedIn) return [];
    try {
      final a = await _db.collection('tests').where('teacher', isEqualTo: uid).limit(40).get();
      final b = await _db.collection('tests').where('students', arrayContains: uid).limit(40).get();
      return [..._docs(a), ..._docs(b)].where((t) => t['kind'] == 'duel').toList()..sort((x, y) => ((y['at'] ?? 0) as num).compareTo((x['at'] ?? 0) as num));
    } catch (_) {
      return [];
    }
  }
}
