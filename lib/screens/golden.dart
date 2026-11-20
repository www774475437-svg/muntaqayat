import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../ui.dart';
import 'majlis.dart';

/// بيت الذهب: عشر مراحل متتالية، محاولة واحدة لكل مرحلة، مرة واحدة في اليوم.
/// Stage kinds: 0 أكمل الشطر · 1 القافية · 2 في أي باب؟ · 3 من القائل؟ ·
/// 4 البيت المختلط · 5 الكلمة الغريبة · 6 رتّب الشطر.
class GoldenScreen extends StatefulWidget {
  const GoldenScreen({super.key});
  @override
  State<GoldenScreen> createState() => _GoldenScreenState();
}

class _GoldenStage {
  final String question;
  final List<String> shown; // lines of the verse (or hints) shown above the choices
  final List<String> options;
  final int correct;
  const _GoldenStage(this.question, this.shown, this.options, this.correct);
}

class _GoldenScreenState extends State<GoldenScreen> {
  static const stageCount = 10;
  static const perStage = 10;

  final Random rnd = Random();
  late final List<_GoldenStage> stages;
  int stage = 0;
  int? picked;
  int score = 0;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    stages = _build();
  }

  /// Every verse of the pool, as (poem, verse-index, [first, second]).
  List<List<String>> get _allVerses => [
        for (final p in Majlis.pool)
          for (final v in p.lines)
            if (v.length == 2 && v[0].trim().isNotEmpty && v[1].trim().isNotEmpty) v,
      ];

  List<String> _others(List<List<String>> all, List<String> avoid, int n, String Function(List<String>) pick) {
    final out = <String>[];
    final seen = {for (final a in avoid) Ar.plain(a)};
    final shuffled = [...all]..shuffle(rnd);
    for (final v in shuffled) {
      final s = pick(v);
      if (s.trim().isEmpty || !seen.add(Ar.plain(s))) continue;
      out.add(s);
      if (out.length == n) break;
    }
    return out;
  }

  List<_GoldenStage> _build() {
    final all = _allVerses;
    final kinds = [for (var i = 0; i < stageCount; i++) i % 7]..shuffle(rnd);
    final verses = Majlis.pick(stageCount);
    final out = <_GoldenStage>[];
    for (var i = 0; i < stageCount; i++) {
      final (poem, idx) = verses[i % verses.length];
      final v = poem.lines[idx];
      final s = _stage(kinds[i], poem, v, all);
      out.add(s);
    }
    return out;
  }

  /// One stage, or a plain fallback if the verse is too short for that kind.
  _GoldenStage _stage(int kind, Poem poem, List<String> v, List<List<String>> all) {
    final pickSecond = (List<String> x) => Majlis.clean(x[1]);
    switch (kind) {
      case 1: // القافية
        final words = Majlis.clean(v[1]).split(' ').where((w) => w.isNotEmpty).toList();
        if (words.length >= 2) {
          final last = words.last;
          final rest = words.sublist(0, words.length - 1).join(' ');
          final wrong = _others(all, [last], 3, (x) => Majlis.clean(x[1]).split(' ').last);
          final opts = [last, ...wrong]..shuffle(rnd);
          return _GoldenStage('اختر الكلمة التي ينتهي بها البيت.', [v[0], '$rest ……'], opts, opts.indexOf(last));
        }
        break;
      case 2: // في أي باب؟
        final right = poem.chapterName;
        final wrong = [for (final c in Library.chapters) c.name]..remove(right)..shuffle(rnd);
        final opts = [right, ...wrong.take(3)]..shuffle(rnd);
        return _GoldenStage('في أي باب من الكتاب يقع هذا البيت؟', [v[0], v[1]], opts, opts.indexOf(right));
      case 3: // من القائل؟
        final right = poem.poet;
        final wrong = [for (final p in Library.namedPoets) p.name]..remove(right)..shuffle(rnd);
        final opts = [right, ...wrong.take(3)]..shuffle(rnd);
        return _GoldenStage('من قائل هذا البيت؟', [v[0], v[1]], opts, opts.indexOf(right));
      case 4: // البيت المختلط
        final other = _others(all, [v[1]], 1, (x) => x[0]);
        if (other.isNotEmpty) {
          final right = pickSecond(v);
          final wrong = _others(all, [v[1]], 3, pickSecond);
          final opts = [right, ...wrong]..shuffle(rnd);
          return _GoldenStage('أكمل الشطر الثاني الصحيح لهذا الشطر الأول.', [v[0]], opts, opts.indexOf(right));
        }
        break;
      case 5: // الكلمة الغريبة
        final mine = Majlis.clean(v.join(' ')).split(' ').where((w) => w.length > 2).toSet().toList()..shuffle(rnd);
        if (mine.length >= 3) {
          final inside = mine.take(3).toList();
          final odd = _others(all, [v.join(' ')], 1, (x) {
            final ws = Majlis.clean(x.join(' ')).split(' ').where((w) => w.length > 2).toList();
            for (final w in ws) {
              if (!mine.contains(w)) return w;
            }
            return '';
          });
          if (odd.isNotEmpty) {
            final opts = [...inside, odd.first]..shuffle(rnd);
            return _GoldenStage('أيّ كلمة لا تنتمي إلى هذا البيت؟', [], opts, opts.indexOf(odd.first));
          }
        }
        break;
      case 6: // رتّب الشطر: اختر الترتيب الصحيح لكلمات الشطر الثاني
        final ws = Majlis.clean(v[1]).split(' ').where((w) => w.isNotEmpty).toList();
        if (ws.length >= 3) {
          final right = ws.join(' ');
          final wrongs = <String>{};
          var guard = 0;
          while (wrongs.length < 3 && guard++ < 40) {
            final s = [...ws]..shuffle(rnd);
            final c = s.join(' ');
            if (c != right) wrongs.add(c);
          }
          if (wrongs.length == 3) {
            final opts = [right, ...wrongs]..shuffle(rnd);
            return _GoldenStage('اختر الشطر الثاني بترتيب كلماته الصحيح.', [v[0]], opts, opts.indexOf(right));
          }
        }
        break;
      default:
        break;
    }
    // Fallback: the second half, with three other halves.
    final right = pickSecond(v);
    final wrong = _others(all, [v[1]], 3, pickSecond);
    final opts = [right, ...wrong]..shuffle(rnd);
    return _GoldenStage('أكمل الشطر الثاني الصحيح لهذا الشطر الأول.', [v[0]], opts, opts.indexOf(right));
  }

  void _answer(int i) {
    if (picked != null) return;
    final ok = i == stages[stage].correct;
    setState(() {
      picked = i;
      if (ok) score += perStage;
    });
  }

  void _next() {
    if (stage == stageCount - 1) {
      final day = Store.today;
      Store.i.majlis['golden'] = {'day': day, 'score': score};
      Store.i.saveMajlis();
      setState(() => finished = true);
      return;
    }
    setState(() {
      stage++;
      picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بيت الذهب')),
      body: finished ? _result(context) : _stageView(context),
    );
  }

  Widget _stageView(BuildContext context) {
    final s = stages[stage];
    final done = picked != null;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 30), children: [
      Row(children: [
        Text('المرحلة ${Ar.num(stage + 1)} من ${Ar.num(stageCount)}', style: TextStyle(color: C.muted(context))),
        const Spacer(),
        Text('النقاط ${Ar.num(score)}', style: TextStyle(fontWeight: FontWeight.w700, color: Majlis.gold)),
      ]),
      const SizedBox(height: 10),
      LinearProgressIndicator(value: stage / stageCount, minHeight: 6, borderRadius: BorderRadius.circular(4), color: Majlis.gold),
      const SizedBox(height: 16),
      Text(s.question, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
      const SizedBox(height: 12),
      if (s.shown.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: Majlis.gold)),
          child: Column(children: [for (final l in s.shown) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(l, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, height: 1.7, color: C.ink(context))))]),
        ),
      const SizedBox(height: 14),
      for (var i = 0; i < s.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: done ? null : () => _answer(i),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: done && i == s.correct ? Majlis.green : (done && i == picked ? Majlis.red : Majlis.gold)),
              ),
              child: Text(s.options[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: C.ink(context))),
            ),
          ),
        ),
      if (done) ...[
        const SizedBox(height: 6),
        Text(picked == s.correct ? 'أصبت، +${Ar.num(perStage)} نقاط' : 'لم تُصب. الجواب الصحيح مُعلَّم باللون الأخضر.',
            style: TextStyle(fontWeight: FontWeight.w700, color: picked == s.correct ? Majlis.green : Majlis.red)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _next, child: Text(stage == stageCount - 1 ? 'انتهِ' : 'التالي')),
      ],
    ]);
  }

  Widget _result(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, size: 56, color: Majlis.gold),
            const SizedBox(height: 14),
            Text('نتيجة بيت الذهب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.ink(context))),
            const SizedBox(height: 8),
            Text('${Ar.num(score)} من ${Ar.num(stageCount * perStage)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Majlis.gold)),
            const SizedBox(height: 12),
            Text('تُعرض الترتيبات بعد انتهاء اليوم، وتُفعَّل مع الخادم بعد نشر القواعد.', textAlign: TextAlign.center, style: TextStyle(color: C.muted(context), height: 1.6)),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
          ]),
        ),
      );
}

/// Whether the golden challenge was already played today.
bool goldenDoneToday() {
  final g = Store.i.majlis['golden'];
  return g is Map && g['day'] == Store.today;
}
