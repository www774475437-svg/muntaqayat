import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'lists.dart';
import 'majlis.dart';

/// The result of a round as a geometric figure: it fills as the score rises.
/// Every round has its own figure (the seed changes the petals and the style).
class ShapeBadge extends StatelessWidget {
  final double size, fraction;
  final int seed;
  final Color? color;
  const ShapeBadge({super.key, required this.size, required this.fraction, this.seed = 0, this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _ShapePainter(fraction.clamp(0, 1).toDouble(), seed.abs(), color ?? Majlis.gold, C.line(context))),
      );
}

class _ShapePainter extends CustomPainter {
  final double f;
  final int seed;
  final Color on, off;
  _ShapePainter(this.f, this.seed, this.on, this.off);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero), r = s.width / 2;
    final k = 6 + seed % 7; // 6…12 petals
    final style = (seed ~/ 7) % 3;
    final filled = (f * k).round();
    final fill = Paint()..color = on;
    final soft = Paint()..color = on.withValues(alpha: 0.18);
    final line = Paint()
      ..color = off
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, r * 0.035);
    final edge = Paint()
      ..color = on
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, r * 0.035);
    for (var i = 0; i < k; i++) {
      final a = -pi / 2 + 2 * pi * i / k, w = pi / k;
      final done = i < filled;
      final Path p;
      if (style == 0) {
        // pointed petals
        p = Path()
          ..moveTo(c.dx + r * 0.22 * cos(a), c.dy + r * 0.22 * sin(a))
          ..quadraticBezierTo(c.dx + r * 0.7 * cos(a - w), c.dy + r * 0.7 * sin(a - w), c.dx + r * 0.96 * cos(a), c.dy + r * 0.96 * sin(a))
          ..quadraticBezierTo(c.dx + r * 0.7 * cos(a + w), c.dy + r * 0.7 * sin(a + w), c.dx + r * 0.22 * cos(a), c.dy + r * 0.22 * sin(a));
      } else if (style == 1) {
        // a ring of circles
        final rr = r * sin(w) * 0.62;
        p = Path()..addOval(Rect.fromCircle(center: Offset(c.dx + (r - rr - 1) * cos(a), c.dy + (r - rr - 1) * sin(a)), radius: rr));
      } else {
        // diamonds
        final m = r * 0.6;
        p = Path()
          ..moveTo(c.dx + r * 0.25 * cos(a), c.dy + r * 0.25 * sin(a))
          ..lineTo(c.dx + m * cos(a - w * 0.8), c.dy + m * sin(a - w * 0.8))
          ..lineTo(c.dx + r * 0.96 * cos(a), c.dy + r * 0.96 * sin(a))
          ..lineTo(c.dx + m * cos(a + w * 0.8), c.dy + m * sin(a + w * 0.8))
          ..close();
      }
      if (done) {
        canvas.drawPath(p, fill);
      } else {
        canvas.drawPath(p, soft);
        canvas.drawPath(p, line);
      }
    }
    canvas.drawCircle(c, r * 0.17, filled == k ? fill : soft);
    canvas.drawCircle(c, r * 0.17, edge);
  }

  @override
  bool shouldRepaint(_ShapePainter o) => o.f != f || o.seed != seed || o.on != on;
}

/// The rank and level beside a name, like the big games.
class RankBadge extends StatelessWidget {
  final int xp;
  final bool small;
  const RankBadge(this.xp, {super.key, this.small = false});
  @override
  Widget build(BuildContext context) {
    final l = Majlis.levelOf(xp), i = Majlis.rankIndex(l), col = Majlis.rankColors[i];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 10, vertical: small ? 2 : 4),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: col, width: 1.2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shield_rounded, size: small ? 12 : 15, color: col),
        const SizedBox(width: 4),
        Text('${Majlis.rankNames[i]} ${Ar.num(l)}', style: TextStyle(fontSize: small ? 11.5 : 13.5, fontWeight: FontWeight.w700, color: col)),
      ]),
    );
  }
}

// ------------------------------------------------------------ achievements

class Achievement {
  final String title, desc;
  final int tier; // 0 easy, 1 medium, 2 hard
  final int now, target;
  final IconData icon;
  const Achievement(this.title, this.desc, this.tier, this.now, this.target, this.icon);
  bool get done => now >= target;
}

