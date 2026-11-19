import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data.dart';
import '../ui.dart';
import 'lists.dart';
import 'matn_tools.dart';
import 'plus.dart';

/// «متون طالب العلم وقصائده»: branches, then the poems to memorize.
class MutunScreen extends StatelessWidget {
  const MutunScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final due = Store.i.dueAll;
          return Scaffold(
            appBar: AppBar(title: const Text('متون طالب العلم وقصائده')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              Text('منظومات علماء السنة للحفظ والمراجعة: احفظ وِردك كل يوم، وراجع ما حفظت، واختبر نفسك كتابةً.',
                  style: TextStyle(fontSize: 15, color: C.muted(context), height: 1.6)),
              if (due > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const Icon(Icons.notifications_active_outlined, color: Color(0xFFD9A21B)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('عليك مراجعة ${Ar.verses(due)} اليوم حتى لا تُنسى', style: TextStyle(fontSize: 15.5, color: C.ink(context)))),
                    ]),
                  ),
                ),
              for (final b in Library.branches) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                  child: Text(b, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.accent(context))),
                ),
                for (final m in Library.mutun.where((m) => m.branch == b)) _card(context, m),
              ],
            ]),
          );
        },
      );

  Widget _card(BuildContext context, Matn m) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(
          onTap: () => push(context, MatnScreen(matn: m)),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            RoundIcon(m.ready ? Icons.menu_book_rounded : Icons.hourglass_empty_rounded, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
                Text('${m.author}${m.death.isEmpty ? '' : ' · ت ${m.death}'}', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (m.ready)
                    Text('حفظتَ ${Ar.num(Store.i.memOf(m.id).length)} من ${Ar.num(m.lines.length)} بيتاً',
                        style: TextStyle(fontSize: 13.5, color: C.accent(context))),
                  if (!m.complete) const IncompleteTag(),
                  if (Store.i.developer && Store.i.isVerified('m:${m.id}')) const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF2F6B4F)),
                ]),
              ]),
            ),
            Icon(Icons.chevron_left_rounded, color: C.muted(context)),
          ]),
        ),
      );
}

class IncompleteTag extends StatelessWidget {
  const IncompleteTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0x1AB3261E), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFB3261E))),
        child: const Text('غير كاملة', style: TextStyle(fontSize: 12.5, color: Color(0xFFB3261E), fontWeight: FontWeight.w700)),
      );
}

