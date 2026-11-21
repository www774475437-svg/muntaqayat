import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'data.dart';

/// Colours of «منتقيات الشعر»: warm paper with a terracotta ink.
class C {
  static bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color bg(BuildContext c) => dark(c) ? const Color(0xFF15130F) : const Color(0xFFF7F4EE);
  static Color card(BuildContext c) => dark(c) ? const Color(0xFF201D18) : const Color(0xFFF0ECE4);
  static Color line(BuildContext c) => dark(c) ? const Color(0xFF332E27) : const Color(0xFFE0D9CC);
  static Color ink(BuildContext c) => dark(c) ? const Color(0xFFEDE6DA) : const Color(0xFF1E1B16);
  static Color muted(BuildContext c) => dark(c) ? const Color(0xFFA39A8C) : const Color(0xFF7B746A);
  static Color accent(BuildContext c) => dark(c) ? const Color(0xFFD9956A) : const Color(0xFF8C4A2F);
  static Color soft(BuildContext c) => dark(c) ? const Color(0xFF2C2620) : const Color(0xFFE6DED2);
  static Color bar(BuildContext c) => dark(c) ? const Color(0xFF26221C) : const Color(0xFFFCFBF8);
}

const verseFont = 'Amiri';
const uiFont = 'Tajawal';

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final accent = dark ? const Color(0xFFD9956A) : const Color(0xFF8C4A2F);
  final bg = dark ? const Color(0xFF15130F) : const Color(0xFFF7F4EE);
  final ink = dark ? const Color(0xFFEDE6DA) : const Color(0xFF1E1B16);
  return ThemeData(
    brightness: b,
    useMaterial3: true,
    fontFamily: uiFont,
    scaffoldBackgroundColor: bg,
    // a swipe from the edge closes a page (on Android too), so leaving a page needs no arrow
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: b, surface: bg, primary: accent),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: uiFont, fontSize: 21, fontWeight: FontWeight.w700, color: ink),
    ),
    textTheme: Typography.material2021().black.apply(fontFamily: uiFont, bodyColor: ink, displayColor: ink),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2F6B4F) : const Color(0xFF2F6B4F),
      contentTextStyle: const TextStyle(fontFamily: uiFont, color: Colors.white, fontSize: 15),
    ),
  );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}

/// Section title like «بيت اليوم» / «قد يعجبك», with an optional «المزيد».
class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const SectionTitle(this.title, {super.key, this.onMore});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
      child: Row(children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: C.ink(context)))),
        if (onMore != null)
          InkWell(
            onTap: onMore,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('المزيد', style: TextStyle(fontSize: 17, color: C.accent(context))),
                Icon(Icons.chevron_left_rounded, color: C.accent(context), size: 22),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// A soft rounded card with a thin border.
class SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;
  const SoftCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(18), this.margin = EdgeInsets.zero});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: C.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: BorderSide(color: C.line(context))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Round grey circle with an icon (like the reference design).
class RoundIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  const RoundIcon(this.icon, {super.key, this.size = 52});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: C.soft(context), shape: BoxShape.circle),
      child: Icon(icon, color: C.accent(context), size: size * 0.48),
    );
  }
}

class Avatar extends StatelessWidget {
  final String letter;
  final double size;
  const Avatar(this.letter, {super.key, this.size = 50});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: C.soft(context), shape: BoxShape.circle),
      child: Text(letter, style: TextStyle(fontFamily: verseFont, fontSize: size * 0.42, color: C.accent(context), height: 1.2)),
    );
  }
}

