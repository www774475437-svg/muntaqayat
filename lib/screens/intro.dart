import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../ui.dart';

/// صفحات الاستقبال: تظهر مرة واحدة عند أول فتح للتطبيق.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  static const pages = [
    ('منتقيات الشعر', 'من أجود ما قالته العرب، مختاراً موثّقاً، بين يديك.'),
    ('اقرأ وتصفّح', 'أبواب وشعراء وعصور، وبيت جديد كل يوم.'),
    ('احفظ واختبر نفسك', 'متون طالب العلم، ومجلس الشعر، وبيت الذهب، وأمثال العرب.'),
    ('انسخ وشارك', 'انسخ البيت أو شاركه صورة، واجمع مختاراتك في مجموعاتك.'),
    ('قوافي وحسابك', 'انشر اقتباساتك وشعرك في «قوافي»، وتابع من تحب، وادعُ أصدقاءك.'),
  ];

  /// يُقرأ مرة عند الإقلاع: هل يُعرض الاستقبال هذه المرة؟
  static bool needed = false;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    needed = !(p.getBool('introSeen') ?? false);
  }

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final ctl = PageController();
  int at = 0;

  Future<void> _done() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('introSeen', true);
    IntroScreen.needed = false;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = IntroScreen.pages.length;
    final last = at == n - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(onPressed: _done, child: const Text('تخطٍّ')),
          ),
          Expanded(
            child: PageView.builder(
              controller: ctl,
              itemCount: n,
              onPageChanged: (i) => setState(() => at = i),
              itemBuilder: (context, i) {
                final p = IntroScreen.pages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(p.$1,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: C.accent(context))),
                    const SizedBox(height: 18),
                    Text(p.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.7)),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < n; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == at ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == at ? C.accent(context) : C.line(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: last
                    ? _done
                    : () => ctl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(last ? 'ابدأ' : 'التالي', style: const TextStyle(fontSize: 17)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