class MatnScreen extends StatelessWidget {
  final Matn matn;
  const MatnScreen({super.key, required this.matn});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final mem = Store.i.memOf(matn.id);
          final total = matn.lines.length;
          final due = Store.i.dueOf(matn.id).length;
          final dev = Store.i.developer;
          final head = <Widget>[
            Text('${matn.author}${matn.death.isEmpty ? '' : ' · ت ${matn.death}'}',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: C.accent(context))),
            if (!matn.complete || dev)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (!matn.complete) const IncompleteTag(),
                  if (dev)
                    ActionChip(
                      avatar: Icon(Store.i.isVerified('m:${matn.id}') ? Icons.verified_rounded : Icons.verified_outlined,
                          color: Store.i.isVerified('m:${matn.id}') ? const Color(0xFF2F6B4F) : Colors.orange.shade700),
                      label: Text(Store.i.isVerified('m:${matn.id}') ? 'المنظومة موثّقة (للمطوّر)' : 'وثّق المنظومة كلها (للمطوّر)'),
                      onPressed: () => Store.i.toggleVerified('m:${matn.id}'),
                    ),
                ]),
              ),
            if (matn.intro.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(matn.intro, style: TextStyle(fontSize: 15, height: 1.6, color: C.ink(context))),
              ),
            if (matn.source.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('المصدر: ${matn.source}', style: TextStyle(fontSize: 13, color: C.muted(context))),
              ),
            if (!matn.ready)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: EmptyNote(Icons.hourglass_empty_rounded, 'نصّ هذه المنظومة يُضاف قريباً من طبعة محقّقة بإذن الله.'),
              )
            else ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: total == 0 ? 0 : mem.length / total, minHeight: 8, borderRadius: BorderRadius.circular(6)),
              const SizedBox(height: 6),
              Text('حفظتَ ${Ar.num(mem.length)} من ${Ar.num(total)} بيتاً${due > 0 ? ' · للمراجعة اليوم ${Ar.num(due)}' : ''}',
                  style: TextStyle(color: C.muted(context))),
              const SizedBox(height: 14),
              Row(children: [
                _big(context, Icons.auto_stories_rounded, 'احفظ', 'وِرد اليوم', () => push(context, WirdScreen(matn: matn))),
                const SizedBox(width: 10),
                _big(context, Icons.replay_rounded, 'راجع', due > 0 ? 'حان ${Ar.num(due)}' : 'ما حفظتَه', () {
                  if (mem.isEmpty) {
                    toast(context, 'لم تحفظ شيئاً بعد. ابدأ بـ«احفظ».');
                  } else {
                    push(context, WirdScreen(matn: matn, review: true));
                  }
                }),
                const SizedBox(width: 10),
                _big(context, Icons.edit_note_rounded, 'اختبر', 'كتابةً', () => push(context, TestSetupScreen(matn: matn))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _small(context, Icons.grid_view_rounded, 'خريطة الحفظ', () => push(context, MemoryMapScreen(matn: matn))),
                const SizedBox(width: 8),
                _small(context, Icons.record_voice_over_outlined, 'استمع وردّد', () => push(context, ListenScreen(matn: matn))),
                const SizedBox(width: 8),
                _small(context, Icons.workspace_premium_outlined, 'الشهادة', () {
                  if (certificateReady(matn) || dev) {
                    push(context, CertificateScreen(matn: matn));
                  } else {
                    soonSheet(context, 'شهادة إتمام الحفظ',
                        'احفظ المنظومة كلها، ثم اختبر نفسك كتابةً فيها كلها، فإذا نلت ٩ من ١٠ أو أكثر ظهرت لك شهادتك باسمك بصيغة PDF.\n\nأفضل درجتك الآن: ${Ar.num(Store.i.best[matn.id] ?? 0)} من ١٠.');
                  }
                }),
              ]),
            ],
            ShuruhSection(matn: matn),
            if (matn.ready) const SectionTitle('أبيات المنظومة'),
            if (matn.ready)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.soft(context), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF2F6B4F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('إذا حفظت بيتاً فاضغط الدائرة بجانبه فتصير خضراء «حفظتُه»، فيُحسب في تقدّمك ويدخل في المراجعة.',
                        style: TextStyle(fontSize: 14, height: 1.5, color: C.ink(context))),
                  ),
                ]),
              ),
          ];
          return Scaffold(
            appBar: AppBar(title: Text(matn.title)),
            body: CustomScrollView(slivers: [
              SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), sliver: SliverList.list(children: head)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList.builder(itemCount: total, itemBuilder: (c, i) => _verse(c, i, mem.contains(i + 1))),
              ),
            ]),
          );
        },
      );

  Widget _small(BuildContext context, IconData icon, String t, VoidCallback onTap) => Expanded(
        child: SoftCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(children: [
            Icon(icon, color: C.accent(context)),
            const SizedBox(height: 4),
            Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.ink(context))),
          ]),
        ),
      );

  Widget _big(BuildContext context, IconData icon, String t, String sub, VoidCallback onTap) => Expanded(
        child: SoftCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(children: [
            RoundIcon(icon, size: 46),
            const SizedBox(height: 6),
            Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
            Text(sub, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
          ]),
        ),
      );

  Widget _verse(BuildContext context, int i, bool done) {
    final note = matn.notes[i + 1];
    final h = matn.heads[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (h != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Text(h, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: VerseLines(matn.lines[i], size: 22, number: i + 1)),
          if (Store.i.developer)
            Column(mainAxisSize: MainAxisSize.min, children: [
              VerifyButton('m:${matn.id}:${i + 1}', what: 'هذا البيت'),
              Text('توثيق', style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
            ]),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Store.i.setMemorized(matn.id, i + 1, !done),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 28, color: done ? const Color(0xFF2F6B4F) : C.muted(context)),
                const SizedBox(height: 2),
                Text(done ? 'حفظتُه' : 'حفظتَه؟', style: TextStyle(fontSize: 11.5, color: done ? const Color(0xFF2F6B4F) : C.muted(context))),
              ]),
            ),
          ),
        ]),
        if (note != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 30),
            child: ActionChip(
              backgroundColor: const Color(0x1AB3261E),
              side: const BorderSide(color: Color(0xFFB3261E)),
              avatar: const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB3261E)),
              label: Text('ملاحظة ${note.$1}${note.$3 ? ' — مهم' : ''}', style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w700)),
              onPressed: () => showModalBottomSheet(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 36),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ملاحظة ${note.$1}${note.$3 ? ' — مهم في العقيدة' : ''}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFB3261E))),
                    const SizedBox(height: 10),
                    Text(note.$2, style: const TextStyle(fontSize: 17, height: 1.8)),
                  ]),
                ),
              ),
            ),
          ),
        if (Store.i.developer && matn.review.contains(i + 1))
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 30),
            child: Text('للمطوّر: هذا البيت يحتاج مقابلة بطبعة محقّقة', style: TextStyle(fontSize: 13, color: Colors.orange.shade800)),
          ),
      ]),
    );
  }
}