List<Achievement> achievements() {
  final st = Majlis.st;
  int n(String k) => (st[k] as num?)?.toInt() ?? 0;
  final rounds = n('rounds'), perfect = n('perfect'), full = n('fullDays'), weekly = n('weekly'), friday = n('friday'), wins = n('duelWins');
  final best = max(n('bestStreak'), Majlis.streak), level = Majlis.levelOf(Majlis.total);
  final poets = (st['poets'] as List? ?? []).length;
  final memo = Store.i.memorized.values.fold<int>(0, (a, b) => a + b.length);
  return [
    Achievement('أول الغيث', 'أتمّ جولتك الأولى', 0, rounds, 1, Icons.water_drop_outlined),
    Achievement('بلا خطأ', 'أتمّ جولة كاملة بلا أي خطأ', 0, perfect, 1, Icons.check_circle_outline_rounded),
    Achievement('ثلاثة أيام', 'العب ثلاثة أيام متتالية', 0, best, 3, Icons.local_fire_department_outlined),
    Achievement('جليس المجلس', 'أتمّ خمسين جولة', 0, rounds, 50, Icons.event_seat_outlined),
    Achievement('البرونزي', 'ابلغ المستوى الأول', 0, level, 1, Icons.shield_outlined),
    Achievement('أسبوع كامل', 'العب سبعة أيام متتالية', 1, best, 7, Icons.local_fire_department_rounded),
    Achievement('اليوم التامّ', 'أتمّ الجولات العشر في يوم واحد', 1, full, 1, Icons.done_all_rounded),
    Achievement('المتقن', 'عشر جولات بلا خطأ', 1, perfect, 10, Icons.verified_outlined),
    Achievement('راوية الشعراء', 'أصب في أبيات عشرين شاعراً', 1, poets, 20, Icons.groups_outlined),
    Achievement('شاعر الأسبوع', 'أتمّ جولة شاعر الأسبوع', 1, weekly, 1, Icons.star_outline_rounded),
    Achievement('جمعة مباركة', 'العب جولة يوم الجمعة', 1, friday, 1, Icons.wb_sunny_outlined),
    Achievement('الفضي', 'ابلغ المستوى العاشر', 1, level, 10, Icons.shield_rounded),
    Achievement('الغالب', 'افز على صديق في مبارزة', 1, wins, 1, Icons.sports_kabaddi_rounded),
    Achievement('حافظ المئة', 'احفظ مئة بيت من المتون', 1, memo, 100, Icons.bookmark_added_outlined),
    Achievement('شهر لا ينقطع', 'العب ثلاثين يوماً متتالية', 2, best, 30, Icons.whatshot_rounded),
    Achievement('ألف جولة', 'أتمّ ألف جولة', 2, rounds, 1000, Icons.all_inclusive_rounded),
    Achievement('مئة بلا خطأ', 'مئة جولة بلا خطأ', 2, perfect, 100, Icons.workspace_premium_outlined),
    Achievement('خمسون شاعراً', 'أصب في أبيات خمسين شاعراً', 2, poets, 50, Icons.diversity_3_rounded),
    Achievement('عشرة أسابيع', 'أتمّ جولة شاعر الأسبوع عشر مرات', 2, weekly, 10, Icons.star_rounded),
    Achievement('فارس المبارزة', 'افز في عشرين مبارزة', 2, wins, 20, Icons.military_tech_outlined),
    Achievement('الراوي', 'ابلغ المستوى الخمسين', 2, level, 50, Icons.military_tech_rounded),
    Achievement('سنة في المجلس', 'العب ٣٦٥ يوماً متتالية', 2, best, 365, Icons.calendar_month_rounded),
    Achievement('أمير المجلس', 'ابلغ المستوى المئة', 2, level, 100, Icons.emoji_events_rounded),
  ];
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});
  static const tiers = ['سهلة', 'متوسطة', 'صعبة'];
  static const tierColors = [Color(0xFFA9714B), Color(0xFF8E9AA6), Majlis.gold];
  @override
  Widget build(BuildContext context) {
    final all = achievements();
    final got = all.where((a) => a.done).length;
    return Scaffold(
      appBar: AppBar(title: const Text('الأوسمة والإنجازات')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        Text('نلت ${Ar.num(got)} من ${Ar.num(all.length)} وساماً.', style: TextStyle(color: C.muted(context))),
        for (var t = 0; t < 3; t++) ...[
          SectionTitle('إنجازات ${tiers[t]}'),
          for (final a in all.where((a) => a.tier == t))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: a.done ? tierColors[t].withValues(alpha: 0.18) : C.soft(context),
                      border: Border.all(color: a.done ? tierColors[t] : C.line(context), width: 1.6),
                    ),
                    child: Icon(a.icon, color: a.done ? tierColors[t] : C.muted(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context))),
                      Text(a.desc, style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: (a.now / a.target).clamp(0, 1).toDouble(), minHeight: 6, borderRadius: BorderRadius.circular(4), color: tierColors[t]),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  a.done
                      ? Icon(Icons.check_circle_rounded, color: tierColors[t])
                      : Text('${Ar.num(min(a.now, a.target))}/${Ar.num(a.target)}', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------ mistakes

/// «أخطائي»: the verses the reader missed, to practise again.
class MistakesScreen extends StatelessWidget {
  const MistakesScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final items = Majlis.mistakes;
          return Scaffold(
            appBar: AppBar(title: const Text('أخطائي')),
            body: items.isEmpty
                ? const EmptyNote(Icons.task_alt_rounded, 'لا أخطاء الآن. كل بيت تخطئ فيه يُجمع هنا لتتدرب عليه.')
                : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
                    Text('أبيات أخطأت فيها. إذا أصبت في البيت في جولة قادمة خرج من القائمة.', style: TextStyle(color: C.muted(context), height: 1.6)),
                    const SizedBox(height: 10),
                    if (items.length >= 5)
                      FilledButton.icon(
                        onPressed: () => push(context, ChallengeScreen(picks: (List.of(items)..shuffle()).take(5).toList())),
                        icon: const Icon(Icons.fitness_center_rounded),
                        label: const Text('تدرّب على خمسة منها (بلا نقاط)'),
                      ),
                    const SizedBox(height: 10),
                    for (final (p, i) in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SoftCard(
                          padding: const EdgeInsets.all(12),
                          onTap: () => openPoem(context, p),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            VerseLines(p.lines[i], size: 19),
                            Text('${p.poet} · ${p.chapterName}', style: TextStyle(fontSize: 13, color: C.accent(context))),
                          ]),
                        ),
                      ),
                  ]),
          );
        },
      );
}