/// One verse: first hemistich from the right, second slightly indented.
class VerseLines extends StatelessWidget {
  final List<String> line;
  final double size;
  final int? number;
  final Color? color;
  const VerseLines(this.line, {super.key, this.size = 24, this.number, this.color});
  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontFamily: verseFont, fontSize: size * Store.i.fontScale, height: 1.9, color: color ?? C.ink(context));
    final show = Store.i.show;
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(show(line[0]), style: st, textAlign: line.length == 1 ? TextAlign.center : TextAlign.start),
      if (line.length > 1)
        Padding(
          padding: EdgeInsetsDirectional.only(start: size * 1.6),
          child: Text(show(line[1]), style: st, textAlign: TextAlign.start),
        ),
    ]);
    if (number == null) return body;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 30,
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.55),
          child: Text(Ar.num(number!), style: TextStyle(fontSize: 14, color: C.muted(context))),
        ),
      ),
      Expanded(child: body),
    ]);
  }
}

/// The card used in lists and grids: first verse + poet + details.
/// The red marks shown at the bottom of cards: «بلا تشكيل» when the text has no harakat, plus the poem's own flags.
List<String> cardMarks(Poem p) {
  final text = p.lines.expand((l) => l).join(' ');
  final noHarakat = !RegExp('[\u064B-\u0652]').hasMatch(text);
  return [if (noHarakat) 'بلا تشكيل', ...p.flags];
}

class MarkChips extends StatelessWidget {
  final List<String> marks;
  const MarkChips(this.marks, {super.key});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final m in marks)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0x1AB3261E), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFB3261E))),
            child: Text(m, style: const TextStyle(fontSize: 12, color: Color(0xFFB3261E), fontWeight: FontWeight.w700)),
          ),
      ]);
}

class PoemCard extends StatelessWidget {
  final Poem poem;
  final VoidCallback onTap;
  final bool compact;
  final double? width;
  const PoemCard({super.key, required this.poem, required this.onTap, this.compact = false, this.width});
  @override
  Widget build(BuildContext context) {
    final v = poem.firstVerse;
    final size = compact ? 17.0 : 20.0;
    final meta = [
      if (poem.era.isNotEmpty) poem.era,
      Ar.verses(poem.verseCount),
    ].join(' · ');
    return SizedBox(
      width: width,
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(Store.i.show(v[0]), style: TextStyle(fontFamily: verseFont, fontSize: size, height: 1.8, color: C.ink(context)),
              maxLines: width != null ? 1 : 2, overflow: TextOverflow.ellipsis),
          if (v.length > 1)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 18),
              child: Text(Store.i.show(v[1]), style: TextStyle(fontFamily: verseFont, fontSize: size, height: 1.8, color: C.ink(context)),
                  maxLines: width != null ? 1 : 2, overflow: TextOverflow.ellipsis),
            ),
          Divider(height: 24, color: C.line(context)),
          Text(poem.poet, style: TextStyle(fontSize: compact ? 15 : 17, fontWeight: FontWeight.w700, color: C.ink(context)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(meta, style: TextStyle(fontSize: 13.5, color: C.muted(context))),
          const SizedBox(height: 2),
          Text(poem.chapterName, style: TextStyle(fontSize: 13.5, color: C.accent(context), fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (cardMarks(poem).isNotEmpty) ...[
            const SizedBox(height: 8),
            MarkChips(cardMarks(poem)),
          ],
        ]),
      ),
    );
  }
}

/// Two columns of cards (a light masonry look).
class TwoColumns extends StatelessWidget {
  final List<Poem> poems;
  final void Function(Poem) onTap;
  const TwoColumns({super.key, required this.poems, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final a = <Widget>[], b = <Widget>[];
    for (var i = 0; i < poems.length; i++) {
      final w = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PoemCard(poem: poems[i], compact: true, onTap: () => onTap(poems[i])),
      );
      (i.isEven ? a : b).add(w);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: a)),
        const SizedBox(width: 12),
        Expanded(child: Column(children: b)),
      ]),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyNote(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Column(children: [
        RoundIcon(icon, size: 70),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: C.muted(context), height: 1.6)),
      ]),
    );
  }
}