/// Today's portion (or review of memorized verses): the second hemistich
/// stays hidden until tapped.
class WirdScreen extends StatefulWidget {
  final Matn matn;
  final bool review;
  const WirdScreen({super.key, required this.matn, this.review = false});
  @override
  State<WirdScreen> createState() => _WirdScreenState();
}

class _WirdScreenState extends State<WirdScreen> {
  final shown = <int>{};
  final graded = <int, bool>{};
  late List<int> items;
  bool dueOnly = false;

  @override
  void initState() {
    super.initState();
    final mem = Store.i.memOf(widget.matn.id);
    final all = List.generate(widget.matn.lines.length, (i) => i + 1);
    if (widget.review) {
      final due = Store.i.dueOf(widget.matn.id);
      dueOnly = due.isNotEmpty;
      items = dueOnly ? due : all.where(mem.contains).toList();
    } else {
      items = all.where((n) => !mem.contains(n)).take(Store.i.wird).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.matn;
    return Scaffold(
      appBar: AppBar(title: Text(widget.review ? 'مراجعة ما حفظت' : 'وِرد اليوم')),
      body: items.isEmpty
          ? const EmptyNote(Icons.celebration_rounded, 'أتممتَ حفظ المنظومة كلها، بارك الله فيك! راجعها واختبر نفسك.')
          : ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 40), children: [
              if (!widget.review)
                Row(children: [
                  Expanded(child: Text('عدد أبيات الوِرد:', style: TextStyle(color: C.muted(context)))),
                  DropdownButton<int>(
                    value: Store.i.wird,
                    items: [for (final n in [3, 5, 7, 10, 15]) DropdownMenuItem(value: n, child: Text(Ar.num(n)))],
                    onChanged: (v) {
                      if (v == null) return;
                      Store.i.setWird(v);
                      final mem = Store.i.memOf(m.id);
                      setState(() => items = List.generate(m.lines.length, (i) => i + 1).where((n) => !mem.contains(n)).take(v).toList());
                    },
                  ),
                ]),
              if (widget.review)
                Text(dueOnly ? 'هذه الأبيات حان وقت مراجعتها. بعد أن ترى الشطر الثاني اختر: تذكّرته أو نسيته.' : 'لا شيء حان وقت مراجعته اليوم، وهذه كل أبياتك المحفوظة.',
                    style: TextStyle(color: C.ink(context), height: 1.6)),
              Text('اقرأ الشطر الأول وتذكّر الثاني، ثم اضغط لتراه.', style: TextStyle(color: C.muted(context))),
              const SizedBox(height: 12),
              for (final n in items) _card(context, n),
              if (!widget.review)
                FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    for (final n in items) {
                      Store.i.setMemorized(m.id, n, true);
                    }
                    toast(context, 'سُجّل وِرد اليوم محفوظاً');
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('حفظتُ وِرد اليوم', style: TextStyle(fontSize: 17)),
                ),
            ]),
    );
  }

  Widget _card(BuildContext context, int n) {
    final l = widget.matn.lines[n - 1];
    final st = TextStyle(fontFamily: verseFont, fontSize: 23 * Store.i.fontScale, height: 1.9, color: C.ink(context));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${Ar.num(n)}', style: TextStyle(color: C.muted(context))),
          Text(Store.i.show(l[0]), style: st),
          if (l.length > 1)
            GestureDetector(
              onTap: () => setState(() => shown.contains(n) ? shown.remove(n) : shown.add(n)),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 34),
                child: shown.contains(n)
                    ? Text(Store.i.show(l[1]), style: st.copyWith(color: C.accent(context)))
                    : Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: C.soft(context), borderRadius: BorderRadius.circular(12)),
                        child: Text('اضغط لإظهار الشطر الثاني', style: TextStyle(color: C.muted(context))),
                      ),
              ),
            ),
          if (widget.review && (shown.contains(n) || l.length < 2))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: graded.containsKey(n)
                  ? Text(graded[n]! ? 'أحسنت! تُراجعه بعد مدة أطول.' : 'لا بأس، سيُعاد عليك غداً.',
                      style: TextStyle(color: graded[n]! ? const Color(0xFF2F6B4F) : const Color(0xFFB3261E)))
                  : Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            graded[n] = false;
                            Store.i.reviewed1(widget.matn.id, n, false);
                          }),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFFB3261E)),
                          label: const Text('نسيته'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2F6B4F)),
                          onPressed: () => setState(() {
                            graded[n] = true;
                            Store.i.reviewed1(widget.matn.id, n, true);
                          }),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('تذكّرته'),
                        ),
                      ),
                    ]),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- writing test

