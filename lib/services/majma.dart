import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One proverb of «مجمع الأمثال» للميداني, with the book's own words.
class Mathal {
  final int n; // its number in the printed book
  final String text; // the proverb
  final String body; // the book's explanation and story, word for word
  final String usage; // the book's «يضرب ...» sentence, when it has one
  final int part, page;
  final bool quiz; // fits the daily quiz
  const Mathal(this.n, this.text, this.body, this.usage, this.part, this.page, this.quiz);

  String get source => 'مجمع الأمثال للميداني، الجزء $part، الصفحة $page، المثل رقم $n';
}

class Majma {
  static List<Mathal>? _all;

  static Future<List<Mathal>> all() async {
    final cached = _all;
    if (cached != null) return cached;
    final raw = jsonDecode(await rootBundle.loadString('assets/data/majma.json')) as List;
    final list = <Mathal>[
      for (final x in raw)
        Mathal(
          (x as Map)['n'] as int,
          x['t'] as String,
          x['b'] as String,
          x['u'] as String,
          x['j'] as int,
          x['p'] as int,
          x['q'] == 1,
        )
    ];
    _all = list;
    return list;
  }
}
