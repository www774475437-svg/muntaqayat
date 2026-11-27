import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data.dart';
import '../main.dart';
import '../services/cloud.dart';
import '../services/device.dart';
import '../ui.dart';
import 'boards.dart';
import 'lists.dart';
import 'poem.dart' show formatVerses;

/// «بيت الذهب»: questions about the verse of the day, the same for everyone,
/// one attempt for each question, once a day. What the reader gets right turns
/// gold on the verse's own plate, and the rest stays grey.
class Golden {
  /// Every verse played so far, by poem id: {day, r, t, ans}.
  static Map<String, dynamic> get log => Map<String, dynamic>.from(Store.i.majlis['goldenLog'] as Map? ?? {});

  static Map? get _run {
    final g = Store.i.majlis['goldenRun'];
    return g is Map && g['day'] == Store.today ? g : null;
  }

  /// Today's answers so far: 1 right, 0 wrong.
  static List<int> get todayAnswers => [for (final x in (_run?['ans'] as List? ?? const [])) x == 1 ? 1 : 0];
  static bool get doneToday => _run?['done'] == true;

  static int _n(dynamic v) => v is num ? v.toInt() : 0;
  static int get played => log.length;
  static int get full => log.values.where((e) => e is Map && _n(e['t']) > 0 && _n(e['r']) == _n(e['t'])).length;
  static int get rightTotal => log.values.fold(0, (a, e) => a + (e is Map ? _n(e['r']) : 0));
  static int get askedTotal => log.values.fold(0, (a, e) => a + (e is Map ? _n(e['t']) : 0));
  static int get percent => askedTotal == 0 ? 0 : (rightTotal * 100 / askedTotal).floor();

  /// Days in a row that ended with a complete verse, up to today (or yesterday, before today's is played).
  static int get streak {
    final days = <int>{for (final e in log.values) if (e is Map && _n(e['t']) > 0 && _n(e['r']) == _n(e['t'])) _n(e['day'])};
    var d = Store.today;
    if (!days.contains(d)) d--;
    var n = 0;
    while (days.contains(d)) {
      n++;
      d--;
    }
    return n;
  }

  /// The longest run of complete days so far.
  static int get bestStreak {
    final days = (<int>{for (final e in log.values) if (e is Map && _n(e['t']) > 0 && _n(e['r']) == _n(e['t'])) _n(e['day'])}.toList())..sort();
    var best = 0, run = 0, last = -5;
    for (final d in days) {
      run = d == last + 1 ? run + 1 : 1;
      if (run > best) best = run;
      last = d;
    }
    return best;
  }

  /// Day number → (right, asked), for the calendar.
  static Map<int, (int, int)> get byDay => {
        for (final e in log.values)
          if (e is Map) _n(e['day']): (_n(e['r']), _n(e['t']))
      };

  static int dayOf(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024, 1, 1)).inDays;

  /// The calendar day of a day number.
  static DateTime dateOf(int day) => DateTime.utc(2024, 1, 1 + day);

  static void saveAnswer(Poem p, List<int> ans, int total) {
    final m = Store.i.majlis;
    final done = ans.length >= total;
    m['goldenRun'] = {'day': Store.today, 'poem': p.id, 'ans': ans, 'done': done};
    if (done) {
      final l = log;
      final right = ans.where((a) => a == 1).length;
      final old = l['${p.id}'];
      // A verse that comes round again keeps its better result.
      if (old is! Map || _n(old['r']) <= right) l['${p.id}'] = {'day': Store.today, 'r': right, 't': total, 'ans': ans};
      m['goldenLog'] = l;
    }
    Store.i.saveMajlis();
    if (done) {
      Cloud.i.publishStats({'goldFull': full, 'goldRight': rightTotal, 'goldStreak': streak});
      Device.refresh();
    }
  }
}

/// Whether the golden challenge was already finished today.
bool goldenDoneToday() => Golden.doneToday;

class _GQ {
  final bool order; // arrange the words; otherwise pick one of four
  final String title, correct;
  final List<String> shown, options;
  const _GQ(this.title, this.shown, this.options, this.correct, {this.order = false});
}

const _shortVowels = ['َ', 'ُ', 'ِ'];

List<String> _split(String s) => s.trim().split(RegExp(r'\s+'));