enum TestMode { all, half, alternate }

class TestSetupScreen extends StatefulWidget {
  final Matn matn;
  const TestSetupScreen({super.key, required this.matn});
  @override
  State<TestSetupScreen> createState() => _TestSetupScreenState();
}

class _TestSetupScreenState extends State<TestSetupScreen> {
  TestMode mode = TestMode.half;
  bool onlyMemorized = true;
  RangeValues range = const RangeValues(1, 10);

  @override
  void initState() {
    super.initState();
    final n = widget.matn.lines.length.toDouble();
    range = RangeValues(1, n < 10 ? n : 10);
    onlyMemorized = Store.i.memOf(widget.matn.id).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.matn.lines.length.toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('اختبار كتابة')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 40), children: [
        Text('طريقة الاختبار', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
        RadioListTile(value: TestMode.half, groupValue: mode, onChanged: (v) => setState(() => mode = v!), title: const Text('شطر ظاهر وشطر مخفي')),
        RadioListTile(value: TestMode.alternate, groupValue: mode, onChanged: (v) => setState(() => mode = v!), title: const Text('بيت ظاهر وبيت مخفي')),
        RadioListTile(value: TestMode.all, groupValue: mode, onChanged: (v) => setState(() => mode = v!), title: const Text('اكتب الأبيات كلها')),
        const Divider(height: 26),
        SwitchListTile(
          value: onlyMemorized,
          onChanged: Store.i.memOf(widget.matn.id).isEmpty ? null : (v) => setState(() => onlyMemorized = v),
          title: const Text('ما حفظتُه فقط'),
        ),
        if (!onlyMemorized) ...[
          Text('من البيت ${Ar.num(range.start.round())} إلى ${Ar.num(range.end.round())}', style: TextStyle(color: C.muted(context))),
          RangeSlider(values: range, min: 1, max: n, divisions: n > 1 ? (n - 1).round() : 1, onChanged: (v) => setState(() => range = v)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
          onPressed: () {
            final mem = Store.i.memOf(widget.matn.id);
            final verses = onlyMemorized
                ? (mem.toList()..sort())
                : [for (var i = range.start.round(); i <= range.end.round(); i++) i];
            push(context, WritingTestScreen(matn: widget.matn, verses: verses, mode: mode));
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('ابدأ الاختبار', style: TextStyle(fontSize: 17)),
        ),
      ]),
    );
  }
}

