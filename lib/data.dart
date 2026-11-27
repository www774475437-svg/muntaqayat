import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'services/likes.dart';

/// One selection from the book: one or more verses, its poet and its chapter.
class Poem {
  final int id;
  final int chapter;
  final int section;
  final int page;
  // The text, the poet and what follows from him can be corrected by the developer («تحرير»).
  List<List<String>> lines;
  final List<String> notes;
  String poet;
  String era;
  String death;
  final String poetNote;
  final String rhyme;
  final List<String> flags;

  /// «ثابت» or «يُنسب» (empty for verses without a poet).
  final String status;

  /// 'book' = from the book; 'add' = added from outside the book.
  final String src;

  /// For a verse a scholar cited, shown in the feed: who cited it and where.
  final String cite, citeScholar;

  /// Set for a piece shown from the citations or from «كتب الشعر»: the id of its [Shahid].
  final String shahidId;
  bool get fromShahid => shahidId.isNotEmpty;

  /// A piece the developer showed from the citations or from a book of verses, as a selection,
  /// so it stands in its era, its rhyme and the search beside the selections of the book.
  factory Poem.ofShahid(Shahid x) {
    final name = x.own ? x.scholar : (x.poet.isEmpty ? 'بلا نسبة' : x.poet);
    final poet = Library.poetByName[name];
    return Poem.fromJson({
      'id': Library.shahidNumber(x.id),
      'ch': 0,
      'sec': 0,
      'page': 0,
      'lines': x.lines,
      'notes': <String>[],
      'poet': name,
      'era': x.era.isNotEmpty ? x.era : (poet?.era ?? ''),
      'death': x.died.isNotEmpty ? x.died : (poet?.death ?? ''),
      'rhyme': Ar.rhymeOf(x.lines),
      'flags': <String>[],
      'src': 'shahid',
      'cite': x.citeLine,
      'citeScholar': x.scholar,
      'shahid': x.id,
    });
  }

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
        src = (j['src'] as String?) ?? 'book',
        cite = (j['cite'] as String?) ?? '',
        citeScholar = (j['citeScholar'] as String?) ?? '',
        shahidId = (j['shahid'] as String?) ?? '';

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

  /// The chapter of the book; for a piece shown from elsewhere, where it was taken from.
  String get chapterName => fromShahid ? cite : Library.chapters[chapter].name;

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
  final String id, scholar, book, edition, vol, page, by, url;
  String poet; // the developer can correct it («تحرير»)

  /// Set for a verse taken from a book of verses («نهاية الأرب»), not cited by a scholar.
  final String author, died, era;

  /// The scholar's own verse, found in his book: it stands under «من شعره», apart from what he cited.
  final bool own;
  List<List<String>> lines;

  /// A poet's own diwan: its pieces carry a line above them (title, occasion, meter).
  final String note;

  /// Where the same verses already stand in the app, when all of them do («المكررة»).
  final String dup;

  /// Verse number (1-based) → where that verse already stands.
  final Map<int, String> same;

  /// The editor's notes on its words: verse number (1-based) and the note, in the book's order.
  final List<(int, String)> sharh;

  /// A book whose commentary is kept in a file of its own, read when asked for: the file, and how the commentary begins.
  final String sharhAsset, sharhStart;
  bool get hasSharh => sharh.isNotEmpty || sharhStart.isNotEmpty;

  /// The whole commentary of this piece: (verse number, note); verse 0 is what stands before the first verse.
  Future<List<(int, String)>> fullSharh() async {
    if (sharh.isNotEmpty || sharhAsset.isEmpty) return sharh;
    final all = await (_sharhFiles[sharhAsset] ??= rootBundle.loadString(sharhAsset).then((t) => jsonDecode(t) as Map<String, dynamic>));
    return [for (final s in (all[id] as List? ?? [])) (((s as List)[0] as num).toInt(), s[1] as String)];
  }

  static final Map<String, Future<Map<String, dynamic>>> _sharhFiles = {};

  /// Why the supervisor should look at this piece before showing it (set when the gathering was unsure).
  final String chk;

