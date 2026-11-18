import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data.dart';
import 'screens/account.dart';
import 'screens/browse.dart';
import 'screens/poem.dart';
import 'screens/search.dart';
import 'screens/today.dart';
import 'services/device.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([Library.load(), Store.i.load()]);
  runApp(const MuntaqayatApp());
  Device.init();
  Device.checkUpdate();
}

class MuntaqayatApp extends StatelessWidget {
  const MuntaqayatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) => MaterialApp(
        title: 'منتقيات الشعر',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark][Store.i.themeMode],
        onGenerateRoute: (s) {
          // Shared links: …/#/p/12 opens that selection directly.
          final m = RegExp(r'^/p/(\d+)').firstMatch(s.name ?? '');
          final poem = m == null ? null : Library.byId[int.parse(m.group(1)!)];
          if (poem != null) {
            return MaterialPageRoute(settings: s, builder: (_) => PoemScreen(poem: poem, fromLink: true));
          }
          return MaterialPageRoute(settings: s, builder: (_) => const Shell());
        },
      ),
    );
  }
}

/// The three tabs with the floating bar and the round search button.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(onBrowse: () => setState(() => tab = 1)),
      const BrowseScreen(),
      const AccountScreen(),
    ];
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: IndexedStack(index: tab, children: pages)),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14 + MediaQuery.paddingOf(context).bottom,
          child: Row(children: [
            Expanded(
              child: Container(
                height: 74,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: C.bar(context),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 22, offset: const Offset(0, 6))],
                ),
                child: Row(children: [
                  _item(0, Icons.wb_sunny_outlined, Icons.wb_sunny, 'اليوم'),
                  _item(1, Icons.grid_view_outlined, Icons.grid_view_rounded, 'تصفّح'),
                  _item(2, Icons.account_circle_outlined, Icons.account_circle, 'حسابك'),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: C.bar(context),
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: Colors.black26,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
                child: SizedBox(width: 74, height: 74, child: Icon(Icons.search_rounded, size: 32, color: C.ink(context))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _item(int i, IconData icon, IconData active, String label) {
    final on = tab == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(color: on ? C.soft(context) : Colors.transparent, borderRadius: BorderRadius.circular(34)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(on ? active : icon, color: on ? C.accent(context) : C.ink(context), size: 27),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? C.accent(context) : C.ink(context))),
          ]),
        ),
      ),
    );
  }
}

/// Open a selection (used everywhere).
void openPoem(BuildContext context, Poem p) {
  Navigator.of(context).push(MaterialPageRoute(settings: RouteSettings(name: '/p/${p.id}'), builder: (_) => PoemScreen(poem: p)));
}
