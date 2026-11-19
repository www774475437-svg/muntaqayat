import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';

/// Developer only: every verse, sorted into «غير موثّقة», «موثّقة» and «مخفية».
/// Blue mark = verified by the developer. Hidden verses disappear for readers,
/// and can then be deleted for good from the hidden list.
class MarksScreen extends StatefulWidget {
  const MarksScreen({super.key});
  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  int tab = 0;
  int source = 0; // 0 all, 1 in the book, 2 outside the book

  static final _letters = RegExp('[^\u0621-\u064A ]');
  static String _key(String t) => Ar.norm(t).replaceAll(_letters, '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Verses that share their first half: (same whole verse?, the places).
  List<(bool, List<(Poem, int)>)> _duplicates() {
    final byHalf = <String, List<(Poem, int)>>{};
    for (final p in Library.all) {
      for (var v = 1; v <= p.lines.length; v++) {
        if (p.deletedVerse(v)) continue;
        final k = _key(p.lines[v - 1][0]);
        if (k.length < 8) continue;
        byHalf.putIfAbsent(k, () => []).add((p, v));
      }
    }
    final out = <(bool, List<(Poem, int)>)>[];
    for (final g in byHalf.values) {
      if (g.length < 2) continue;
      if (source == 1 && !g.any((x) => x.$1.fromBook)) continue;
      if (source == 2 && !g.any((x) => !x.$1.fromBook)) continue;
      final whole = g.map((x) => _key(x.$1.lines[x.$2 - 1].join(' '))).toSet().length == 1;
      out.add((whole, g));
    }
    return out;
  }

  Widget _dupCard(BuildContext context, (bool, List<(Poem, int)>) g) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.$1 ? 'البيت نفسه في ${Ar.num(g.$2.length)} مواضع' : 'الشطر الأول نفسه في ${Ar.num(g.$2.length)} مواضع',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.accent(context))),
            VerseLines(g.$2.first.$1.lines[g.$2.first.$2 - 1], size: 19),
            for (final (p, v) in g.$2)
              InkWell(
                onTap: () => openPoem(context, p),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!g.$1 && (p, v) != g.$2.first) VerseLines(p.lines[v - 1], size: 16, color: C.muted(context)),
                  Row(children: [
                    Icon(p.fromBook ? Icons.menu_book_rounded : Icons.add_circle_outline_rounded, size: 16, color: p.fromBook ? bookGreen : C.muted(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${p.poet} · ${p.chapterName} · البيت ${Ar.num(v)}${p.hiddenVerse(v) ? ' · مخفي' : ''}',
                          maxLines: 2, style: TextStyle(fontSize: 13, color: C.ink(context))),
                    ),
                    TextButton(onPressed: () => openPoem(context, p), child: const Text('افتحه')),
                    TextButton(onPressed: () => Store.i.setHidden('p:${p.id}:$v', !p.hiddenVerse(v)), child: Text(p.hiddenVerse(v) ? 'أظهر' : 'أخفِ')),
                  ]),
                ]),
              ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final rows = <(Poem, int)>[];
          var nVer = 0, nHid = 0, nNot = 0;
          for (final p in Library.all) {
            if (source == 1 && !p.fromBook || source == 2 && p.fromBook) continue;
            for (var v = 1; v <= p.lines.length; v++) {
              if (p.deletedVerse(v)) continue;
              final hid = p.hiddenVerse(v), ver = p.verifiedVerse(v);
              if (hid) {
                nHid++;
              } else if (ver) {
                nVer++;
              } else {
                nNot++;
              }
              final t = hid ? 2 : (ver ? 1 : 0);
              if (t == tab) rows.add((p, v));
            }
          }
          final dups = _duplicates();
          return Scaffold(
            appBar: AppBar(title: const Text('الموثّقة وغير الموثّقة')),
            body: Column(children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 0, label: Text('غير موثّقة ${Ar.num(nNot)}')),
                    ButtonSegment(value: 1, label: Text('موثّقة ${Ar.num(nVer)}')),
                    ButtonSegment(value: 2, label: Text('مخفية ${Ar.num(nHid)}')),
                    ButtonSegment(value: 3, label: Text('مكررات ${Ar.num(dups.length)}')),
                  ],
                  selected: {tab},
                  onSelectionChanged: (v) => setState(() => tab = v.first),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, label: Text('الكل')),
                    ButtonSegment(value: 1, label: Text('داخل الكتاب'), icon: Icon(Icons.menu_book_rounded, size: 16)),
                    ButtonSegment(value: 2, label: Text('خارج الكتاب'), icon: Icon(Icons.add_circle_outline_rounded, size: 16)),
                  ],
                  selected: {source},
                  onSelectionChanged: (v) => setState(() => source = v.first),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  tab == 3
                      ? 'أبيات تكرر شطرها الأول في أكثر من موضع. اضغط «افتحه» لتنتقل إلى الموضع، أو «أخفِ» لتخفي الزائد.'
                      : tab == 2
                          ? 'المخفي لا يراه القرّاء. اضغط «أظهر» ليعود، أو «احذف» ليُزال نهائياً.'
                          : 'العلامة الزرقاء توثيقك أنت، والخضراء لما في الكتاب. يصل التوثيق والإخفاء إلى كل الأجهزة وأنت داخل بحساب المطوّر.',
                  style: TextStyle(fontSize: 13, color: C.muted(context)),
                ),
              ),
              Expanded(
                child: tab == 3
                    ? (dups.isEmpty
                        ? const EmptyNote(Icons.inbox_outlined, 'لا مكررات.')
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
                            itemCount: dups.length,
                            itemBuilder: (context, i) => _dupCard(context, dups[i]),
                          ))
                    : rows.isEmpty
                    ? const EmptyNote(Icons.inbox_outlined, 'لا شيء هنا.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final (p, v) = rows[i];
                          final key = 'p:${p.id}:$v';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SoftCard(
                              padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
                              onTap: () => openPoem(context, p),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                VerseLines(p.lines[v - 1], size: 19),
                                Row(children: [
                                  if (p.fromBook) const Icon(Icons.menu_book_rounded, size: 16, color: bookGreen),
                                  if (p.verifiedVerse(v)) const Icon(Icons.verified_rounded, size: 16, color: verifiedBlue),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(p.poet, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: C.muted(context)))),
                                  if (tab != 2)
                                    TextButton(
                                      onPressed: () => s.toggleVerified(key),
                                      child: Text(p.verifiedVerse(v) ? 'ألغِ التوثيق' : 'وثّق', style: const TextStyle(color: verifiedBlue)),
                                    ),
                                  TextButton(onPressed: () => s.setHidden(key, tab != 2), child: Text(tab == 2 ? 'أظهر' : 'أخفِ')),
                                  if (tab == 2)
                                    TextButton(
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (d) => AlertDialog(
                                          title: const Text('حذف البيت نهائياً؟'),
                                          content: const Text('لن يظهر بعد ذلك في أي قائمة، ولا يمكن التراجع من داخل التطبيق.'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
                                            FilledButton(
                                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
                                              onPressed: () {
                                                s.deleteForGood(key);
                                                Navigator.pop(d);
                                              },
                                              child: const Text('احذف'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      child: const Text('احذف', style: TextStyle(color: Color(0xFFB3261E))),
                                    ),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          );
        },
      );
}
