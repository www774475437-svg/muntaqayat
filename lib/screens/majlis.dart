import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../main.dart';
import '../services/cloud.dart';
import 'golden.dart';
import '../ui.dart';
import 'lists.dart';
import 'majlis_plus.dart';
import 'social.dart';

/// «مجلس الشعر»: the daily challenge. One selection a day, five stages,
/// three attempts each. Every finished day adds a leaf to the reader's «ديوان».
class Majlis {
  static const gold = Color(0xFFB08A3E), green = Color(0xFF2F6B4F), red = Color(0xFFB3261E);
  static const stages = ['اللمحة', 'أكمل الشطر', 'القافية', 'في أي باب؟', 'من القائل؟'];
  static const maxPoints = 100; // one round
  static const roundsPerDay = 10;

  /// Points needed to reach a level (1…100): 100, 300, 600, 1000 … 505,000.
  static int need(int level) => 50 * level * (level + 1);
  static int levelOf(int xp) {
    var n = 0;
    while (n < 100 && need(n + 1) <= xp) {
      n++;
    }
    return n;
  }

  /// A rank for every ten levels.
  static const rankNames = ['مبتدئ', 'برونزي', 'فضي', 'ذهبي', 'بلاتيني', 'ماسي', 'راوٍ', 'حافظ', 'أديب', 'علّامة', 'شيخ المجلس', 'أمير المجلس'];
  static const rankColors = [
    Color(0xFF8A8A8A), Color(0xFFA9714B), Color(0xFF8E9AA6), gold, Color(0xFF4F9DA6), Color(0xFF5B7FD1),
    green, Color(0xFF7A4FA3), Color(0xFFB3541E), red, Color(0xFF6B4A2F), Color(0xFFD4A017), //
  ];
  static int rankIndex(int level) => level == 0 ? 0 : min(level ~/ 10 + 1, 11);

  static Map<String, dynamic> get st => (Store.i.majlis['st'] as Map<String, dynamic>?) ?? {};
  static int get roundsToday => (((Store.i.majlis['rounds'] as Map?)?['${Store.today}']) as num?)?.toInt() ?? 0;
  static bool get friday => DateTime.now().weekday == DateTime.friday && Store.i.feature('friday');

  /// (id, title, reward) of the three daily tasks.
  static const tasks = [('r3', 'العب ثلاث جولات', 30), ('p1', 'أتمّ جولة بلا خطأ', 40), ('r10', 'أتمّ الجولات العشر', 100)];
  static Map<String, dynamic> get _tasksToday {
    final t = Store.i.majlis['tasks'];
    return t is Map && t['day'] == Store.today ? Map<String, dynamic>.from(t) : {'day': Store.today, 'done': <String>[], 'perfect': 0};
  }

  static bool taskDone(String id) => (_tasksToday['done'] as List).contains(id);

  /// The poet of the week: the same for everyone, a new one every Saturday.
  static List<String>? _weeklyNames;
  static String get weeklyPoet {
    if (_weeklyNames == null) {
      final count = <String, int>{};
      for (final p in pool) {
        count[p.poet] = (count[p.poet] ?? 0) + p.lines.where((l) => l.length == 2).length;
      }
      _weeklyNames = (count.entries.where((e) => e.value >= 8).map((e) => e.key).toList()..sort());
    }
    return _weeklyNames!.isEmpty ? '' : _weeklyNames![(weekStart ~/ 7) % _weeklyNames!.length];
  }

  static bool get weeklyDone => Store.i.majlis['weekly'] == weekStart;

