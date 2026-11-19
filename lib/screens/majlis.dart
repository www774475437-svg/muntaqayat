import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'lists.dart';
import 'social.dart';

/// «مجلس الشعر»: the daily challenge. One selection a day, five stages,
/// three attempts each. Every finished day adds a leaf to the reader's «ديوان».
class Majlis {
  static const gold = Color(0xFFB08A3E), green = Color(0xFF2F6B4F), red = Color(0xFFB3261E);
  static const stages = ['اللمحة', 'أكمل الشطر', 'القافية', 'في أي باب؟', 'من القائل؟'];
  static const maxPoints = 15;

  /// Ranks by all-time points.
  static const ranks = [(0, 'مستمع'), (30, 'راوٍ'), (120, 'حافظ'), (300, 'أديب'), (600, 'علّامة'), (1200, 'شيخ المجلس')];

  static List<Poem> get pool => Library.poems.where((p) => p.poet != 'بلا نسبة' && p.lines.isNotEmpty && p.lines.first.length == 2).toList();

  static Poem poemOf(int day) {
    final c = pool;
    return c[(day * 7919) % c.length];
  }

  static Map<String, dynamic> get _days => (Store.i.majlis['days'] as Map<String, dynamic>?) ?? {};

  /// [points, poem id] of a played day.
  static List<int>? played(int day) {
    final v = _days['$day'];
    return v == null ? null : [for (final x in v as List) (x as num).toInt()];
  }

  static void record(int day, int points, int poemId) {
    final d = Map<String, dynamic>.from(_days);
    d['$day'] = [points, poemId];
    Store.i.majlis['days'] = d;
    Store.i.saveMajlis();
  }

  static int sum(int fromDay) {
    var s = 0;
    _days.forEach((k, v) {
      if (int.parse(k) >= fromDay) s += ((v as List)[0] as num).toInt();
    });
    return s;
  }

  static int get total => sum(0);

  /// The week starts on Saturday.
  static int get weekStart {
    final wd = DateTime.now().weekday; // Mon=1 … Sun=7
    return Store.today - ((wd + 1) % 7);
  }

  static int get monthStart => Store.today - (DateTime.now().day - 1);

  static int get streak {
    var n = 0;
    var d = Store.today;
    if (played(d) == null) d--;
    while (played(d) != null) {
      n++;
      d--;
    }
    return n;
  }

  static (String, int?) rank(int points) {
    var name = ranks.first.$2;
    int? next;
    for (final r in ranks) {
      if (points >= r.$1) {
        name = r.$2;
      } else {
        next = r.$1;
        break;
      }
    }
    return (name, next);
  }

  static String get name => (Store.i.majlis['name'] as String?) ?? '';
  static void setName(String v) {
    Store.i.majlis['name'] = v.trim();
    Store.i.saveMajlis();
  }
}

/// The card on the home page.
class MajlisCard extends StatelessWidget {
  const MajlisCard({super.key});
  @override
  Widget build(BuildContext context) {
    final done = Majlis.played(Store.today);
    final (rank, _) = Majlis.rank(Majlis.total);
    return SoftCard(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      onTap: () => push(context, const MajlisScreen()),
      child: Row(children: [
        const Leaf(size: 62),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مجلس الشعر', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink(context))),
            const SizedBox(height: 2),
            Text(
              done == null ? 'تحدّي اليوم ينتظرك: خمس مراحل على بيت واحد.' : 'أتممت تحدّي اليوم: ${Ar.num(done[0])} من ${Ar.num(Majlis.maxPoints)}. يتجدد غداً.',
              style: TextStyle(fontSize: 14.5, height: 1.5, color: C.muted(context)),
            ),
            const SizedBox(height: 2),
            Text('لقبك: $rank · ${Ar.num(Majlis.total)} نقطة', style: TextStyle(fontSize: 13.5, color: C.accent(context))),
          ]),
        ),
        Icon(Icons.chevron_left_rounded, color: C.muted(context)),
      ]),
    );
  }
}