/// The day's questions. Seeded by the day and the verse, so everyone gets the same.
List<_GQ> _goldenQuestions(Poem p, {int? day}) {
  final rnd = Random((day ?? Store.today) * 31 + p.id);
  final v = p.firstVerse;
  final first = v[0].trim(), second = v.length > 1 ? v[1].trim() : '';
  final words = [..._split(first), if (second.isNotEmpty) ..._split(second)];
  final qs = <_GQ>[];

  _GQ pick(String title, List<String> shown, String right, List<String> wrong) => _GQ(title, shown, [right, ...wrong]..shuffle(rnd), right);

  // 1. Arrange the words of the verse.
  var mixed = [...words]..shuffle(rnd);
  if (mixed.join(' ') == words.join(' ')) mixed = mixed.reversed.toList();
  qs.add(_GQ('رتّب كلمات البيت', const [], mixed, words.join(' '), order: true));

  // 2. Who said it? The other names come from the same era when there are enough.
  if (p.poet.isNotEmpty && !p.unattributed) {
    bool usable(Poem o) => o.poet.isNotEmpty && !o.unattributed && o.poet != p.poet && !p.poetNote.contains(o.poet);
    final same = <String>{for (final o in Library.all) if (usable(o) && o.era == p.era) o.poet}.toList()..shuffle(rnd);
    final any = <String>{for (final o in Library.all) if (usable(o)) o.poet}.toList()..shuffle(rnd);
    final wrong = <String>[...same.take(3)];
    for (final a in any) {
      if (wrong.length >= 3) break;
      if (!wrong.contains(a)) wrong.add(a);
    }
    if (wrong.length == 3) qs.add(pick('من قائل البيت؟', [first, second], p.poet, wrong));
  }

  // 3. The second half of the verse. The other halves share its rhyme when there are enough.
  if (second.isNotEmpty) {
    final seen = <String>{Ar.plain(second)};
    final sameRhyme = <String>[], other = <String>[];
    for (final o in ([...Library.all]..shuffle(rnd))) {
      if (o.id == p.id || o.lines.isEmpty || o.lines.first.length != 2) continue;
      final s = o.lines.first[1].trim();
      if (s.isEmpty || !seen.add(Ar.plain(s))) continue;
      (o.rhyme == p.rhyme && p.rhyme.isNotEmpty ? sameRhyme : other).add(s);
    }
    final wrong = [...sameRhyme, ...other].take(3).toList();
    if (wrong.length == 3) qs.add(pick('أكمل الشطر الثاني', [first], second, wrong));
  }

  // 4. Its chapter in the book.
  final chapters = <String>{for (final c in Library.chapters) if (c.name != p.chapterName) c.name}.toList()..shuffle(rnd);
  if (chapters.length >= 3) qs.add(pick('في أي باب هذا البيت؟', [first, second], p.chapterName, chapters.take(3).toList()));

  // 5. When the poet died, when the book records it.
  if (p.death.isNotEmpty && !p.unattributed) {
    final deaths = <String>{for (final o in Library.all) if (o.death.isNotEmpty && o.death != p.death && o.poet != p.poet) o.death}.toList()..shuffle(rnd);
    if (deaths.length >= 3) qs.add(pick('متى توفي ${p.poet}؟', const [], p.death, deaths.take(3).toList()));
  }

  // 6. The poet's era. Eras that overlap with the right one are not offered.
  if (p.era.isNotEmpty && !p.unattributed) {
    const overlap = {
      'مخضرم': ['جاهلي', 'صدر الإسلام'],
      'جاهلي': ['مخضرم'],
      'صدر الإسلام': ['مخضرم', 'أموي'],
      'أموي': ['صدر الإسلام'],
      'عباسي': ['أندلسي', 'أيوبي'],
      'أندلسي': ['عباسي', 'أيوبي', 'مملوكي'],
      'أيوبي': ['عباسي', 'أندلسي', 'مملوكي'],
      'مملوكي': ['أيوبي', 'أندلسي', 'عثماني'],
      'عثماني': ['مملوكي', 'حديث'],
      'حديث': ['عثماني'],
    };
    final skip = overlap[p.era] ?? const <String>[];
    final eras = <String>{for (final o in Library.all) if (o.era.isNotEmpty && o.era != p.era && !skip.contains(o.era)) o.era}.toList()..shuffle(rnd);
    if (eras.length >= 3) qs.add(pick('في أي عصر عاش ${p.poet}؟', const [], p.era, eras.take(3).toList()));
  }

  // 7. How one word is vowelled in the verse. Asked only on verses the developer
  // has verified, so a slip in the stored vowels is never counted against the reader.
  final verified = p.verifiedVerse(p.lines.indexOf(v) + 1);
  final marked = [
    for (final w in words)
      if (verified && Ar.plain(w).length >= 4 && w.split('').where(_shortVowels.contains).length >= 2) w
  ];
  if (marked.isNotEmpty) {
    final w = marked[rnd.nextInt(marked.length)];
    final at = [for (var i = 0; i < w.length; i++) if (_shortVowels.contains(w[i])) i];
    final wrong = <String>{};
    for (var guard = 0; wrong.length < 3 && guard < 80; guard++) {
      final chars = w.split('');
      final i = at[rnd.nextInt(at.length)];
      final others = _shortVowels.where((x) => x != chars[i]).toList();
      chars[i] = others[rnd.nextInt(others.length)];
      wrong.add(chars.join());
    }
    if (wrong.length == 3) qs.add(pick('كيف ضُبطت كلمة «${Ar.plain(w)}» في البيت؟', [Ar.plain(first), Ar.plain(second)], w, wrong.toList()));
  }
  return qs;
}

