import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'shawahid.dart';

void openList(BuildContext context, String title, List<Poem> poems, {String? subtitle}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoemListScreen(title: title, poems: poems, subtitle: subtitle)));
}

void openPoet(BuildContext context, String name) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoetScreen(name: name)));
}

void push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

class PoemListScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Poem> poems;
  const PoemListScreen({super.key, required this.title, required this.poems, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: poems.isEmpty
          ? const EmptyNote(Icons.menu_book_outlined, 'لا يوجد شيء هنا بعد.')
          : ListView(padding: const EdgeInsets.only(bottom: 40), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(subtitle ?? Ar.selections(poems.length), style: TextStyle(fontSize: 15, color: C.muted(context))),
              ),
              TwoColumns(poems: poems, onTap: (p) => openPoem(context, p)),
            ]),
    );
  }
}

class PoetScreen extends StatelessWidget {
  final String name;
  const PoetScreen({super.key, required this.name});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final poet = Library.poetByName[name];
    final poems = Library.ofPoet(name);
    final verses = poems.fold<int>(0, (s, p) => s + p.verseCount);
    final follows = Store.i.follows(name);
    final chapters = <String>{for (final p in poems) p.chapterName};
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Avatar(poet?.initial ?? '؟', size: 76),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: C.ink(context))),
                const SizedBox(height: 6),
                Text([
                  if ((poet?.era ?? '').isNotEmpty) 'العصر: ${poet!.era}',
                  if ((poet?.death ?? '').isNotEmpty) 'الوفاة: ${poet!.death}',
                ].join(' · '), style: TextStyle(fontSize: 15, color: C.muted(context))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _stat(context, Ar.num(poems.length), 'مقطعاً في الكتاب'),
            const SizedBox(width: 10),
            _stat(context, Ar.num(verses), 'بيتاً'),
            const SizedBox(width: 10),
            _stat(context, Ar.num(chapters.length), 'باباً'),
          ]),
        ),
        if ((poet?.bio ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: SelectableText(poet!.bio, style: TextStyle(fontSize: 16.5, height: 1.9, color: C.ink(context))),
          ),
        if ((poet?.sources ?? const []).isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line(context))),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text('المصادر', style: TextStyle(fontSize: 15.5, color: C.muted(context))),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  expandedAlignment: AlignmentDirectional.centerStart,
                  children: [
                    for (final src in poet!.sources)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(src, style: TextStyle(fontSize: 14.5, height: 1.6, color: C.muted(context))),
                      ),
                  ],
                ),
              ),
            ),
          ),
        PoetShawahid(poet: name),
        if (name != 'بلا نسبة')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: follows ? C.soft(context) : C.accent(context),
                    foregroundColor: follows ? C.ink(context) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Store.i.toggleFollow(name),
                  icon: Icon(follows ? Icons.check_rounded : Icons.person_add_alt_rounded),
                  label: Text(follows ? 'في «شعراؤك»' : 'أضِف إلى «شعراؤك»', style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14)),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Text(
                      'سيرة الشاعر المفصّلة — مولده ووفاته وبلده ونبذة عنه — تُضاف قريباً بإذن الله.',
                      style: TextStyle(fontSize: 17, height: 1.7),
                    ),
                  ),
                ),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('السيرة', style: TextStyle(fontSize: 16)),
              ),
            ]),
          ),
        const SectionTitle('مختاراته في الكتاب'),
        TwoColumns(poems: poems, onTap: (p) => openPoem(context, p)),
      ]),
    );
  }

  Widget _stat(BuildContext context, String n, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line(context))),
          child: Column(children: [
            Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.accent(context))),
            Text(label, style: TextStyle(fontSize: 13.5, color: C.muted(context))),
          ]),
        ),
      );
}