/// A leaf of the diwan: the prize of a finished day.
class Leaf extends StatelessWidget {
  final double size;
  final String? letter;
  final int? points;
  const Leaf({super.key, this.size = 60, this.letter, this.points});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size * 1.25,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFFFBF3DF), Color(0xFFEAD9B0)]),
          borderRadius: BorderRadius.circular(size * 0.12),
          border: Border.all(color: Majlis.gold, width: 1.4),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(1, 3))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(letter ?? 'م', style: TextStyle(fontFamily: verseFont, fontSize: size * 0.46, height: 1, color: const Color(0xFF8C4A2F), fontWeight: FontWeight.w700)),
          if (points != null) Text('${Ar.num(points!)}/${Ar.num(Majlis.maxPoints)}', style: TextStyle(fontSize: size * 0.17, color: const Color(0xFF6E5A2E))),
        ]),
      );
}

class MajlisScreen extends StatelessWidget {
  const MajlisScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final today = Store.today;
          final done = Majlis.played(today);
          final total = Majlis.total;
          final (rank, next) = Majlis.rank(total);
          final prev = Majlis.ranks.lastWhere((r) => total >= r.$1).$1;
          final days = [for (var d = today; d > today - 60; d--) if (Majlis.played(d) != null) d];
          return Scaffold(
            appBar: AppBar(title: const Text('مجلس الشعر')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.workspace_premium_rounded, color: Majlis.gold, size: 30),
                    const SizedBox(width: 8),
                    Text(rank, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.ink(context))),
                    const Spacer(),
                    Text('${Ar.num(total)} نقطة', style: TextStyle(fontSize: 16, color: C.accent(context), fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: next == null ? 1 : (total - prev) / (next - prev),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(6),
                    color: Majlis.gold,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    next == null ? 'بلغت أعلى الألقاب.' : 'بقي ${Ar.num(next - total)} نقطة للقب «${Majlis.rank(next).$1}»',
                    style: TextStyle(color: C.muted(context)),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.local_fire_department_rounded, size: 20, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text('${Ar.num(Majlis.streak)} يوماً متتالياً', style: TextStyle(color: C.ink(context))),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              SoftCard(
                onTap: done == null ? () => push(context, ChallengeScreen(poem: Majlis.poemOf(today), day: today)) : null,
                child: Row(children: [
                  Leaf(size: 56, letter: done == null ? '؟' : null, points: done?[0]),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('تحدّي اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
                      Text(
                        done == null ? 'خمس مراحل: اللمحة، أكمل الشطر، القافية، الباب، القائل. لكل مرحلة ثلاث محاولات.' : 'أتممته اليوم، وورقته في ديوانك. يتجدد غداً.',
                        style: TextStyle(fontSize: 14.5, height: 1.5, color: C.muted(context)),
                      ),
                    ]),
                  ),
                  if (done == null) FilledButton(onPressed: () => push(context, ChallengeScreen(poem: Majlis.poemOf(today), day: today)), child: const Text('ابدأ')),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    onTap: () => push(context, const LeaderboardScreen()),
                    child: Column(children: [
                      Icon(Icons.emoji_events_outlined, color: Majlis.gold, size: 30),
                      const SizedBox(height: 4),
                      Text('لوحة الصدارة', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
                      Text('أسبوعك: ${Ar.num(Majlis.sum(Majlis.weekStart))}', style: TextStyle(fontSize: 13, color: C.muted(context))),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    onTap: () {
                      final c = Majlis.pool;
                      push(context, ChallengeScreen(poem: c[Random().nextInt(c.length)]));
                    },
                    child: Column(children: [
                      Icon(Icons.fitness_center_rounded, color: C.accent(context), size: 30),
                      const SizedBox(height: 4),
                      Text('جولة تدريب', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
                      Text('بلا نقاط، متى شئت', style: TextStyle(fontSize: 13, color: C.muted(context))),
                    ]),
                  ),
                ),
              ]),
              const SectionTitle('ديوانك'),
              if (days.isEmpty)
                Text('كل يوم تتمّ فيه التحدي تُضاف ورقة إلى ديوانك، فيها بيت ذلك اليوم.', style: TextStyle(color: C.muted(context), height: 1.6))
              else
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final d in days)
                    InkWell(
                      onTap: () {
                        final p = Library.byId[Majlis.played(d)![1]];
                        if (p != null) openPoem(context, p);
                      },
                      child: Leaf(
                        size: 58,
                        letter: Library.poetByName[Library.byId[Majlis.played(d)![1]]?.poet]?.initial,
                        points: Majlis.played(d)![0],
                      ),
                    ),
                ]),
            ]),
          );
        },
      );
}

