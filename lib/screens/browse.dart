import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'lists.dart';
import 'games.dart';
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
                _link(context, Icons.favorite_border, 'الأكثر إعجاباً', () => _mostLiked(context)),
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
        const SectionTitle('مختارات'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: _pick(context, Icons.auto_stories_outlined, 'أبواب الإيمان', 'والرقائق', () => push(context, const ChaptersScreen(section: 0))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _pick(context, Icons.format_list_bulleted_rounded, 'الأبواب العامة', 'حكمة وأخلاق وأدب', () => push(context, const ChaptersScreen(section: 1))),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _pick(context, Icons.mosque_outlined, 'ديوان العلماء والصحابة', 'ابن القيم، ابن تيمية، الشافعي، الخنساء، حسان…',
              () => push(context, const ChaptersScreen(section: 2))),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: _pick(context, Icons.extension_outlined, 'أكمل البيت', 'اختر الشطر الثاني', () => push(context, const GameScreen(kind: 0)))),
            const SizedBox(width: 12),
            Expanded(child: _pick(context, Icons.person_search_outlined, 'من القائل؟', 'اعرف الشاعر', () => push(context, const GameScreen(kind: 1)))),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _pick(context, Icons.school_outlined, 'المتون والمنظومات', 'ألفية ابن مالك، النونية، الرحبية… للحفظ — قريباً',
              () => soonSheet(context, 'المتون والمنظومات', 'قسم لطلاب العلم: ألفية ابن مالك، ونونية ابن القيم، والرحبية، والبيقونية وغيرها، مع قائمة الحفظ والورد اليومي ووضع التسميع — قريباً بإذن الله.')),
        ),
        const SectionTitle('قصائد لك'),
        TwoColumns(poems: forYou, onTap: (p) => openPoem(context, p)),
      ]),
    );
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