class _Item {
  final int verse; // 1-based
  final String shown; // what is visible ('' = nothing)
  final String hidden; // what the student writes
  final ctl = TextEditingController();
  _Item(this.verse, this.shown, this.hidden);
}

class WritingTestScreen extends StatefulWidget {
  final Matn matn;
  final List<int> verses;
  final TestMode mode;
  const WritingTestScreen({super.key, required this.matn, required this.verses, required this.mode});
  @override
  State<WritingTestScreen> createState() => _WritingTestScreenState();
}

class _WritingTestScreenState extends State<WritingTestScreen> {
  late final List<_Item> items;
  final shownVerses = <(int, List<String>)>[];
  bool checked = false;

  @override
  void initState() {
    super.initState();
    items = [];
    for (var k = 0; k < widget.verses.length; k++) {
      final n = widget.verses[k];
      final l = widget.matn.lines[n - 1];
      switch (widget.mode) {
        case TestMode.half:
          items.add(_Item(n, l[0], l.length > 1 ? l[1] : ''));
        case TestMode.all:
          items.add(_Item(n, '', l.join(' ')));
        case TestMode.alternate:
          if (k.isEven) {
            shownVerses.add((n, l));
          } else {
            items.add(_Item(n, '', l.join(' ')));
          }
      }
    }
  }

  @override
  void dispose() {
    for (final i in items) {
      i.ctl.dispose();
    }
    super.dispose();
  }

