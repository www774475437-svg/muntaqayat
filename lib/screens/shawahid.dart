import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../ui.dart';
import '../services/likes.dart';
import 'lists.dart';
import 'edit.dart';
import 'poem.dart' show copyVerses, formatVerses, siteUrl;

/// Like with its count, copy and share under a cited verse, the same as on the poem's own page.
Widget shahidActions(BuildContext context, Shahid x) => ListenableBuilder(
      listenable: LikeCounts.i,
      builder: (context, _) {
        final key = 'v:${x.id}';
        LikeCounts.i.watch(key);
        final n = LikeCounts.i.count(key);
        final on = LikeCounts.i.liked(key);
        return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          IconButton(
            tooltip: on ? 'إزالة الإعجاب' : 'أعجبني',
            visualDensity: VisualDensity.compact,
            onPressed: () => LikeCounts.i.toggle(key),
            icon: Icon(on ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, size: 18, color: on ? C.accent(context) : C.muted(context)),
          ),
          if (n > 0) Text(Ar.num(n), style: TextStyle(fontSize: 14, color: C.muted(context))),
          _actionButtons(context, x),
        ]);
      },
    );

Widget _actionButtons(BuildContext context, Shahid x) => Row(mainAxisSize: MainAxisSize.min, children: [
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
                    Text(Ar.num(Library.shawahid.where((x) => x.scholar == s && !x.own && (x.shown || (Cloud.i.canShahid(s) && x.draft))).length), style: TextStyle(color: C.muted(context))),
                    Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                  ]),
                ),
              ),
          ]),
        ),
      );
}

/// Opens one scholar's cited verses.
void openShawahid(BuildContext context, String scholar, {bool own = false}) => push(context, ScholarShawahidScreen(scholar: scholar, own: own));

class ScholarShawahidScreen extends StatefulWidget {
  final String scholar;

  /// His own verse, not what he cited.
  final bool own;
  const ScholarShawahidScreen({super.key, required this.scholar, this.own = false});
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
          final staff = Cloud.i.canShahid(widget.scholar);
          final all = Library.shawahid.where((x) => x.scholar == widget.scholar && x.own == widget.own).toList();
          // His own verse opens from a line at the top of what he cited.
          final ownCount = widget.own ? 0 : Library.shawahid.where((x) => x.scholar == widget.scholar && x.own && (x.shown || (staff && x.draft))).length;
          bool inTab(Shahid x) => !staff ? x.shown : (tab == 0 ? x.draft && x.dup.isEmpty : (tab == 1 ? x.shown : (tab == 2 ? x.hidden : x.draft && x.dup.isNotEmpty)));
          final ofTab = all.where(inTab).toList();
          final books = <String, int>{};
          for (final x in ofTab) {
            books[x.book] = (books[x.book] ?? 0) + 1;
          }
          if (book.isNotEmpty && !books.containsKey(book)) book = '';
          final list = book.isEmpty ? ofTab : ofTab.where((x) => x.book == book).toList();
          int n(bool Function(Shahid) f) => all.where(f).length;
          return Scaffold(
            appBar: AppBar(title: Text(widget.own ? 'من شعر ${widget.scholar}' : Library.verseBooks.containsKey(widget.scholar) ? 'أشعار «${widget.scholar}»' : 'مما استشهد به ${widget.scholar}')),
            body: Column(children: [
              if (ownCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SoftCard(
                    onTap: () => openShawahid(context, widget.scholar, own: true),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Icon(Icons.edit_note_rounded, color: C.accent(context)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('من شعر ${widget.scholar}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context)))),
                      Text(Ar.num(ownCount), style: TextStyle(color: C.muted(context))),
                      Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                    ]),
                  ),
                ),
              if (staff)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 0, label: Text('المسودة ${Ar.num(n((x) => x.draft && x.dup.isEmpty))}')),
                      ButtonSegment(value: 1, label: Text('الظاهرة ${Ar.num(n((x) => x.shown))}')),
                      ButtonSegment(value: 2, label: Text('المخفية ${Ar.num(n((x) => x.hidden))}')),
                      if (all.any((x) => x.dup.isNotEmpty)) ButtonSegment(value: 3, label: Text('المكررة ${Ar.num(n((x) => x.draft && x.dup.isNotEmpty))}')),
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
                    ? EmptyNote(Icons.menu_book_outlined, staff ? 'لا شيء في هذه القائمة.' : (widget.own ? 'يُضاف شعره قريباً بإذن الله.' : 'تُضاف شواهده قريباً بإذن الله.'))
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
            if (x.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(x.note, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: C.accent(context))),
              ),
            for (final l in x.lines) Padding(padding: const EdgeInsets.only(bottom: 6), child: VerseLines(l, size: 21)),
            if (x.hasSharh) shahidSharh(context, x),
            Divider(color: C.line(context)),
            if (staff && x.chk.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline_rounded, size: 17, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text('يحتاج مراجعة: ${x.chk}', style: const TextStyle(fontSize: 13.5, color: Colors.orange, height: 1.6))),
                ]),
              ),
            if (staff && x.same.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  x.dup.isNotEmpty ? 'مكرر: موجود ${x.dup}' : 'فيه مكرر: ${x.same.entries.map((e) => 'البيت ${Ar.num(e.key)} ${e.value}').join('، ')}',
                  style: TextStyle(fontSize: 13.5, color: C.muted(context), height: 1.6),
                ),
              ),
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
                if (Store.i.developer)
                  IconButton(
                    tooltip: 'تحرير',
                    onPressed: () => push(context, EditPieceScreen.piece(x)),
                    icon: const Icon(Icons.edit_rounded),
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
    final all = poet == 'بلا نسبة' ? const <Shahid>[] : Library.shawahid.where((x) => x.poet == poet && !x.own && x.shown).toList();
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
                if (x.note.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(x.note, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.muted(context)))),
                for (final l in x.lines) Padding(padding: const EdgeInsets.only(bottom: 6), child: VerseLines(l, size: 20)),
                if (x.hasSharh) shahidSharh(context, x),
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

