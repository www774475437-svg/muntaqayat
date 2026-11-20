import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../services/majma.dart';
import '../ui.dart';
import 'boards.dart';
import 'lists.dart';

int _dayNumber() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).difference(DateTime(2026, 1, 1)).inDays;
}

class _Q {
  final Mathal m;
  final String title, text, correct;
  final List<String> options;
  const _Q(this.m, this.title, this.text, this.options, this.correct);
}

/// «أمثال العرب»: three questions every day from «مجمع الأمثال», two attempts
/// for each. After each answer the proverb appears with the book's explanation.
class ProverbQuizScreen extends StatefulWidget {
  const ProverbQuizScreen({super.key});
  @override
  State<ProverbQuizScreen> createState() => _ProverbQuizScreenState();
}

class _ProverbQuizScreenState extends State<ProverbQuizScreen> {
  final day = _dayNumber();
  List<_Q>? questions;
  // For each question: the wrong picks so far, and how it ended.
  // done: 0 = still open, 1 = right from the first try, 2 = right from the second, 3 = missed.
  final List<List<String>> wrong = [[], [], []];
  final List<int> done = [0, 0, 0];
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await Majma.all();
    final p = await SharedPreferences.getInstance();
    final pool = [for (final m in list) if (m.quiz) m];
    final rnd = math.Random(day * 7919 + 13);
    final picked = <Mathal>[];
    while (picked.length < 3 && picked.length < pool.length) {
      final m = pool[rnd.nextInt(pool.length)];
      if (!picked.contains(m)) picked.add(m);
    }
    final qs = <_Q>[
      for (var i = 0; i < picked.length; i++) i == 1 ? _meaning(pool, picked[i], rnd) : _complete(pool, picked[i], rnd),
    ];
    // What was answered earlier today stays answered.
    try {
      final saved = jsonDecode(p.getString('proverbQuiz') ?? '{}') as Map;
      if (saved['day'] == day) {
        final d = saved['done'] as List, w = saved['wrong'] as List;
        for (var i = 0; i < 3; i++) {
          done[i] = d[i] as int;
          wrong[i].addAll([for (final x in w[i] as List) '$x']);
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      prefs = p;
      questions = qs;
    });
  }

  /// «أكمِل المثل»: the last word is hidden.
  _Q _complete(List<Mathal> pool, Mathal m, math.Random rnd) {
    final words = m.text.split(' ');
    final last = words.last;
    final opts = <String>{last};
    while (opts.length < 4) {
      final w = pool[rnd.nextInt(pool.length)].text.split(' ').last;
      if (Ar.plain(w) != Ar.plain(last)) opts.add(w);
    }
    return _Q(m, 'أكمِل المثل', '${words.sublist(0, words.length - 1).join(' ')} …', opts.toList()..shuffle(rnd), last);
  }

  /// «أيّ مثل يُضرب لهذا؟»: the book's «يضرب» sentence, and four proverbs.
  _Q _meaning(List<Mathal> pool, Mathal m, math.Random rnd) {
    final opts = <String>{m.text};
    while (opts.length < 4) {
      opts.add(pool[rnd.nextInt(pool.length)].text);
    }
    return _Q(m, 'أيّ مثل يُضرب لهذا؟', m.usage, opts.toList()..shuffle(rnd), m.text);
  }

  void _save() {
    prefs?.setString('proverbQuiz', jsonEncode({'day': day, 'done': done, 'wrong': wrong}));
  }

  void _pick(int i, String choice) {
    final q = questions![i];
    if (done[i] != 0 || wrong[i].contains(choice)) return;
    setState(() {
      if (choice == q.correct) {
        done[i] = wrong[i].isEmpty ? 1 : 2;
      } else {
        wrong[i].add(choice);
        if (wrong[i].length >= 2) done[i] = 3;
      }
    });
    _save();
    if (done[i] != 0) Cloud.i.countQuizAnswer(done[i] != 3);
  }

