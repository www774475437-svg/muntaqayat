import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../ui.dart';

/// «أمثال العرب»: three questions every day, two attempts for each.
/// The proverbs come from «مجمع الأمثال» للميداني. Meanings and stories are
/// added only where they have been written and checked.
class ProverbQuizScreen extends StatefulWidget {
  const ProverbQuizScreen({super.key});
  @override
  State<ProverbQuizScreen> createState() => _ProverbQuizScreenState();
}

class _Proverb {
  final String full, meaning, story;
  final int n;
  _Proverb(this.n, this.full, this.meaning, this.story);
  String get lastWord => full.split(' ').last;
  String get lastBlank => '${full.substring(0, full.length - lastWord.length).trimRight()} …';
}

class _Q {
  final String title, text, correct;
  final List<String> options;
  const _Q(this.title, this.text, this.options, this.correct);
}

class _ProverbQuizScreenState extends State<ProverbQuizScreen> {
  List<_Proverb>? all;
  final List<_Proverb> today = [];
  final List<_Q> questions = [];
  int step = 0; // 0..2 questions, 3 = finished
  int tries = 2;
  String? wrongPick;
  bool revealed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final book = jsonDecode(await rootBundle.loadString('assets/data/proverbs_book.json')) as List;
    final notes = jsonDecode(await rootBundle.loadString('assets/data/proverb_notes.json')) as List;
    final byNumber = <int, Map<String, dynamic>>{for (final x in notes) (x as Map)['n'] as int: Map<String, dynamic>.from(x)};
    final list = <_Proverb>[];
    for (final x in book) {
      final m = Map<String, dynamic>.from(x as Map);
      final note = byNumber[m['n'] as int];
      list.add(_Proverb(m['n'] as int, m['full'] as String, (note?['meaning'] ?? '') as String, (note?['story'] ?? '') as String));
    }
    if (!mounted) return;
    setState(() {
      all = list;
      _pickToday(list);
    });
  }

  /// Three proverbs for the day, the same for everyone on that day.
  void _pickToday(List<_Proverb> list) {
    final day = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    final n = list.length;
    for (var k = 0; today.length < 3 && k < n; k++) {
      final p = list[(day * 7 + k * 613) % n];
      if (!today.contains(p)) today.add(p);
    }
    final rnd = math.Random(day);
    for (var i = 0; i < today.length; i++) {
      final p = today[i];
      if (p.meaning.isNotEmpty) {
        // Which proverb fits this meaning?
        final others = [for (final o in list) if (o != p) o.full]..shuffle(rnd);
        final opts = <String>{p.full, ...others.take(3)}.toList()..shuffle(rnd);
        questions.add(_Q('أيّ مثل يُضرب لهذا؟', p.meaning, opts, p.full));
      } else {
        // Which word ends this proverb?
        final others = <String>{for (final o in list) if (o != p && o.lastWord != p.lastWord) o.lastWord}.toList()..shuffle(rnd);
        final opts = <String>{p.lastWord, ...others.take(3)}.toList()..shuffle(rnd);
        questions.add(_Q('أكمِل المثل بآخر كلمة', p.lastBlank, opts, p.lastWord));
      }
    }
  }

  void _pick(String choice) {
    if (step >= 3 || revealed || wrongPick != null) return;
    final q = questions[step];
    if (choice == q.correct) {
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
              Text('ثلاثة أسئلة كل يوم من «مجمع الأمثال» للميداني، ولكل سؤال محاولتان. ثم تعرف المثل وقصته.', style: TextStyle(fontSize: 15, height: 1.7, color: C.muted(context))),
              const SizedBox(height: 16),
              if (step < 3) _questionCard(context, questions[step], step + 1),
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
        if (revealed && wrongPick != null)
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

  /// After the three questions: each proverb with its source, and its meaning and story where written.
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
              if (p.meaning.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('المعنى: ${p.meaning}', style: TextStyle(fontSize: 15, height: 1.7, color: C.ink(context))),
              ],
              if (p.story.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('القصة: ${p.story}', style: TextStyle(fontSize: 15, height: 1.7, color: C.ink(context))),
              ],
              const SizedBox(height: 8),
              Text('المصدر: مجمع الأمثال للميداني، رقم ${p.n}', style: TextStyle(fontSize: 13, color: C.muted(context))),
            ]),
          ),
        ),
    ]);
  }
}
