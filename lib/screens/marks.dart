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
  bool bookOnly = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final rows = <(Poem, int)>[];
          var nVer = 0, nHid = 0, nNot = 0;
          for (final p in Library.all) {
            if (bookOnly && !p.fromBook) continue;
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
          return Scaffold(
            appBar: AppBar(title: const Text('الموثّقة وغير الموثّقة')),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 0, label: Text('غير موثّقة ${Ar.num(nNot)}')),
                    ButtonSegment(value: 1, label: Text('موثّقة ${Ar.num(nVer)}')),
                    ButtonSegment(value: 2, label: Text('مخفية ${Ar.num(nHid)}')),
                  ],
                  selected: {tab},
                  onSelectionChanged: (v) => setState(() => tab = v.first),
                ),
              ),
              SwitchListTile(
                dense: true,
                value: bookOnly,
                onChanged: (v) => setState(() => bookOnly = v),
                title: const Text('أبيات الكتاب فقط (العلامة الخضراء)'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  tab == 2
                      ? 'المخفي لا يراه القرّاء. اضغط «أظهر» ليعود، أو «احذف» ليُزال نهائياً.'
                      : 'العلامة الزرقاء توثيقك أنت، والخضراء لما في الكتاب. يعمّ التوثيق والإخفاء كل الأجهزة بعد ربط فايربيس.',
                  style: TextStyle(fontSize: 13, color: C.muted(context)),
                ),
              ),
              Expanded(
                child: rows.isEmpty
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
