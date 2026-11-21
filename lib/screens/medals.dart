import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../ui.dart';
import 'majlis.dart';

// «الأوسمة»: real medals earned from what the reader actually did, each in
// three grades (برونزي، فضي، ذهبي), drawn as metal rosettes with ribbons.

class MedalFamily {
  final String id;
  final String name;
  final IconData icon;
  final List<int> tiers; // what each grade needs
  final String unit; // what is counted
  const MedalFamily(this.id, this.name, this.icon, this.tiers, this.unit);
}

const medalFamilies = [
  MedalFamily('own', 'الناظم', Icons.history_edu_rounded, [1, 10, 30], 'قصيدة من شعره'),
  MedalFamily('quotes', 'المقتبس', Icons.format_quote_rounded, [1, 25, 100], 'اقتباساً'),
  MedalFamily('likes', 'المحبوب', Icons.thumb_up_alt_rounded, [10, 100, 1000], 'إعجاباً على ما نشره'),
  MedalFamily('followers', 'المتبوع', Icons.groups_rounded, [10, 100, 1000], 'متابِعاً'),
  MedalFamily('memo', 'الحافظ', Icons.menu_book_rounded, [10, 100, 500], 'بيتاً حفظها'),
  MedalFamily('streak', 'المثابر', Icons.local_fire_department_rounded, [7, 30, 100], 'يوماً متتالياً'),
  MedalFamily('level', 'فارس المجلس', Icons.shield_rounded, [1, 10, 30], 'مستوى في المجلس'),
  MedalFamily('poets', 'رفيق الشعراء', Icons.person_search_rounded, [5, 20, 50], 'شاعراً يتابعه'),
  MedalFamily('old', 'الأصيل', Icons.event_available_rounded, [30, 180, 365], 'يوماً منذ انضمامه'),
];

const gradeNames = ['برونزي', 'فضي', 'ذهبي'];

/// What the reader has: family id → the number counted.
Map<String, int> medalCounts({
  required Map<String, dynamic> user,
  required int own,
  required int quotes,
  required int likes,
  required int followers,
}) {
  int n(String k) => (user[k] as num?)?.toInt() ?? 0;
  final joined = n('joined');
  return {
    'own': own,
    'quotes': quotes,
    'likes': likes,
    'followers': followers,
    'memo': n('memo'),
    'streak': max(n('streak'), n('bestStreak')),
    'level': Majlis.levelOf(n('points')),
    'poets': n('poets'),
    'old': joined == 0 ? 0 : DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(joined)).inDays,
  };
}

/// The grade reached: -1 none, 0 bronze, 1 silver, 2 gold.
int gradeOf(MedalFamily f, int count) {
  var g = -1;
  for (var i = 0; i < f.tiers.length; i++) {
    if (count >= f.tiers[i]) g = i;
  }
  return g;
}

int medalsEarned(Map<String, int> counts) => medalFamilies.fold(0, (a, f) => a + gradeOf(f, counts[f.id] ?? 0) + 1);
int get medalsTotal => medalFamilies.length * 3;

// ------------------------------------------------------------ the drawing

class Medal extends StatelessWidget {
  final IconData icon;
  final int grade; // -1 locked
  final double size;
  const Medal({super.key, required this.icon, required this.grade, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final locked = grade < 0;
    return SizedBox(
      width: size,
      height: size * 1.32,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _MedalPainter(grade))),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: size,
          child: Center(
            child: Icon(icon,
                size: size * 0.36,
                color: locked ? Colors.white.withValues(alpha: 0.75) : Colors.white,
                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: size * 0.05, offset: Offset(0, size * 0.02))]),
          ),
        ),
        if (locked)
          Positioned(
            top: size * 0.62,
            right: size * 0.12,
            child: Container(
              padding: EdgeInsets.all(size * 0.04),
              decoration: BoxDecoration(color: const Color(0xFF5E5A54), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1)),
              child: Icon(Icons.lock_rounded, size: size * 0.15, color: Colors.white),
            ),
          ),
      ]),
    );
  }
}

class _MedalPainter extends CustomPainter {
  final int grade;
  _MedalPainter(this.grade);

