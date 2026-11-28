import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'extras.dart';
import 'lists.dart';
import 'majlis.dart';
import 'games.dart';
import 'mutun.dart';
import 'proverbs_quiz.dart';
import 'shawahid.dart';
import 'whosaid.dart';
import 'plus.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final forYou = Library.dailyPicks(20, salt: 11);
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.only(bottom: 130), children: [
        const SectionTitle('مداخل الديوان'),
        SoftCard(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.zero,
          child: Column(children: [
            InkWell(
              onTap: () => push(context, Builder(builder: erasScreen)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: Column(children: [
                  Row(children: [
                    const RoundIcon(Icons.history_rounded),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('العصور', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: C.ink(context))),
                        Text('تصفّح الشعر من العصر الجاهلي إلى الحديث', style: TextStyle(fontSize: 15, color: C.muted(context))),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(child: Container(height: 5, decoration: BoxDecoration(color: C.accent(context).withValues(alpha: 0.35 + i * 0.1), borderRadius: BorderRadius.circular(4)))),
                    ],
                  ]),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _entry(context, Icons.badge_outlined, 'الشعراء', () => push(context, Builder(builder: poetsScreen))),
                _sep(context),
                _entry(context, Icons.graphic_eq_rounded, 'البحور', () => soonSheet(context, 'البحور', 'يُضاف بحر كل بيت بعد التحقق منه، ثم تتصفّح الأبيات بحسب بحورها — قريباً بإذن الله.')),
                _sep(context),
                _entry(context, Icons.menu_book_outlined, 'الأبواب', () => push(context, const ChaptersScreen())),
                _sep(context),
                _entry(context, Icons.format_quote_rounded, 'القوافي', () => push(context, Builder(builder: rhymesScreen))),
              ]),
            ),
            Divider(height: 1, indent: 18, endIndent: 18, color: C.line(context)),
            IntrinsicHeight(
              child: Row(children: [
                _link(context, Icons.thumb_up_alt_outlined, 'الأكثر إعجاباً', () => _mostLiked(context)),
                VerticalDivider(width: 1, indent: 12, endIndent: 12, color: C.line(context)),
                _link(context, Icons.menu_book_outlined, 'الأكثر قراءة', () => _mostRead(context)),
              ]),
            ),
            Divider(height: 1, indent: 18, endIndent: 18, color: C.line(context)),
            InkWell(
              onTap: () => openList(context, 'أبيات غريبة الألفاظ', Library.ofChapter(Library.chapterNamed('أبيات غريبة الألفاظ'))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(children: [
                  Icon(Icons.translate_rounded, color: C.muted(context)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('أبيات غريبة الألفاظ', style: TextStyle(fontSize: 17, color: C.ink(context)))),
                  Icon(Icons.chevron_left_rounded, color: C.muted(context)),
                ]),
              ),
            ),
          ]),
        ),
        const ErasWheel(),
        const SectionTitle('مختارات'),
        if (Store.i.developer)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => push(context, const BrowseEditScreen()),
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: const Text('رتّب الأزرار وأخفِ ما تشاء (للمطوّر)'),
              ),
            ),
          ),
        ..._pickRows(context),
        const SectionTitle('قصائد لك'),
        TwoColumns(poems: forYou, onTap: (p) => openPoem(context, p)),
      ]),
    );
  }

  /// The buttons of «مختارات», in the order the developer chose and without what he hid.
  /// Two stand in a row; a wide one, or one left alone, takes the row.
  List<Widget> _pickRows(BuildContext context) {
    final open = <String, VoidCallback>{
      'iman': () => push(context, const ChaptersScreen(section: 0)),
      'general': () => push(context, const ChaptersScreen(section: 1)),
      'diwan': () => push(context, const DiwanScreen()),
      'book': () => openList(context, 'أبيات الكتاب', Library.bookPoems, subtitle: 'كل ما في كتاب «منتقيات شعرية»'),
      'verified': () => openList(context, 'الأبيات الموثّقة', Library.verifiedPoems, subtitle: 'ما وثّقه المطوّر بيتاً بيتاً'),
      'amthal': () => push(context, const AmthalScreen()),
      'hikam': () => push(context, const HikamScreen()),
      'quiz': () => push(context, const ProverbQuizScreen()),
      'majma': () => push(context, const MajmaScreen()),
      'stories': () => push(context, const StoriesScreen()),
      'answers': () => push(context, const AnswersScreen()),
      'majlis': () => push(context, const MajlisScreen()),
      'board': () => push(context, const LeaderboardScreen()),
      'complete': () => push(context, const GameScreen(kind: 0)),
      'whogame': () => push(context, const GameScreen(kind: 1)),
      'mutun': () => push(context, const MutunScreen()),
      'shawahid': () => push(context, const ShawahidScreen()),
      'whosaid': () => push(context, const WhoSaidScreen()),
      'books': () => push(context, const VerseBooksScreen()),
    };
    String sub(BrowsePick x) => switch (x.id) {
          'book' => 'العلامة الخضراء · ${Ar.num(Library.bookPoems.length)}',
          'verified' => 'العلامة الزرقاء · ${Ar.num(Library.verifiedPoems.length)}',
          _ => x.sub,
        };
    final list = [
      for (final x in BrowsePick.ordered())
        if (!Store.i.browseHidden.contains(x.id) && (x.id != 'books' || VerseBooksScreen.visible)) x
    ];
    Widget card(BrowsePick x) => _pick(context, x.icon, x.title, sub(x), open[x.id]!);
    final rows = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      final x = list[i];
      final pair = !x.wide && i + 1 < list.length && !list[i + 1].wide;
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: pair ? Row(children: [Expanded(child: card(x)), const SizedBox(width: 12), Expanded(child: card(list[i + 1]))]) : card(x),
      ));
      if (pair) i++;
    }
    return rows;
  }

  void _mostLiked(BuildContext context) {
    final liked = Library.poems.where((p) => Store.i.liked(p.id)).toList();
    openList(context, 'الأكثر إعجاباً', liked.isEmpty ? Library.dailyPicks(16, salt: 5) : liked,
        subtitle: liked.isEmpty ? 'لم تُعجَب بشيء بعد — هذه مختارات لك' : 'ما أعجبك على هذا الجهاز');
  }

  void _mostRead(BuildContext context) {
    final r = Store.i.reads.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final list = [for (final e in r) if (Library.byId[e.key] != null) Library.byId[e.key]!];
    openList(context, 'الأكثر قراءة', list.isEmpty ? Library.dailyPicks(16, salt: 9) : list,
        subtitle: list.isEmpty ? 'لم تقرأ شيئاً بعد — هذه مختارات لك' : 'أكثر ما قرأته على هذا الجهاز');
  }

  Widget _sep(BuildContext context) => Container(width: 1, height: 70, color: C.line(context));

  Widget _entry(BuildContext context, IconData icon, String label, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              RoundIcon(icon, size: 54),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
            ]),
          ),
        ),
      );

  Widget _link(BuildContext context, IconData icon, String label, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: C.accent(context), size: 22),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 16.5, color: C.ink(context))),
              Icon(Icons.chevron_left_rounded, color: C.muted(context), size: 20),
            ]),
          ),
        ),
      );

  Widget _pick(BuildContext context, IconData icon, String title, String sub, VoidCallback onTap) => SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          RoundIcon(icon, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
              Text(sub, style: TextStyle(fontSize: 13.5, color: C.muted(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}

/// «دائرة العصور»: the eras set around one big circle. The middle opens them all, each small circle opens its own era.
class ErasWheel extends StatefulWidget {
  const ErasWheel({super.key});
  @override
  State<ErasWheel> createState() => _ErasWheelState();
}

class _ErasWheelState extends State<ErasWheel> with SingleTickerProviderStateMixin {
  // A green line goes round the wheel without hurry: about four seconds for each era.
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final have = <String>{
      for (final p in Library.wide)
        if (p.era.isNotEmpty) p.era,
    };
    final eras = [
      for (final e in Library.eras)
        if (have.contains(e)) e,
    ];
    if (eras.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(children: [
        Center(
        child: LayoutBuilder(builder: (context, box) {
          final size = math.min(box.maxWidth, 340.0);
          final d = size * 0.2; // one era's circle
          final r = (size - d) / 2; // where the eras sit
          final mid = size * 0.36;
          return SizedBox(
            width: size,
            height: size,
            child: Stack(children: [
              Positioned(
                left: d / 2,
                top: d / 2,
                width: size - d,
                height: size - d,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: C.card(context), border: Border.all(color: C.line(context), width: 1.5)),
                ),
              ),
              Positioned(
                left: (size - mid) / 2,
                top: (size - mid) / 2,
                width: mid,
                height: mid,
                child: _disc(
                  context,
                  fill: C.accent(context),
                  edge: C.accent(context),
                  onTap: () => push(context, const ErasJourneyScreen()),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('العصور', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: C.card(context), height: 1.3)),
                    Text('كلّها', style: TextStyle(fontSize: 13, color: C.card(context).withValues(alpha: 0.85), height: 1.3)),
                  ]),
                ),
              ),
              // From the top, turning to the left as Arabic reads: oldest era first.
              for (var i = 0; i < eras.length; i++)
                Positioned(
                  left: size / 2 - r * math.sin(2 * math.pi * i / eras.length) - d / 2,
                  top: size / 2 - r * math.cos(2 * math.pi * i / eras.length) - d / 2,
                  width: d,
                  height: d,
                  child: _disc(
                    context,
                    fill: C.soft(context),
                    edge: C.line(context),
                    onTap: () => openList(context, 'العصر: ${eras[i]}', Library.ofEra(eras[i])),
                    child: Text(
                      eras[i].replaceFirst(' ', '\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.ink(context), height: 1.25),
                    ),
                  ),
                ),
              // The moving line is only drawn over the wheel; taps pass through it.
              if (!MediaQuery.of(context).disableAnimations)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _WheelLine(_turn, eras.length, r, d, const Color(0xFF2F8F5B))),
                    ),
                  ),
                ),
            ]),
          );
        }),
        ),
        // Under the wheel, in a shade of its own: what has no known era.
        if (Library.wide.any((p) => p.era.isEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Material(
              color: const Color(0xFF2F8F5B).withValues(alpha: 0.12),
              shape: StadiumBorder(side: BorderSide(color: const Color(0xFF2F8F5B).withValues(alpha: 0.45))),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => openList(context, 'لا يُعرف عصره', Library.noEra),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.help_outline_rounded, size: 19, color: Color(0xFF2F6B4F)),
                    const SizedBox(width: 8),
                    Text('لا يُعرف عصره', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _disc(BuildContext context, {required Color fill, required Color edge, required VoidCallback onTap, required Widget child}) => Material(
        color: fill,
        shape: CircleBorder(side: BorderSide(color: edge)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      );
}


/// The line of «دائرة العصور»: it comes to an era along the big circle, goes once round
/// that era's small circle while the circle takes a little of its colour, then moves on
/// to the next era, and so round them all.
class _WheelLine extends CustomPainter {
  final Animation<double> turn;
  final int n;
  final double r, d;
  final Color color;
  _WheelLine(this.turn, this.n, this.r, this.d, this.color) : super(repaint: turn);

  @override
  void paint(Canvas canvas, Size size) {
    if (n < 2) return;
    final c = size.center(Offset.zero);
    final step = 2 * math.pi / n;
    final v = turn.value * n;
    final i = v.floor() % n;
    final t = v - v.floor();
    // Where era i sits, as an angle of the canvas (the eras go round to the left).
    double at(int k) => -math.pi / 2 - step * k;
    Offset onRing(double a) => c + Offset(math.cos(a), math.sin(a)) * r;
    // How much of the big circle one small circle covers, to each side of its middle.
    final cover = 2 * math.asin((d / 2) / (2 * r));
    final centre = onRing(at(i));
    double from(Offset p) => math.atan2(p.dy - centre.dy, p.dx - centre.dx);
    final enter = from(onRing(at(i) + cover));
    final leave = from(onRing(at(i) - cover));
    var round = (leave - enter) % (2 * math.pi);
    if (round < 0) round += 2 * math.pi;
    round += 2 * math.pi; // once fully round, then on to where it leaves
    const circling = 0.68; // the share of an era's time spent going round it
    final a = (t / circling).clamp(0.0, 1.0);
    final b = ((t - circling) / (1 - circling)).clamp(0.0, 1.0);
    final ease = Curves.easeInOut.transform(a);
    final fade = 1 - b;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // The era's circle takes the colour softly, most in the middle of its turn.
    canvas.drawCircle(centre, d / 2, Paint()..color = color.withValues(alpha: 0.16 * math.sin(math.pi * a) * fade + 0.10 * a * fade));
    canvas.drawArc(Rect.fromCircle(center: centre, radius: d / 2), enter, round * ease, false, line..color = color.withValues(alpha: fade));
    if (b > 0) {
      final go = Curves.easeInOut.transform(b);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), at(i) - cover, -(step - 2 * cover) * go, false, line..color = color.withValues(alpha: 0.35 + 0.65 * math.sin(math.pi * b)));
    }
  }

  @override
  bool shouldRepaint(_WheelLine old) => old.n != n || old.r != r || old.d != d || old.color != color;
}


/// One button of «مختارات» in «تصفّح».
class BrowsePick {
  final String id, title, sub;
  final IconData icon;
  final bool wide;
  const BrowsePick(this.id, this.icon, this.title, this.sub, {this.wide = false});

  /// As the page was first laid out.
  static const all = [
    BrowsePick('iman', Icons.auto_stories_outlined, 'أبواب الإيمان', 'والرقائق'),
    BrowsePick('general', Icons.format_list_bulleted_rounded, 'الأبواب العامة', 'حكمة وأخلاق وأدب'),
    BrowsePick('diwan', Icons.mosque_outlined, 'ديوان العلماء والصحابة', 'ابن القيم، ابن تيمية، الشافعي، الخنساء، حسان…', wide: true),
    BrowsePick('book', Icons.menu_book_rounded, 'أبيات الكتاب', 'العلامة الخضراء'),
    BrowsePick('verified', Icons.verified_rounded, 'الأبيات الموثّقة', 'العلامة الزرقاء'),
    BrowsePick('amthal', Icons.format_quote_rounded, 'أمثال من الشعر', 'أكثر من ألفَي بيت سائر'),
    BrowsePick('hikam', Icons.short_text_rounded, 'حِكَم قصيرة', 'بيت واحد لحالتك'),
    BrowsePick('quiz', Icons.quiz_rounded, 'مسابقة الأمثال', 'ثلاثة أسئلة كل يوم'),
    BrowsePick('majma', Icons.auto_stories_rounded, 'مجمع الأمثال', 'المثل وشرحه وقصته'),
    BrowsePick('stories', Icons.auto_stories_outlined, 'قصائد لها قصة', 'سبب القصيدة وخبرها'),
    BrowsePick('answers', Icons.forum_outlined, 'بيت وجوابه', 'المعارضات والنقائض بين الشعراء', wide: true),
    BrowsePick('majlis', Icons.lightbulb_outline_rounded, 'مجلس الشعر', 'تحدّي اليوم وديوانك'),
    BrowsePick('board', Icons.emoji_events_outlined, 'لوحة الصدارة', 'الأسبوع والشهر'),
    BrowsePick('complete', Icons.extension_outlined, 'أكمل البيت', 'اختر الشطر الثاني'),
    BrowsePick('whogame', Icons.person_search_outlined, 'من القائل؟', 'اعرف الشاعر'),
    BrowsePick('mutun', Icons.school_outlined, 'متون طالب العلم وقصائده', 'احفظ وراجع واختبر نفسك كتابةً', wide: true),
    BrowsePick('shawahid', Icons.format_quote_rounded, 'مما استشهد به العلماء', 'بالكتاب والصفحة'),
    BrowsePick('whosaid', Icons.manage_search_rounded, 'من قائل هذا البيت؟', 'الصق وابحث'),
    BrowsePick('books', Icons.auto_stories_outlined, 'كتب استُخرجت أشعارها', 'أولها «نهاية الأرب» للنويري', wide: true),
  ];

  /// In the developer's order; a button added to the app later keeps its first place after them.
  static List<BrowsePick> ordered() {
    final order = Store.i.browseOrder;
    if (order.isEmpty) return all;
    final by = {for (final x in all) x.id: x};
    return [
      for (final id in order)
        if (by.containsKey(id)) by[id]!,
      for (final x in all)
        if (!order.contains(x.id)) x,
    ];
  }
}

/// Developer: drag the buttons of «مختارات» into the order he wants, and switch off what he hides.
/// It reaches every reader.
class BrowseEditScreen extends StatelessWidget {
  const BrowseEditScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final list = BrowsePick.ordered();
          final hidden = Store.i.browseHidden;
          return Scaffold(
            appBar: AppBar(
              title: const Text('أزرار «تصفّح»'),
              actions: [
                TextButton(
                  onPressed: () {
                    Store.i.setBrowse(const [], const {});
                    toast(context, 'عاد الترتيب الأصلي');
                  },
                  child: const Text('الأصل'),
                ),
              ],
            ),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('اضغط على الزر مطوّلاً ثم اسحبه إلى مكانه (وعلى الحاسوب اسحبه من الخطوط)، وأطفئ المفتاح لتخفيه. يتغيّر عند كل القرّاء.', style: TextStyle(color: C.muted(context), height: 1.6)),
              ),
              Expanded(
                child: ReorderableListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  onReorder: (from, to) {
                    final ids = [for (final x in list) x.id];
                    if (to > from) to--;
                    ids.insert(to, ids.removeAt(from));
                    Store.i.setBrowse(ids, hidden);
                  },
                  children: [
                    for (final x in list)
                      SwitchListTile(
                        key: ValueKey(x.id),
                        secondary: Icon(x.icon, color: C.accent(context)),
                        title: Text(x.title),
                        value: !hidden.contains(x.id),
                        onChanged: (on) {
                          final h = {...hidden};
                          on ? h.remove(x.id) : h.add(x.id);
                          Store.i.setBrowse([for (final y in list) y.id], h);
                        },
                      ),
                  ],
                ),
              ),
            ]),
          );
        },
      );
}