  @override
  Widget build(BuildContext context) {
    final qs = questions;
    final finished = !done.contains(0);
    final right = done.where((d) => d == 1 || d == 2).length;
    return Scaffold(
      appBar: AppBar(title: const Text('أمثال العرب'), actions: [
        IconButton(tooltip: 'كل الأمثال', icon: const Icon(Icons.menu_book_outlined), onPressed: () => push(context, const MajmaScreen())),
        IconButton(tooltip: 'المتصدرون', icon: const Icon(Icons.emoji_events_outlined), onPressed: () => push(context, const BoardsScreen())),
      ]),
      body: qs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
              Text('ثلاثة أسئلة كل يوم من «مجمع الأمثال» للميداني، ولكل سؤال محاولتان. ثم المثل وشرحه وقصته من الكتاب.', style: TextStyle(fontSize: 15, height: 1.7, color: C.muted(context))),
              const SizedBox(height: 14),
              for (var i = 0; i < qs.length; i++) ...[
                _card(context, i, qs[i]),
                const SizedBox(height: 14),
              ],
              if (finished)
                SoftCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('درجتك اليوم ${Ar.num((right * 100 / qs.length).floor())}٪: ${Ar.num(right)} من ${Ar.num(qs.length)}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
                    const SizedBox(height: 4),
                    Text('لا تُعاد أسئلة اليوم. أمثال جديدة غداً، وهي واحدة عند الجميع.', style: TextStyle(color: C.muted(context))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: FilledButton.icon(onPressed: () => push(context, const BoardsScreen()), icon: const Icon(Icons.emoji_events_outlined), label: const Text('المتصدرون'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(onPressed: () => push(context, const MajmaScreen()), icon: const Icon(Icons.menu_book_outlined), label: const Text('كل الأمثال'))),
                    ]),
                  ]),
                ),
            ]),
    );
  }

  Widget _card(BuildContext context, int i, _Q q) {
    final d = done[i];
    const green = Color(0xFF2F6B4F);
    final wide = q.options.any((o) => o.length > 14);
    Widget option(String o) {
      final isWrong = wrong[i].contains(o);
      final isRight = d != 0 && o == q.correct;
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: d != 0 || isWrong ? null : () => _pick(i, o),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(color: isRight ? green.withValues(alpha: 0.18) : C.soft(context).withValues(alpha: isWrong ? 0.45 : 1), borderRadius: BorderRadius.circular(16)),
          child: Text(
            o,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Amiri', fontSize: 19, height: 1.5, color: isWrong ? C.muted(context) : C.ink(context), decoration: isWrong ? TextDecoration.lineThrough : null),
          ),
        ),
      );
    }

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(q.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context)))),
          if (d == 1) const Text('من المحاولة الأولى', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: green)),
          if (d == 2) const Text('من المحاولة الثانية', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: green)),
          if (d == 3) Text('لم تُصب', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.muted(context))),
        ]),
        const SizedBox(height: 8),
        Text(q.text, style: TextStyle(fontFamily: 'Amiri', fontSize: 22, height: 1.7, color: C.ink(context))),
        const SizedBox(height: 12),
        if (wide)
          for (final o in q.options) Padding(padding: const EdgeInsets.only(bottom: 8), child: option(o))
        else
          for (var r = 0; r < q.options.length; r += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: option(q.options[r])),
                const SizedBox(width: 8),
                Expanded(child: r + 1 < q.options.length ? option(q.options[r + 1]) : const SizedBox()),
              ]),
            ),
        if (d == 0 && wrong[i].length == 1) Text('ليس هذا. بقيت لك محاولة.', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
        if (d != 0) ...[
          Divider(height: 24, color: C.muted(context).withValues(alpha: 0.3)),
          MathalBody(q.m, short: true),
        ],
      ]),
    );
  }
}

/// The proverb, then the book's words about it, then where it is in the book.
class MathalBody extends StatelessWidget {
  final Mathal m;
  final bool short; // inside the quiz: a long story is cut, and a link opens the whole of it
  const MathalBody(this.m, {super.key, this.short = false});

