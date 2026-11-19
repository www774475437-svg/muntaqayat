import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// One selection from the book: one or more verses, its poet and its chapter.
class Poem {
  final int id;
  final int chapter;
  final int section;
  final int page;
  final List<List<String>> lines;
  final List<String> notes;
  final String poet;
  final String era;
  final String death;
  final String poetNote;
  final String rhyme;
  final List<String> flags;

  /// «ثابت» or «يُنسب» (empty for verses without a poet).
  final String status;

  /// 'book' = from the book; 'add' = added from outside the book.
  final String src;

  Poem.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        chapter = j['ch'] as int,
        section = j['sec'] as int,
        page = j['page'] as int,
        lines = [
          for (final l in (j['lines'] as List)) [for (final h in (l as List)) h as String]
        ],
        notes = [for (final n in (j['notes'] as List)) n as String],
        poet = j['poet'] as String,
        era = (j['era'] as String?) ?? '',
        death = (j['death'] as String?) ?? '',
        poetNote = (j['pnote'] as String?) ?? '',
        rhyme = (j['rhyme'] as String?) ?? '',
        flags = [for (final f in (j['flags'] as List)) f as String],
        status = (j['status'] as String?) ?? '',
        src = (j['src'] as String?) ?? 'book';

  /// Number of verses, counting a lone hemistich line as a verse.
  int get verseCount => lines.length;

  /// Verse numbers (1-based) the developer hid or deleted.
  bool hiddenVerse(int v) => Store.i.hidden.contains('p:$id:$v');
  bool deletedVerse(int v) => Store.i.deleted.contains('p:$id:$v');
  bool gone(int v) => hiddenVerse(v) || deletedVerse(v);
  bool verifiedVerse(int v) => Store.i.verified.contains('p:$id:$v');
  bool get anyVerified => [for (var v = 1; v <= lines.length; v++) v].any(verifiedVerse);
  bool get allGone => [for (var v = 1; v <= lines.length; v++) v].every(gone);
  bool get fromBook => src == 'book';

  /// What readers see: the verses that are not hidden.
  List<List<String>> get shown => [
        for (var i = 0; i < lines.length; i++)
          if (!gone(i + 1)) lines[i]
      ];

  /// The first full verse (two hemistichs) — used on cards.
  List<String> get firstVerse {
    final s = shown.isEmpty ? lines : shown;
    return s.firstWhere((l) => l.length == 2, orElse: () => s.first);
  }

  bool get unattributed => poet == 'بلا نسبة';

  String get chapterName => Library.chapters[chapter].name;

  String get plainText => lines.map((l) => l.join(' ')).join(' ');
}

class Poet {
  final String name;
  final String era;
  final String death;
  final int count;
  final String bio;
  final List<String> sources; // book names only, no links
  Poet.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String,
        bio = (j['bio'] as String?) ?? '',
        sources = [for (final x in (j['sources'] as List? ?? [])) x as String],
        era = (j['era'] as String?) ?? '',
        death = (j['death'] as String?) ?? '',
        count = j['count'] as int;

  /// First letter, shown in the round avatar.
  String get initial {
    var n = name.startsWith('ال') ? name.substring(2) : name;
    if (n.startsWith('إمام ')) n = n.substring(5);
    if (n.startsWith('ال')) n = n.substring(2);
    return n.isEmpty ? '؟' : String.fromCharCode(n.runes.first);
  }
}

/// A scholarly poem for memorizing («متون طالب العلم وقصائده»).
class Matn {
  final String id, title, author, death, branch, intro, source;
  final List<List<String>> lines;
  final Set<int> review; // verse numbers (1-based) still to be checked
  final Map<int, (String, String, bool)> notes; // verse → (scholar, text, important)
  final bool complete; // false → «غير كاملة»
  final Map<int, String> heads; // verse index (0-based) → section title
  final List<Map<String, String>> links; // explanations shipped with the app: {title,url}
  Matn.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        author = j['author'] as String,
        death = (j['death'] as String?) ?? '',
        branch = j['branch'] as String,
        intro = (j['intro'] as String?) ?? '',
        source = (j['source'] as String?) ?? '',
        lines = [
          for (final l in (j['lines'] as List)) [for (final h in (l as List)) h as String]
        ],
        review = {for (final r in (j['review'] as List? ?? [])) r as int},
        notes = {
          for (final e in ((j['notes'] as Map?) ?? {}).entries)
            int.parse(e.key as String): (
              (e.value as Map)['scholar'] as String,
              (e.value as Map)['text'] as String,
              ((e.value as Map)['important'] as bool?) ?? false
            )
        },
        complete = (j['complete'] as bool?) ?? true,
        links = [for (final x in (j['shuruh'] as List? ?? [])) Map<String, String>.from(x as Map)],
        heads = {
          for (final h in (j['heads'] as List? ?? [])) ((h as List)[0] as num).toInt(): h[1] as String
        };
  bool get ready => lines.isNotEmpty;