  static List<String> _words(String s) =>
      Ar.norm(s).replaceAll(RegExp(r'[^ء-ي\s]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Marks every expected word as right (true) or wrong/missing (false),
  /// using the longest common sequence of words.
  static List<bool> _marks(List<String> want, List<String> got) {
    final dp = List.generate(want.length + 1, (_) => List.filled(got.length + 1, 0));
    for (var i = want.length - 1; i >= 0; i--) {
      for (var j = got.length - 1; j >= 0; j--) {
        dp[i][j] = want[i] == got[j] ? dp[i + 1][j + 1] + 1 : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
      }
    }
    final ok = List.filled(want.length, false);
    var i = 0, j = 0;
    while (i < want.length && j < got.length) {
      if (want[i] == got[j]) {
        ok[i] = true;
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    return ok;
  }

  (int, int) get _score {
    var right = 0, total = 0;
    for (final it in items) {
      final m = _marks(_words(it.hidden), _words(it.ctl.text));
      total += m.length;
      right += m.where((x) => x).length;
    }
    return (right, total);
  }

  String _report() {
    final (r, t) = _score;
    final b = StringBuffer('نتيجة اختبار «${widget.matn.title}»: ${Ar.num(r)} من ${Ar.num(t)} كلمة صحيحة\n\n');
    for (final it in items) {
      b.writeln('البيت ${Ar.num(it.verse)}:');
      b.writeln('ما كتبتُ: ${it.ctl.text.trim().isEmpty ? '—' : it.ctl.text.trim()}');
      b.writeln('الصحيح: ${it.hidden}\n');
    }
    b.write('— منتقيات الشعر');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontFamily: verseFont, fontSize: 21 * Store.i.fontScale, height: 1.8, color: C.ink(context));
    final (r, t) = checked ? _score : (0, 0);
    return Scaffold(
      appBar: AppBar(title: Text('اختبار: ${widget.matn.title}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        if (checked)
          SoftCard(
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(children: [
              Text('${Ar.num(t == 0 ? 0 : (r * 10 / t).round())} / ١٠',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: C.accent(context))),
              Text('${Ar.num(r)} كلمة صحيحة من ${Ar.num(t)}', style: TextStyle(color: C.muted(context))),
              const SizedBox(height: 6),
              Wrap(spacing: 10, children: [
                _legend(const Color(0xFF2F6B4F), 'صحيح'),
                _legend(const Color(0xFFB3261E), 'خطأ أو ناقص'),
              ]),
            ]),
          ),
        Text('اكتب ما حفظت في الخانات. لا تُحسب الحركات.', style: TextStyle(color: C.muted(context))),
        const SizedBox(height: 10),
        ..._body(context, st),
        const SizedBox(height: 12),
        if (!checked)
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            onPressed: () {
              FocusScope.of(context).unfocus();
              setState(() => checked = true);
              final (r, t) = _score;
              if (t > 0 && widget.verses.length >= widget.matn.lines.length) {
                Store.i.setBest(widget.matn.id, (r * 10 / t).floor());
                if (certificateReady(widget.matn)) {
                  toast(context, 'مبارك! نلت شهادة إتمام الحفظ — افتحها من صفحة المنظومة');
                }
              }
            },
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('تحقّق', style: TextStyle(fontSize: 17)),
          )
        else
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  checked = false;
                  for (final i in items) {
                    i.ctl.clear();
                  }
                }),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('أعد الاختبار'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Share.share(_report()),
                icon: const Icon(Icons.send_rounded),
                label: const Text('أرسل النتيجة'),
              ),
            ),
          ]),
      ]),
    );
  }

  List<Widget> _body(BuildContext context, TextStyle st) {
    // Show hidden and visible verses in their order.
    final order = <(int, Widget)>[];
    for (final v in shownVerses) {
      order.add((v.$1, Padding(padding: const EdgeInsets.only(bottom: 10), child: SoftCard(child: VerseLines(v.$2, size: 21, number: v.$1)))));
    }
    for (final it in items) {
      order.add((it.verse, _item(context, it, st)));
    }
    order.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final o in order) o.$2];
  }

  Widget _item(BuildContext context, _Item it, TextStyle st) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('البيت ${Ar.num(it.verse)}', style: TextStyle(color: C.muted(context))),
          if (it.shown.isNotEmpty) Text(Store.i.show(it.shown), style: st),
          if (!checked)
            TextField(
              controller: it.ctl,
              minLines: 1,
              maxLines: 3,
              style: st,
              decoration: InputDecoration(
                hintText: it.shown.isEmpty ? 'اكتب البيت' : 'اكتب الشطر الثاني',
                filled: true,
                fillColor: C.bg(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          else ...[
            Text('ما كتبتَ:', style: TextStyle(fontSize: 13, color: C.muted(context))),
            Text(it.ctl.text.trim().isEmpty ? '—' : it.ctl.text.trim(), style: st.copyWith(fontSize: st.fontSize! * 0.9)),
            const SizedBox(height: 6),
            Text('الصحيح:', style: TextStyle(fontSize: 13, color: C.muted(context))),
            _colored(it, st),
          ],
        ]),
      ),
    );
  }

  Widget _colored(_Item it, TextStyle st) {
    final words = it.hidden.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final norm = [for (final w in words) _words(w).join()];
    final ok = _marks(norm, _words(it.ctl.text));
    return Text.rich(TextSpan(children: [
      for (var i = 0; i < words.length; i++)
        TextSpan(
          text: '${words[i]} ',
          style: st.copyWith(
            color: ok[i] ? const Color(0xFF2F6B4F) : const Color(0xFFB3261E),
            fontWeight: ok[i] ? FontWeight.normal : FontWeight.w700,
            decoration: ok[i] ? null : TextDecoration.underline,
          ),
        ),
    ]));
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(t),
      ]);
}
