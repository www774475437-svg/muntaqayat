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

  /// The first full verse (two hemistichs) — used on cards.
  List<String> get firstVerse => lines.firstWhere((l) => l.length == 2, orElse: () => lines.first);

  bool get unattributed => poet == 'بلا نسبة';

  String get chapterName => Library.chapters[chapter].name;

  String get plainText => lines.map((l) => l.join(' ')).join(' ');
}

class Poet {
  final String name;
  final String era;
  final String death;
  final int count;
  Poet.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String,
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
  static List<Poem> poems = [];
  static final Map<int, Poem> byId = {};
  static final Map<String, Poet> poetByName = {};

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
    poems = [for (final p in j['poems'] as List) Poem.fromJson(p as Map<String, dynamic>)];
    byId
      ..clear()
      ..addEntries(poems.map((p) => MapEntry(p.id, p)));
    poetByName
      ..clear()
      ..addEntries(poets.map((p) => MapEntry(p.name, p)));
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

  bool isReviewed(int id) => reviewed.contains(id);
  void toggleReviewed(int id) {
    reviewed.contains(id) ? reviewed.remove(id) : reviewed.add(id);
    _p.setStringList('reviewed', reviewed.map((e) => '$e').toList());
    notifyListeners();
  }

  /// The text as the reader wants it (with or without tashkeel).
  String show(String s) => tashkeel ? s : Ar.plain(s);
}