  /// Whether the text carries tashkeel (checked on its first verses).
  late final bool vocalized = () {
    final t = lines.take(6).map((l) => l.join()).join();
    if (t.isEmpty) return true;
    return RegExp('[\u064B-\u0652]').allMatches(t).length / t.length > 0.12;
  }();
}

/// A verse a scholar quoted in one of his books («مما استشهد به العلماء»).
class Shahid {
  final String scholar, book, vol, page, poet, url;
  final List<List<String>> lines;
  Shahid.fromJson(Map<String, dynamic> j)
      : scholar = j['scholar'] as String,
        book = j['book'] as String,
        vol = (j['vol'] as String?) ?? '',
        page = (j['page'] as String?) ?? '',
        poet = (j['poet'] as String?) ?? '',
        url = (j['url'] as String?) ?? '',
        lines = [
          for (final l in (j['lines'] as List)) [for (final h in (l as List)) h as String]
        ];
}

class Chapter {
  final int index;
  final String name;
  final int section;
  Chapter(this.index, this.name, this.section);
}

/// Everything from the book, loaded once from assets.
class Library {
  static String book = '';
  static String author = '';
  static List<String> sections = [];
  static List<Chapter> chapters = [];
  static List<String> eras = [];
  static List<Poet> poets = [];
  static List<Poem> poems = []; // what readers see (without fully hidden selections)
  static List<Poem> all = [];
  static final Map<int, Poem> byId = {};

  /// Re-applies the developer's hidden / deleted marks.
  static void refresh() => poems = all.where((p) => !p.allGone).toList();
  static List<Poem> get bookPoems => poems.where((p) => p.fromBook).toList();
  static List<Poem> get verifiedPoems => poems.where((p) => p.anyVerified).toList();
  static final Map<String, Poet> poetByName = {};
  static List<String> branches = [];
  static List<Matn> mutun = [];
  static List<String> shawahidScholars = [];
  static List<Shahid> shawahid = [];

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/data/poems.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    book = j['book'] as String;
    author = j['author'] as String;
    sections = [for (final s in j['sections'] as List) s as String];
    final ch = j['chapters'] as List;
    chapters = [
      for (var i = 0; i < ch.length; i++)
        Chapter(i, (ch[i] as Map)['name'] as String, (ch[i] as Map)['sec'] as int)
    ];
    eras = [for (final e in j['eras'] as List) e as String];
    poets = [for (final p in j['poets'] as List) Poet.fromJson(p as Map<String, dynamic>)];
    all = [for (final p in j['poems'] as List) Poem.fromJson(p as Map<String, dynamic>)];
    poems = all;
    byId
      ..clear()
      ..addEntries(poems.map((p) => MapEntry(p.id, p)));
    poetByName
      ..clear()
      ..addEntries(poets.map((p) => MapEntry(p.name, p)));
    final m = jsonDecode(await rootBundle.loadString('assets/data/mutun.json')) as Map<String, dynamic>;
    branches = [for (final b in m['branches'] as List) b as String];
    mutun = [for (final x in m['mutun'] as List) Matn.fromJson(x as Map<String, dynamic>)];
    final sh = jsonDecode(await rootBundle.loadString('assets/data/shawahid.json')) as Map<String, dynamic>;
    shawahidScholars = [for (final x in sh['scholars'] as List) x as String];
    shawahid = [for (final x in sh['items'] as List) Shahid.fromJson(x as Map<String, dynamic>)];
  }

  static List<Poem> ofPoet(String name) => poems.where((p) => p.poet == name).toList();
  static List<Poem> ofEra(String era) => poems.where((p) => p.era == era).toList();
  static List<Poem> ofChapter(int c) => poems.where((p) => p.chapter == c).toList();
  static List<Poem> ofRhyme(String r) => poems.where((p) => p.rhyme == r).toList();

  /// Named poets only (without «بلا نسبة»), most selections first.
  static List<Poet> get namedPoets => poets.where((p) => p.name != 'بلا نسبة').toList();

  static int _dayIndex([DateTime? d]) {
    final n = d ?? DateTime.now();
    return DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(2024, 1, 1)).inDays;
  }

  /// The verse of the day: same for everyone on the same day.
  static Poem poemOfDay([DateTime? day]) {
    final full = poems.where((p) => p.lines.isNotEmpty && p.lines.first.length == 2 && p.flags.isEmpty).toList();
    final list = full.isEmpty ? poems : full;
    return list[(_dayIndex(day) * 37) % list.length];
  }

  static int chapterNamed(String name) => chapters.indexWhere((c) => c.name == name);

  /// Selections added from outside the book (scholars and Companions).
  static List<Poem> get additions => poems.where((p) => p.src == 'add').toList();

  static Poet poetOfDay() {
    final list = namedPoets.where((p) => p.count >= 2).toList();
    return list[(_dayIndex() * 13) % list.length];
  }

  /// A stable daily shuffle (different every day).
  static List<Poem> dailyPicks(int n, {int salt = 1}) {
    final d = _dayIndex();
    final list = [...poems]..sort((a, b) => ((a.id * 7919 + d * salt) % 997).compareTo((b.id * 7919 + d * salt) % 997));
    return list.take(n).toList();
  }

  /// Related selections: same chapter first, then same poet.
  static List<Poem> related(Poem p, {int n = 4}) {
    final same = poems.where((x) => x.chapter == p.chapter && x.id != p.id).toList();
    final poet = p.unattributed ? <Poem>[] : poems.where((x) => x.poet == p.poet && x.id != p.id && x.chapter != p.chapter).toList();
    return [...same, ...poet].take(n).toList();
  }
}