  /// The verses the reader missed, newest first.
  static List<(Poem, int)> get mistakes => [
        for (final k in ((Store.i.majlis['miss'] as List?) ?? []).reversed)
          if (Library.byId[int.tryParse('$k'.split(':').first)] != null && int.parse('$k'.split(':').last) < Library.byId[int.parse('$k'.split(':').first)]!.lines.length)
            (Library.byId[int.parse('$k'.split(':').first)]!, int.parse('$k'.split(':').last))
      ];
  static void markMiss((Poem, int) x, bool wrong) {
    final l = [...((Store.i.majlis['miss'] as List?) ?? [])];
    final k = '${x.$1.id}:${x.$2}';
    l.remove(k);
    if (wrong) l.add(k);
    Store.i.majlis['miss'] = l.length > 300 ? l.sublist(l.length - 300) : l;
  }

  static List<Poem> get pool => Library.poems.where((p) => p.poet != 'بلا نسبة' && p.lines.isNotEmpty && p.lines.first.length == 2).toList();

  static final _punct = RegExp(r'[؟?!.،,:؛«»"()\[\]…*]');
  static String clean(String s) => s.replaceAll(_punct, '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Five verses never asked before, each from a different selection (and poet when possible).
  /// When every verse in the app has been asked, a new round starts.
  static List<(Poem, int)> pick([int n = 5, String? poet]) {
    final rnd = Random();
    List<(Poem, int)> free() {
      final seen = Store.i.seen.toSet();
      return [
        for (final p in pool)
          for (var i = 0; i < p.lines.length; i++)
            if ((poet == null || p.poet == poet) && p.lines[i].length == 2 && !p.gone(i + 1) && clean(p.lines[i][1]).split(' ').length >= 2 && (poet != null || !seen.contains('${p.id}:$i'))) (p, i)
      ];
    }

    var c = free();
    var reset = false;
    if (c.length < n && poet == null) {
      Store.i.seen = [];
      reset = true;
      c = free();
    }
    c.shuffle(rnd);
    final out = <(Poem, int)>[];
    final poems = <int>{}, poets = <String>{};
    for (final pass in [0, 1, 2]) {
      for (final x in c) {
        if (out.length == n) break;
        if (out.contains(x)) continue;
        if (pass < 2 && poems.contains(x.$1.id)) continue;
        if (pass == 0 && poet == null && poets.contains(x.$1.poet)) continue;
        out.add(x);
        poems.add(x.$1.id);
        poets.add(x.$1.poet);
      }
    }
    if (poet == null) Store.i.markSeen([for (final x in out) '${x.$1.id}:${x.$2}'], reset: reset);
    return out;
  }

  /// Five verses from the book file by a seed: the same for every reader.
  static List<(Poem, int)> seededPicks(int seed) {
    final rnd = Random(seed);
    final c = <(Poem, int)>[
      for (final p in Library.all)
        if (p.poet != 'بلا نسبة' && !p.allGone)
          for (var i = 0; i < p.lines.length; i++)
            if (p.lines[i].length == 2 && !p.gone(i + 1) && clean(p.lines[i][1]).split(' ').length >= 2) (p, i)
    ]..shuffle(rnd);
    final out = <(Poem, int)>[];
    final used = <int>{};
    for (final x in c) {
      if (out.length == 5) break;
      if (used.add(x.$1.id)) out.add(x);
    }
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

  /// Adds a finished round to the day. Returns the titles of the daily tasks it completed.
  static List<String> record(int day, int points, int poemId, {bool perfect = false, Iterable<String> poets = const [], bool weekly = false}) {
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;
    final m = Store.i.majlis;
    final r = Map<String, dynamic>.from(m['rounds'] as Map? ?? {})..removeWhere((k, _) => (int.tryParse(k) ?? 0) < day - 40);
    r['$day'] = n(r['$day']) + 1;
    m['rounds'] = r;
    final s = Map<String, dynamic>.from(st);
    s['rounds'] = n(s['rounds']) + 1;
    if (perfect) s['perfect'] = n(s['perfect']) + 1;
    if (r['$day'] == roundsPerDay) s['fullDays'] = n(s['fullDays']) + 1;
    if (weekly) {
      s['weekly'] = n(s['weekly']) + 1;
      m['weekly'] = weekStart;
    }
    if (DateTime.now().weekday == DateTime.friday) s['friday'] = n(s['friday']) + 1;
    s['poets'] = {...(s['poets'] as List? ?? []), ...poets}.toList();
    m['st'] = s;
    // daily tasks
    var bonus = 0;
    final finished = <String>[];
    if (Store.i.feature('tasks')) {
      final t = _tasksToday;
      final done = List<String>.from(t['done'] as List);
      final perfectToday = n(t['perfect']) + (perfect ? 1 : 0);
      final ok = {'r3': n(r['$day']) >= 3, 'p1': perfectToday >= 1, 'r10': n(r['$day']) >= roundsPerDay};
      for (final (id, title, reward) in tasks) {
        if (ok[id] == true && !done.contains(id)) {
          done.add(id);
          bonus += reward;
          finished.add('$title (+${Ar.num(reward)})');
        }
      }
      m['tasks'] = {'day': day, 'done': done, 'perfect': perfectToday};
    }
    final d = Map<String, dynamic>.from(_days);
    final old = d['$day'] as List?;
    d['$day'] = [n(old?[0]) + points + bonus, old == null ? poemId : n(old[1])];
    m['days'] = d;
    s['bestStreak'] = max(n(s['bestStreak']), streak);
    Store.i.saveMajlis();
    return finished;
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

  /// (rank and level, points of the next level).
  static (String, int?) rank(int points) {
    final l = levelOf(points);
    return ('${rankNames[rankIndex(l)]} · المستوى ${Ar.num(l)}', l >= 100 ? null : need(l + 1));
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
              Majlis.roundsToday >= Majlis.roundsPerDay
                  ? 'أتممت جولات اليوم العشر. تتجدد غداً.'
                  : (done == null ? 'عشر جولات تنتظرك اليوم: خمس مراحل بخمسة أبيات.' : 'لعبت ${Ar.num(Majlis.roundsToday)} من ١٠ جولات اليوم.'),
              style: TextStyle(fontSize: 14.5, height: 1.5, color: C.muted(context)),
            ),
            const SizedBox(height: 2),
            Text('$rank · ${Ar.num(Majlis.total)} نقطة', style: TextStyle(fontSize: 13.5, color: C.accent(context))),
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
          if (points != null) ShapeBadge(size: size * 0.36, fraction: points! / 300, seed: points!, color: const Color(0xFF8C4A2F)),
        ]),
      );
}