/// A simple list of tappable rows with a count on the left.
class CountList extends StatelessWidget {
  final String title;
  final String? intro;
  final List<(String, int, VoidCallback)> rows;
  final bool searchable;
  const CountList({super.key, required this.title, required this.rows, this.intro, this.searchable = false});
  @override
  Widget build(BuildContext context) => _CountListBody(title: title, rows: rows, intro: intro, searchable: searchable);
}

class _CountListBody extends StatefulWidget {
  final String title;
  final String? intro;
  final List<(String, int, VoidCallback)> rows;
  final bool searchable;
  const _CountListBody({required this.title, required this.rows, this.intro, required this.searchable});
  @override
  State<_CountListBody> createState() => _CountListBodyState();
}

class _CountListBodyState extends State<_CountListBody> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final rows = q.isEmpty ? widget.rows : widget.rows.where((r) => Ar.norm(r.$1).contains(Ar.norm(q))).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        if (widget.intro != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(widget.intro!, style: TextStyle(fontSize: 15, color: C.muted(context), height: 1.6)),
          ),
        if (widget.searchable)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(
                hintText: 'ابحث في القائمة',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: C.card(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: C.line(context))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: C.line(context))),
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: C.line(context))),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 18, endIndent: 18, color: C.line(context)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                title: Text(rows[i].$1, style: TextStyle(fontSize: 17, color: C.ink(context))),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(Ar.num(rows[i].$2), style: TextStyle(fontSize: 15, color: C.muted(context))),
                  Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                ]),
                onTap: rows[i].$3,
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

Widget erasScreen(BuildContext context) {
  final counts = <String, int>{};
  for (final p in Library.wide) {
    if (p.era.isNotEmpty) counts[p.era] = (counts[p.era] ?? 0) + 1;
  }
  final rows = [
    for (final e in Library.eras)
      if ((counts[e] ?? 0) > 0) (e == 'صدر الإسلام' ? 'عصر صدر الإسلام' : 'العصر ال${e == 'حديث' ? 'حديث' : e}', counts[e]!, () => openList(context, 'العصر: $e', Library.ofEra(e))),
  ];
  final unknown = Library.noEra;
  if (unknown.isNotEmpty) rows.add(('لا يُعرف عصره', unknown.length, () => openList(context, 'لا يُعرف عصره', Library.noEra)));
  return CountList(title: 'العصور', intro: 'من العصر الجاهلي إلى العصر الحديث، مرتّبة على التاريخ.', rows: rows);
}

Widget poetsScreen(BuildContext context) {
  final rows = [
    for (final p in Library.namedPoets) (p.name, Library.countOf(p), () => openPoet(context, p.name)),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  final un = Library.poetByName['بلا نسبة'];
  if (un != null) rows.add(('أبيات بلا نسبة', un.count, () => openPoet(context, 'بلا نسبة')));
  return CountList(title: 'الشعراء', intro: 'مرتّبون على عدد مختاراتهم في الكتاب.', rows: rows, searchable: true);
}

Widget rhymesScreen(BuildContext context) {
  final counts = <String, int>{};
  for (final p in Library.wide) {
    if (p.rhyme.isNotEmpty) counts[p.rhyme] = (counts[p.rhyme] ?? 0) + 1;
  }
  const order = 'ءابتثجحخدذرزسشصضطظعغفقكلمنهوي';
  final keys = counts.keys.toList()..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
  return Scaffold(
    appBar: AppBar(title: const Text('القوافي')),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
        child: Text('على حرف الرويّ في آخر البيت (تقريبي).', style: TextStyle(fontSize: 15, color: C.muted(context))),
      ),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (final k in keys)
            SoftCard(
              padding: const EdgeInsets.all(6),
              onTap: () => openList(context, 'قافية $k', Library.ofRhyme(k)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(k, style: TextStyle(fontFamily: verseFont, fontSize: 30, color: C.accent(context), height: 1.3)),
                Text(Ar.num(counts[k]!), style: TextStyle(fontSize: 13, color: C.muted(context))),
              ]),
            ),
        ],
      ),
    ]),
  );
}