/// Arabic text helpers.
class Ar {
  static final _marks = RegExp('[ً-ٰٟۡؐ-ؚـ]');

  /// Without tashkeel (for display when the reader hides it).
  static String plain(String s) => s.replaceAll(_marks, '');

  /// For searching: no marks, unified alef / ya / ta marbuta.
  static String norm(String s) => plain(s)
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .toLowerCase();

  static const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  static String num(int n) => n.toString().split('').map((c) => _digits[int.parse(c)]).join();

  static String verses(int n) {
    if (n == 1) return 'بيت واحد';
    if (n == 2) return 'بيتان';
    if (n <= 10) return '${num(n)} أبيات';
    return '${num(n)} بيتاً';
  }

  static String selections(int n) {
    if (n == 1) return 'مقطع واحد';
    if (n == 2) return 'مقطعان';
    if (n <= 10) return '${num(n)} مقاطع';
    return '${num(n)} مقطعاً';
  }
}

/// The reader's own things, kept on this device.
class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();
  late SharedPreferences _p;

  Set<int> likes = {};
  Set<String> followed = {};
  Map<String, List<int>> collections = {};
  Map<int, int> reads = {};
  Set<int> reviewed = {};
  List<String> recent = [];
  int lastRead = 0;
  int themeMode = 0; // 0 = phone, 1 = light, 2 = dark
  double fontScale = 1.0;
  bool tashkeel = true;
  bool developer = false;
  bool morning = false;
  int morningHour = 7;
  int morningMinute = 0;
  Set<String> days = {};
  Map<String, Set<int>> memorized = {};
  int wird = 5;
  Set<String> hidden = {}; // developer: hidden verses, p:ID:v
  Set<String> deleted = {}; // developer: removed for good
  List<String> seen = []; // challenge: verses already asked, 'id:line'
  Map<String, String> studentNames = {}; // teacher: personal number → name
  List<Map<String, dynamic>> testLog = []; // teacher: tests he sent
  Set<String> verified = {}; // developer «توثيق» marks: p:ID, p:ID:v, m:ID, m:ID:v
  Map<String, List<int>> memLog = {}; // 'matn:verse' → [epoch day of last review, stage]
  Map<String, int> best = {}; // matn → best writing-test score out of 10 (whole matn)
  String certName = '';
  int repeat = 3;
  Map<String, String> myNotes = {}; // the reader's own note on a selection (by id)
  Map<String, dynamic> majlis = {}; // daily challenge: points, days, weeks, title
  /// Set by the cloud service: sends the developer's marks and settings to everyone.
  static void Function()? cloudPush;
  String payLink = '';
  bool plusOn = true; // developer switch: show «منتقيات+» to non-subscribers
  bool teacher = false; // «خانة المعلّم» turned on in settings
  List<String> students = []; // personal numbers the teacher added before
  Map<String, List<Map<String, String>>> shuruh = {}; // matn → [{title,url}] added by the developer

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    likes = (_p.getStringList('likes') ?? []).map(int.parse).toSet();
    followed = (_p.getStringList('followed') ?? []).toSet();
    reviewed = (_p.getStringList('reviewed') ?? []).map(int.parse).toSet();
    recent = _p.getStringList('recent') ?? [];
    days = (_p.getStringList('days') ?? []).toSet();
    lastRead = _p.getInt('lastRead') ?? 0;
    themeMode = _p.getInt('themeMode') ?? 0;
    fontScale = _p.getDouble('fontScale') ?? 1.0;
    tashkeel = _p.getBool('tashkeel') ?? true;
    developer = _p.getBool('developer') ?? false;
    morning = _p.getBool('morning') ?? false;
    morningHour = _p.getInt('morningHour') ?? 7;
    morningMinute = _p.getInt('morningMinute') ?? 0;
    wird = _p.getInt('wird') ?? 5;
    verified = (_p.getStringList('verified') ?? []).toSet();
    hidden = (_p.getStringList('hidden') ?? []).toSet();
    deleted = (_p.getStringList('deleted') ?? []).toSet();
    seen = _p.getStringList('seen') ?? [];
    try {
      studentNames = Map<String, String>.from(jsonDecode(_p.getString('studentNames') ?? '{}') as Map);
      testLog = [for (final x in jsonDecode(_p.getString('testLog') ?? '[]') as List) Map<String, dynamic>.from(x as Map)];
    } catch (_) {}
    certName = _p.getString('certName') ?? '';
    repeat = _p.getInt('repeat') ?? 3;
    plusOn = _p.getBool('plusOn') ?? true;
    payLink = _p.getString('payLink') ?? '';
    try {
      myNotes = Map<String, String>.from(jsonDecode(_p.getString('myNotes') ?? '{}') as Map);
      majlis = jsonDecode(_p.getString('majlis') ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    teacher = _p.getBool('teacher') ?? false;
    students = _p.getStringList('students') ?? [];
    try {
      final ml = jsonDecode(_p.getString('memLog') ?? '{}') as Map<String, dynamic>;
      memLog = ml.map((k, v) => MapEntry(k, [for (final x in v as List) (x as num).toInt()]));
      final b = jsonDecode(_p.getString('best') ?? '{}') as Map<String, dynamic>;
      best = b.map((k, v) => MapEntry(k, (v as num).toInt()));
      final sh = jsonDecode(_p.getString('shuruh') ?? '{}') as Map<String, dynamic>;
      shuruh = sh.map((k, v) => MapEntry(k, [for (final x in v as List) Map<String, String>.from(x as Map)]));
    } catch (_) {}
    try {
      final mm = jsonDecode(_p.getString('memorized') ?? '{}') as Map<String, dynamic>;
      memorized = mm.map((k, v) => MapEntry(k, {for (final x in v as List) x as int}));
    } catch (_) {}
    try {
      final c = jsonDecode(_p.getString('collections') ?? '{}') as Map<String, dynamic>;
      collections = c.map((k, v) => MapEntry(k, [for (final x in v as List) x as int]));
      final r = jsonDecode(_p.getString('reads') ?? '{}') as Map<String, dynamic>;
      reads = r.map((k, v) => MapEntry(int.parse(k), v as int));
    } catch (_) {}
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (days.add(today)) await _p.setStringList('days', days.toList());
  }

  bool liked(int id) => likes.contains(id);
  void toggleLike(int id) {
    likes.contains(id) ? likes.remove(id) : likes.add(id);
    _p.setStringList('likes', likes.map((e) => '$e').toList());
    notifyListeners();
  }

  bool follows(String poet) => followed.contains(poet);
  void toggleFollow(String poet) {
    followed.contains(poet) ? followed.remove(poet) : followed.add(poet);
    _p.setStringList('followed', followed.toList());
    notifyListeners();
  }

  void opened(int id) {
    reads[id] = (reads[id] ?? 0) + 1;
    lastRead = id;
    _p.setString('reads', jsonEncode(reads.map((k, v) => MapEntry('$k', v))));
    _p.setInt('lastRead', id);
    notifyListeners();
  }

  void _saveCollections() => _p.setString('collections', jsonEncode(collections));

  void createCollection(String name) {
    collections.putIfAbsent(name, () => []);
    _saveCollections();
    notifyListeners();
  }

  void deleteCollection(String name) {
    collections.remove(name);
    _saveCollections();
    notifyListeners();
  }

  void toggleIn(String name, int id) {
    final l = collections.putIfAbsent(name, () => []);
    l.contains(id) ? l.remove(id) : l.add(id);
    _saveCollections();
    notifyListeners();
  }

  void addRecent(String q) {
    q = q.trim();
    if (q.isEmpty) return;
    recent
      ..remove(q)
      ..insert(0, q);
    if (recent.length > 8) recent = recent.sublist(0, 8);
    _p.setStringList('recent', recent);
  }

  void clearRecent() {
    recent = [];
    _p.setStringList('recent', recent);
    notifyListeners();
  }

  void setTheme(int m) {
    themeMode = m;
    _p.setInt('themeMode', m);
    notifyListeners();
  }

  void setFontScale(double v) {
    fontScale = v;
    _p.setDouble('fontScale', v);
    notifyListeners();
  }

  void setTashkeel(bool v) {
    tashkeel = v;
    _p.setBool('tashkeel', v);
    notifyListeners();
  }

  void setDeveloper(bool v) {
    developer = v;
    _p.setBool('developer', v);
    notifyListeners();
  }

  void setMorning(bool on, int hour, int minute) {
    morning = on;
    morningHour = hour;
    morningMinute = minute;
    _p.setBool('morning', on);
    _p.setInt('morningHour', hour);
    _p.setInt('morningMinute', minute);
    notifyListeners();
  }

  Set<int> memOf(String matn) => memorized[matn] ?? <int>{};
  void setMemorized(String matn, int verse, bool on) {
    final s = memorized.putIfAbsent(matn, () => <int>{});
    on ? s.add(verse) : s.remove(verse);
    if (on) {
      memLog.putIfAbsent('$matn:$verse', () => [today, 0]);
    } else {
      memLog.remove('$matn:$verse');
    }
    _p.setString('memorized', jsonEncode(memorized.map((k, v) => MapEntry(k, v.toList()))));
    _p.setString('memLog', jsonEncode(memLog));
    notifyListeners();
  }

  /// Days since 2024-01-01 (local calendar day).
  static int get today {
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(2024, 1, 1)).inDays;
  }

  /// Smart review: after 1, 3, 7, 14, 30 then 60 days.
  static const intervals = [1, 3, 7, 14, 30, 60];

  /// Memorized verses whose review day has come.
  List<int> dueOf(String matn) {
    final out = <int>[];
    for (final v in memOf(matn)) {
      final l = memLog['$matn:$v'];
      if (l == null || today >= l[0] + intervals[l[1].clamp(0, intervals.length - 1)]) out.add(v);
    }
    return out..sort();
  }

  int get dueAll => [for (final m in memorized.keys) dueOf(m).length].fold(0, (a, b) => a + b);

  /// Result of reviewing a verse: remembered → next, longer step; forgot → back to the start.
  void reviewed1(String matn, int verse, bool remembered) {
    final l = memLog['$matn:$verse'] ?? [today, 0];
    memLog['$matn:$verse'] = [today, remembered ? (l[1] + 1).clamp(0, intervals.length - 1) : 0];
    _p.setString('memLog', jsonEncode(memLog));
    notifyListeners();
  }

  /// 0 = not memorized (grey), 1 = due for review (yellow), 2 = firm (green).
  int stateOf(String matn, int verse) {
    if (!memOf(matn).contains(verse)) return 0;
    final l = memLog['$matn:$verse'];
    if (l == null) return 1;
    return today >= l[0] + intervals[l[1].clamp(0, intervals.length - 1)] ? 1 : 2;
  }

  void setBest(String matn, int score) {
    if ((best[matn] ?? -1) >= score) return;
    best[matn] = score;
    _p.setString('best', jsonEncode(best));
    notifyListeners();
  }

  void setCertName(String v) {
    certName = v;
    _p.setString('certName', v);
  }

  void setRepeat(int n) {
    repeat = n;
    _p.setInt('repeat', n);
    notifyListeners();
  }

  String noteOf(int id) => myNotes['$id'] ?? '';
  void setNote(int id, String text) {
    text.trim().isEmpty ? myNotes.remove('$id') : myNotes['$id'] = text.trim();
    _p.setString('myNotes', jsonEncode(myNotes));
    notifyListeners();
  }

  void saveMajlis() {
    _p.setString('majlis', jsonEncode(majlis));
    notifyListeners();
  }

  void setPlusOn(bool v) {
    plusOn = v;
    _p.setBool('plusOn', v);
    notifyListeners();
    cloudPush?.call();
  }

  void setPayLink(String v) {
    payLink = v.trim();
    _p.setString('payLink', payLink);
    notifyListeners();
    cloudPush?.call();
  }

  /// What the developer set for everyone (marks, subscription switch, explanations).
  void applyCloud({List<String>? verified, List<String>? hidden, List<String>? deleted, bool? plus, String? payLink, Map<String, dynamic>? shuruh}) {
    if (verified != null) {
      this.verified = verified.toSet();
      _p.setStringList('verified', verified);
    }
    if (hidden != null) {
      this.hidden = hidden.toSet();
      _p.setStringList('hidden', hidden);
    }
    if (deleted != null) {
      this.deleted = deleted.toSet();
      _p.setStringList('deleted', deleted);
    }
    if (plus != null) {
      plusOn = plus;
      _p.setBool('plusOn', plus);
    }
    if (payLink != null) {
      this.payLink = payLink;
      _p.setString('payLink', payLink);
    }
    if (shuruh != null) {
      this.shuruh = {
        for (final e in shuruh.entries) e.key: [for (final x in e.value as List) Map<String, String>.from(x as Map)]
      };
      _p.setString('shuruh', jsonEncode(this.shuruh));
    }
    Library.refresh();
    notifyListeners();
  }

  void setTeacher(bool v) {
    teacher = v;
    _p.setBool('teacher', v);
    notifyListeners();
  }

  void addStudents(Iterable<String> ids) {
    for (final id in ids) {
      if (!students.contains(id)) students.add(id);
    }
    _p.setStringList('students', students);
    notifyListeners();
  }

  void removeStudent(String id) {
    students.remove(id);
    _p.setStringList('students', students);
    notifyListeners();
  }

  void setHidden(String key, bool on) {
    on ? hidden.add(key) : hidden.remove(key);
    _p.setStringList('hidden', hidden.toList());
    Library.refresh();
    notifyListeners();
    cloudPush?.call();
  }

  /// Removes a hidden verse for good (it leaves the hidden list too).
  void deleteForGood(String key) {
    hidden.remove(key);
    verified.remove(key);
    deleted.add(key);
    _p.setStringList('hidden', hidden.toList());
    _p.setStringList('verified', verified.toList());
    _p.setStringList('deleted', deleted.toList());
    Library.refresh();
    notifyListeners();
    cloudPush?.call();
  }

  void markSeen(Iterable<String> keys, {bool reset = false}) {
    if (reset) seen = [];
    seen.addAll(keys);
    _p.setStringList('seen', seen);
  }

  void setStudentName(String id, String name) {
    name.trim().isEmpty ? studentNames.remove(id) : studentNames[id] = name.trim();
    _p.setString('studentNames', jsonEncode(studentNames));
    notifyListeners();
  }

  void logTest(Map<String, dynamic> t) {
    testLog.insert(0, t);
    if (testLog.length > 200) testLog.removeLast();
    _p.setString('testLog', jsonEncode(testLog));
    notifyListeners();
  }

  bool isVerified(String key) => verified.contains(key);
  void toggleVerified(String key) {
    verified.contains(key) ? verified.remove(key) : verified.add(key);
    _p.setStringList('verified', verified.toList());
    notifyListeners();
    cloudPush?.call();
  }

  List<Map<String, String>> shuruhOf(String matn) => shuruh[matn] ?? const [];
  void addSharh(String matn, String title, String url) {
    shuruh.putIfAbsent(matn, () => []).add({'title': title, 'url': url});
    _p.setString('shuruh', jsonEncode(shuruh));
    notifyListeners();
    cloudPush?.call();
  }

  void removeSharh(String matn, int i) {
    shuruh[matn]?.removeAt(i);
    _p.setString('shuruh', jsonEncode(shuruh));
    notifyListeners();
    cloudPush?.call();
  }

  void setWird(int n) {
    wird = n;
    _p.setInt('wird', n);
    notifyListeners();
  }

  bool isReviewed(int id) => reviewed.contains(id);
  void toggleReviewed(int id) {
    reviewed.contains(id) ? reviewed.remove(id) : reviewed.add(id);
    _p.setStringList('reviewed', reviewed.map((e) => '$e').toList());
    notifyListeners();
  }

  /// The text as the reader wants it (with or without tashkeel).
  String show(String s) => tashkeel ? s : Ar.plain(s);
}