/// Approximate Hijri date (arithmetic calendar).
class Hijri {
  static const months = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];
  static const gMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static const weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  /// The day's name, then the Hijri and the Gregorian date.
  static String full([DateTime? at]) {
    final d = at ?? DateTime.now();
    final (hy, hm, hd) = parts(d);
    return '${weekdays[d.weekday - 1]} · ${Ar.num(hd)} ${months[(hm - 1).clamp(0, 11)]} ${Ar.num(hy)} هـ · ${Ar.num(d.day)} ${gMonths[d.month - 1]} ${Ar.num(d.year)}';
  }

  /// (year, month 1–12, day) in the Hijri calendar.
  static (int, int, int) parts([DateTime? at]) {
    final d = at ?? DateTime.now();
    final a = (14 - d.month) ~/ 12;
    final y = d.year + 4800 - a;
    final m = d.month + 12 * a - 3;
    final jd = d.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
    final hm = (24 * l) ~/ 709;
    final hd = l - (709 * hm) ~/ 24;
    return (30 * n + j - 30, hm, hd);
  }

  static String today() {
    final d = DateTime.now();
    final a = (14 - d.month) ~/ 12;
    final y = d.year + 4800 - a;
    final m = d.month + 12 * a - 3;
    final jd = d.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
    final hm = (24 * l) ~/ 709;
    final hd = l - (709 * hm) ~/ 24;
    final hy = 30 * n + j - 30;
    return '${Ar.num(hd)} ${months[(hm - 1).clamp(0, 11)]} ${Ar.num(hy)} هـ · ${Ar.num(d.day)} ${gMonths[d.month - 1]} ${Ar.num(d.year)}';
  }
}

/// The small round mark with the app's name.
class AppMark extends StatelessWidget {
  final double size;
  final Color? color;
  const AppMark({super.key, this.size = 30, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? C.muted(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 1)),
      child: Text('منتقيات\nالشعر', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontSize: size * 0.22, height: 1.2, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

/// «ثابت النسبة» (green) or «يُنسب» (amber).
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final ok = status == 'ثابت';
    final c = ok ? const Color(0xFF2F6B4F) : const Color(0xFFB7791F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ok ? Icons.verified_rounded : Icons.help_outline_rounded, size: 15, color: c),
        const SizedBox(width: 4),
        Text(ok ? 'ثابت النسبة' : 'يُنسب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  const Tag(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: C.soft(context), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 13, color: C.muted(context))),
      );
}

/// Developer-only «توثيق» mark (nobody else sees it).
class VerifyButton extends StatelessWidget {
  final String keyName;
  final String what;
  const VerifyButton(this.keyName, {super.key, this.what = ''});
  @override
  Widget build(BuildContext context) {
    final ok = Store.i.isVerified(keyName);
    return IconButton(
      tooltip: ok ? 'موثّق — اضغط للإلغاء' : 'توثيق $what',
      visualDensity: VisualDensity.compact,
      onPressed: () {
        Store.i.toggleVerified(keyName);
        toast(context, ok ? 'أُلغي التوثيق' : 'تمّ توثيق $what ✓');
      },
      icon: Icon(ok ? Icons.verified_rounded : Icons.verified_outlined, size: 20, color: ok ? verifiedBlue : Colors.orange.shade700),
    );
  }
}

/// Blue = verified by the developer. Green = from the book.
const verifiedBlue = Color(0xFF1D7BD8);
const bookGreen = Color(0xFF2F6B4F);

class MarkBadge extends StatelessWidget {
  final bool book; // true: green «من الكتاب», false: blue «موثّق»
  const MarkBadge.book({super.key}) : book = true;
  const MarkBadge.verified({super.key}) : book = false;
  @override
  Widget build(BuildContext context) {
    final c = book ? bookGreen : verifiedBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(book ? Icons.menu_book_rounded : Icons.verified_rounded, size: 15, color: c),
        const SizedBox(width: 4),
        Text(book ? 'من الكتاب' : 'موثّق', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}