/// «الشرح»: how the commentary begins, and the whole of it when pressed, as it stands in the book.
Widget shahidSharh(BuildContext context, Shahid x) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (x.sharhStart.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('الشرح: ${x.sharhStart}', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, height: 1.7, color: C.muted(context))),
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: Text(x.sharh.isNotEmpty ? 'شرح الأبيات (${Ar.num(x.sharh.length)})' : 'الشرح كاملاً'),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) => DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              builder: (context, scroll) => FutureBuilder<List<(int, String)>>(
                future: x.fullSharh(),
                builder: (context, snap) => ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  children: [
                    Text('شرح الأبيات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink(context))),
                    const SizedBox(height: 4),
                    Text('من ${Library.verseBooks[x.scholar] ?? x.scholar}، ${x.place}', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                    const SizedBox(height: 12),
                    if (!snap.hasData && !snap.hasError) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                    if (snap.hasError || (snap.hasData && snap.data!.isEmpty)) Text('لم يُعثر على الشرح.', style: TextStyle(color: C.muted(context))),
                    for (final (v, t) in snap.data ?? const <(int, String)>[]) ...[
                      if (v >= 1 && v <= x.lines.length) VerseLines(x.lines[v - 1], size: 18),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 16),
                        child: SelectableText(t, style: TextStyle(fontSize: 16, height: 1.8, color: C.ink(context))),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);

/// One shown piece on a page of its own: reached from its era, its rhyme and the search.
class ShahidPieceScreen extends StatelessWidget {
  final Shahid piece;
  const ShahidPieceScreen({super.key, required this.piece});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.i, builder: (context, _) => _page(context));

  Widget _page(BuildContext context) {
    final x = piece;
    final name = x.own ? x.scholar : (x.poet.isEmpty ? 'بلا نسبة' : x.poet);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        InkWell(
          onTap: x.own ? () => openShawahid(context, x.scholar, own: true) : () => openPoet(context, name),
          child: Text(name, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: C.accent(context))),
        ),
        const SizedBox(height: 6),
        Text(
          [Ar.verses(x.lines.length), if (x.era.isNotEmpty) x.era, if (x.died.isNotEmpty) 'ت ${x.died.endsWith('هـ') ? x.died : '${x.died}هـ'}'].join(' · '),
          style: TextStyle(fontSize: 15, color: C.muted(context)),
        ),
        Divider(height: 32, color: C.line(context)),
        if (x.note.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(x.note, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.muted(context)))),
        for (final l in x.lines) Padding(padding: const EdgeInsets.only(bottom: 10), child: VerseLines(l, size: 23)),
        if (x.hasSharh) shahidSharh(context, x),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => openShawahid(context, x.scholar, own: x.own),
          child: Text(x.citeLine, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.accent(context))),
        ),
        if (x.edition.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('الطبعة: ${x.edition}', style: TextStyle(fontSize: 13, color: C.muted(context)))),
        const SizedBox(height: 6),
        shahidActions(context, x),
        if (Store.i.developer)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: OutlinedButton.icon(
              onPressed: () => push(context, EditPieceScreen.piece(x)),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(Store.i.edits.containsKey('s:${x.id}') ? 'تحرير (معدَّل)' : 'تحرير: النص والتشكيل واسم الشاعر'),
            ),
          ),
      ]),
    );
  }
}