  static const metals = [
    [Color(0xFFF6D2AE), Color(0xFFC27A43), Color(0xFF7A4521)], // bronze
    [Color(0xFFFFFFFF), Color(0xFFBFC6CF), Color(0xFF6E7782)], // silver
    [Color(0xFFFFF4C4), Color(0xFFE2B14A), Color(0xFF8A5E12)], // gold
    [Color(0xFFD9D5CF), Color(0xFFA29C93), Color(0xFF6B665F)], // locked
  ];
  static const ribbons = [
    [Color(0xFF8C2F24), Color(0xFFD9B26A)],
    [Color(0xFF23395B), Color(0xFFE8ECF2)],
    [Color(0xFF2F6B4F), Color(0xFFF2D98A)],
    [Color(0xFF8E8880), Color(0xFFCFCAC2)],
  ];

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final m = metals[grade < 0 ? 3 : grade];
    final rb = ribbons[grade < 0 ? 3 : grade];
    final c = Offset(w / 2, w / 2);
    final r = w * 0.44;

    // ribbons: two tails with a notch, a light stripe down the middle
    for (final side in [-1.0, 1.0]) {
      final x0 = c.dx + side * w * 0.05;
      final x1 = c.dx + side * w * 0.36;
      final top = c.dy + r * 0.3;
      final bottom = s.height;
      final tail = Path()
        ..moveTo(x0 - side * w * 0.12, top)
        ..lineTo(x0 + side * w * 0.12, top)
        ..lineTo(x1 + side * w * 0.02, bottom)
        ..lineTo((x0 + x1) / 2 + side * w * 0.02, bottom - w * 0.1)
        ..lineTo(x1 - side * w * 0.2, bottom)
        ..close();
      canvas.drawPath(tail, Paint()..color = rb[0]);
      final stripe = Path()
        ..moveTo(x0 - side * w * 0.02, top)
        ..lineTo(x0 + side * w * 0.03, top)
        ..lineTo(x1 - side * w * 0.07, bottom - w * 0.04)
        ..lineTo(x1 - side * w * 0.11, bottom - w * 0.04)
        ..close();
      canvas.drawPath(stripe, Paint()..color = rb[1].withValues(alpha: 0.85));
    }

    // a soft shadow under the rosette
    canvas.drawCircle(c.translate(0, w * 0.03), r, Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04));

    // the scalloped rosette
    final rosette = Path();
    const lobes = 18;
    for (var i = 0; i <= 360; i++) {
      final a = i * pi / 180;
      final rr = r * (0.93 + 0.07 * cos(lobes * a));
      final p = c + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? rosette.moveTo(p.dx, p.dy) : rosette.lineTo(p.dx, p.dy);
    }
    rosette.close();
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawPath(rosette, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: m).createShader(rect));
    canvas.drawPath(rosette, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, w * 0.012)
      ..color = m[2]);

    // the inner disc, lit from the other side so it looks struck in metal
    final ri = r * 0.7;
    final inner = Rect.fromCircle(center: c, radius: ri);
    canvas.drawCircle(c, ri, Paint()..shader = LinearGradient(begin: Alignment.bottomRight, end: Alignment.topLeft, colors: [m[0], m[1], m[2]]).createShader(inner));
    canvas.drawCircle(c, ri, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, w * 0.02)
      ..color = m[0].withValues(alpha: 0.9));
    canvas.drawCircle(c, ri * 0.86, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, w * 0.008)
      ..color = m[2].withValues(alpha: 0.7));
    // little beads around the inner ring
    final bead = Paint()..color = m[0].withValues(alpha: 0.9);
    for (var i = 0; i < 24; i++) {
      final a = i * 2 * pi / 24;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * (ri * 0.93), max(0.5, w * 0.008), bead);
    }
    // a shine across the top
    canvas.save();
    canvas.clipPath(rosette);
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(-r * 0.25, -r * 0.45), width: r * 1.2, height: r * 0.5),
        Paint()
          ..color = Colors.white.withValues(alpha: grade < 0 ? 0.08 : 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MedalPainter old) => old.grade != grade;
}

// ------------------------------------------------------------ the row on the page