// ------------------------------------------------------------ the challenge

class ChallengeScreen extends StatefulWidget {
  final Poem poem;
  final int? day; // null = practice round
  const ChallengeScreen({super.key, required this.poem, this.day});
  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late final Random rnd = Random(widget.day ?? DateTime.now().microsecondsSinceEpoch);
  Poem get p => widget.poem;
  int stage = 0;
  int tries = 3;
  bool hinted = false;
  final points = <int>[]; // per stage
  String? wrong; // last wrong choice
  final removed = <String>{};

  // stage 0 — the glance
  late final List<String> words = p.lines.first.join(' ').split(' ').where((w) => w.isNotEmpty).toList();
  late List<int> shuffled;
  final placed = <int>[];
  bool showing = true;
  int seconds = 6;
  Timer? timer;
  double left = 1;

  // options of the other stages
  late final List<String> lineB = p.lines.length > 1 ? p.lines[1] : p.lines.first;
  late final List<String> optHalf = _options(lineB[1], [for (final q in _similar()) q.lines.first[1]]);
  late final String lastWord = p.lines.first[1].trim().split(' ').last;
  late final List<String> optRhyme = _options(lastWord, [for (final q in _similar()) q.lines.first[1].trim().split(' ').last]);
  late final List<String> optChapter = _options(p.chapterName, [for (final c in Library.chapters) c.name]);
  late final List<String> optPoet = _options(p.poet, [for (final x in Library.namedPoets) x.name]);

  List<Poem> _similar() {
    final same = Majlis.pool.where((q) => q.id != p.id && q.rhyme == p.rhyme && q.rhyme.isNotEmpty).toList();
    final rest = Majlis.pool.where((q) => q.id != p.id).toList()..shuffle(rnd);
    return [...(same..shuffle(rnd)), ...rest];
  }

  List<String> _options(String answer, List<String> others) {
    final out = <String>[answer];
    final seen = {Ar.plain(answer)};
    for (final o in others) {
      if (out.length == 4) break;
      if (o.trim().isEmpty || !seen.add(Ar.plain(o))) continue;
      out.add(o);
    }
    return out..shuffle(rnd);
  }

  @override
  void initState() {
    super.initState();
    shuffled = [for (var i = 0; i < words.length; i++) i]..shuffle(rnd);
    _startGlance();
  }