class ChaptersScreen extends StatelessWidget {
  final int? section;
  const ChaptersScreen({super.key, this.section});
  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{};
    for (final p in Library.poems) {
      counts[p.chapter] = (counts[p.chapter] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: Text(section == null ? 'الأبواب' : Library.sections[section!])),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        for (var s = 0; s < Library.sections.length; s++)
          if (section == null || section == s) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
              child: Text(s == 2 ? Library.sections[s] : 'القسم ${s == 0 ? 'الأول' : 'الثاني'}: ${Library.sections[s]}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: C.line(context))),
              child: Column(children: [
                for (final c in Library.chapters.where((c) => c.section == s)) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    title: Text(c.name, style: TextStyle(fontSize: 17, color: C.ink(context))),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(Ar.num(counts[c.index] ?? 0), style: TextStyle(fontSize: 15, color: C.muted(context))),
                      Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                    ]),
                    onTap: () => openList(context, c.name, Library.ofChapter(c.index)),
                  ),
                  Divider(height: 1, indent: 18, endIndent: 18, color: C.line(context)),
                ],
              ]),
            ),
          ],
      ]),
    );
  }
}

/// «ديوان العلماء والصحابة»: the names the developer placed in each part. Whatever is shown
/// under such a name (in the book, or shown from «كتب الشعر» and the citations) is reached
/// from here and from the poet's own page alike, with nothing to move by hand.
class DiwanScreen extends StatelessWidget {
  const DiwanScreen({super.key});

  static const parts = [('sahaba', 'الصحابة رضي الله عنهم'), ('ulama', 'العلماء')];

  /// What readers can see under each name.
  static Map<String, int> _counts() {
    final c = <String, int>{};
    for (final p in Library.poems) {
      c[p.poet] = (c[p.poet] ?? 0) + 1;
    }
    for (final x in Library.shawahid) {
      if (!x.shown) continue;
      final n = x.own ? x.scholar : x.poet;
      if (n.isNotEmpty) c[n] = (c[n] ?? 0) + 1;
    }
    return c;
  }

  static void _open(BuildContext context, String name) {
    final asPoet = Library.ofPoet(name).isNotEmpty || Library.shawahid.any((x) => !x.own && x.poet == name && x.shown);
    if (!asPoet && Library.shawahid.any((x) => x.own && x.scholar == name)) {
      openShawahid(context, name, own: true);
    } else {
      openPoet(context, name);
    }
  }