  @override
  Widget build(BuildContext context) {
    final cut = short && m.body.length > 520;
    final body = cut ? '${m.body.substring(0, 520)}…' : m.body;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(m.text, style: TextStyle(fontFamily: 'Amiri', fontSize: short ? 21 : 26, fontWeight: FontWeight.w700, height: 1.7, color: C.ink(context))),
      if (!short && m.usage.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.accent(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مَضرِب المثل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.accent(context))),
            const SizedBox(height: 4),
            Text(m.usage, style: TextStyle(fontSize: 16.5, height: 1.8, color: C.ink(context))),
          ]),
        ),
      ],
      const SizedBox(height: 10),
      if (!short && body.isNotEmpty) Text('الشرح والقصة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.accent(context))),
      if (body.isEmpty)
        Text('ذكره الميداني ولم يشرحه.', style: TextStyle(color: C.muted(context)))
      else
        SelectableText(body, style: TextStyle(fontSize: short ? 15 : 17, height: 1.9, color: C.ink(context))),
      const SizedBox(height: 8),
      if (short)
        InkWell(
          onTap: () => push(context, MathalScreen(m)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(cut ? 'أكمل القصة في «مجمع الأمثال» ←' : 'المثل في «مجمع الأمثال» ←', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.accent(context))),
          ),
        )
      else
        Text(m.source, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
    ]);
  }
}

/// One proverb on its own page.
class MathalScreen extends StatelessWidget {
  final Mathal m;
  const MathalScreen(this.m, {super.key});

  String get _shareText => '${m.text}\n\n${m.body}\n\n${m.source}\n— منتقيات الشعر';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('المثل ${Ar.num(m.n)}'), actions: [
          IconButton(
            tooltip: 'نسخ',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _shareText));
              toast(context, 'نُسخ المثل وشرحه');
            },
          ),
          IconButton(tooltip: 'مشاركة', icon: const Icon(Icons.ios_share_rounded), onPressed: () => Share.share(_shareText)),
        ]),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
          SoftCard(padding: const EdgeInsets.all(18), child: MathalBody(m)),
        ]),
      );
}

/// «مجمع الأمثال»: every proverb of the book, with search.
class MajmaScreen extends StatefulWidget {
  const MajmaScreen({super.key});
  @override
  State<MajmaScreen> createState() => _MajmaScreenState();
}

class _MajmaScreenState extends State<MajmaScreen> {
  List<Mathal>? all;
  // Search text prepared once: the proverb, and the proverb with its explanation.
  List<String> _titles = const [], _bodies = const [];
  String query = '';
  bool storiesOnly = false;

  @override
  void initState() {
    super.initState();
    Majma.all().then((l) {
      if (!mounted) return;
      _titles = [for (final m in l) Ar.norm(m.text)];
      _bodies = [for (final m in l) Ar.norm(m.body)];
      setState(() => all = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = all;
    final q = Ar.norm(query.trim());
    final shown = list == null
        ? const <Mathal>[]
        : [
            for (var i = 0; i < list.length; i++)
              if ((!storiesOnly || list[i].body.length > 200) && (q.isEmpty || _titles[i].contains(q) || (q.length > 2 && _bodies[i].contains(q)))) list[i]
          ];
    return Scaffold(
      appBar: AppBar(title: const Text('مجمع الأمثال')),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(hintText: 'ابحث في الأمثال وشروحها', prefixIcon: Icon(Icons.search_rounded)),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  FilterChip(label: const Text('ما له قصة أو شرح طويل'), selected: storiesOnly, onSelected: (v) => setState(() => storiesOnly = v)),
                  const Spacer(),
                  Text('${Ar.num(shown.length)} مثلاً', style: TextStyle(fontSize: 13, color: C.muted(context))),
                ]),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: shown.isEmpty
                    ? const EmptyNote(Icons.search_off_rounded, 'لا مثل بهذا اللفظ.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final m = shown[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SoftCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              onTap: () => push(context, MathalScreen(m)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Expanded(child: Text(m.text, style: TextStyle(fontFamily: 'Amiri', fontSize: 19, height: 1.6, fontWeight: FontWeight.w700, color: C.ink(context)))),
                                  Text(Ar.num(m.n), style: TextStyle(fontSize: 12, color: C.muted(context))),
                                ]),
                                if (m.usage.isNotEmpty) Text(m.usage, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 1.6, color: C.muted(context))),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}
