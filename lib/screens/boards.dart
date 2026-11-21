import 'package:flutter/material.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../ui.dart';

/// «المتصدرون»: the proverb quiz and the duels, one ranking at a time.
/// Each ranking is read once a day.
class BoardsScreen extends StatefulWidget {
  const BoardsScreen({super.key});
  @override
  State<BoardsScreen> createState() => _BoardsScreenState();
}

class _BoardsScreenState extends State<BoardsScreen> {
  static const sections = <(String, List<(String, String, String)>)>[
    ('بيت الذهب', [
      ('goldFull', 'أكثر البيوت المكتملة', 'بيتاً'),
      ('goldStreak', 'أطول سلسلة أيام', 'يوماً'),
      ('goldRight', 'أكثر إجابة صحيحة', 'إجابة'),
    ]),
    ('الأمثال', [
      ('quizCorrect', 'أكثر إجابة صحيحة', 'صحيحة'),
      ('quizAnswered', 'أكثر من أجاب', 'سؤالاً'),
    ]),
    ('المبارزات', [
      ('duelWon', 'أكثر من فاز', 'فوزاً'),
      ('duelDone', 'أكثر من أكمل', 'تحدياً'),
      ('duelSent', 'أكثر من أرسل', 'تحدياً'),
    ]),
  ];
  int section = 0, choice = 0;
  late Future<List<Doc>> job = Cloud.i.statBoard(sections[0].$2[0].$1);

  void _select(int s, int i) => setState(() {
        section = s;
        choice = i;
        job = Cloud.i.statBoard(sections[s].$2[i].$1);
      });

  @override
  Widget build(BuildContext context) {
    final r = sections[section].$2[choice];
    return Scaffold(
      appBar: AppBar(title: const Text('المتصدرون')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        Text('تُقرأ الصدارة مرة في اليوم.', style: TextStyle(height: 1.7, color: C.muted(context))),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [for (var i = 0; i < sections.length; i++) ButtonSegment(value: i, label: Text(sections[i].$1))],
          selected: {section},
          onSelectionChanged: (v) => _select(v.first, 0),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < sections[section].$2.length; i++)
            ChoiceChip(label: Text(sections[section].$2[i].$2), selected: choice == i, onSelected: (_) => _select(section, i)),
        ]),
        const SizedBox(height: 16),
        Text('${sections[section].$1}: ${r.$2}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
        const SizedBox(height: 8),
        FutureBuilder<List<Doc>>(
          future: job,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            final list = snap.data ?? [];
            if (list.isEmpty) return const EmptyNote(Icons.emoji_events_outlined, 'لا أرقام بعد في هذه الصدارة.');
            return Column(children: [
              for (var i = 0; i < list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      SizedBox(width: 34, child: Text(Ar.num(i + 1), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context)))),
                      Expanded(child: Text('${list[i]['name'] ?? ''}'.trim().isEmpty ? '${list[i]['publicId'] ?? ''}' : '${list[i]['name']}', style: TextStyle(fontSize: 16, color: C.ink(context)))),
                      Text('${Ar.num(_n(list[i]['v']))} ${r.$3}', style: TextStyle(fontSize: 15, color: C.muted(context))),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }

  int _n(dynamic v) => v is num ? v.toInt() : 0;
}

/// A bar in three parts with their shares: wins, losses and ties by default.
class WinBar extends StatelessWidget {
  final int won, lost, tied;
  final (String, String, String) labels;
  const WinBar({super.key, required this.won, required this.lost, required this.tied, this.labels = const ('فوز', 'خسارة', 'تعادل')});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2F6B4F), red = Color(0xFFB3261E), grey = Color(0xFF9A9A9A);
    final total = won + lost + tied;
    if (total <= 0) return const SizedBox();
    int pct(int a) => (a * 100 / total).round();
    Widget key(Color c, String label, int n) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$label ${Ar.num(n)} (${Ar.num(pct(n))}٪)', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 14,
          child: Row(children: [
            if (won > 0) Expanded(flex: won, child: Container(color: green)),
            if (lost > 0) Expanded(flex: lost, child: Container(color: red)),
            if (tied > 0) Expanded(flex: tied, child: Container(color: grey)),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 12, runSpacing: 4, children: [
        key(green, labels.$1, won),
        key(red, labels.$2, lost),
        if (tied > 0) key(grey, labels.$3, tied),
      ]),
    ]);
  }
}

/// One ranking on its own page (the week's challenge, Friday's challenge).
class FieldBoardScreen extends StatelessWidget {
  final String title, field, unit;
  const FieldBoardScreen({super.key, required this.title, required this.field, required this.unit});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: FutureBuilder<List<Doc>>(
          future: Cloud.i.statBoard(field),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final list = snap.data ?? <Doc>[];
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              Text('تُقرأ الصدارة مرة في اليوم.', style: TextStyle(color: C.muted(context))),
              const SizedBox(height: 10),
              if (list.isEmpty) const EmptyNote(Icons.emoji_events_outlined, 'لا نتائج بعد في هذه الصدارة.'),
              for (var i = 0; i < list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      SizedBox(width: 34, child: Text(Ar.num(i + 1), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context)))),
                      Expanded(child: Text('${list[i]['name'] ?? ''}'.trim().isEmpty ? '${list[i]['publicId'] ?? ''}' : '${list[i]['name']}', style: TextStyle(fontSize: 16, color: C.ink(context)))),
                      Text('${Ar.num(list[i]['v'] is num ? (list[i]['v'] as num).toInt() : 0)} $unit', style: TextStyle(fontSize: 15, color: C.muted(context))),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}