class GoldenScreen extends StatefulWidget {
  const GoldenScreen({super.key});
  @override
  State<GoldenScreen> createState() => _GoldenScreenState();
}

class _GoldenScreenState extends State<GoldenScreen> {
  static const gold = Color(0xFFB08A3E), green = Color(0xFF2F6B4F), red = Color(0xFFB3261E);
  late final Poem poem = Library.poemOfDay();
  late final List<_GQ> qs = _goldenQuestions(poem);
  late List<int> ans = Golden.todayAnswers.take(qs.length).toList();
  String? picked; // the choice made on the question in view
  bool answered = false, lastRight = false;
  final List<int> placed = []; // indexes of the words placed so far, in order

  int get step => answered ? ans.length - 1 : ans.length;
  bool get finished => ans.length >= qs.length && !answered;

  void _record(bool ok) {
    setState(() {
      answered = true;
      lastRight = ok;
      ans = [...ans, ok ? 1 : 0];
    });
    Golden.saveAnswer(poem, ans, qs.length);
  }

  void _next() => setState(() {
        answered = false;
        picked = null;
        placed.clear();
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('بيت الذهب'), actions: [
          IconButton(tooltip: 'بيت الأمس', icon: const Icon(Icons.history_rounded), onPressed: () => push(context, const GoldenYesterdayScreen())),
          IconButton(tooltip: 'بيوتي الذهبية', icon: const Icon(Icons.collections_bookmark_outlined), onPressed: () => push(context, const GoldenGalleryScreen())),
        ]),
        body: finished ? _result(context) : _question(context),
      );