class MajlisScreen extends StatelessWidget {
  const MajlisScreen({super.key});

  void _play(BuildContext context) {
    if (Majlis.roundsToday >= Majlis.roundsPerDay) {
      toast(context, 'أتممت جولات اليوم العشر. تتجدد غداً، ولك جولة التدريب متى شئت.');
      return;
    }
    push(context, ChallengeScreen(picks: Majlis.pick(), day: Store.today));
  }

  /// [big]: the key entries of the page are drawn a little larger, so they stand out.
  Widget _tile(BuildContext context, IconData icon, String title, String sub, VoidCallback onTap, {Color? color, bool big = false}) => SoftCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Column(children: [
          Icon(icon, color: color ?? C.accent(context), size: big ? 34 : 28),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: big ? 17 : 14, fontWeight: FontWeight.w700, color: C.ink(context))),
          Text(sub, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
        ]),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final today = Store.today;
          final total = Majlis.total;
          final level = Majlis.levelOf(total);
          final prev = Majlis.need(level), next = level >= 100 ? null : Majlis.need(level + 1);
          final rounds = Majlis.roundsToday;
          final days = [for (var d = today; d > today - 60; d--) if (Majlis.played(d) != null) d];
          final got = achievements().where((a) => a.done).length;
          final sp = min(Majlis.streak, 15) * 2;
          final f = Store.i.feature;
          return Scaffold(
            appBar: AppBar(title: const Text('مجلس الشعر'), actions: [
              IconButton(tooltip: 'التعليمات', onPressed: () => push(context, const GuideScreen()), icon: const Icon(Icons.help_outline_rounded)),
            ]),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Majlis.rankColors[Majlis.rankIndex(level)], width: 3),
                        color: Majlis.rankColors[Majlis.rankIndex(level)].withValues(alpha: 0.12),
                      ),
                      child: Text(Ar.num(level), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Majlis.rankColors[Majlis.rankIndex(level)])),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(Majlis.rankNames[Majlis.rankIndex(level)], style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.ink(context))),
                        Text('المستوى ${Ar.num(level)} من ١٠٠ · ${Ar.num(total)} نقطة', style: TextStyle(color: C.muted(context))),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: next == null ? 1 : (total - prev) / (next - prev),
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(6),
                    color: Majlis.rankColors[Majlis.rankIndex(level)],
                  ),
                  const SizedBox(height: 6),
                  Text(next == null ? 'بلغت المستوى المئة: أمير المجلس.' : 'بقي ${Ar.num(next - total)} نقطة للمستوى ${Ar.num(level + 1)}', style: TextStyle(color: C.muted(context))),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.local_fire_department_rounded, size: 20, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Expanded(child: Text('${Ar.num(Majlis.streak)} يوماً متتالياً${sp > 0 ? ' · مكافأة +${Ar.num(sp)}٪' : ''}', style: TextStyle(color: C.ink(context)))),
                    if (Majlis.friday) const Tag('الجمعة: النقاط مضاعفة'),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              SoftCard(
                onTap: () => _play(context),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('جولات اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
                        Text(
                          rounds >= Majlis.roundsPerDay ? 'أتممت العشر. تتجدد غداً.' : 'لعبت ${Ar.num(rounds)} من ١٠. كل جولة خمس مراحل بخمسة أبيات جديدة، ومئة نقطة.',
                          style: TextStyle(fontSize: 14.5, height: 1.5, color: C.muted(context)),
                        ),
                      ]),
                    ),
                    if (rounds < Majlis.roundsPerDay) FilledButton(onPressed: () => _play(context), child: Text(rounds == 0 ? 'ابدأ' : 'العب')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (var i = 0; i < Majlis.roundsPerDay; i++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 8,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: i < rounds ? Majlis.gold : C.line(context)),
                        ),
                      ),
                  ]),
                ]),
              ),
              if (f('tasks')) ...[
                const SizedBox(height: 10),
                SoftCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('مهام اليوم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
                    for (final (id, title, reward) in Majlis.tasks)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(children: [
                          Icon(Majlis.taskDone(id) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: Majlis.taskDone(id) ? Majlis.green : C.muted(context)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(title, style: TextStyle(color: C.ink(context)))),
                          Text('+${Ar.num(reward)}', style: TextStyle(fontWeight: FontWeight.w700, color: Majlis.gold)),
                        ]),
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05, children: [
                ...[
                  _tile(context, Icons.emoji_events_outlined, 'الصدارة', 'أسبوعك: ${Ar.num(Majlis.sum(Majlis.weekStart))}', () => push(context, const LeaderboardScreen()), color: Majlis.gold, big: true),
                  if (f('weekly') && Majlis.weeklyPoet.isNotEmpty)
                    _tile(context, Icons.star_outline_rounded, 'شاعر الأسبوع', Majlis.weeklyDone ? 'أتممتها' : Majlis.weeklyPoet, () {
                      if (Majlis.weeklyDone) {
                        toast(context, 'أتممت جولة «${Majlis.weeklyPoet}» هذا الأسبوع. شاعر جديد يوم السبت.');
                      } else {
                        push(context, ChallengeScreen(picks: Majlis.pick(5, Majlis.weeklyPoet), day: today, weekly: true));
                      }
                    }, color: Majlis.gold),
                  _tile(context, Icons.military_tech_outlined, 'الأوسمة', '${Ar.num(got)} وساماً', () => push(context, const AchievementsScreen())),
                  if (f('duel')) _tile(context, Icons.sports_kabaddi_rounded, 'المبارزات', 'تحدَّ صديقاً', () => push(context, const DuelsScreen())),
                  _tile(context, Icons.refresh_rounded, 'أخطائي', '${Ar.num(Majlis.mistakes.length)} بيتاً', () => push(context, const MistakesScreen())),
                  _tile(context, Icons.fitness_center_rounded, 'تدريب', 'بلا نقاط', () => push(context, ChallengeScreen(picks: Majlis.pick()))),
                  if (f('golden'))
                    _tile(context, Icons.auto_awesome_rounded, 'بيت الذهب', goldenDoneToday() ? 'أُنجز اليوم: شاهد بيتك' : 'أسئلة عن بيت اليوم', () => push(context, const GoldenScreen()), color: Majlis.gold, big: true),
                  _tile(context, Icons.menu_book_outlined, 'التعليمات', 'كيف تُحسب النقاط', () => push(context, const GuideScreen())),
                ],
              ]),
              const SectionTitle('ديوانك'),
              if (days.isEmpty)
                Text('كل يوم تلعب فيه تُضاف ورقة إلى ديوانك، فيها بيت ذلك اليوم.', style: TextStyle(color: C.muted(context), height: 1.6))
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
  final bool weekly; // the poet of the week: double points
  final String? duel; // a duel with a friend: the result goes to the server
  final void Function(int points)? onDone; // a shared challenge: called once, when the round is finished
  const ChallengeScreen({super.key, required this.picks, this.day, this.weekly = false, this.duel, this.onDone});
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
  int tries = 3; // three in the first stage only; one in the others
  DateTime started = DateTime.now();
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
    // The glance gets shorter as the level rises.
    seconds = max(3, 6 - Majlis.levelOf(Majlis.total) ~/ 20);
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
    final int got;
    if (stage == 0) {
      got = hinted && tries == 3 ? 14 : const [8, 14, 20][tries - 1];
    } else {
      final fast = DateTime.now().difference(started).inSeconds < 7;
      got = (hinted ? 11 : 18) + (fast ? 2 : 0);
    }
    points.add(got);
    if (widget.day != null) Majlis.markMiss(widget.picks[stage % widget.picks.length], false);
    _next();
  }

  void _lose(String choice) {
    HapticFeedback.heavyImpact();
    setState(() {
      tries--;
      wrong = choice;
      if (tries == 0) {
        // A miss in the one-attempt stages takes five points off the round.
        points.add(stage == 0 ? 0 : -5);
        if (widget.day != null) Majlis.markMiss(widget.picks[stage % widget.picks.length], true);
      }
    });
    if (tries == 0) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) _next();
      });
    }
  }

  void _next() {
    if (stage == Majlis.stages.length - 1) {
      final base = max(0, points.fold(0, (a, b) => a + b));
      var earned = base;
      final notes = <String>[];
      int? newLevel;
      if (widget.day != null) {
        final before = Majlis.levelOf(Majlis.total);
        final sp = min(Majlis.streak, 15) * 2;
        var mult = 1 + sp / 100;
        if (sp > 0) notes.add('مكافأة المواظبة +${Ar.num(sp)}٪');
        if (Majlis.friday) {
          mult *= 2;
          notes.add('جولة الجمعة: النقاط مضاعفة');
        }
        if (widget.weekly) {
          mult *= 2;
          notes.add('شاعر الأسبوع: النقاط مضاعفة');
        }
        earned = (base * mult).round();
        final tasks = Majlis.record(
          widget.day!,
          earned,
          poemAt(0).id,
          perfect: points.first == 20 && points.skip(1).every((p) => p >= 18),
          poets: [for (var i = 0; i < points.length; i++) if (points[i] > 0) poemAt(i).poet],
          weekly: widget.weekly,
        );
        notes.addAll([for (final t in tasks) 'مهمة اليوم: $t']);
        final after = Majlis.levelOf(Majlis.total);
        if (after > before) newLevel = after;
        Cloud.i.pushBoard();
        Cloud.i.syncSoon();
      }
      if (widget.duel != null) Cloud.i.submitResult(widget.duel!, base, Majlis.maxPoints);
      widget.onDone?.call(base);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ResultScreen(picks: widget.picks, points: List.of(points), daily: widget.day != null, base: base, earned: earned, notes: notes, newLevel: newLevel, duel: widget.duel != null)));
      return;
    }
    setState(() {
      stage++;
      tries = 1;
      started = DateTime.now();
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
        title: Text(widget.duel != null ? 'مبارزة' : (widget.weekly ? 'شاعر الأسبوع' : (widget.day == null ? 'جولة تدريب' : 'جولة اليوم'))),
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

  Widget _tries(BuildContext context) => stage != 0
      ? Text(tries == 0 ? 'لم تُصب: نقصت ٥ نقاط' : 'محاولة واحدة · الخطأ ينقص ٥ نقاط', style: TextStyle(fontSize: 13, color: tries == 0 ? Majlis.red : C.muted(context)))
      : Row(mainAxisSize: MainAxisSize.min, children: [
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
  final bool daily, duel;
  final int base, earned;
  final List<String> notes;
  final int? newLevel;
  const ResultScreen({super.key, required this.picks, required this.points, required this.daily, required this.base, required this.earned, this.notes = const [], this.newLevel, this.duel = false});
  @override
  Widget build(BuildContext context) {
    final seed = picks.fold(0, (a, x) => a + x.$1.id * 7 + x.$2);
    return Scaffold(
      appBar: AppBar(title: Text(duel ? 'نتيجة المبارزة' : (daily ? 'نتيجة الجولة' : 'نتيجة التدريب'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 40), children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: base / Majlis.maxPoints),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => ShapeBadge(size: 170, fraction: t, seed: seed),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            base >= 100 ? 'اكتمل الشكل! جولة تامّة' : (base >= 70 ? 'أحسنت' : (base >= 40 ? 'لا بأس، والقادمة أفضل' : 'حاول مرة أخرى')),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.ink(context)),
          ),
        ),
        Center(
          child: Text(
            duel
                ? 'وصلت نتيجتك. ترى نتيجة صاحبك في «المبارزات».'
                : (daily ? 'أُضيفت ${Ar.num(earned)} نقطة إلى مستواك.' : 'جولة تدريب: لا تُحسب في النقاط.'),
            style: TextStyle(color: C.muted(context)),
          ),
        ),
        if (newLevel != null) ...[
          const SizedBox(height: 12),
          SoftCard(
            child: Row(children: [
              const Icon(Icons.keyboard_double_arrow_up_rounded, color: Majlis.gold, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text('صعدت إلى المستوى ${Ar.num(newLevel!)} · ${Majlis.rankNames[Majlis.rankIndex(newLevel!)]}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
              ),
            ]),
          ),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [for (final n in notes) Tag(n)]),
        ],
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
                  Text(points[i] >= 20 ? 'تامّة' : (points[i] > 0 ? 'أصبت' : (points[i] < 0 ? 'لم تُصب (−٥)' : 'لم تُصب')), style: TextStyle(color: C.muted(context))),
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
              ButtonSegment(value: 1, label: Text('موسم الشهر')),
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
                          const SizedBox(height: 2),
                          Row(children: [
                            RankBadge(((list[i]['total'] ?? list[i]['pts'] ?? 0) as num).toInt(), small: true),
                            const SizedBox(width: 6),
                            Text('${Ar.num(((list[i]['streak'] ?? 0) as num).toInt())} يوماً', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
                          ]),
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