class MedalsRow extends StatelessWidget {
  final Map<String, int> counts;
  final String name;
  const MedalsRow({super.key, required this.counts, required this.name});

  @override
  Widget build(BuildContext context) {
    final earned = [
      for (final f in medalFamilies)
        if (gradeOf(f, counts[f.id] ?? 0) >= 0) (f, gradeOf(f, counts[f.id] ?? 0))
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final n = medalsEarned(counts);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MedalsScreen(counts: counts, name: name))),
      child: Row(children: [
        Expanded(
          child: earned.isEmpty
              ? Text('لم ينل وساماً بعد', style: TextStyle(color: C.muted(context)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final (f, g) in earned.take(8))
                      Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: Medal(icon: f.icon, grade: g, size: 36)),
                  ]),
                ),
        ),
        const SizedBox(width: 8),
        Text('${Ar.num(n)} وساماً', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.accent(context))),
        Icon(Icons.chevron_left_rounded, color: C.accent(context)),
      ]),
    );
  }
}

// ------------------------------------------------------------ all the medals

class MedalsScreen extends StatelessWidget {
  final Map<String, int> counts;
  final String name;
  const MedalsScreen({super.key, required this.counts, required this.name});

  @override
  Widget build(BuildContext context) {
    final n = medalsEarned(counts);
    return Scaffold(
      appBar: AppBar(title: Text('أوسمة $name')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        SoftCard(
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var g = 0; g < 3; g++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(children: [
                    Medal(icon: Icons.star_rounded, grade: g, size: 48),
                    Text('${Ar.num(_gradeCount(g))} ${gradeNames[g]}', style: TextStyle(fontSize: 13, color: C.muted(context))),
                  ]),
                ),
            ]),
            const SizedBox(height: 10),
            Text('${Ar.num(n)} وساماً من ${Ar.num(medalsTotal)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: n / medalsTotal, minHeight: 8, backgroundColor: C.soft(context), color: const Color(0xFFB08A3E)),
            ),
            const SizedBox(height: 8),
            Text('لكل وسام ثلاث درجات: برونزي ثم فضي ثم ذهبي. تُنال بالعمل، لا تُشترى ولا تُهدى.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.6, color: C.muted(context))),
          ]),
        ),
        const SizedBox(height: 12),
        for (final f in medalFamilies) _card(context, f),
      ]),
    );
  }

  int _gradeCount(int g) => medalFamilies.where((f) => gradeOf(f, counts[f.id] ?? 0) >= g).length;

  Widget _card(BuildContext context, MedalFamily f) {
    final have = counts[f.id] ?? 0;
    final g = gradeOf(f, have);
    final next = g + 1 < f.tiers.length ? f.tiers[g + 1] : null;
    final prev = g < 0 ? 0 : f.tiers[g];
    final p = next == null ? 1.0 : ((have - prev) / (next - prev)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Medal(icon: f.icon, grade: g, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(f.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
                const SizedBox(width: 8),
                if (g >= 0) Text(gradeNames[g], style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _gradeColor(g))),
              ]),
              const SizedBox(height: 2),
              Text(
                next == null ? 'نال الدرجة الذهبية: ${Ar.num(have)} ${f.unit}.' : 'الدرجة ${gradeNames[g + 1]}: ${Ar.num(next)} ${f.unit} (لديه ${Ar.num(have)})',
                style: TextStyle(fontSize: 13.5, height: 1.5, color: C.muted(context)),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: p, minHeight: 6, backgroundColor: C.soft(context), color: g < 0 ? C.muted(context) : _gradeColor(g)),
              ),
              const SizedBox(height: 6),
              Row(children: [
                for (var i = 0; i < 3; i++) ...[
                  Icon(Icons.circle, size: 9, color: i <= g ? _gradeColor(i) : C.line(context)),
                  const SizedBox(width: 3),
                  Text(Ar.num(f.tiers[i]), style: TextStyle(fontSize: 12, color: C.muted(context))),
                  const SizedBox(width: 10),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  static Color _gradeColor(int g) => const [Color(0xFFA8642F), Color(0xFF7D8590), Color(0xFFB08A3E)][g.clamp(0, 2)];
}
