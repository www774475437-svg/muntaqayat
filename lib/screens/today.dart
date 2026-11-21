import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'lists.dart';
import 'majlis.dart';
import 'plus.dart';
import 'poem.dart';
import '../services/device.dart';
import '../services/words.dart';
import 'golden.dart';
import 'proverbs_quiz.dart';

class TodayScreen extends StatelessWidget {
  final VoidCallback onBrowse;
  const TodayScreen({super.key, required this.onBrowse});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final day = Library.poemOfDay();
    final poet = Library.poetOfDay();
    final picks = Library.dailyPicks(8, salt: 3);
    final last = Library.byId[Store.i.lastRead];
    final chapterOfDay = Library.chapters[(day.id * 7 + DateTime.now().day) % Library.chapters.length];
    final chapterPoems = Library.ofChapter(chapterOfDay.index);
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.only(bottom: 130), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            const Spacer(),
            if (Store.i.plusOn || Store.i.developer) const PlusChip(),
          ]),
        ),
        ValueListenableBuilder<int?>(
          valueListenable: Device.update,
          builder: (context, n, _) => n == null
              ? const SizedBox.shrink()
              : SoftCard(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  padding: const EdgeInsets.all(14),
                  onTap: () => launchUrl(Uri.parse(apkUrl), mode: LaunchMode.externalApplication),
                  child: Row(children: [
                    RoundIcon(Icons.system_update_rounded, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('يوجد تحديث جديد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
                        Text('اضغط لتحميله، ثم ثبّته فوق التطبيق', style: TextStyle(fontSize: 14, color: C.muted(context))),
                      ]),
                    ),
                    Icon(Icons.download_rounded, color: C.accent(context)),
                  ]),
                ),
        ),
        const WordOfDayCard(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => push(context, const ProverbQuizScreen()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.soft(context), borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Icon(Icons.quiz_rounded, color: C.accent(context)),
                const SizedBox(width: 12),
                Expanded(child: Text('أمثال العرب: ثلاثة أسئلة كل يوم', style: TextStyle(fontSize: 16, color: C.ink(context), fontWeight: FontWeight.w700))),
                Icon(Icons.chevron_left_rounded, color: C.muted(context)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text(Hijri.full(), style: TextStyle(fontSize: 15, color: C.muted(context))))),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _rule(context),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('بيت اليوم', style: TextStyle(fontSize: 16, color: C.muted(context)))),
          _rule(context),
        ]),
        const SizedBox(height: 22),
        if (goldenDoneToday())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GoldenPlate(poem: day, ans: Golden.todayAnswers, onTap: () => openPoem(context, day)),
          )
        else
          InkWell(
            onTap: () => openPoem(context, day),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: VerseLines(day.firstVerse, size: 29),
            ),
          ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: goldenDoneToday()
              ? OutlinedButton.icon(
                  onPressed: () => push(context, const GoldenScreen()),
                  icon: const Icon(Icons.filter_vintage_rounded, size: 18, color: Color(0xFFB08A3E)),
                  label: const Text('نتيجتك في البيت الذهبي اليوم'),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFB08A3E))),
                )
              : FilledButton.icon(
                  onPressed: () => push(context, const GoldenScreen()),
                  icon: const Icon(Icons.filter_vintage_rounded, size: 20),
                  label: const Text('اضغط لتنال البيت الذهبي اليومي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB08A3E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
                ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(children: [
            Expanded(
              child: InkWell(
                onTap: day.unattributed || !goldenDoneToday() ? null : () => openPoet(context, day.poet),
                child: goldenDoneToday()
                    ? Text.rich(TextSpan(children: [
                        TextSpan(text: day.poet, style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
                        if (day.era.isNotEmpty) TextSpan(text: ' · ${day.era}'),
                        TextSpan(text: ' · ${day.chapterName}'),
                      ]), style: TextStyle(fontSize: 15.5, color: C.muted(context)))
                    // The poet, era and chapter are answers in «بيت الذهب», so they wait until it is done.
                    : Text('يظهر الشاعر وعصره وبابه بعد «بيت الذهب»', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
              ),
            ),
            if (!goldenDoneToday())
              IconButton(
                tooltip: 'نسخ',
                visualDensity: VisualDensity.compact,
                iconSize: 17,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${formatVerses([day.firstVerse])}\n\n${Hijri.full()}\nمنتقيات الشعر'));
                  toast(context, 'نُسخ البيت');
                },
                icon: Icon(Icons.copy_rounded, color: C.muted(context)),
              ),
            IconButton(
              onPressed: () => Store.i.toggleLike(day.id),
              icon: Icon(Store.i.liked(day.id) ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, color: Store.i.liked(day.id) ? C.accent(context) : C.ink(context)),
            ),
            IconButton(tooltip: 'مشاركة', visualDensity: VisualDensity.compact, iconSize: 19, onPressed: () => shareSheet(context, day, day.firstVerse), icon: Icon(Icons.ios_share_rounded, color: C.ink(context))),
          ]),
        ),
        const MajlisCard(),
        if (season() case final se?) ...[
          SectionTitle(se.$1, onMore: () => openList(context, se.$1, se.$2)),
          _row(context, se.$2.take(8).toList()),
        ],
        const SectionTitle('شاعر اليوم'),
        SoftCard(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          onTap: () => openPoet(context, poet.name),
          child: Row(children: [
            Avatar(poet.initial),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(poet.name, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink(context))),
                const SizedBox(height: 4),
                Text([
                  if (poet.era.isNotEmpty) poet.era,
                  if (poet.death.isNotEmpty) 'ت ${poet.death}',
                  Ar.selections(poet.count),
                ].join(' · '), style: TextStyle(fontSize: 14.5, color: C.muted(context))),
                if (poet.bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(poet.bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, height: 1.6, color: C.ink(context))),
                  ),
              ]),
            ),
            Icon(Icons.chevron_left_rounded, color: C.muted(context)),
          ]),
        ),
        SectionTitle('قد يعجبك', onMore: () => openList(context, 'قد يعجبك', Library.dailyPicks(40, salt: 3))),
        _row(context, picks),
        if (last != null) ...[
          const SectionTitle('تابع القراءة'),
          SoftCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            onTap: () => openPoem(context, last),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(last.poet, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context)))),
                Icon(Icons.chevron_left_rounded, color: C.muted(context)),
              ]),
              Divider(height: 22, color: C.line(context)),
              VerseLines(last.firstVerse, size: 21),
            ]),
          ),
        ],
        SectionTitle('من باب «${chapterOfDay.name}»', onMore: () => openList(context, chapterOfDay.name, chapterPoems)),
        _row(context, chapterPoems.take(8).toList()),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: onBrowse,
            icon: Icon(Icons.grid_view_rounded, color: C.accent(context)),
            label: Text('تصفّح الديوان كلّه', style: TextStyle(fontSize: 16, color: C.accent(context))),
          ),
        ),
      ]),
    );
  }

  Widget _rule(BuildContext context) => Row(children: [
        Icon(Icons.square, size: 7, color: C.muted(context)),
        Container(width: 60, height: 1, color: C.muted(context)),
      ]);

  Widget _row(BuildContext context, List<Poem> list) {
    return SizedBox(
      height: 262,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (c, i) => PoemCard(poem: list[i], width: 300, onTap: () => openPoem(context, list[i])),
      ),
    );
  }
}

