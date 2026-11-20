import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../ui.dart';

/// «كلمة اليوم»: a rare word with its meaning and the book it was taken from.
/// Entries live in assets/data/words.json as {"word", "meaning", "source"}.
class Words {
  static List<Map<String, String>>? _all;

  static Future<List<Map<String, String>>> all() async {
    if (_all == null) {
      final raw = await rootBundle.loadString('assets/data/words.json');
      _all = [for (final x in jsonDecode(raw) as List) Map<String, String>.from(x as Map)];
    }
    return _all!;
  }

  /// The word of the day: the same for everyone on the same date.
  static Map<String, String>? pick(List<Map<String, String>> list, DateTime day) {
    if (list.isEmpty) return null;
    final n = day.difference(DateTime(2026, 1, 1)).inDays;
    return list[n % list.length];
  }
}

class WordOfDayCard extends StatefulWidget {
  const WordOfDayCard({super.key});
  @override
  State<WordOfDayCard> createState() => _WordOfDayCardState();
}

class _WordOfDayCardState extends State<WordOfDayCard> {
  Map<String, String>? word;

  @override
  void initState() {
    super.initState();
    Words.all().then((list) {
      if (mounted) setState(() => word = Words.pick(list, DateTime.now()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = word;
    if (w == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: C.line(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('كلمة اليوم', style: TextStyle(fontSize: 13, color: C.accent(context), fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(w['word'] ?? '', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 6),
        Text(w['meaning'] ?? '', style: TextStyle(fontSize: 16, height: 1.6, color: C.ink(context))),
        if ((w['source'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('المصدر: ${w['source']}', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
        ],
      ]),
    );
  }
}