  void _startGlance() {
    timer?.cancel();
    final totalMs = seconds * 1000;
    var ms = 0;
    setState(() {
      showing = true;
      left = 1;
    });
    timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      ms += 50;
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => left = 1 - ms / totalMs);
      if (ms >= totalMs) {
        t.cancel();
        setState(() => showing = false);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _win() {
    HapticFeedback.mediumImpact();
    final got = hinted && tries == 3 ? 2 : tries;
    points.add(got);
    _next();
  }

  void _lose(String choice) {
    HapticFeedback.heavyImpact();
    setState(() {
      tries--;
      wrong = choice;
      if (tries == 0) {
        points.add(0);
      }
    });
    if (tries == 0) Future.delayed(const Duration(milliseconds: 1400), () => mounted ? _next() : null);
  }

  void _next() {
    if (stage == Majlis.stages.length - 1) {
      final sum = points.fold(0, (a, b) => a + b);
      if (widget.day != null) Majlis.record(widget.day!, sum, p.id);
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultScreen(poem: p, points: List.of(points), daily: widget.day != null)));
      return;
    }
    setState(() {
      stage++;
      tries = 3;
      hinted = false;
      wrong = null;
      removed.clear();
    });
  }

  void _hint(List<String> options, String answer) {
    final cand = options.where((o) => o != answer && !removed.contains(o)).toList();
    if (cand.isEmpty) return;
    setState(() {
      hinted = true;
      removed.add(cand.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (stage) {
      0 => _glance(context),
      1 => _choice(context, 'أكمل الشطر', 'اختر الشطر الثاني الصحيح.', [lineB[0], '……'], optHalf, lineB[1], verse: true),
      2 => _choice(context, 'القافية', 'اختر الكلمة التي ينتهي بها البيت.',
          [p.lines.first[0], '${(p.lines.first[1].trim().split(' ')..removeLast()).join(' ')} ……'], optRhyme, lastWord, verse: true),
      3 => _choice(context, 'في أي باب؟', 'في أي أبواب الكتاب يقع هذا البيت؟', p.lines.first, optChapter, p.chapterName),
      _ => _choice(context, 'من القائل؟', 'من قائل هذا البيت؟', p.lines.first, optPoet, p.poet),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.day == null ? 'جولة تدريب' : 'تحدّي اليوم'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(child: Text('${Ar.num(stage + 1)} من ${Ar.num(Majlis.stages.length)}', style: TextStyle(color: C.muted(context)))),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            for (var i = 0; i < Majlis.stages.length; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i < points.length ? (points[i] > 0 ? Majlis.green : Majlis.red) : (i == stage ? Majlis.gold : C.line(context)),
                  ),
                ),
              ),
          ]),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a), child: c)),
            child: KeyedSubtree(key: ValueKey(stage), child: body),
          ),
        ),
      ]),
    );
  }

  Widget _head(BuildContext context, String title, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: C.ink(context))),
        Text(sub, style: TextStyle(fontSize: 15, height: 1.6, color: C.muted(context))),
        const SizedBox(height: 14),
      ]);

  Widget _tries(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(i < tries ? Icons.circle : Icons.close_rounded, size: i < tries ? 10 : 14, color: i < tries ? Majlis.gold : Majlis.red),
          ),
        const SizedBox(width: 6),
        Text(tries == 3 ? '٣ محاولات' : (tries == 0 ? 'انتهت المحاولات' : 'بقيت ${Ar.num(tries)}'), style: TextStyle(fontSize: 13, color: C.muted(context))),
      ]);

  Widget _verseBox(BuildContext context, List<String> line) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line(context))),
        child: VerseLines(line, size: 22),
      );

  Widget _glance(BuildContext context) {
    final failed = tries == 0;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 30), children: [
      _head(context, 'اللمحة', 'يظهر البيت ثوانيَ ثم يختفي. احفظه بنظرة، ثم أعد كلماته إلى مواضعها.'),
      if (showing) ...[
        _verseBox(context, p.lines.first),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: left.clamp(0, 1), minHeight: 6, borderRadius: BorderRadius.circular(4), color: Majlis.gold),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: [
          ActionChip(label: const Text('أخفِه الآن'), onPressed: () {
            timer?.cancel();
            setState(() => showing = false);
          }),
          ActionChip(label: const Text('مهلة أطول'), onPressed: () {
            seconds = 12;
            _startGlance();
          }),
        ]),
      ] else ...[
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: wrong != null && !failed ? Majlis.red : C.line(context))),
          child: failed
              ? VerseLines(p.lines.first, size: 22)
              : Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final i in placed) _chip(context, words[i], () => setState(() => placed.remove(i)), filled: true),
                  if (placed.isEmpty) Text('اضغط الكلمات بترتيبها', style: TextStyle(color: C.muted(context))),
                ]),
        ),
        const SizedBox(height: 16),
        if (!failed)
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (final i in shuffled)
              if (!placed.contains(i)) _chip(context, words[i], () => setState(() => placed.add(i))),
          ]),
        const SizedBox(height: 16),
        if (wrong != null && !failed) Text('ليس هذا الترتيب.', style: const TextStyle(color: Majlis.red)),
        Row(children: [
          _tries(context),
          const Spacer(),
          IconButton(
            tooltip: 'تلميح: انظر البيت مرة أخرى',
            onPressed: failed
                ? null
                : () {
                    hinted = true;
                    seconds = 3;
                    _startGlance();
                  },
            icon: const Icon(Icons.lightbulb_outline_rounded),
          ),
        ]),
        const SizedBox(height: 8),
        if (!failed)
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            onPressed: placed.length != words.length
                ? null
                : () {
                    final ok = [for (final i in placed) words[i]].join(' ') == words.join(' ');
                    if (ok) {
                      _win();
                    } else {
                      _lose('x');
                      if (tries > 0) setState(placed.clear);
                    }
                  },
            child: const Text('تحقّق', style: TextStyle(fontSize: 17)),
          ),
      ],
    ]);
  }

  Widget _chip(BuildContext context, String w, VoidCallback onTap, {bool filled = false}) => InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: filled ? C.soft(context) : C.bar(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: filled ? Majlis.gold : C.line(context)),
          ),
          child: Text(w, style: TextStyle(fontFamily: verseFont, fontSize: 21, color: C.ink(context))),
        ),
      );

  Widget _choice(BuildContext context, String title, String sub, List<String> line, List<String> options, String answer, {bool verse = false}) {
    final failed = tries == 0;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 30), children: [
      _head(context, title, sub),
      _verseBox(context, line),
      const SizedBox(height: 16),
      for (final o in options)
        if (!removed.contains(o))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: failed
                  ? null
                  : () {
                      if (o == answer) {
                        _win();
                      } else {
                        _lose(o);
                        if (tries > 0) setState(() => removed.add(o));
                      }
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: failed && o == answer ? Majlis.green.withValues(alpha: 0.15) : C.bar(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: failed && o == answer ? Majlis.green : (wrong == o ? Majlis.red : C.line(context)), width: 1.4),
                ),
                child: Text(o,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: verse ? verseFont : uiFont, fontSize: verse ? 21 : 16.5, fontWeight: verse ? FontWeight.normal : FontWeight.w700, color: C.ink(context))),
              ),
            ),
          ),
      Row(children: [
        _tries(context),
        const Spacer(),
        IconButton(
          tooltip: 'تلميح: احذف جواباً خاطئاً',
          onPressed: failed || hinted ? null : () => _hint(options, answer),
          icon: const Icon(Icons.lightbulb_outline_rounded),
        ),
      ]),
    ]);
  }
}