  Widget _question(BuildContext context) {
    final q = qs[step];
    return ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 120), children: [
      Row(children: [
        Text('السؤال ${Ar.num(step + 1)} من ${Ar.num(qs.length)}', style: TextStyle(color: C.muted(context))),
        const Spacer(),
        for (var i = 0; i < qs.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 5),
            child: Icon(Icons.circle, size: 11, color: i < ans.length ? (ans[i] == 1 ? gold : C.muted(context)) : C.line(context)),
          ),
      ]),
      const SizedBox(height: 6),
      Text('محاولة واحدة لكل سؤال.', style: TextStyle(fontSize: 13, color: C.muted(context))),
      const SizedBox(height: 14),
      Text(q.title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink(context))),
      const SizedBox(height: 12),
      if (q.shown.where((s) => s.isNotEmpty).isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: gold)),
          child: Column(children: [
            for (final l in q.shown.where((s) => s.isNotEmpty))
              FittedBox(fit: BoxFit.scaleDown, child: Text(l, style: TextStyle(fontFamily: 'Amiri', fontSize: 22, height: 1.8, color: C.ink(context)))),
          ]),
        ),
      if (q.order) ..._orderBody(context, q) else ..._pickBody(context, q),
      if (answered) ...[
        const SizedBox(height: 8),
        Text(lastRight ? 'أصبت.' : 'لم تُصب.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: lastRight ? green : red)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _next, child: Text(ans.length >= qs.length ? 'النتيجة' : 'السؤال التالي')),
      ],
    ]);
  }

  List<Widget> _pickBody(BuildContext context, _GQ q) => [
        for (final o in q.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: answered
                    ? null
                    : () {
                        picked = o;
                        _record(o == q.correct);
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  side: BorderSide(width: answered && (o == q.correct || o == picked) ? 2 : 1, color: answered && o == q.correct ? green : (answered && o == picked ? red : gold)),
                ),
                child: Text(o, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontSize: 19, height: 1.6, color: C.ink(context))),
              ),
            ),
          ),
      ];

  List<Widget> _orderBody(BuildContext context, _GQ q) {
    Widget chip(String w, {VoidCallback? onTap, bool faded = false}) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: faded ? Colors.transparent : C.soft(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: faded ? C.line(context) : gold)),
            child: Text(w, style: TextStyle(fontFamily: 'Amiri', fontSize: 20, height: 1.5, color: faded ? Colors.transparent : C.ink(context))),
          ),
        );
    return [
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: answered ? (lastRight ? green : red) : gold)),
        child: placed.isEmpty
            ? Center(child: Text('اضغط الكلمات بترتيبها الصحيح', style: TextStyle(color: C.muted(context))))
            : Wrap(spacing: 8, runSpacing: 8, children: [
                for (final i in placed) chip(q.options[i], onTap: answered ? null : () => setState(() => placed.remove(i))),
              ]),
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        for (var i = 0; i < q.options.length; i++)
          placed.contains(i) ? chip(q.options[i], faded: true) : chip(q.options[i], onTap: answered ? null : () => setState(() => placed.add(i))),
      ]),
      const SizedBox(height: 16),
      if (!answered)
        FilledButton(
          onPressed: placed.length == q.options.length ? () => _record([for (final i in placed) q.options[i]].join(' ') == q.correct) : null,
          child: const Text('تأكيد الترتيب'),
        ),
      if (answered && !lastRight) ...[
        Text('الترتيب الصحيح:', style: TextStyle(color: C.muted(context))),
        const SizedBox(height: 6),
        VerseLines(poem.firstVerse, size: 21),
      ],
    ];
  }

  Widget _result(BuildContext context) {
    final right = ans.where((a) => a == 1).length;
    final all = right == qs.length;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 120), children: [
      GoldenPlate(poem: poem, ans: ans),
      const SizedBox(height: 10),
      Text(
        all ? 'نلتَ البيت ذهبياً كاملاً' : 'نلتَ من البيت ${Ar.num(right)} من ${Ar.num(qs.length)}',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: all ? gold : C.ink(context)),
      ),
      const SizedBox(height: 4),
      Text('درجتك ${Ar.num((right * 100 / qs.length).floor())}٪ · بيت جديد غداً', textAlign: TextAlign.center, style: TextStyle(color: C.muted(context))),
      const SizedBox(height: 16),
      for (var i = 0; i < qs.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(ans[i] == 1 ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 20, color: ans[i] == 1 ? gold : C.muted(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(qs[i].title, style: TextStyle(fontSize: 14, color: C.muted(context))),
                  Text(qs[i].correct, style: TextStyle(fontFamily: 'Amiri', fontSize: 17, height: 1.6, color: C.ink(context))),
                ]),
              ),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => push(context, const GoldenGalleryScreen()), icon: const Icon(Icons.collections_bookmark_outlined), label: const Text('بيوتي الذهبية'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: () => push(context, const BoardsScreen()), icon: const Icon(Icons.emoji_events_outlined), label: const Text('المتصدرون'))),
      ]),
      const SizedBox(height: 6),
      Center(
        child: TextButton.icon(
          onPressed: () => reportDialog(context, 'بيت الذهب', 'البيت رقم ${poem.id}'),
          icon: const Icon(Icons.flag_outlined, size: 18),
          label: const Text('أبلغ عن خطأ في الأسئلة'),
        ),
      ),
    ]);
  }
}

/// Asks what is wrong, then sends the report to the developer.
Future<void> reportDialog(BuildContext context, String kind, String target) async {
  final t = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('ما الخطأ؟'),
      content: TextField(controller: t, maxLines: 4, maxLength: 300, decoration: const InputDecoration(hintText: 'اكتب الخطأ الذي رأيته وموضعه')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(d, t.text.trim()), child: const Text('أرسل')),
      ],
    ),
  );
  if (text == null || text.isEmpty || !context.mounted) return;
  final ok = await Cloud.i.report(kind, target, text);
  if (context.mounted) toast(context, ok ? 'وصل بلاغك، شكراً لك' : 'ادخل بحسابك أولاً لترسل البلاغ');
}

