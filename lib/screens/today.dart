import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'lists.dart';
import 'plus.dart';
import 'poem.dart';

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
            const PlusChip(),
          ]),
        ),
        const SizedBox(height: 26),
        Center(child: Text(Hijri.today(), style: TextStyle(fontSize: 15, color: C.muted(context)))),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _rule(context),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('بيت اليوم', style: TextStyle(fontSize: 16, color: C.muted(context)))),
          _rule(context),
        ]),
        const SizedBox(height: 22),
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
          child: Row(children: [
            Expanded(
              child: InkWell(
                onTap: day.unattributed ? null : () => openPoet(context, day.poet),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: day.poet, style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
                  if (day.era.isNotEmpty) TextSpan(text: ' · ${day.era}'),
                  TextSpan(text: ' · ${day.chapterName}'),
                ]), style: TextStyle(fontSize: 15.5, color: C.muted(context))),
              ),
            ),
            IconButton(
              onPressed: () => Store.i.toggleLike(day.id),
              icon: Icon(Store.i.liked(day.id) ? Icons.favorite : Icons.favorite_border, color: Store.i.liked(day.id) ? C.accent(context) : C.ink(context)),
            ),
            IconButton(onPressed: () => shareSheet(context, day, day.firstVerse), icon: Icon(Icons.ios_share_rounded, color: C.ink(context))),
          ]),
        ),
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