class ResultScreen extends StatelessWidget {
  final Poem poem;
  final List<int> points;
  final bool daily;
  const ResultScreen({super.key, required this.poem, required this.points, required this.daily});
  @override
  Widget build(BuildContext context) {
    final sum = points.fold(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(title: Text(daily ? 'ورقة اليوم' : 'نتيجة التدريب')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 40), children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, t, child) => Transform.scale(scale: t, child: child),
            child: Leaf(size: 110, letter: Library.poetByName[poem.poet]?.initial, points: sum),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            sum == Majlis.maxPoints ? 'أحسنت! الدرجة كاملة' : (sum >= 10 ? 'أحسنت' : (sum >= 5 ? 'لا بأس، وغداً أفضل' : 'حاول غداً')),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.ink(context)),
          ),
        ),
        Center(child: Text(daily ? 'أُضيفت الورقة إلى ديوانك، ونقاطها إلى رصيدك.' : 'جولة تدريب: لا تُحسب في النقاط.', style: TextStyle(color: C.muted(context)))),
        const SizedBox(height: 14),
        for (var i = 0; i < points.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(points[i] > 0 ? Icons.check_circle_rounded : Icons.cancel_rounded, color: points[i] > 0 ? Majlis.green : Majlis.red, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(Majlis.stages[i], style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context)))),
              Text(points[i] == 3 ? 'من أول محاولة' : (points[i] == 0 ? 'لم تُصب' : '${Ar.num(points[i])} من ٣'), style: TextStyle(color: C.muted(context))),
            ]),
          ),
        const Divider(height: 28),
        Text(poem.poet, style: TextStyle(fontSize: 17, color: C.accent(context), fontWeight: FontWeight.w700)),
        Text(poem.chapterName, style: TextStyle(color: C.muted(context))),
        const SizedBox(height: 8),
        for (final l in poem.lines) VerseLines(l, size: 21),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () => openPoem(context, poem), icon: const Icon(Icons.menu_book_rounded), label: const Text('اقرأ المقطع')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => openPoet(context, poem.poet), icon: const Icon(Icons.person_outline_rounded), label: const Text('تعرّف على الشاعر')),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلى المجلس')),
      ]),
    );
  }
}