/// «بيت الأمس»: the verse and its answers, to read only. It is not won from here.
class GoldenYesterdayScreen extends StatelessWidget {
  const GoldenYesterdayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final date = DateTime.now().subtract(const Duration(days: 1));
    final p = Library.poemOfDay(date);
    final day = Store.today - 1;
    final qs = _goldenQuestions(p, day: day);
    final mine = Golden.log['${p.id}'];
    final played = mine is Map && mine['day'] == day;
    return Scaffold(
      appBar: AppBar(title: const Text('بيت الأمس')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 120), children: [
        Text(played ? 'لعبتَ هذا البيت أمس، وهذه أجوبته.' : 'فاتك هذا البيت. هذه أجوبته للاطلاع، ولا يُنال بعد يومه.', style: TextStyle(height: 1.7, color: C.muted(context))),
        const SizedBox(height: 12),
        SoftCard(padding: const EdgeInsets.all(16), onTap: () => openPoem(context, p), child: VerseLines(p.firstVerse, size: 23)),
        const SizedBox(height: 12),
        for (final q in qs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(q.title, style: TextStyle(fontSize: 14, color: C.muted(context))),
                Text(q.correct, style: TextStyle(fontFamily: 'Amiri', fontSize: 17, height: 1.6, color: C.ink(context))),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------ the plate

/// The verse on its own plate. Background, frame, ornaments, gold and script
/// all come from the verse's number, so no two verses look alike. The share of
/// the words that was won is gold; the rest is grey.
class GoldenVerseCard extends StatelessWidget {
  final Poem poem;
  final List<int> ans;
  final bool compact;

  /// The home page's plate: the same plate, thinner, so it does not fill the screen.
  final bool slim;
  final DateTime? date; // the day it was won; today when absent
  const GoldenVerseCard({super.key, required this.poem, required this.ans, this.compact = false, this.slim = false, this.date});

  static const _grounds = [
    [Color(0xFF0E1A2B), Color(0xFF1B2F4B)],
    [Color(0xFF0F2A22), Color(0xFF1C4436)],
    [Color(0xFF2B0F16), Color(0xFF4A1C27)],
    [Color(0xFF1B1B1F), Color(0xFF34343B)],
    [Color(0xFF24132E), Color(0xFF3E2450)],
    [Color(0xFF0C2A30), Color(0xFF17464F)],
    [Color(0xFF2A1C0E), Color(0xFF47311A)],
    [Color(0xFF14142E), Color(0xFF262654)],
  ];
  static const _golds = [
    [Color(0xFFF7E3A1), Color(0xFFD4A645), Color(0xFFA9792A)],
    [Color(0xFFFFEFC2), Color(0xFFE2B95B), Color(0xFFB98A2E)],
    [Color(0xFFF3D9A0), Color(0xFFC9973F), Color(0xFF8F6A1F)],
  ];
  static const _fonts = ['Amiri', 'ArefRuqaa', 'ReemKufi'];
  static const _grey = Color(0xFF8C8C92);

  @override
  Widget build(BuildContext context) {
    final id = poem.id;
    final ground = _grounds[(id * 7 + id ~/ 3) % _grounds.length];
    final golds = _golds[(id * 5 + id ~/ 7) % _golds.length];
    final font = _fonts[(id + id ~/ 4) % _fonts.length];
    final total = ans.length, right = ans.where((a) => a == 1).length;
    final all = total > 0 && right == total;
    final v = poem.firstVerse;
    final halves = [for (final h in v) if (h.trim().isNotEmpty) _split(h)];
    final wordCount = halves.fold(0, (a, h) => a + h.length);
    final goldWords = total == 0 ? 0 : (all ? wordCount : (wordCount * right / total).floor());
    final size = compact ? 17.0 : (slim ? 21.0 : 24.0);
    final shader = LinearGradient(colors: golds, begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTWH(0, 0, 300, size * 2.2));
    var seen = 0;
    Widget half(List<String> words) {
      final spans = <TextSpan>[];
      for (final w in words) {
        final isGold = seen < goldWords;
        seen++;
        spans.add(TextSpan(text: '$w ', style: isGold ? TextStyle(foreground: Paint()..shader = shader) : const TextStyle(color: _grey)));
      }
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text.rich(TextSpan(children: spans), textDirection: TextDirection.rtl, style: TextStyle(fontFamily: font, fontSize: size, height: slim ? 1.6 : 1.9, fontWeight: FontWeight.w700)),
      );
    }

    final pad = compact ? 18.0 : (slim ? 16.0 : 30.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 16 : 22),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(colors: ground, begin: Alignment.topRight, end: Alignment.bottomLeft)),
        child: CustomPaint(
          painter: _PlatePainter(id, all ? golds[1] : _grey, golds[1]),
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, pad + 4, pad, pad),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('بيت الذهب', style: TextStyle(fontSize: compact ? 11 : 13, letterSpacing: 0, color: (all ? golds[0] : _grey).withValues(alpha: 0.9))),
              SizedBox(height: compact ? 6 : (slim ? 4 : 12)),
              for (final h in halves) half(h),
              SizedBox(height: compact ? 6 : (slim ? 4 : 12)),
              if (!poem.unattributed) Text(poem.poet, style: TextStyle(fontSize: compact ? 11.5 : 14, color: Colors.white.withValues(alpha: 0.75))),
              SizedBox(height: compact ? 8 : (slim ? 6 : 14)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final a in ans)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Transform.rotate(
                      angle: pi / 4,
                      child: Container(width: compact ? 8 : 11, height: compact ? 8 : 11, decoration: BoxDecoration(color: a == 1 ? golds[1] : _grey.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(2))),
                    ),
                  ),
              ]),
              SizedBox(height: compact ? 6 : (slim ? 4 : 10)),
              Text(all ? 'مكتمل' : '${Ar.num(right)} من ${Ar.num(total)}', style: TextStyle(fontSize: compact ? 11 : 13, fontWeight: FontWeight.w700, color: all ? golds[0] : _grey)),
              SizedBox(height: compact ? 8 : (slim ? 6 : 14)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                AppMark(size: compact ? 22 : 28, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(Hijri.full(date), style: TextStyle(fontSize: compact ? 10 : 11.5, color: Colors.white.withValues(alpha: 0.7))),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  final int id;
  final Color frame, gold;
  _PlatePainter(this.id, this.frame, this.gold);

  Path _star(Offset c, double r, int points) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = pi * i / points - pi / 2;
      final pt = Offset(c.dx + rr * cos(a), c.dy + rr * sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  Path _diamond(Offset c, double r) => Path()
    ..moveTo(c.dx, c.dy - r)
    ..lineTo(c.dx + r * 0.7, c.dy)
    ..lineTo(c.dx, c.dy + r)
    ..lineTo(c.dx - r * 0.7, c.dy)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(id * 7919 + 11);
    final kind = (id * 11 + id ~/ 2) % 4;
    final frameKind = (id * 3 + id ~/ 5) % 5;

    // Ornaments scattered behind the verse, in places of this verse's own.
    for (var i = 0; i < 16; i++) {
      final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = 5 + rnd.nextDouble() * 13;
      final fill = Paint()..color = gold.withValues(alpha: 0.05 + rnd.nextDouble() * 0.09);
      final line = Paint()
        ..color = gold.withValues(alpha: 0.10 + rnd.nextDouble() * 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      switch (kind) {
        case 0:
          canvas.drawPath(_star(c, r, 8), fill);
        case 1:
          canvas.drawPath(_diamond(c, r), line);
        case 2:
          canvas.drawCircle(c, r, line);
          canvas.drawCircle(c, r * 0.45, fill);
        default:
          canvas.drawPath(_star(c, r, 5 + i % 3), line);
      }
    }

    // The frame.
    final p = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final thin = Paint()
      ..color = frame.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final solid = Paint()..color = frame;
    final box = Rect.fromLTWH(9, 9, size.width - 18, size.height - 18);
    final corners = [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight];
    switch (frameKind) {
      case 0:
        canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(14)), p);
        canvas.drawRRect(RRect.fromRectAndRadius(box.deflate(5), const Radius.circular(10)), thin);
      case 1:
        canvas.drawRect(box, p);
        for (final c in corners) {
          canvas.drawPath(_diamond(c, 7), solid);
        }
      case 2:
        const gap = 9.0;
        for (var x = box.left; x <= box.right; x += gap) {
          canvas.drawCircle(Offset(x, box.top), 1.5, solid);
          canvas.drawCircle(Offset(x, box.bottom), 1.5, solid);
        }
        for (var y = box.top; y <= box.bottom; y += gap) {
          canvas.drawCircle(Offset(box.left, y), 1.5, solid);
          canvas.drawCircle(Offset(box.right, y), 1.5, solid);
        }
      case 3:
        canvas.drawRect(box.deflate(4), thin);
        for (final c in corners) {
          canvas.drawCircle(c, 12, p);
          canvas.drawPath(_star(c, 6, 4), solid);
        }
      default:
        canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(6)), p);
        canvas.drawRRect(RRect.fromRectAndRadius(box.deflate(4), const Radius.circular(4)), thin);
        for (final c in [box.topCenter, box.bottomCenter, box.centerLeft, box.centerRight]) {
          canvas.drawPath(_star(c, 7, 8), solid);
        }
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.id != id || old.frame != frame || old.gold != gold;
}

/// The plate with two small marks under it: copy the verse, and share the plate as a picture.
class GoldenPlate extends StatefulWidget {
  final Poem poem;
  final List<int> ans;
  final DateTime? date;
  final VoidCallback? onTap;
  final bool slim;
  const GoldenPlate({super.key, required this.poem, required this.ans, this.date, this.onTap, this.slim = false});
  @override
  State<GoldenPlate> createState() => _GoldenPlateState();
}

class _GoldenPlateState extends State<GoldenPlate> {
  final _key = GlobalKey();
  bool busy = false;

