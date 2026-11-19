import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../main.dart';
import '../services/cloud.dart';
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

  static final _punct = RegExp(r'[؟?!.،,:؛«»"()\[\]…*]');
  static String clean(String s) => s.replaceAll(_punct, '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Five verses never asked before, each from a different selection (and poet when possible).
  /// When every verse in the app has been asked, a new round starts.
  static List<(Poem, int)> pick([int n = 5]) {
    final rnd = Random();
    List<(Poem, int)> free() {
      final seen = Store.i.seen.toSet();
      return [
        for (final p in pool)
          for (var i = 0; i < p.lines.length; i++)
            if (p.lines[i].length == 2 && !p.gone(i + 1) && clean(p.lines[i][1]).split(' ').length >= 2 && !seen.contains('${p.id}:$i')) (p, i)
      ];
    }

    var c = free();
    var reset = false;
    if (c.length < n) {
      Store.i.seen = [];
      reset = true;
      c = free();
    }
    c.shuffle(rnd);
    final out = <(Poem, int)>[];
    final poems = <int>{}, poets = <String>{};
    for (final pass in [0, 1]) {
      for (final x in c) {
        if (out.length == n) break;
        if (poems.contains(x.$1.id)) continue;
        if (pass == 0 && poets.contains(x.$1.poet)) continue;
        out.add(x);
        poems.add(x.$1.id);
        poets.add(x.$1.poet);
      }
    }
    Store.i.markSeen([for (final x in out) '${x.$1.id}:${x.$2}'], reset: reset);
    return out;
  }

  /// Today's five verses: chosen once, the same if the reader comes back the same day.
  static List<(Poem, int)> todayPicks() {
    final t = Store.i.majlis['today'];
    if (t is Map && t['day'] == Store.today) {
      final out = <(Poem, int)>[
        for (final x in t['picks'] as List)
          if (Library.byId[((x as List)[0] as num).toInt()] != null) (Library.byId[(x[0] as num).toInt()]!, (x[1] as num).toInt())
      ];
      if (out.length == 5) return out;
    }
    final out = pick();
    Store.i.majlis['today'] = {
      'day': Store.today,
      'picks': [for (final x in out) [x.$1.id, x.$2]]
    };
    Store.i.saveMajlis();
    return out;
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
              done == null ? 'تحدّي اليوم ينتظرك: خمس مراحل بخمسة أبيات.' : 'أتممت تحدّي اليوم: ${Ar.num(done[0])} من ${Ar.num(Majlis.maxPoints)}. يتجدد غداً.',
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
                onTap: done == null ? () => push(context, ChallengeScreen(picks: Majlis.todayPicks(), day: today)) : null,
                child: Row(children: [
                  Leaf(size: 56, letter: done == null ? '؟' : null, points: done?[0]),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('تحدّي اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
                      Text(
                        done == null ? 'خمس مراحل، ولكل مرحلة بيت جديد لشاعر آخر، وثلاث محاولات. لا يتكرر بيت حتى تنتهي أبيات التطبيق.' : 'أتممته اليوم، وورقته في ديوانك. يتجدد غداً.',
                        style: TextStyle(fontSize: 14.5, height: 1.5, color: C.muted(context)),
                      ),
                    ]),
                  ),
                  if (done == null) FilledButton(onPressed: () => push(context, ChallengeScreen(picks: Majlis.todayPicks(), day: today)), child: const Text('ابدأ')),
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
                    onTap: () => push(context, ChallengeScreen(picks: Majlis.pick())),
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
  final List<(Poem, int)> picks; // one verse per stage
  final int? day; // null = practice round
  const ChallengeScreen({super.key, required this.picks, this.day});
  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final Random rnd = Random();
  Poem poemAt(int i) => widget.picks[i % widget.picks.length].$1;
  List<String> verseAt(int i) {
    final x = widget.picks[i % widget.picks.length];
    return x.$1.lines[x.$2];
  }

  int stage = 0;
  int tries = 3;
  bool hinted = false;
  final points = <int>[]; // per stage
  String? wrong; // last wrong choice
  final removed = <String>{};

  // stage 0 — the glance
  late final List<String> words = Majlis.clean(verseAt(0).join(' ')).split(' ').where((w) => w.isNotEmpty).toList();
  late List<int> shuffled;
  final placed = <int>[];
  bool showing = true;
  int seconds = 6;
  Timer? timer;
  double left = 1;

  // options of the other stages
  late final String halfAnswer = Majlis.clean(verseAt(1)[1]);
  late final List<String> optHalf = _options(halfAnswer, [for (final q in _similar(1)) Majlis.clean(q.lines.first.last)], const []);
  late final List<String> rhymeWords = Majlis.clean(verseAt(2)[1]).split(' ');
  late final String lastWord = rhymeWords.last;
  late final List<String> optRhyme =
      _options(lastWord, [for (final q in _similar(2)) Majlis.clean(q.lines.first.last).split(' ').last], Majlis.clean(verseAt(2).join(' ')).split(' '));
  late final List<String> optChapter = _options(poemAt(3).chapterName, [for (final c in Library.chapters) c.name]..shuffle(rnd), const []);
  late final List<String> optPoet = _options(poemAt(4).poet, [for (final x in Library.namedPoets) x.name]..shuffle(rnd), const []);

  List<Poem> _similar(int i) {
    final p = poemAt(i);
    final same = Majlis.pool.where((q) => q.id != p.id && q.rhyme == p.rhyme && q.rhyme.isNotEmpty).toList();
    final rest = Majlis.pool.where((q) => q.id != p.id).toList()..shuffle(rnd);
    return [...(same..shuffle(rnd)), ...rest];
  }

  /// The answer plus three wrong choices: no duplicates, and never a word already shown in the verse.
  List<String> _options(String answer, List<String> others, List<String> shownWords) {
    final out = <String>[answer];
    final seen = {Ar.plain(answer), for (final w in shownWords) Ar.plain(w)};
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
      if (widget.day != null) {
        Majlis.record(widget.day!, sum, poemAt(0).id);
        Cloud.i.pushBoard();
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultScreen(picks: widget.picks, points: List.of(points), daily: widget.day != null)));
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
      1 => _choice(context, 'أكمل الشطر', 'اختر الشطر الثاني الصحيح.', [verseAt(1)[0], '……'], optHalf, halfAnswer, verse: true),
      2 => _choice(context, 'القافية', 'اختر الكلمة التي ينتهي بها البيت.',
          [verseAt(2)[0], '${rhymeWords.sublist(0, rhymeWords.length - 1).join(' ')} ……'], optRhyme, lastWord, verse: true),
      3 => _choice(context, 'في أي باب؟', 'في أي أبواب الكتاب يقع هذا البيت؟', verseAt(3), optChapter, poemAt(3).chapterName),
      _ => _choice(context, 'من القائل؟', 'من قائل هذا البيت؟', verseAt(4), optPoet, poemAt(4).poet),
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
        _verseBox(context, verseAt(0)),
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
              ? VerseLines(verseAt(0), size: 22)
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
  final List<(Poem, int)> picks;
  final List<int> points;
  final bool daily;
  const ResultScreen({super.key, required this.picks, required this.points, required this.daily});
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
            child: Leaf(size: 110, letter: Library.poetByName[picks.first.$1.poet]?.initial, points: sum),
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
        for (var i = 0; i < points.length && i < picks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              padding: const EdgeInsets.all(12),
              onTap: () => openPoem(context, picks[i].$1),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(points[i] > 0 ? Icons.check_circle_rounded : Icons.cancel_rounded, color: points[i] > 0 ? Majlis.green : Majlis.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(Majlis.stages[i], style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context)))),
                  Text(points[i] == 3 ? 'من أول محاولة' : (points[i] == 0 ? 'لم تُصب' : '${Ar.num(points[i])} من ٣'), style: TextStyle(color: C.muted(context))),
                ]),
                VerseLines(picks[i].$1.lines[picks[i].$2], size: 19),
                Text('${picks[i].$1.poet} · ${picks[i].$1.chapterName}', style: TextStyle(fontSize: 13, color: C.accent(context))),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('إلى المجلس')),
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
  late Future<List<Doc>> job = Cloud.i.board(0);
  void _load({bool refresh = false}) => setState(() => job = Cloud.i.board(range, refresh: refresh));
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
            onSelectionChanged: (v) {
              range = v.first;
              _load();
            },
          ),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<Doc>>(
          future: job,
          builder: (context, snap) {
            var list = snap.data ?? <Doc>[];
            if (list.isEmpty) {
              list = [
                {'uid': Cloud.i.uid, 'name': name, 'pts': mine, 'streak': Majlis.streak}
              ];
            }
            String nm(int i) => i < list.length ? '${list[i]['name'] ?? 'قارئ'}' : '—';
            int? pt(int i) => i < list.length ? ((list[i]['pts'] ?? 0) as num).toInt() : null;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (snap.connectionState != ConnectionState.done) const LinearProgressIndicator(),
              // The podium.
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _step(context, 2, nm(1), pt(1), 70),
                _step(context, 1, nm(0), pt(0), 104),
                _step(context, 3, nm(2), pt(2), 52),
              ]),
              const SizedBox(height: 16),
              for (var i = 0; i < list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      SizedBox(width: 30, child: Text(Ar.num(i + 1), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: i < 3 ? Majlis.gold : C.muted(context)))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(list[i]['uid'] == Cloud.i.uid && Cloud.i.signedIn ? '${nm(i)} (أنت)' : nm(i),
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
                          Text('${Majlis.rank(pt(i) ?? 0).$1} · ${Ar.num(((list[i]['streak'] ?? 0) as num).toInt())} يوماً متتالياً', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                        ]),
                      ),
                      Text(Ar.num(pt(i) ?? 0), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.accent(context))),
                    ]),
                  ),
                ),
            ]);
          },
        ),
        if (!Cloud.i.signedIn) ...[
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: () async {
              if (await needAccount(context, 'ليظهر اسمك ونقاطك بين القرّاء.') && mounted) {
                await Cloud.i.pushBoard();
                _load(refresh: true);
              }
            },
            icon: const Icon(Icons.login_rounded),
            label: const Text('ادخل بحسابك ليظهر اسمك في اللوحة'),
          ),
        ],
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
                      if (Cloud.i.signedIn) {
                        Cloud.i.setName(c.text).then((_) {
                          if (mounted) _load();
                        });
                      } else {
                        setState(() {});
                      }
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
              'يظهر هنا أعلى عشرين قارئاً ممن دخلوا بحساباتهم. يرسل كل جوال نتيجته بعد تحدي اليوم، ويقرأ اللوحة مرة واحدة في اليوم، فما تراه من ترتيب غيرك هو ترتيب أول فتحك لها اليوم.',
              style: TextStyle(height: 1.7, color: C.muted(context)),
            ),
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
