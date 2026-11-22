import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../ui.dart';
import 'lists.dart';

/// Who decides what readers see of the cited verses.
bool get _staff => Cloud.i.isDev;

/// «مما استشهد به العلماء»: verses scholars quoted, with book and page.
class ShawahidScreen extends StatelessWidget {
  const ShawahidScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Store.i, Cloud.i]),
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('مما استشهد به العلماء')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
            Text('أبيات استشهد بها العلماء في كتبهم، مع اسم الكتاب والجزء والصفحة.', style: TextStyle(fontSize: 15, color: C.muted(context), height: 1.6)),
            const SizedBox(height: 12),
            for (final s in Library.shawahidScholars)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  onTap: () => openShawahid(context, s),
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Avatar(s.replaceFirst('ابن ', '').substring(0, 1)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context)))),
                    Text(Ar.num(Library.shawahid.where((x) => x.scholar == s && (x.shown || (_staff && x.draft))).length), style: TextStyle(color: C.muted(context))),
                    Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                  ]),
                ),
              ),
          ]),
        ),
      );
}

/// Opens one scholar's cited verses.
void openShawahid(BuildContext context, String scholar) => push(context, ScholarShawahidScreen(scholar: scholar));

class ScholarShawahidScreen extends StatefulWidget {
  final String scholar;
  const ScholarShawahidScreen({super.key, required this.scholar});
  @override
  State<ScholarShawahidScreen> createState() => _ScholarShawahidState();
}

class _ScholarShawahidState extends State<ScholarShawahidScreen> {
  /// 0 = the draft, 1 = shown to readers, 2 = put away. Readers only ever see 1.
  int tab = 0;
  String book = '';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Store.i, Cloud.i]),
        builder: (context, _) {
          final all = Library.shawahid.where((x) => x.scholar == widget.scholar).toList();
          final staff = _staff;
          bool inTab(Shahid x) => !staff ? x.shown : (tab == 0 ? x.draft : (tab == 1 ? x.shown : x.hidden));
          final ofTab = all.where(inTab).toList();
          final books = <String, int>{};
          for (final x in ofTab) {
            books[x.book] = (books[x.book] ?? 0) + 1;
          }
          if (book.isNotEmpty && !books.containsKey(book)) book = '';
          final list = book.isEmpty ? ofTab : ofTab.where((x) => x.book == book).toList();
          int n(bool Function(Shahid) f) => all.where(f).length;
          return Scaffold(
            appBar: AppBar(title: Text('مما استشهد به ${widget.scholar}')),
            body: Column(children: [
              if (staff)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 0, label: Text('المسودة ${Ar.num(n((x) => x.draft))}')),
                      ButtonSegment(value: 1, label: Text('الظاهرة ${Ar.num(n((x) => x.shown))}')),
                      ButtonSegment(value: 2, label: Text('المخفية ${Ar.num(n((x) => x.hidden))}')),
                    ],
                    selected: {tab},
                    onSelectionChanged: (v) => setState(() => tab = v.first),
                  ),
                ),
              if (books.length > 1)
                SizedBox(
                  height: 46,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(label: Text('كل الكتب ${Ar.num(ofTab.length)}'), selected: book.isEmpty, onSelected: (_) => setState(() => book = '')),
                    ),
                    for (final e in books.entries)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(label: Text('${e.key} ${Ar.num(e.value)}'), selected: book == e.key, onSelected: (_) => setState(() => book = e.key)),
                      ),
                  ]),
                ),
              Expanded(
                child: list.isEmpty
                    ? EmptyNote(Icons.menu_book_outlined, staff ? 'لا شيء في هذه القائمة.' : 'تُضاف شواهده قريباً بإذن الله.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                        itemCount: list.length,
                        itemBuilder: (context, i) => _card(context, list[i], staff),
                      ),
              ),
            ]),
          );
        },
      );

  Widget _card(BuildContext context, Shahid x, bool staff) => Padding(
        key: ValueKey(x.id),
        padding: const EdgeInsets.only(bottom: 12),
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final l in x.lines) Padding(padding: const EdgeInsets.only(bottom: 6), child: VerseLines(l, size: 21)),
            Divider(color: C.line(context)),
            InkWell(
              onTap: x.poet.isNotEmpty && Library.poetByName.containsKey(x.poet) ? () => openPoet(context, x.poet) : null,
              child: Text(x.poet.isEmpty ? 'بلا نسبة' : 'القائل: ${x.poet}', style: TextStyle(fontWeight: FontWeight.w700, color: x.poet.isEmpty ? C.muted(context) : C.ink(context))),
            ),
            const SizedBox(height: 4),
            Text('«${x.book}» ${x.place}', style: TextStyle(color: C.ink(context))),
            if (x.edition.isNotEmpty) Text('الطبعة: ${x.edition}', style: TextStyle(fontSize: 13, color: C.muted(context))),
            // Only a link to that very page of that very book is offered, never a search for the words.
            if (x.url.isNotEmpty)
              InkWell(
                onTap: () => launchUrl(Uri.parse(x.url), mode: LaunchMode.externalApplication),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('افتح الصفحة في «تراث»', style: TextStyle(color: C.accent(context), decoration: TextDecoration.underline)),
                ),
              ),
            if (staff) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (!x.shown)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Store.i.setShahid(x.id, 1),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('إظهار'),
                    ),
                  ),
                if (!x.shown && !x.hidden) const SizedBox(width: 8),
                if (!x.hidden)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Store.i.setShahid(x.id, -1),
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: const Text('إخفاء'),
                    ),
                  ),
                if (!x.draft)
                  IconButton(
                    tooltip: 'أعده إلى المسودة',
                    onPressed: () => Store.i.setShahid(x.id, 0),
                    icon: const Icon(Icons.undo_rounded),
                  ),
              ]),
            ],
          ]),
        ),
      );
}