  String get _text => '${formatVerses([widget.poem.firstVerse])}\n\n${widget.poem.unattributed ? '' : '${widget.poem.poet}\n'}${Hijri.full(widget.date)}\nمنتقيات الشعر';

  Future<void> _share() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await Share.shareXFiles([XFile.fromData(data!.buffer.asUint8List(), mimeType: 'image/png', name: 'bayt-althahab-${widget.poem.id}.png')], text: 'بيت الذهب — منتقيات الشعر');
    } catch (_) {
      if (mounted) toast(context, 'تعذّرت المشاركة');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget mark(IconData icon, String tip, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Tooltip(message: tip, child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 17, color: C.muted(context)))),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(onTap: widget.onTap, child: RepaintBoundary(key: _key, child: GoldenVerseCard(poem: widget.poem, ans: widget.ans, date: widget.date, slim: widget.slim))),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        mark(Icons.copy_rounded, 'نسخ', () {
          Clipboard.setData(ClipboardData(text: _text));
          toast(context, 'نُسخ البيت');
        }),
        mark(Icons.ios_share_rounded, 'مشاركة صورة', _share),
      ]),
    ]);
  }
}

// ------------------------------------------------------------ the collection

List<(Poem, List<int>, int)> _goldenEntries() {
  final out = <(Poem, List<int>, int)>[];
  Golden.log.forEach((k, e) {
    final p = Library.byId[int.tryParse(k)];
    if (p == null || e is! Map) return;
    out.add((p, [for (final x in e['ans'] as List? ?? const []) x == 1 ? 1 : 0], e['day'] is num ? (e['day'] as num).toInt() : 0));
  });
  out.sort((a, b) => b.$3.compareTo(a.$3));
  return out;
}