// ------------------------------------------------------------ guide

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget part(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: Majlis.gold),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
              ]),
              const SizedBox(height: 6),
              Text(body, style: TextStyle(fontSize: 15.5, height: 1.8, color: C.ink(context))),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('تعليمات المجلس')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        part(Icons.flag_outlined, 'الجولة',
            'لك عشر جولات في اليوم. كل جولة خمس مراحل، ولكل مرحلة بيت جديد لا يتكرر حتى تنتهي أبيات التطبيق كلها.\n\n• اللمحة: ترى البيت ثوانيَ ثم ترتّب كلماته. لك فيها ثلاث محاولات.\n• أكمل الشطر، القافية، في أي باب، من القائل: محاولة واحدة فقط.'),
        part(Icons.calculate_outlined, 'النقاط',
            'الجولة التامّة مئة نقطة: عشرون لكل مرحلة.\n\n• اللمحة: ٢٠ من أول محاولة، ١٤ من الثانية، ٨ من الثالثة.\n• بقية المراحل: ١٨ للصواب، ونقطتان زائدتان إن أجبت في أقل من سبع ثوانٍ (مكافأة السرعة).\n• التلميح ينقص ما تأخذه من المرحلة.\n• الخطأ في مراحل المحاولة الواحدة ينقص خمس نقاط من الجولة.'),
        part(Icons.shield_outlined, 'المستويات والرتب',
            'مئة مستوى تُفتح بنقاطك المتراكمة، وكل مستوى أبعد من الذي قبله: الأول ١٠٠ نقطة، الثاني ٣٠٠، الثالث ٦٠٠، العاشر ٥٬٥٠٠، الخمسون ١٢٧٬٥٠٠، والمئة ٥٠٥٬٠٠٠. من واظب بلغ المئة في سنة إلى ثلاث.\n\nوكل عشرة مستويات رتبة: برونزي، فضي، ذهبي، بلاتيني، ماسي، راوٍ، حافظ، أديب، علّامة، شيخ المجلس، ثم «أمير المجلس» عند المئة. وتظهر رتبتك بجانب اسمك في الصدارة وصفحتك. وكلما علا مستواك قصرت مهلة اللمحة.'),
        part(Icons.local_fire_department_outlined, 'مكافأة المواظبة',
            'كل يوم متتالٍ تلعبه يزيد نقاط جولاتك ٢٪، حتى ٣٠٪ عند خمسة عشر يوماً. فإن انقطعت يوماً رجعت الزيادة إلى أولها.'),
        part(Icons.task_alt_rounded, 'المهام اليومية',
            'ثلاث مهام تتجدد كل يوم: العب ثلاث جولات (٣٠ نقطة)، أتمّ جولة بلا خطأ (٤٠ نقطة)، أتمّ الجولات العشر (١٠٠ نقطة). تُضاف جائزتها تلقائياً.'),
        part(Icons.star_outline_rounded, 'شاعر الأسبوع وجولة الجمعة',
            'كل أسبوع شاعر، وله جولة خاصة من شعره مرة في الأسبوع بنقاط مضاعفة. وجولات يوم الجمعة كلها مضاعفة.'),
        part(Icons.emoji_events_outlined, 'الصدارة والموسم',
            'لوحة الصدارة لأعلى عشرين: للأسبوع (يبدأ السبت)، وللموسم (يبدأ أول كل شهر من الصفر)، ومنذ البداية. مستواك لا ينقص بانتهاء الموسم. يدخل اللوحة من دخل بحسابه.'),
        part(Icons.sports_kabaddi_rounded, 'المبارزة',
            'افتح صفحة صديق برقمه الشخصي واضغط «بارزه». تلعبان الأبيات الخمسة نفسها، والأعلى نقاطاً يفوز. نتيجتها في «المبارزات».'),
        part(Icons.military_tech_outlined, 'الأوسمة',
            'إنجازات سهلة ومتوسطة وصعبة: للمواظبة، وللجولات بلا خطأ، ولبلوغ المستويات، وللفوز في المبارزة. تراها في «الأوسمة والإنجازات» ومعها تقدّمك في كل واحد.'),
        part(Icons.refresh_rounded, 'أخطائي والتدريب',
            'كل بيت تخطئ فيه يُجمع في «أخطائي» لتتدرب عليه. وجولة التدريب متاحة متى شئت بلا نقاط.'),
      ]),
    );
  }
}
