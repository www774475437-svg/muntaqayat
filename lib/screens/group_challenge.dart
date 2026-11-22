import 'package:flutter/material.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../ui.dart';
import 'boards.dart';
import 'lists.dart';
import 'majlis.dart';

/// «تحدي الأسبوع» and «تحدي الجمعة»: the same five verses for every reader,
/// one attempt each, and a ranking. A round that was started and left
/// unfinished is not counted.
class GroupChallenges extends StatefulWidget {
  const GroupChallenges({super.key});
  @override
  State<GroupChallenges> createState() => _GroupChallengesState();
}

class _GroupChallengesState extends State<GroupChallenges> {
  Map<String, dynamic> get _rec => Map<String, dynamic>.from(Store.i.majlis['group'] as Map? ?? {});

  void _save(String key, int value) {
    final g = _rec..[key] = value;
    // Old weeks and Fridays are dropped; the last dozen is enough.
    final keys = g.keys.toList();
    for (var i = 0; i < keys.length - 12; i++) {
      g.remove(keys[i]);
    }
    Store.i.majlis['group'] = g;
    Store.i.saveMajlis();
  }

  void _play(String key, int seed) {
    final picks = Majlis.seededPicks(seed);
    if (picks.length < 5) return;
    _save(key, -1);
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => ChallengeScreen(
                picks: picks,
                onDone: (pts) {
                  _save(key, pts);
                  Cloud.i.publishStats({key: pts});
                  Cloud.i.noteOwnStat(key, pts);
                })))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _card(BuildContext context, {required IconData icon, required String title, required String sub, required String key, required int seed, required bool open, required String closedNote}) {
    const gold = Color(0xFFB08A3E);
    final mine = _rec[key];
    final played = mine is num;
    final String status;
    if (!played) {
      status = open ? sub : closedNote;
    } else if (mine < 0) {
      status = 'بدأتَه ولم تُكمله، فلا يُحسب لك.';
    } else {
      status = 'نقاطك: ${Ar.num(mine.toInt())} من ${Ar.num(Majlis.maxPoints)}';
    }
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: gold),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context)))),
        ]),
        const SizedBox(height: 4),
        Text(status, style: TextStyle(height: 1.6, color: played && mine >= 0 ? gold : C.muted(context), fontWeight: played && mine >= 0 ? FontWeight.w700 : FontWeight.w400)),
        const SizedBox(height: 8),
        Row(children: [
          if (!played && open)
            Expanded(child: FilledButton(onPressed: () => _play(key, seed), style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.white), child: const Text('ابدأ التحدي'))),
          if (!played && open) const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => push(context, FieldBoardScreen(title: 'صدارة $title', field: key, unit: 'نقطة')), icon: const Icon(Icons.emoji_events_outlined, size: 18), label: const Text('الصدارة'))),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friday = DateTime.now().weekday == DateTime.friday;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(context,
          icon: Icons.calendar_view_week_rounded,
          title: 'تحدي الأسبوع',
          sub: 'خمسة أبيات واحدة عند الجميع، ومحاولة واحدة حتى الجمعة.',
          key: 'w${Majlis.weekStart}',
          seed: 900000 + Majlis.weekStart,
          open: true,
          closedNote: ''),
      const SizedBox(height: 8),
      _card(context,
          icon: Icons.mosque_outlined,
          title: 'تحدي الجمعة',
          sub: 'خمسة أبيات واحدة عند الجميع، ومحاولة واحدة اليوم.',
          key: 'f${friday ? Store.today : 0}',
          seed: 500000 + Store.today,
          open: friday,
          closedNote: 'يُفتح يوم الجمعة فقط.'),
    ]);
  }
}
