import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'poem.dart';

/// Two games: «أكمل البيت» (kind 0) and «من القائل؟» (kind 1).
class GameScreen extends StatefulWidget {
  final int kind;
  const GameScreen({super.key, required this.kind});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _rnd = Random();
  late Poem poem;
  late List<String> verse;
  late List<String> options;
  late String answer;
  String? chosen;
  int score = 0, played = 0;

  bool get complete => widget.kind == 0;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    final pool = Library.poems
        .where((p) => p.flags.isEmpty && p.lines.any((l) => l.length == 2) && (complete || !p.unattributed))
        .toList();
    poem = pool[_rnd.nextInt(pool.length)];
    final full = poem.lines.where((l) => l.length == 2).toList();
    verse = full[_rnd.nextInt(full.length)];
    if (complete) {
      answer = verse[1];
      // Wrong choices: second hemistichs of other verses, same rhyme first.
      final others = [
        for (final p in Library.poems)
          if (p.id != poem.id)
            for (final l in p.lines)
              if (l.length == 2) (p.rhyme == poem.rhyme ? 0 : 1, l[1])
      ]..shuffle(_rnd);
      others.sort((a, b) => a.$1.compareTo(b.$1));
      final wrong = others.take(12).map((e) => e.$2).toSet().take(3).toList();
      options = [answer, ...wrong]..shuffle(_rnd);
    } else {
      answer = poem.poet;
      final names = Library.namedPoets.map((p) => p.name).where((n) => n != answer).toList()..shuffle(_rnd);
      options = [answer, ...names.take(3)]..shuffle(_rnd);
    }
    chosen = null;
  }

  void _pick(String o) {
    if (chosen != null) return;
    setState(() {
      chosen = o;
      played++;
      if (o == answer) score++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = complete ? 'أكمل البيت' : 'من القائل؟';
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(child: Text('${Ar.num(score)} / ${Ar.num(played)}', style: TextStyle(fontSize: 17, color: C.accent(context)))),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        Text(complete ? 'اختر الشطر الثاني الصحيح:' : 'من قائل هذا البيت؟', style: TextStyle(fontSize: 16, color: C.muted(context))),
        const SizedBox(height: 12),
        SoftCard(
          child: complete
              ? Text(Store.i.show(verse[0]), style: TextStyle(fontFamily: verseFont, fontSize: 25 * Store.i.fontScale, height: 1.9))
              : VerseLines(verse, size: 24),
        ),
        const SizedBox(height: 16),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _option(context, o),
          ),
        if (chosen != null) ...[
          const SizedBox(height: 6),
          Text(chosen == answer ? 'أحسنت! ✓' : 'الجواب الصحيح مُعلَّم بالأخضر.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: chosen == answer ? const Color(0xFF2F6B4F) : const Color(0xFFB3261E))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => openPoem(context, poem),
                child: const Text('اقرأ المقطع'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => setState(_next),
                child: const Text('التالي'),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 16),
        if (!complete)
          TextButton.icon(
            onPressed: () => Share.share('من قائل هذا البيت؟\n\n${verse.join('\n')}\n\nجرّب «منتقيات الشعر»: $siteUrl'),
            icon: const Icon(Icons.share_rounded),
            label: const Text('تحدَّ صديقك بهذا البيت'),
          ),
      ]),
    );
  }

  Widget _option(BuildContext context, String o) {
    final done = chosen != null;
    final right = o == answer;
    Color? bg;
    if (done && right) bg = const Color(0x332F6B4F);
    if (done && o == chosen && !right) bg = const Color(0x33B3261E);
    return Material(
      color: bg ?? C.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: C.line(context))),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _pick(o),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(complete ? Store.i.show(o) : o,
              style: complete
                  ? TextStyle(fontFamily: verseFont, fontSize: 20, height: 1.7, color: C.ink(context))
                  : TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
        ),
      ),
    );
  }
}
