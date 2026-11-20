import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../ui.dart';

/// «أمثال العرب»: three questions every day, two attempts for each.
/// Source of the proverbs: «مجمع الأمثال» للميداني.
class ProverbQuizScreen extends StatefulWidget {
  const ProverbQuizScreen({super.key});
  @override
  State<ProverbQuizScreen> createState() => _ProverbQuizScreenState();
}

class _Proverb {
  final String full, answer, meaning, topic, source, story;
  final List<String> opts;
  _Proverb(Map<String, dynamic> m)
      : full = m['full'] as String,
        answer = m['answer'] as String,
        meaning = m['meaning'] as String,
        topic = m['topic'] as String,
        source = (m['source'] ?? '') as String,
        story = (m['story'] ?? '') as String,
        opts = [for (final o in m['opts'] as List) o as String];

  /// Question 1: the first part is hidden and must be completed.
  String get firstBlank => full.replaceFirst(answer, '…');

  /// Question 3: the last word is hidden.
  String get lastWord => full.split(' ').last;
  String get lastBlank => '${full.substring(0, full.length - lastWord.length).trimRight()} …';
}

/// One question on the screen. Each has two attempts.
class _Q {
  final String title, text;
  final List<String> options;
  final String correct;
  const _Q(this.title, this.text, this.options, this.correct);
}

class _ProverbQuizScreenState extends State<ProverbQuizScreen> {
  List<_Proverb>? all;
  int step = 0; // 0..2 questions, 3 = finished
  int tries = 2;
  String? wrongPick; // the option picked wrongly on the current question
  bool revealed = false;
  late List<_Q> questions;
  final List<_Proverb> today = [];

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/data/proverbs.json').then((raw) {
      if (!mounted) return;
      final list = [for (final x in jsonDecode(raw) as List) _Proverb(Map<String, dynamic>.from(x as Map))];
      setState(() {
        all = list;
        _pickToday(list);
      });
    });
  }

  /// Three different proverbs for the day, the same for everyone on that day.
  void _pickToday(List<_Proverb> list) {
    final day = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    final n = list.length;
    for (var k = 0; today.length < 3 && k < n; k++) {
      final p = list[(day * 3 + k * 5) % n];
      if (!today.contains(p)) today.add(p);
    }
    questions = [
      for (final p in today) _question1(list, p),
      for (final p in today) _question2(list, p),
      for (final p in today) _question3(list, p),
    ];
  }

  // The three questions are asked in order: all completions, then meanings, then last words.
  _Q _question1(List<_Proverb> list, _Proverb p) => _Q('أكمِل المثل', p.firstBlank, p.opts, p.answer);

  _Q _question2(List<_Proverb> list, _Proverb p) {
    final others = [for (final o in list) if (o != p) o.full];
    final opts = <String>[p.full, ...others.take(3)]..shuffle();
    return _Q('أيّ مثل يُضرب لهذا؟', p.meaning, opts, p.full);
  }

  _Q _question3(List<_Proverb> list, _Proverb p) {
    final others = [for (final o in list) if (o != p && o.lastWord != p.lastWord) o.lastWord];
    final opts = <String>[p.lastWord, ...others.take(3)]..shuffle();
    return _Q('أكمِل آخر كلمة', p.lastBlank, opts, p.lastWord);
  }

  // The question currently on screen.
  _Q get _current => questions[step];

  void _pick(String choice) {
    if (step >= 3 || revealed || wrongPick != null) return;
    if (choice == _current.correct) {
      setState(() => revealed = true);
      Future.delayed(const Duration(milliseconds: 900), _next);
      return;
    }
    setState(() {
      tries--;
      wrongPick = choice;
    });
    if (tries == 0) {
      setState(() => revealed = true);
      Future.delayed(const Duration(milliseconds: 1400), _next);
    } else {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => wrongPick = null);
      });
    }
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      step++;
      tries = 2;
      wrongPick = null;
      revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = all;
    return Scaffold(
      appBar: AppBar(title: const Text('أمثال العرب')),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              Text('ثلاثة أسئلة كل يوم، ولكل سؤال محاولتان. ثم تعرف المثل وقصته.', style: TextStyle(fontSize: 15, height: 1.7, color: C.muted(context))),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: C.accent(context).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text('موضوع اليوم: ${today.isEmpty ? '' : today.first.topic}', style: TextStyle(fontSize: 13.5, color: C.accent(context), fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              if (step < 3) _questionCard(context, _current, step + 1),
              if (step >= 3) _result(context),
            ]),
    );
  }

  Widget _questionCard(BuildContext context, _Q q, int number) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('السؤال $number من 3: ${q.title}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.accent(context))),
        const SizedBox(height: 8),
        Text(q.text, style: TextStyle(fontSize: 21, height: 1.7, color: C.ink(context))),
        const SizedBox(height: 12),
        for (final o in q.options)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: _choice(context, q, o)),
        if (wrongPick != null && !revealed)
          Text('ليس هذا. بقيت لك محاولة', style: TextStyle(fontSize: 14, color: C.accent(context), fontWeight: FontWeight.w700)),
        if (revealed && tries == 0)
          Text('الجواب الصحيح: ${q.correct}', style: TextStyle(fontSize: 14, color: C.accent(context), fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _choice(BuildContext context, _Q q, String o) {
    Color bg = C.soft(context);
    final isWrong = o == wrongPick;
    final isRight = revealed && o == q.correct;
    if (isRight) bg = const Color(0xFF2F6B4F).withValues(alpha: 0.2);
    if (isWrong) bg = const Color(0xFFB3261E).withValues(alpha: 0.18);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: revealed || wrongPick != null ? null : () => _pick(o),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Text(
          o,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            color: isWrong ? C.muted(context) : C.ink(context),
            decoration: isWrong ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }

  /// After the three questions: each proverb with its meaning, source and story.
  Widget _result(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('أنهيت أسئلة اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.accent(context))),
      const SizedBox(height: 12),
      for (final p in today)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.full, style: TextStyle(fontSize: 20, height: 1.7, color: C.ink(context))),
              const SizedBox(height: 8),
              Text('المعنى: ${p.meaning}', style: TextStyle(fontSize: 15, height: 1.7, color: C.ink(context))),
              if (p.story.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('القصة: ${p.story}', style: TextStyle(fontSize: 15, height: 1.7, color: C.ink(context))),
              ],
              if (p.source.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('المصدر: ${p.source}', style: TextStyle(fontSize: 13, color: C.muted(context))),
              ],
            ]),
          ),
        ),
    ]);
  }
}
