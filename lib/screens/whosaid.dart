import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'plus.dart';

/// «من قائل هذا البيت؟»: paste a verse, a few verses or a whole poem.
class WhoSaidScreen extends StatefulWidget {
  const WhoSaidScreen({super.key});
  @override
  State<WhoSaidScreen> createState() => _WhoSaidScreenState();
}

class _WhoSaidScreenState extends State<WhoSaidScreen> {
  final ctl = TextEditingController();
  List<(Poem, double)>? results;

  /// How many verses were pasted: two lines (or one line with a separator)
  /// make one verse.
  int get _verses {
    final lines = ctl.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty && l != '..').toList();
    if (lines.isEmpty) return 0;
    final joined = lines.where((l) => l.contains('...') || l.contains('***') || l.contains('*')).length;
    return joined + ((lines.length - joined) / 2).ceil();
  }

  String get _question {
    final n = _verses;
    if (n <= 1) return 'من قائل هذا البيت؟';
    if (n == 2) return 'من قائل هذين البيتين؟';
    if (n <= 6) return 'من قائل هذه الأبيات؟';
    return 'من قائل هذه القصيدة؟';
  }

  void _search() {
    final words = Ar.norm(ctl.text).replaceAll(RegExp(r'[^ء-ي\s]'), ' ').split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    if (words.length < 3) {
      toast(context, 'الصق بيتاً كاملاً على الأقل');
      return;
    }
    final found = <(Poem, double)>[];
    for (final p in Library.poems) {
      final t = Ar.norm(p.plainText).split(RegExp(r'\s+')).toSet();
      final hit = words.where(t.contains).length / words.length;
      if (hit >= 0.6) found.add((p, hit));
    }
    found.sort((a, b) => b.$2.compareTo(a.$2));
    setState(() => results = found.take(5).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_question)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        Text('الصق البيت أو الأبيات أو القصيدة، ثم اضغط «ابحث».', style: TextStyle(color: C.muted(context))),
        const SizedBox(height: 10),
        TextField(
          controller: ctl,
          minLines: 4,
          maxLines: 12,
          onChanged: (_) => setState(() => results = null),
          style: const TextStyle(fontFamily: verseFont, fontSize: 20, height: 1.7),
          decoration: InputDecoration(
            hintText: 'الصق هنا…',
            filled: true,
            fillColor: C.card(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
          onPressed: _search,
          icon: const Icon(Icons.search_rounded),
          label: Text('ابحث: $_question', style: const TextStyle(fontSize: 16)),
        ),
        if (results != null) ...[
          const SizedBox(height: 18),
          if (results!.isEmpty) ...[
            Text('لم يُعثر عليه في مكتبة التطبيق.', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => soonSheet(context, 'البحث بالذكاء الاصطناعي',
                  'يبحث في المصادر الموثوقة ويذكر المصدر، وإن لم يتيقّن قال: «لم يُعرف قائله بيقين» — يُفعَّل قريباً بإذن الله.'),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('ابحث بالذكاء الاصطناعي — قريباً'),
            ),
          ] else
            for (final r in results!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PoemCard(poem: r.$1, onTap: () => openPoem(context, r.$1)),
              ),
        ],
      ]),
    );
  }
}