  /// Developer: where this name goes.
  static void choose(BuildContext context, String name) {
    final now = Store.i.diwanOf(name);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
          ),
          for (final (key, title) in parts)
            ListTile(
              leading: Icon(now == key ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: C.accent(context)),
              title: Text(now == key ? 'هو في «$title»' : 'أضفه إلى «$title»'),
              onTap: () {
                Navigator.pop(c);
                if (now == key) return;
                Store.i.setDiwan(name, key);
                toast(context, 'أُضيف إلى «$title»');
              },
            ),
          if (now != null)
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: const Text('أخرجه من الديوان'),
              onTap: () {
                Navigator.pop(c);
                Store.i.setDiwan(name, null);
                toast(context, 'أُخرج من الديوان');
              },
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final dev = Store.i.developer;
          final counts = _counts();
          final chapterCounts = <int, int>{};
          for (final p in Library.poems) {
            chapterCounts[p.chapter] = (chapterCounts[p.chapter] ?? 0) + 1;
          }
          final chapters = Library.chapters.where((c) => c.section == 2).toList();
          return Scaffold(
            appBar: AppBar(title: const Text('ديوان العلماء والصحابة')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              if (dev)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: SoftCard(
                    onTap: () => push(context, const DiwanPickScreen()),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Icon(Icons.person_search_rounded, color: C.accent(context)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('أضف اسماً إلى الديوان', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
                          Text('ابحث عن الاسم ثم اختر: الصحابة أو العلماء (للمطوّر)', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                        ]),
                      ),
                      Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                    ]),
                  ),
                ),
              for (final (key, title) in parts) ..._part(context, title, Store.i.diwan[key]!, counts, dev),
              if (chapters.isNotEmpty) ...[
                _head(context, 'مختارات الديوان'),
                _box(context, [
                  for (final c in chapters)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                      title: Text(c.name, style: TextStyle(fontSize: 17, color: C.ink(context))),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(Ar.num(chapterCounts[c.index] ?? 0), style: TextStyle(fontSize: 15, color: C.muted(context))),
                        Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                      ]),
                      onTap: () => openList(context, c.name, Library.ofChapter(c.index)),
                    ),
                ]),
              ],
            ]),
          );
        },
      );

  /// Readers see a name once something of his is shown; the developer sees every name he added.
  List<Widget> _part(BuildContext context, String title, List<String> names, Map<String, int> counts, bool dev) {
    final list = [
      for (final n in names)
        if (dev || (counts[n] ?? 0) > 0) n
    ];
    if (list.isEmpty) return const [];
    return [
      _head(context, title),
      _box(context, [
        for (final n in list)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            title: Text(n, style: TextStyle(fontSize: 17, color: C.ink(context))),
            subtitle: (counts[n] ?? 0) == 0 ? Text('لم يُظهَر من شعره شيء بعد، فلا يراه القرّاء', style: TextStyle(fontSize: 13, color: C.muted(context))) : null,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(Ar.num(counts[n] ?? 0), style: TextStyle(fontSize: 15, color: C.muted(context))),
              Icon(Icons.chevron_left_rounded, color: C.muted(context)),
            ]),
            onTap: () => _open(context, n),
            onLongPress: dev ? () => choose(context, n) : null,
          ),
      ]),
    ];
  }

  Widget _head(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
        child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
      );

  Widget _box(BuildContext context, List<Widget> rows) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: C.line(context))),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 18, endIndent: 18, color: C.line(context)),
            rows[i],
          ],
        ]),
      );
}

/// Developer: every name the app knows (poets of the book, of «كتب الشعر» and of the
/// citations, and the scholars with verse of their own). A tap puts the name in the diwan.
class DiwanPickScreen extends StatefulWidget {
  const DiwanPickScreen({super.key});
  @override
  State<DiwanPickScreen> createState() => _DiwanPickState();
}

class _DiwanPickState extends State<DiwanPickScreen> {
  String q = '';
  late final List<String> names = () {
    final s = <String>{
      for (final p in Library.poets) p.name,
      for (final x in Library.shawahid)
        if (x.own) x.scholar else if (x.poet.isNotEmpty) x.poet,
    }..remove('بلا نسبة');
    return s.toList()..sort((a, b) => Ar.norm(a).compareTo(Ar.norm(b)));
  }();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final k = Ar.norm(q);
          final list = k.isEmpty ? names : names.where((n) => Ar.norm(n).contains(k)).toList();
          return Scaffold(
            appBar: AppBar(title: const Text('أضف اسماً إلى الديوان')),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => q = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن شاعر أو عالم',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: C.card(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: C.line(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: C.line(context))),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(child: Text('لا يوجد هذا الاسم في التطبيق', style: TextStyle(color: C.muted(context))))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final part = Store.i.diwanOf(list[i]);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                            title: Text(list[i], style: TextStyle(fontSize: 17, color: C.ink(context))),
                            trailing: part == null
                                ? Icon(Icons.add_rounded, color: C.muted(context))
                                : Text(part == 'sahaba' ? 'الصحابة' : 'العلماء', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.accent(context))),
                            onTap: () => DiwanScreen.choose(context, list[i]),
                          );
                        },
                      ),
              ),
            ]),
          );
        },
      );
}