  /// A one-volume book gives the page alone.
  final bool oneVol;

  /// A verse of a book whose verses were gathered: [key] is the book's short name.
  Shahid.ofBook(Map<String, dynamic> j, String key, this.author, this.edition, {this.oneVol = false, this.sharhAsset = ''})
      : id = j['id'] as String,
        scholar = key,
        vol = (j['vol'] as String?) ?? '',
        page = (j['page'] as String?) ?? '',
        book = 'الجزء ${Ar.num(int.tryParse((j['vol'] as String?) ?? '') ?? 1)}',
        poet = (j['poet'] as String?) ?? '',
        died = (j['died'] as String?) ?? '',
        era = (j['era'] as String?) ?? '',
        by = '',
        url = '',
        own = false,
        note = (j['note'] as String?) ?? '',
        dup = (j['dup'] as String?) ?? '',
        same = {for (final s in (j['same'] as List? ?? [])) ((s as List)[0] as num).toInt(): s[1] as String},
        sharh = [for (final s in (j['sharh'] as List? ?? [])) (((s as List)[0] as num).toInt(), s[1] as String)],
        sharhStart = (j['sh0'] as String?) ?? '',
        chk = (j['chk'] as String?) ?? '',
        lines = [
          for (final l in (j['lines'] as List)) [for (final h in (l as List)) h as String]
        ];
  bool get fromBook => author.isNotEmpty;
  Shahid.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as String?) ?? '',
        scholar = j['scholar'] as String,
        book = j['book'] as String,
        edition = (j['ed'] as String?) ?? '',
        vol = (j['vol'] as String?) ?? '',
        page = (j['page'] as String?) ?? '',
        poet = (j['poet'] as String?) ?? '',
        by = (j['by'] as String?) ?? '',
        url = (j['url'] as String?) ?? '',
        author = '',
        died = '',
        era = '',
        own = j['own'] == true,
        note = '',
        dup = '',
        same = const {},
        sharh = const [],
        sharhAsset = '',
        sharhStart = '',
        chk = '',
        oneVol = false,
        lines = [
          for (final l in (j['lines'] as List)) [for (final h in (l as List)) h as String]
        ];

  /// Readers see it only after the developer pressed «إظهار».
  bool get shown => Store.i.shShown.contains(id);

  /// The developer pressed «إخفاء»: out of the draft, kept in his hidden list.
  bool get hidden => Store.i.shHidden.contains(id);
  bool get draft => !shown && !hidden;

  /// «(٣/٥١)» for a book in volumes, «ص ٥١» otherwise.
  String get place => page.isEmpty ? '' : (!oneVol && (fromBook || _multi.putIfAbsent(book, () => Library.shawahid.any((x) => x.book == book && x.vol.isNotEmpty && x.vol != '1'))) ? '(${Ar.num(int.tryParse(vol) ?? 1)}/${Ar.num(int.tryParse(page) ?? 0)})' : 'ص ${Ar.num(int.tryParse(page) ?? 0)}');
  static final Map<String, bool> _multi = {};

  /// The line under it in the feed.
  String get citeLine => own ? 'من شعر $scholar في «$book»${place.isEmpty ? '' : ' $place'}' : fromBook ? (oneVol ? 'من «${Library.verseBooks[scholar] ?? scholar}» $place' : 'من كتاب «$scholar» ${author.startsWith('ال') ? 'لل${author.substring(2)}' : 'لـ$author'} $place') : 'استشهد به $scholar في «$book»${place.isEmpty ? '' : ' $place'}';

  /// Where it stands: the book and the page.
  String get where => fromBook ? '«$scholar» $place' : '«$book» $place';

  /// The poet with what the book of verses says of him.
  String get poetLine => poet.isEmpty ? 'بلا نسبة' : 'القائل: $poet${by.isEmpty ? '' : ' ($by)'}${died.isEmpty ? '' : ' (ت ${died.endsWith('هـ') ? died : '$diedهـ'})'}${era.isEmpty ? '' : ' — $era'}';
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
  static void refresh() {
    _applyEdits();
    poems = all.where((p) => !p.allGone).toList();
    // What the developer showed from the citations and from «كتب الشعر», under a known name.
    // A piece whose verses already stand in the app («المكررة») is not repeated.
    // A poet known only from what was shown (not one of the book's poets) gets his place among
    // the poets, with the era and the year his source gives.
    final base = <String>{for (final p in poets) p.name};
    final added = <String, Poet>{};
    shownCount.clear();
    for (final x in shawahid) {
      if (!x.shown || x.dup.isNotEmpty) continue;
      final name = x.own ? x.scholar : x.poet;
      if (name.isEmpty) continue;
      shownCount[name] = (shownCount[name] ?? 0) + 1;
      if (x.own || base.contains(name)) continue;
      final old = added[name];
      if (old == null || (old.era.isEmpty && x.era.isNotEmpty)) {
        added[name] = Poet.fromJson({'name': name, 'era': x.era.isNotEmpty ? x.era : (old?.era ?? ''), 'death': x.died.isNotEmpty ? x.died : (old?.death ?? ''), 'count': 0});
      }
    }
    // The book's selections under each name as they stand now (a corrected poet moves his piece),
    // and a name the developer wrote that is new to the app gets a page of its own.
    bookCount.clear();
    for (final p in poems) {
      bookCount[p.poet] = (bookCount[p.poet] ?? 0) + 1;
      if (!base.contains(p.poet) && !added.containsKey(p.poet) && p.poet != 'بلا نسبة') {
        added[p.poet] = Poet.fromJson({'name': p.poet, 'era': p.era, 'death': p.death, 'count': 0});
      }
    }
    shownPoets = added.values.toList();
    poetByName
      ..clear()
      ..addEntries(poets.map((p) => MapEntry(p.name, p)))
      ..addEntries(shownPoets.map((p) => MapEntry(p.name, p)));
    shownPieces = [
      for (final x in shawahid)
        if (x.shown && x.dup.isEmpty && x.lines.isNotEmpty) Poem.ofShahid(x)
    ];
    wide = [...poems, ...shownPieces];
  }

  /// What each piece said before any correction, so a correction can be taken back.
  static final Map<String, (String, List<List<String>>, String, String)> _orig = {};

  /// Puts the developer's corrections (text, poet) on the selections and the pieces, in place,
  /// so every page that holds one shows it corrected.
  static void _applyEdits() {
    final e = Store.i.edits;
    if (e.isEmpty && _orig.isEmpty) return;
    final known = {for (final p in poets) p.name: p};
    List<List<String>> read(Object? v, List<List<String>> or) {
      if (v is! List || v.isEmpty) return or;
      return [
        for (final l in v) [for (final h in (l as List)) '$h']
      ];
    }

    for (final p in all) {
      final k = 'p:${p.id}';
      final x = e[k];
      if (x == null && !_orig.containsKey(k)) continue;
      final o = _orig[k] ??= (p.poet, p.lines, p.era, p.death);
      final name = (x?['poet'] as String?)?.trim() ?? '';
      p.lines = read(x?['lines'], o.$2);
      p.poet = name.isEmpty ? o.$1 : name;
      final moved = p.poet != o.$1 ? known[p.poet] : null;
      p.era = moved?.era ?? o.$3;
      p.death = moved?.death ?? o.$4;
    }
    for (final s in shawahid) {
      final k = 's:${s.id}';
      final x = e[k];
      if (x == null && !_orig.containsKey(k)) continue;
      final o = _orig[k] ??= (s.poet, s.lines, '', '');
      final name = (x?['poet'] as String?)?.trim() ?? '';
      s.lines = read(x?['lines'], o.$2);
      s.poet = name.isEmpty ? o.$1 : name;
    }
  }

  /// Poets who are not in the book and came in with a shown piece; and how many shown pieces stand under each name.
  static List<Poet> shownPoets = [];
  static final Map<String, int> shownCount = {};

  /// Every selection a reader finds under this name: the book's and the shown pieces.
  static final Map<String, int> bookCount = {};
  static int countOf(Poet p) => (bookCount[p.name] ?? 0) + (shownCount[p.name] ?? 0);

  /// Selections whose era is not known (with the unattributed ones).
  static List<Poem> get noEra => wide.where((p) => p.era.isEmpty).toList();

  /// The shown pieces as selections, and the selections of the book with them: the eras,
  /// the rhymes and the search read [wide]; the chapters, the review and the games keep to [poems].
  static List<Poem> shownPieces = [];
  static List<Poem> wide = [];

  /// A steady number for a piece from its id, the same on every device and in every version
  /// (kept small enough for the web, where numbers are not whole past 2^53).
  static int shahidNumber(String id) {
    var h = 7;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) % 1000000007;
    }
    return 1000000000 + h;
  }

  static Shahid? shahidOf(String id) {
    if (_shahidById.length != shawahid.length) {
      _shahidById
        ..clear()
        ..addEntries(shawahid.map((x) => MapEntry(x.id, x)));
    }
    return _shahidById[id];
  }

  static final Map<String, Shahid> _shahidById = {};
  static List<Poem> get bookPoems => poems.where((p) => p.fromBook).toList();
  static List<Poem> get verifiedPoems => poems.where((p) => p.anyVerified).toList();
  static final Map<String, Poet> poetByName = {};
  static List<String> branches = [];
  static List<Matn> mutun = [];
  static List<String> shawahidScholars = [];
  static List<Shahid> shawahid = [];

  /// Books whose verses were gathered whole: short name → full title.
  static Map<String, String> verseBooks = {};

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
    // Verses gathered from whole books stand in the same list, so the same show and hide buttons serve them.
    final bv = jsonDecode(await rootBundle.loadString('assets/data/book_verses.json')) as Map<String, dynamic>;
    for (final b in bv['books'] as List) {
      final m = b as Map<String, dynamic>;
      final key = m['key'] as String;
      verseBooks[key] = m['title'] as String;
      shawahid.addAll([for (final x in m['items'] as List) Shahid.ofBook(x as Map<String, dynamic>, key, m['author'] as String, (m['ed'] as String?) ?? '', oneVol: m['diwan'] == true, sharhAsset: (m['sharhAsset'] as String?) ?? '')]);
    }
  }

  static List<Poem> ofPoet(String name) => poems.where((p) => p.poet == name).toList();
  static List<Poem> ofEra(String era) => wide.where((p) => p.era == era).toList();
  static List<Poem> ofChapter(int c) => poems.where((p) => p.chapter == c).toList();
  static List<Poem> ofRhyme(String r) => wide.where((p) => p.rhyme == r).toList();

  /// Named poets only (without «بلا نسبة»), most selections first.
  /// A poet known only from a diwan in «كتب الشعر» appears once one of his pieces is shown.
  static List<Poet> get namedPoets {
    return [
      ...poets.where((p) => p.name != 'بلا نسبة' && (p.count > 0 || countOf(p) > 0)),
      ...shownPoets,
    ];
  }

  static int _dayIndex([DateTime? d]) {
    final n = d ?? DateTime.now();
    return DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(2024, 1, 1)).inDays;
  }

  /// The verse of the day: same for everyone on the same day.
  /// Chosen from the whole book file, never from what this account happens to
  /// see, so hidden marks that have not reached a phone yet cannot shift it.
  static Poem poemOfDay([DateTime? day]) {
    // Only the book's own fixed data decides this, never the hidden or removed marks
    // kept on each phone: those differ between devices and would give each person another verse.
    final full = all.where((p) => p.lines.isNotEmpty && p.lines.first.length == 2 && p.flags.isEmpty).toList();
    final list = full.isEmpty ? all : full;
    return list[(_dayIndex(day) * 37) % list.length];
  }

  static int chapterNamed(String name) => chapters.indexWhere((c) => c.name == name);

  /// Selections added from outside the book (scholars and Companions).
  static List<Poem> get additions => poems.where((p) => p.src == 'add').toList();

  static Poet poetOfDay() {
    // From the book's own list alone, so every phone names the same poet whatever was shown or corrected.
    final list = poets.where((p) => p.name != 'بلا نسبة' && p.count >= 2).toList();
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

  /// The rhyme letter of a piece, roughly: the last letter of its first verse, past a closing
  /// long vowel («عقلا» → ل، «أمري» → ر).
  static String rhymeOf(List<List<String>> lines) {
    if (lines.isEmpty || lines.first.isEmpty) return '';
    var t = plain(lines.first.last).replaceAll(RegExp('[^\u0621-\u064A]'), '');
    if (t.length > 2 && t.endsWith('وا')) t = t.substring(0, t.length - 2);
    if (t.length > 1 && 'اويى'.contains(t[t.length - 1])) t = t.substring(0, t.length - 1);
    if (t.isEmpty) return '';
    final c = t[t.length - 1];
    if ('أإآؤئ'.contains(c)) return 'ء';
    if (c == 'ة') return 'ه';
    if (c == 'ى') return 'ي';
    return c;
  }

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
  String palette = 'default'; // a colour set from Palette.all; the others are for Plus members
  double fontScale = 0.8;
  bool tashkeel = true;

  /// Switches the developer sets for everyone (daily tasks, duel, Friday round, poet of the week…). On unless turned off.
  Map<String, bool> features = {};
  bool feature(String k) => features[k] ?? true;
  void setFeature(String k, bool v) {
    features[k] = v;
    _p.setString('features', jsonEncode(features));
    notifyListeners();
    cloudPush?.call();
  }

  /// Set by the cloud service: a subscriber has no limit on collections.
  static bool plusUser = false;
  static const freeCollections = 2, freeCollectionSize = 600;

  /// What follows the account from one phone to another.
  static const _backupKeys = ['likes', 'followed', 'collections', 'memorized', 'memLog', 'reviewed', 'myNotes', 'majlis', 'seen', 'days', 'reads', 'best', 'certName', 'students', 'studentNames', 'testLog'];
  Map<String, dynamic> exportAll() => {
        for (final k in _backupKeys)
          if (_p.get(k) != null) k: _p.get(k)
      };
  Future<void> importAll(Map<String, dynamic> m) async {
    for (final k in _backupKeys) {
      final v = m[k];
      if (v is String) await _p.setString(k, v);
      if (v is List) await _p.setStringList(k, [for (final x in v) '$x']);
    }
    await load();
    Library.refresh();
    notifyListeners();
  }
  /// Developer tools show only when the switch was opened on this device (fifteen taps on
  /// the version line) and the developer's own account is signed in. Either one alone shows nothing.
  bool _developer = false;
  static bool Function()? isDevAccount;
  bool get developer => _developer && (isDevAccount?.call() ?? false);
  bool morning = false;
  int morningHour = 7;
  int morningMinute = 0;
  bool evening = false; // a reminder of «بيت الذهب» and the proverbs before the day ends
  int eveningHour = 20;
  int eveningMinute = 0;
  Set<String> days = {};
  Map<String, Set<int>> memorized = {};
  int wird = 5;
  Set<String> hidden = {}; // hidden verses, p:ID:v (the developer's and the supervisors')
  Set<String> modHidden = {}; // of those, the ones a supervisor hid (kept in a list of their own on the server)
  static void Function(String key, bool on, bool wasMod)? cloudHidden;
  Set<String> deleted = {}; // developer: removed for good
  List<String> seen = []; // challenge: verses already asked, 'id:line'
  Map<String, String> studentNames = {}; // teacher: personal number → name
  List<Map<String, dynamic>> testLog = []; // teacher: tests he sent
  Set<String> shShown = {}, shHidden = {}; // cited verses the developer showed to readers, or put away
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
  bool plusOn = false; // developer switch: show «منتقيات+» to non-subscribers
  bool teacher = false; // «خانة المعلّم» turned on in settings
  List<String> students = []; // personal numbers the teacher added before
  Map<String, List<Map<String, String>>> shuruh = {}; // matn → [{title,url}] added by the developer
  /// The developer's corrections: 'p:<selection number>' or 's:<piece id>' → {poet, lines}.
  Map<String, Map<String, dynamic>> edits = {};

  /// Saves a correction; with neither a poet nor lines, takes it back to what the source says.
  void setEdit(String key, {String? poet, List<List<String>>? lines}) {
    if (poet == null && lines == null) {
      edits.remove(key);
    } else {
      edits[key] = {if (poet != null) 'poet': poet, if (lines != null) 'lines': lines};
    }
    _p.setString('edits', jsonEncode(edits));
    Library.refresh();
    notifyListeners();
  }

  static List<List<String>>? linesOf(Object? v) => v is List
      ? [
          for (final l in v) [for (final h in (l as List)) '$h']
        ]
      : null;

  void _readEdits(Map<String, dynamic> j) {
    edits = {
      for (final x in j.entries)
        if (x.value is Map) x.key: Map<String, dynamic>.from(x.value as Map)
    };
  }

  /// «ديوان العلماء والصحابة»: the names the developer put in each part ('sahaba', 'ulama').
  /// Whatever is shown under such a name stands there by itself, as on the poet's own page.
  Map<String, List<String>> diwan = {'sahaba': [], 'ulama': []};

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    likes = (_p.getStringList('likes') ?? []).map(int.parse).toSet();
    followed = (_p.getStringList('followed') ?? []).toSet();
    reviewed = (_p.getStringList('reviewed') ?? []).map(int.parse).toSet();
    recent = _p.getStringList('recent') ?? [];
    days = (_p.getStringList('days') ?? []).toSet();
    lastRead = _p.getInt('lastRead') ?? 0;
    themeMode = _p.getInt('themeMode') ?? 0;
    palette = _p.getString('palette') ?? 'default';
    fontScale = _p.getDouble('fontScale') ?? 0.8;
    tashkeel = _p.getBool('tashkeel') ?? true;
    try {
      features = Map<String, bool>.from(jsonDecode(_p.getString('features') ?? '{}') as Map);
    } catch (_) {
      features = {};
    }
    _developer = _p.getBool('developer') ?? false;
    morning = _p.getBool('morning') ?? false;
    morningHour = _p.getInt('morningHour') ?? 7;
    morningMinute = _p.getInt('morningMinute') ?? 0;
    evening = _p.getBool('evening') ?? false;
    eveningHour = _p.getInt('eveningHour') ?? 20;
    eveningMinute = _p.getInt('eveningMinute') ?? 0;
    wird = _p.getInt('wird') ?? 5;
    verified = (_p.getStringList('verified') ?? []).toSet();
    shShown = (_p.getStringList('shShown') ?? []).toSet();
    shHidden = (_p.getStringList('shHidden') ?? []).toSet();
    hidden = (_p.getStringList('hidden') ?? []).toSet();
    modHidden = (_p.getStringList('modHidden') ?? []).toSet();
    deleted = (_p.getStringList('deleted') ?? []).toSet();
    seen = _p.getStringList('seen') ?? [];
    try {
      studentNames = Map<String, String>.from(jsonDecode(_p.getString('studentNames') ?? '{}') as Map);
      testLog = [for (final x in jsonDecode(_p.getString('testLog') ?? '[]') as List) Map<String, dynamic>.from(x as Map)];
    } catch (_) {}
    certName = _p.getString('certName') ?? '';
    repeat = _p.getInt('repeat') ?? 3;
    plusOn = _p.getBool('plusShow') ?? false;
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
      _readDiwan(jsonDecode(_p.getString('diwan') ?? '{}') as Map<String, dynamic>);
      _readEdits(jsonDecode(_p.getString('edits') ?? '{}') as Map<String, dynamic>);
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
    LikeCounts.i.add('$id', likes.contains(id));
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

  /// False when the free limit (two collections) is reached.
  bool get canCreateCollection => plusUser || collections.length < freeCollections;

  void createCollection(String name) {
    if (!collections.containsKey(name) && !canCreateCollection) return;
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
    if (!collections.containsKey(name) && !canCreateCollection) return;
    final l = collections.putIfAbsent(name, () => []);
    if (!l.contains(id) && !plusUser && l.length >= freeCollectionSize) return;
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

  void setPalette(String id) {
    palette = id;
    _p.setString('palette', id);
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

  /// The signed-in account changed: pages that look at [developer] draw again.
  void accountChanged() => notifyListeners();

  void setDeveloper(bool v) {
    if (_developer == v) return;
    _developer = v;
    _p.setBool('developer', v);
    notifyListeners();
  }

  void setEvening(bool on, int hour, int minute) {
    evening = on;
    eveningHour = hour;
    eveningMinute = minute;
    _p.setBool('evening', on);
    _p.setInt('eveningHour', hour);
    _p.setInt('eveningMinute', minute);
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
    _p.setBool('plusShow', v);
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
  /// 1 = show to readers, -1 = put away, 0 = back to the draft. The server copy is changed by Cloud.setShahid.
  void setShahid(String id, int state) {
    shShown.remove(id);
    shHidden.remove(id);
    if (state > 0) shShown.add(id);
    if (state < 0) shHidden.add(id);
    _p.setStringList('shShown', shShown.toList());
    _p.setStringList('shHidden', shHidden.toList());
    Library.refresh();
    notifyListeners();
  }

  /// A supervisor's hidden verses, as the server lists them.
  void setModHidden(Iterable<String> keys) {
    modHidden = keys.toSet();
    _p.setStringList('modHidden', modHidden.toList());
  }

  void applyCloud({List<String>? shShown, List<String>? shHidden, List<String>? verified, List<String>? hidden, List<String>? deleted, bool? plus, String? payLink, Map<String, dynamic>? shuruh, Map<String, dynamic>? features, Map<String, dynamic>? diwan, Map<String, dynamic>? edits}) {
    if (features != null) {
      this.features = {
        for (final e in features.entries)
          if (e.value is bool) e.key: e.value as bool
      };
      _p.setString('features', jsonEncode(this.features));
    }
    if (edits != null) {
      _readEdits(edits);
      _p.setString('edits', jsonEncode(this.edits));
    }
    if (diwan != null) {
      _readDiwan(diwan);
      _p.setString('diwan', jsonEncode(this.diwan));
    }
    if (verified != null) {
      this.verified = verified.toSet();
      _p.setStringList('verified', verified);
    }
    if (shShown != null) {
      this.shShown = shShown.toSet();
      _p.setStringList('shShown', shShown);
    }
    if (shHidden != null) {
      this.shHidden = shHidden.toSet();
      _p.setStringList('shHidden', shHidden);
    }
    if (hidden != null) {
      this.hidden = {...hidden, ...modHidden};
      _p.setStringList('hidden', this.hidden.toList());
    }
    if (deleted != null) {
      this.deleted = deleted.toSet();
      _p.setStringList('deleted', deleted);
    }
    if (plus != null) {
      plusOn = plus;
      _p.setBool('plusShow', plus);
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
    final wasMod = modHidden.contains(key);
    if (!on && modHidden.remove(key)) _p.setStringList('modHidden', modHidden.toList());
    _p.setStringList('hidden', hidden.toList());
    Library.refresh();
    notifyListeners();
    cloudPush?.call();
    cloudHidden?.call(key, on, wasMod);
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

  void _readDiwan(Map<String, dynamic> j) {
    diwan = {
      for (final k in const ['sahaba', 'ulama']) k: [for (final x in (j[k] as List? ?? const [])) x as String]
    };
  }

  /// Which part of the diwan a name stands in: 'sahaba', 'ulama' or null.
  String? diwanOf(String name) => diwan['sahaba']!.contains(name) ? 'sahaba' : (diwan['ulama']!.contains(name) ? 'ulama' : null);

  /// Puts a name in one part of the diwan, or takes it out of both (part == null).
  void setDiwan(String name, String? part) {
    diwan['sahaba']!.remove(name);
    diwan['ulama']!.remove(name);
    if (part != null) diwan[part]!.add(name);
    _p.setString('diwan', jsonEncode(diwan));
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
