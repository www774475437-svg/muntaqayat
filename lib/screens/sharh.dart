import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../services/cloud.dart';
import '../ui.dart';
import 'cloud_ui.dart' show ago;
import 'lists.dart';
import 'qawafi.dart' show MemberScreen;

/// One explanation: the verse small, then the text, then who wrote it.
class _SharhCard extends StatelessWidget {
  final Doc x;
  final bool showAuthor, openPoemOnTap;
  final VoidCallback reload;
  const _SharhCard(this.x, {required this.reload, this.showAuthor = true, this.openPoemOnTap = false});

  @override
  Widget build(BuildContext context) {
    final c = Cloud.i;
    final mine = x['uid'] == c.uid;
    final poem = Library.byId[x['poem'] is num ? (x['poem'] as num).toInt() : -1];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        onTap: openPoemOnTap && poem != null ? () => openPoem(context, poem) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${x['a'] ?? ''}${'${x['b'] ?? ''}'.isEmpty ? '' : '  ...  ${x['b']}'}', style: TextStyle(fontFamily: 'Amiri', fontSize: 14.5, height: 1.7, color: C.muted(context))),
          const SizedBox(height: 6),
          Text('${x['text'] ?? ''}', style: TextStyle(fontSize: 16.5, height: 1.9, color: C.ink(context))),
          const SizedBox(height: 6),
          Row(children: [
            if (showAuthor)
              Expanded(
                child: InkWell(
                  onTap: () => push(context, MemberScreen(uid: '${x['uid']}', name: '${x['name'] ?? ''}', publicId: '${x['publicId'] ?? ''}')),
                  child: Text('الشارح: ${x['name'] ?? ''}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.accent(context))),
                ),
              )
            else
              Expanded(child: Text(ago(x['at']), style: TextStyle(fontSize: 12.5, color: C.muted(context)))),
            if (c.sharhOnTrial(x)) Text('تحت التجربة', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
            if (c.sharhOnTrial(x) && c.isDev)
              TextButton(
                onPressed: () {
                  c.acceptSharh('${x['id']}');
                  reload();
                },
                child: const Text('اقبله'),
              ),
            if (mine || c.can('مراجعة'))
              IconButton(
                tooltip: 'حذف',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: () async {
                  await c.deleteQuote('${x['id']}');
                  reload();
                },
                icon: Icon(Icons.delete_outline_rounded, color: C.muted(context)),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// «شروح القرّاء» for one selection. Whoever carries «الشارح» writes from here.
class PoemSharhScreen extends StatefulWidget {
  final Poem poem;
  const PoemSharhScreen({super.key, required this.poem});
  @override
  State<PoemSharhScreen> createState() => _PoemSharhScreenState();
}

class _PoemSharhScreenState extends State<PoemSharhScreen> {
  late Future<List<Doc>> job = Cloud.i.sharhOf(widget.poem.id);
  void reload() => setState(() => job = Cloud.i.sharhOf(widget.poem.id));

  Future<void> _write() async {
    final p = widget.poem;
    var verse = 0;
    final t = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (s) => StatefulBuilder(
        builder: (s, set) => Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(s).viewInsets.bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('اختر البيت ثم اكتب شرحه', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(s))),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (var i = 0; i < p.lines.length; i++)
                  if (!p.gone(i + 1))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(label: Text('البيت ${Ar.num(i + 1)}'), selected: verse == i, onSelected: (_) => set(() => verse = i)),
                    ),
              ]),
            ),
            const SizedBox(height: 6),
            Text(p.lines[verse].join('  ...  '), style: TextStyle(fontFamily: 'Amiri', fontSize: 15, height: 1.7, color: C.muted(s))),
            const SizedBox(height: 8),
            TextField(controller: t, minLines: 4, maxLines: 9, maxLength: 1500, decoration: const InputDecoration(hintText: 'اكتب الشرح، واذكر مصدرك إن نقلت')),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.pop(s, true), child: const Text('انشر الشرح')),
          ]),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final err = await Cloud.i.publishSharh(p, verse, t.text);
    if (!mounted) return;
    toast(context, err ?? (Cloud.i.hasTitle('تحت التجربة') && !Cloud.i.isDev ? 'وصل شرحك، ويظهر للناس بعد قبول المطوّر' : 'نُشر الشرح'));
    if (err == null) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('شروح القرّاء')),
        floatingActionButton: Cloud.i.hasTitle('الشارح') ? FloatingActionButton.extended(onPressed: _write, icon: const Icon(Icons.edit_rounded), label: const Text('اكتب شرحاً')) : null,
        body: FutureBuilder<List<Doc>>(
          future: job,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final list = [...(snap.data ?? <Doc>[])]..sort((a, b) => ((a['v'] ?? 0) as num).compareTo((b['v'] ?? 0) as num));
            if (list.isEmpty) {
              return const EmptyNote(Icons.menu_book_outlined, 'لا شروح لهذا المقطع بعد. يكتبها من منحه المطوّر شارة «الشارح».');
            }
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [for (final x in list) _SharhCard(x, reload: reload)]);
          },
        ),
      );
}

/// Everything one reader explained. Each card opens its verse.
class SharhListScreen extends StatefulWidget {
  final String uid, name;
  const SharhListScreen({super.key, required this.uid, required this.name});
  @override
  State<SharhListScreen> createState() => _SharhListScreenState();
}

class _SharhListScreenState extends State<SharhListScreen> {
  late Future<List<Doc>> job = Cloud.i.sharhBy(widget.uid);
  void reload() => setState(() => job = Cloud.i.sharhBy(widget.uid));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.uid == Cloud.i.uid ? 'شروحي' : 'شروح ${widget.name}')),
        body: FutureBuilder<List<Doc>>(
          future: job,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final list = snap.data ?? <Doc>[];
            if (list.isEmpty) return const EmptyNote(Icons.menu_book_outlined, 'لا شروح بعد. يُكتب الشرح من قائمة المقطع: «شروح القرّاء».');
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
              Text('${Ar.num(list.length)} شرحاً', style: TextStyle(color: C.muted(context))),
              const SizedBox(height: 8),
              for (final x in list) _SharhCard(x, reload: reload, showAuthor: false, openPoemOnTap: true),
            ]);
          },
        ),
      );
}

/// «اطلب شارة»: the request reaches the developer in his messages (one a day).
Future<void> requestBadge(BuildContext context) async {
  const offered = ['الشارح', 'المشكِّل', 'الموثِّق', 'الكاشف', 'المراقب', 'المحرّر', 'شاعر موثّق'];
  var chosen = offered.first;
  final t = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: const Text('اطلب شارة'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final b in offered) ChoiceChip(label: Text(b), selected: chosen == b, onSelected: (_) => set(() => chosen = b)),
            ]),
            const SizedBox(height: 10),
            TextField(controller: t, maxLines: 3, maxLength: 300, decoration: const InputDecoration(hintText: 'لماذا تطلبها؟ اذكر خبرتك باختصار')),
            Text('يراجع المطوّر طلبك، وقد يجرّبك مدة قبل منحها.', style: TextStyle(fontSize: 12.5, color: C.muted(d))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('أرسل الطلب')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final err = await Cloud.i.sendMessage('طلب شارة «$chosen»\n${t.text.trim()}', kind: 'badge');
  if (context.mounted) toast(context, err ?? 'وصل طلبك إلى المطوّر');
}