const apkUrl = 'https://github.com/www774475437-svg/muntaqayat/releases/latest/download/muntaqayat.apk';

/// Verses for the season: Ramadan, the two Eids, the ten days of Dhul-Hijja, Friday.
(String, List<Poem>)? season() {
  final (_, m, d) = Hijri.parts();
  List<String> ch;
  String title;
  if (m == 9) {
    title = 'أبيات رمضان';
    ch = ['التوبة والاستغفار', 'الدعاء والمناجاة', 'الوقت والعمر', 'الإخلاص وصدق النية'];
  } else if (m == 10 && d <= 3) {
    title = 'أبيات العيد';
    ch = ['الأخوة والصداقة', 'الكرم والجود', 'الإحسان إلى الناس', 'العفو والصفح'];
  } else if (m == 12 && d >= 10 && d <= 13) {
    title = 'أبيات عيد الأضحى';
    ch = ['الأخوة والصداقة', 'الكرم والجود', 'الشكر والجحود', 'الإحسان إلى الناس'];
  } else if (m == 12 && d < 10) {
    title = 'أبيات العشر من ذي الحجة';
    ch = ['التوبة والاستغفار', 'الدعاء والمناجاة', 'الافتقار إلى الله'];
  } else if (DateTime.now().weekday == DateTime.friday) {
    title = 'أبيات الجمعة';
    ch = ['ذكر الموت والآخرة', 'التذكير بالله والغفلة', 'الدعاء والمناجاة', 'التوبة والاستغفار'];
  } else {
    return null;
  }
  final list = <Poem>[];
  for (final c in ch) {
    final i = Library.chapterNamed(c);
    if (i >= 0) list.addAll(Library.ofChapter(i));
  }
  if (list.isEmpty) return null;
  final day = DateTime.now().day;
  list.sort((a, b) => ((a.id * 31 + day) % 97).compareTo((b.id * 31 + day) % 97));
  return (title, list);
}
