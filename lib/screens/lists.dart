import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';

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
  for (final p in Library.poems) {
    if (p.era.isNotEmpty) counts[p.era] = (counts[p.era] ?? 0) + 1;
  }
  final rows = [
    for (final e in Library.eras)
      if ((counts[e] ?? 0) > 0) (e == 'صدر الإسلام' ? 'عصر صدر الإسلام' : 'العصر ال${e == 'حديث' ? 'حديث' : e}', counts[e]!, () => openList(context, 'العصر: $e', Library.ofEra(e))),
  ];
  return CountList(title: 'العصور', intro: 'من العصر الجاهلي إلى العصر الحديث، مرتّبة على التاريخ.', rows: rows);
}

Widget poetsScreen(BuildContext context) {
  final rows = [
    for (final p in Library.namedPoets) (p.name, p.count, () => openPoet(context, p.name)),
  ];
  final un = Library.poetByName['بلا نسبة'];
  if (un != null) rows.add(('أبيات بلا نسبة', un.count, () => openPoet(context, 'بلا نسبة')));
  return CountList(title: 'الشعراء', intro: 'مرتّبون على عدد مختاراتهم في الكتاب.', rows: rows, searchable: true);
}

Widget rhymesScreen(BuildContext context) {
  final counts = <String, int>{};
  for (final p in Library.poems) {
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