/// The numbers of «بيت الذهب» in one card, for the profile page.
class GoldenSummary extends StatelessWidget {
  const GoldenSummary({super.key});
  @override
  Widget build(BuildContext context) {
    Widget stat(String n, String label) => Expanded(
          child: Column(children: [
            Text(n, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFB08A3E))),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
          ]),
        );
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: () => push(context, const GoldenGalleryScreen()),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFB08A3E)),
          const SizedBox(width: 8),
          Expanded(child: Text('بيوت الذهب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context)))),
          Icon(Icons.chevron_left_rounded, color: C.muted(context)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          stat(Ar.num(Golden.full), 'مكتملة'),
          stat(Ar.num(Golden.played - Golden.full), 'ناقصة'),
          stat(Ar.num(Golden.streak), 'أيام متتالية'),
          stat('${Ar.num(Golden.percent)}٪', 'نسبة الإصابة'),
        ]),
      ]),
    );
  }
}

/// «بيوتي الذهبية»: every verse played, each on its plate.
class GoldenGalleryScreen extends StatefulWidget {
  const GoldenGalleryScreen({super.key});
  @override
  State<GoldenGalleryScreen> createState() => _GoldenGalleryScreenState();
}

class _GoldenGalleryScreenState extends State<GoldenGalleryScreen> {
  int filter = 0; // 0 all, 1 complete, 2 incomplete

  @override
  Widget build(BuildContext context) {
    final entries = _goldenEntries();
    bool complete((Poem, List<int>, int) e) => e.$2.isNotEmpty && !e.$2.contains(0);
    final shown = [for (final e in entries) if (filter == 0 || (filter == 1) == complete(e)) e];
    return Scaffold(
      appBar: AppBar(title: const Text('بيوتي الذهبية'), actions: [
        IconButton(tooltip: 'المتصدرون', icon: const Icon(Icons.emoji_events_outlined), onPressed: () => push(context, const BoardsScreen())),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
        const GoldenSummary(),
        const SizedBox(height: 12),
        const _StreakMedals(),
        const SizedBox(height: 12),
        const _GoldenCalendar(),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(onPressed: () => push(context, const GoldenYesterdayScreen()), icon: const Icon(Icons.history_rounded, size: 18), label: const Text('بيت الأمس وأجوبته')),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [
          for (final (i, t) in const [(0, 'الكل'), (1, 'المكتملة'), (2, 'الناقصة')]) ChoiceChip(label: Text(t), selected: filter == i, onSelected: (_) => setState(() => filter = i)),
        ]),
        const SizedBox(height: 12),
        if (shown.isEmpty) const EmptyNote(Icons.emoji_events_outlined, 'لا بيوت هنا بعد. العب «بيت الذهب» اليوم لتنال أول بيت.'),
        for (final e in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GoldenPlate(poem: e.$1, ans: e.$2, date: Golden.dateOf(e.$3), onTap: () => openPoem(context, e.$1)),
          ),
        if (!Golden.doneToday) ...[
          const SizedBox(height: 4),
          FilledButton.icon(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GoldenScreen())), icon: const Icon(Icons.emoji_events_rounded), label: const Text('العب بيت اليوم')),
        ],
      ]),
    );
  }
}

