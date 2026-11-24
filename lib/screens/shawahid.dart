import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../ui.dart';
import 'lists.dart';
import 'poem.dart' show copyVerses, formatVerses, siteUrl;

/// Copy and share under a cited verse, the same as on the poem's own page.
Widget shahidActions(BuildContext context, Shahid x) => Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      IconButton(
        tooltip: 'نسخ البيت',
        visualDensity: VisualDensity.compact,
        onPressed: () => copyVerses(context, x.lines),
        icon: Icon(Icons.copy_rounded, size: 18, color: C.muted(context)),
      ),
      IconButton(
        tooltip: 'مشاركة',
        visualDensity: VisualDensity.compact,
        onPressed: () => Share.share('${formatVerses(x.lines, mark: !Cloud.i.noMark)}\n— ${x.poet.isEmpty ? 'بلا نسبة' : x.poet}\n${x.citeLine}\n\n$siteUrl'),
        icon: Icon(Icons.ios_share_rounded, size: 18, color: C.muted(context)),
      ),
    ]);


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
                    Text(Ar.num(Library.shawahid.where((x) => x.scholar == s && (x.shown || (Cloud.i.canShahid(s) && x.draft))).length), style: TextStyle(color: C.muted(context))),
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
          final staff = Cloud.i.canShahid(widget.scholar);
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
            appBar: AppBar(title: Text(Library.verseBooks.containsKey(widget.scholar) ? 'أشعار «${widget.scholar}»' : 'مما استشهد به ${widget.scholar}')),
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
                      child: ChoiceChip(label: Text('${Library.verseBooks.containsKey(widget.scholar) ? 'كل الأجزاء' : 'كل الكتب'} ${Ar.num(ofTab.length)}'), selected: book.isEmpty, onSelected: (_) => setState(() => book = '')),
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

  Future<void> _set(Shahid x, int state) async {
    final ok = await Cloud.i.setShahid(x.id, state);
    if (!ok && mounted) toast(context, 'لم يُحفظ. تحقق من الإنترنت، أو من أن صلاحيتك مفعّلة.');
  }

  Widget _card(BuildContext context, Shahid x, bool staff) => Padding(
        key: ValueKey(x.id),
        padding: const EdgeInsets.only(bottom: 12),
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final l in x.lines) Padding(padding: const EdgeInsets.only(bottom: 6), child: VerseLines(l, size: 21)),
            Divider(color: C.line(context)),
            InkWell(
              onTap: x.poet.isNotEmpty && Library.poetByName.containsKey(x.poet) ? () => openPoet(context, x.poet) : null,
              child: Text(x.poetLine, style: TextStyle(fontWeight: FontWeight.w700, color: x.poet.isEmpty ? C.muted(context) : C.ink(context))),
            ),
            const SizedBox(height: 4),
            Text(x.where, style: TextStyle(color: C.ink(context))),
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
            shahidActions(context, x),
            if (staff) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (!x.shown)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _set(x, 1),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('إظهار'),
                    ),
                  ),
                if (!x.shown && !x.hidden) const SizedBox(width: 8),
                if (!x.hidden)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _set(x, -1),
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: const Text('إخفاء'),
                    ),
                  ),
                if (!x.draft)
                  IconButton(
                    tooltip: 'أعده إلى المسودة',
                    onPressed: () => _set(x, 0),
                    icon: const Icon(Icons.undo_rounded),
                  ),
              ]),
            ],
          ]),
        ),
      );
}

/// On a poet's page: his verses that scholars cited, of those shown to readers.
class PoetShawahid extends StatelessWidget {
  final String poet;
  const PoetShawahid({super.key, required this.poet});
  @override
  Widget build(BuildContext context) {
    final all = poet == 'بلا نسبة' ? const <Shahid>[] : Library.shawahid.where((x) => x.poet == poet && x.shown).toList();
    if (all.isEmpty) return const SizedBox.shrink();
    final cited = all.where((x) => !x.fromBook).toList();
    final inBooks = all.where((x) => x.fromBook).toList();
    return Column(children: [
      if (cited.isNotEmpty) _part(context, 'مما استشهد به العلماء من شعره', cited),
      if (inBooks.isNotEmpty) _part(context, 'من شعره في كتب الأدب', inBooks),
    ]);
  }

  Widget _part(BuildContext context, String title, List<Shahid> list) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 8),
        for (final x in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final l in x.lines) Padding(padding: const EdgeInsets.only(bottom: 6), child: VerseLines(l, size: 20)),
                InkWell(
                  onTap: () => openShawahid(context, x.scholar),
                  child: Text(x.citeLine, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.accent(context))),
                ),
                shahidActions(context, x),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// «الكتب التي استُخرجت منها أبيات الشعر»: whole books whose verses were gathered.
/// Supervisors see the draft and choose what to show; readers see only what was shown.
class VerseBooksScreen extends StatelessWidget {
  const VerseBooksScreen({super.key});

  /// Is there anything in it for this account?
  static bool get visible => Library.verseBooks.keys.any((k) => Cloud.i.canShahid(k)) || Library.shawahid.any((x) => x.fromBook && x.shown);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Store.i, Cloud.i]),
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('كتب استُخرجت أشعارها')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
            Text('الكتب التي استُخرجت منها أبيات الشعر، مع القائل والجزء والصفحة.', style: TextStyle(fontSize: 15, color: C.muted(context), height: 1.6)),
            const SizedBox(height: 12),
            for (final e in Library.verseBooks.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  onTap: () => openShawahid(context, e.key),
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Avatar(e.key.substring(0, 1)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context)))),
                    Text(Ar.num(Library.shawahid.where((x) => x.scholar == e.key && (x.shown || (Cloud.i.canShahid(e.key) && x.draft))).length), style: TextStyle(color: C.muted(context))),
                    Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                  ]),
                ),
              ),
          ]),
        ),
      );
}
