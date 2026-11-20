import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../ui.dart';

/// «أمثال العرب»: a daily quiz. First the proverb is completed, then the
/// proverb is found from its meaning. Two attempts for each question.
class ProverbQuizScreen extends StatefulWidget {
  const ProverbQuizScreen({super.key});
  @override
  State<ProverbQuizScreen> createState() => _ProverbQuizScreenState();
}

class _Proverb {
  final String full, answer, meaning, topic;
  final List<String> opts;
  _Proverb(Map<String, dynamic> m)
      : full = m['full'] as String,
        answer = m['answer'] as String,
        meaning = m['meaning'] as String,
        topic = m['topic'] as String,
        opts = [for (final o in m['opts'] as List) o as String];
  String get blanked => full.replaceFirst(answer, '…');
}

class _ProverbQuizScreenState extends State<ProverbQuizScreen> {
  List<_Proverb>? all;
  int step = 0; // 0: complete the proverb, 1: find it from its meaning, 2: done
  int tries = 2;
  String? chosen;
  bool wrongNow = false;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/data/proverbs.json').then((raw) {
      if (!mounted) return;
      setState(() => all = [for (final x in jsonDecode(raw) as List) _Proverb(Map<String, dynamic>.from(x as Map))]);
    });
  }

  _Proverb _today(List<_Proverb> list) {
    final n = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    return list[n % list.length];
  }

  /// The four choices of the second step: the proverb itself and three others.
  List<String> _choicesFor(List<_Proverb> list, _Proverb p) {
    final i = list.indexOf(p);
    final others = [for (var k = 1; k < list.length && k <= 3; k++) list[(i + k * 3) % list.length].full];
    final out = [p.full, ...others.where((o) => o != p.full)];
    return out.take(4).toList()..shuffle(math.Random(i));
  }

  void _pick(String choice, _Proverb p, String correct) {
    if (step == 2 || chosen != null) return;
    final ok = choice == correct;
    setState(() {
      chosen = choice;
      wrongNow = !ok;
    });
    if (ok) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          step = step + 1;
          tries = 2;
          chosen = null;
          wrongNow = false;
        });
      });
    } else {
      tries--;
      if (tries == 0) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          setState(() {
            step = step + 1;
            tries = 2;
            chosen = null;
            wrongNow = false;
          });
        });
      } else {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() {
                chosen = null;
              });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = all;
    return Scaffold(
      appBar: AppBar(title: const Text('أمثال العرب')),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : _body(context, list),
    );
  }

  Widget _body(BuildContext context, List<_Proverb> list) {
    final p = _today(list);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
      Text('سؤالان كل يوم: أكمل المثل، ثم اعرف المثل من معناه.', style: TextStyle(fontSize: 15, height: 1.7, color: C.muted(context))),
      const SizedBox(height: 12),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: C.accent(context).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text('موضوع اليوم: ${p.topic}', style: TextStyle(fontSize: 13.5, color: C.accent(context), fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 16),
      _question(context, title: 'أكمِل المثل', text: p.blanked, options: p.opts, correct: p.answer, p: p, active: step == 0),
      const SizedBox(height: 14),
      _question(context, title: 'أيّ مثل يُضرب لهذا؟', text: p.meaning, options: _choicesFor(list, p), correct: p.full, p: p, active: step == 1),
      if (step == 2) ...[
        const SizedBox(height: 16),
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أحسنت، أنهيت سؤال اليوم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
            const SizedBox(height: 8),
            Text(p.full, style: TextStyle(fontSize: 20, color: C.ink(context))),
            const SizedBox(height: 6),
            Text('المعنى: ${p.meaning}', style: TextStyle(fontSize: 15, height: 1.6, color: C.ink(context))),
          ]),
        ),
      ],
    ]);
  }

  Widget _question(BuildContext context,
      {required String title, required String text, required List<String> options, required String correct, required _Proverb p, required bool active}) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.accent(context))),
        const SizedBox(height: 8),
        Text(text, style: TextStyle(fontSize: 21, height: 1.7, color: C.ink(context))),
        const SizedBox(height: 12),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _choice(context, o, correct, p, active),
          ),
        if (active && wrongNow && chosen != null)
          Text(tries > 0 ? 'ليس هذا. بقيت لك محاولة' : 'انتهت المحاولات، وهذا هو الجواب', style: TextStyle(fontSize: 14, color: C.accent(context), fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _choice(BuildContext context, String o, String correct, _Proverb p, bool active) {
    final shown = chosen == o;
    Color bg = C.soft(context);
    if (shown && !wrongNow) bg = const Color(0xFF2F6B4F).withValues(alpha: 0.2);
    if (shown && wrongNow) bg = const Color(0xFFB3261E).withValues(alpha: 0.18);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: active && step != 2 ? () => _pick(o, p, correct) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Text(o, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, color: C.ink(context))),
      ),
    );
  }
}