// ------------------------------------------------------------ leaderboard

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int range = 0;
  @override
  Widget build(BuildContext context) {
    final mine = [Majlis.sum(Majlis.weekStart), Majlis.sum(Majlis.monthStart), Majlis.total][range];
    final name = Majlis.name.isEmpty ? 'أنت' : Majlis.name;
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة الصدارة')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        Center(
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('هذا الأسبوع')),
              ButtonSegment(value: 1, label: Text('هذا الشهر')),
              ButtonSegment(value: 2, label: Text('منذ البداية')),
            ],
            selected: {range},
            onSelectionChanged: (v) => setState(() => range = v.first),
          ),
        ),
        const SizedBox(height: 18),
        // The podium.
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _step(context, 2, '—', null, 70),
          _step(context, 1, name, mine, 104),
          _step(context, 3, '—', null, 52),
        ]),
        const SizedBox(height: 16),
        SoftCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Text('١', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Majlis.gold)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
                Text('${Majlis.rank(Majlis.total).$1} · ${Ar.num(Majlis.streak)} يوماً متتالياً', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
              ]),
            ),
            Text(Ar.num(mine), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.accent(context))),
          ]),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            final c = TextEditingController(text: Majlis.name);
            showDialog(
              context: context,
              builder: (d) => AlertDialog(
                title: const Text('اسمك في اللوحة'),
                content: TextField(controller: c, maxLength: 20, decoration: const InputDecoration(hintText: 'اسم لائق يظهر للناس')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
                  FilledButton(
                    onPressed: () {
                      Majlis.setName(c.text);
                      Navigator.pop(d);
                      setState(() {});
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('اختر اسمك في اللوحة'),
        ),
        const SizedBox(height: 14),
        SoftCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('كيف تُحسب؟', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
            const SizedBox(height: 4),
            Text(
              'لكل مرحلة ٣ نقاط إن أصبت من أول محاولة، ثم نقطتان، ثم نقطة. أقصى اليوم ١٥ نقطة، وأقصى الأسبوع ١٠٥. يبدأ الأسبوع يوم السبت.\n\n'
              'ترتيب القرّاء كلهم يظهر هنا بعد ربط الحسابات: يرسل كل جوال نتيجته مرة واحدة في اليوم، ويقرأ اللوحة مرة واحدة في اليوم. وحتى ذلك الحين تُحفظ نقاطك في جوالك ولا تضيع.',
              style: TextStyle(height: 1.7, color: C.muted(context)),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => needsServer(context, 'لوحة الصدارة بين القرّاء.'), child: const Text('متى تُفتح اللوحة للجميع؟')),
          ]),
        ),
      ]),
    );
  }

  Widget _step(BuildContext context, int place, String name, int? pts, double h) => Expanded(
        child: Column(children: [
          if (place == 1) Icon(Icons.workspace_premium_rounded, color: Majlis.gold, size: 34),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
          if (pts != null) Text(Ar.num(pts), style: TextStyle(color: C.accent(context), fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                place == 1 ? Majlis.gold : C.soft(context),
                place == 1 ? Majlis.gold.withValues(alpha: 0.55) : C.card(context),
              ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(Ar.num(place), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: place == 1 ? Colors.white : C.muted(context))),
          ),
        ]),
      );
}
