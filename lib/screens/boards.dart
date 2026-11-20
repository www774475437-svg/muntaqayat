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
  static const rankings = <(String, String, String)>[
    ('goldFull', 'بيت الذهب: أكثر البيوت المكتملة', 'بيتاً'),
    ('goldStreak', 'بيت الذهب: أطول سلسلة أيام', 'يوماً'),
    ('goldRight', 'بيت الذهب: أكثر إجابة صحيحة', 'إجابة'),
    ('quizAnswered', 'الأمثال: أكثر من أجاب', 'سؤالاً'),
    ('quizCorrect', 'الأمثال: أكثر إجابة صحيحة', 'صحيحة'),
    ('duelWon', 'المبارزات: أكثر من فاز', 'فوزاً'),
    ('duelDone', 'المبارزات: أكثر من أكمل', 'تحدياً'),
    ('duelSent', 'المبارزات: أكثر من أرسل', 'تحدياً'),
  ];
  int choice = 0;
  late Future<List<Doc>> job = Cloud.i.statBoard(rankings[0].$1);

  void _select(int i) => setState(() {
        choice = i;
        job = Cloud.i.statBoard(rankings[i].$1);
      });

  @override
  Widget build(BuildContext context) {
    final r = rankings[choice];
    return Scaffold(
      appBar: AppBar(title: const Text('المتصدرون')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        Text('تُجمع الأرقام مرة في اليوم، وتظهر الصدارة كل يوم بعد ذلك.', style: TextStyle(height: 1.7, color: C.muted(context))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < rankings.length; i++)
            ChoiceChip(label: Text(rankings[i].$2), selected: choice == i, onSelected: (_) => _select(i)),
        ]),
        const SizedBox(height: 16),
        Text(r.$2, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
        const SizedBox(height: 8),
        FutureBuilder<List<Doc>>(
          future: job,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            final list = snap.data ?? [];
            if (list.isEmpty) return const EmptyNote(Icons.emoji_events_outlined, 'لا أرقام بعد. ابدأ المسابقة أو التحديات لتظهر هنا.');
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