/// Medals for days in a row with a complete verse: 7, 30 and 100.
class _StreakMedals extends StatelessWidget {
  const _StreakMedals();
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFB08A3E);
    final best = Golden.bestStreak;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('أوسمة السلسلة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.ink(context))),
        Text('أطول سلسلة لك: ${Ar.num(best)} يوماً متتالياً ببيت مكتمل', style: TextStyle(fontSize: 13, color: C.muted(context))),
        const SizedBox(height: 10),
        Row(children: [
          for (final (n, name) in const [(7, 'وسام الأسبوع'), (30, 'وسام الشهر'), (100, 'وسام المئة')])
            Expanded(
              child: Column(children: [
                Icon(Icons.military_tech_rounded, size: 38, color: best >= n ? gold : C.line(context)),
                Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: best >= n ? gold : C.muted(context))),
                Text(best >= n ? 'نلتَه' : '${Ar.num(best)} من ${Ar.num(n)}', style: TextStyle(fontSize: 12, color: C.muted(context))),
              ]),
            ),
        ]),
      ]),
    );
  }
}

/// A month of «بيت الذهب»: gold for a complete day, half gold for an
/// incomplete one, grey for a day that passed unplayed.
class _GoldenCalendar extends StatefulWidget {
  const _GoldenCalendar();
  @override
  State<_GoldenCalendar> createState() => _GoldenCalendarState();
}

class _GoldenCalendarState extends State<_GoldenCalendar> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFB08A3E);
    final byDay = Golden.byDay;
    final today = Store.today;
    final count = DateTime(month.year, month.month + 1, 0).day;
    // The week starts on Saturday.
    final lead = (DateTime(month.year, month.month, 1).weekday + 1) % 7;
    final thisMonth = month.year == DateTime.now().year && month.month == DateTime.now().month;
    Widget cell(int d) {
      final n = Golden.dayOf(DateTime(month.year, month.month, d));
      final e = byDay[n];
      final full = e != null && e.$2 > 0 && e.$1 == e.$2;
      Color fill = Colors.transparent, ink = C.ink(context);
      Border? border;
      if (full) {
        fill = gold;
        ink = Colors.white;
      } else if (e != null) {
        fill = gold.withValues(alpha: 0.28);
        border = Border.all(color: gold);
      } else if (n < today) {
        fill = C.line(context);
        ink = C.muted(context);
      } else if (n == today) {
        border = Border.all(color: C.accent(context), width: 1.5);
      }
      return Container(
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: border),
        child: Text(Ar.num(d), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
      );
    }

    Widget key(Color c, String t, {bool ring = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: ring ? Border.all(color: gold) : null)),
          const SizedBox(width: 5),
          Text(t, style: TextStyle(fontSize: 12, color: C.muted(context))),
        ]);

    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_right_rounded)),
          Expanded(child: Text('${Hijri.gMonths[month.month - 1]} ${Ar.num(month.year)}', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.ink(context)))),
          IconButton(onPressed: thisMonth ? null : () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_left_rounded)),
        ]),
        Row(children: [
          for (final w in const ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج']) Expanded(child: Text(w, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted(context)))),
        ]),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < lead; i++) const SizedBox(),
            for (var d = 1; d <= count; d++) cell(d),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center, children: [
          key(gold, 'مكتمل'),
          key(gold.withValues(alpha: 0.28), 'ناقص', ring: true),
          key(C.line(context), 'فائت'),
        ]),
      ]),
    );
  }
}

/// On another reader's page: his golden verses beside mine.
class GoldenCompare extends StatelessWidget {
  final String uid, name;
  const GoldenCompare({super.key, required this.uid, required this.name});
  @override
  Widget build(BuildContext context) => FutureBuilder<Doc>(
        future: Cloud.i.boardOf(uid),
        builder: (context, snap) {
          final b = snap.data;
          if (b == null) return const SizedBox();
          int n(String k) => b[k] is num ? (b[k] as num).toInt() : 0;
          const gold = Color(0xFFB08A3E);
          Widget col(String who, int full, int streak) => Expanded(
                child: Column(children: [
                  Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: C.muted(context))),
                  Text(Ar.num(full), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: gold)),
                  Text('بيتاً مكتملاً · سلسلة ${Ar.num(streak)}', style: TextStyle(fontSize: 12, color: C.muted(context))),
                ]),
              );
          return SoftCard(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.emoji_events_rounded, size: 16, color: gold),
                const SizedBox(width: 6),
                Text('بيوت الذهب: أنت وهو', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.ink(context))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                col(name.isEmpty ? 'هو' : name, n('goldFull'), n('goldStreak')),
                Container(width: 1, height: 44, color: C.line(context)),
                col('أنت', Golden.full, Golden.streak),
              ]),
            ]),
          );
        },
      );
}
