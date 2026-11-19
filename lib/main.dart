import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data.dart';
import 'screens/account.dart';
import 'screens/browse.dart';
import 'screens/mutun.dart' show TestMode;
import 'screens/social.dart' show TestLinkScreen;
import 'screens/poem.dart';
import 'screens/search.dart';
import 'screens/today.dart';
import 'services/cloud.dart';
import 'services/device.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([Library.load(), Store.i.load()]);
  Library.refresh();
  runApp(const MuntaqayatApp());
  Device.init();
  Cloud.i.init();
  Device.checkUpdate();
}

/// Shared between the shell and the laptop side panel.
final navKey = GlobalKey<NavigatorState>();
final shellTab = ValueNotifier<int>(0);
final wideMode = ValueNotifier<bool>(false);

class MuntaqayatApp extends StatelessWidget {
  const MuntaqayatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) => MaterialApp(
        title: 'منتقيات الشعر',
        debugShowCheckedModeBanner: false,
        navigatorKey: navKey,
        builder: (context, child) => WideFrame(child: child!),
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
          // A teacher's test link: …/#/t/<matn>/<from>-<to>/<mode>
          final t = RegExp(r'^/t/([a-z_]+)/(\d+)-(\d+)/(\d)').firstMatch(s.name ?? '');
          if (t != null) {
            final matn = Library.mutun.where((x) => x.id == t.group(1) && x.ready).firstOrNull;
            if (matn != null) {
              final n = matn.lines.length;
              final from = int.parse(t.group(2)!).clamp(1, n);
              final to = int.parse(t.group(3)!).clamp(from, n);
              final mode = TestMode.values[int.parse(t.group(4)!).clamp(0, TestMode.values.length - 1)];
              return MaterialPageRoute(settings: s, builder: (_) => TestLinkScreen(matn: matn, from: from, to: to, mode: mode));
            }
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

class _ShellState extends State<Shell> with TickerProviderStateMixin {
  int tab = 0;
  int from = 0;
  bool collapsed = false;
  late final AnimationController _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: 1);

  static const _icons = [
    (Icons.wb_sunny_outlined, Icons.wb_sunny, 'اليوم'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'تصفّح'),
    (Icons.account_circle_outlined, Icons.account_circle, 'حسابك'),
  ];

  @override
  void initState() {
    super.initState();
    tab = shellTab.value;
    shellTab.addListener(_fromSide);
    wideMode.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});
  void _fromSide() {
    if (shellTab.value != tab) {
      setState(() {
        from = tab;
        tab = shellTab.value;
      });
    }
  }

  @override
  void dispose() {
    shellTab.removeListener(_fromSide);
    wideMode.removeListener(_rebuild);
    _slide.dispose();
    super.dispose();
  }

  void _go(int i) {
    HapticFeedback.selectionClick();
    if (collapsed) {
      setState(() => collapsed = false);
      if (i == tab) return;
    }
    if (i == tab) return;
    setState(() {
      from = tab;
      tab = i;
    });
    shellTab.value = i;
    _slide.forward(from: 0);
  }

  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    if (n.direction == ScrollDirection.reverse && !collapsed && n.metrics.pixels > 40) {
      setState(() => collapsed = true);
    } else if (n.direction == ScrollDirection.forward && collapsed) {
      setState(() => collapsed = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(onBrowse: () => _go(1)),
      const BrowseScreen(),
      const AccountScreen(),
    ];
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: IndexedStack(index: tab, children: pages),
          ),
        ),
        if (!wideMode.value)
        Positioned(
          left: 16,
          right: 16,
          bottom: 14 + MediaQuery.paddingOf(context).bottom,
          height: 74,
          child: LayoutBuilder(builder: (context, box) {
            final full = box.maxWidth - 74 - 12;
            return Stack(children: [
              // The round search button keeps its place.
              PositionedDirectional(
                end: 0,
                child: _glass(
                  context,
                  width: 74,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
                    },
                    child: Center(child: Icon(Icons.search_rounded, size: 32, color: C.ink(context))),
                  ),
                ),
              ),
              // The bar: full, or shrunk to one circle while reading down a page.
              PositionedDirectional(
                start: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: collapsed ? 0.0 : 1.0),
                  duration: const Duration(milliseconds: 460),
                  curve: Curves.easeOutBack,
                  builder: (context, t, _) {
                    final w = 74 + (full - 74) * t;
                    final open = t.clamp(0.0, 1.0);
                    return _glass(
                      context,
                      width: w < 74 ? 74 : w,
                      child: Stack(children: [
                        if (open > 0.02)
                          Opacity(
                            opacity: Curves.easeIn.transform(open),
                            child: OverflowBox(
                              alignment: AlignmentDirectional.centerStart,
                              minWidth: full,
                              maxWidth: full,
                              child: _items(context, full),
                            ),
                          ),
                        if (open < 0.98)
                          Opacity(
                            opacity: 1 - open,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _go(tab),
                              child: Center(
                                child: Transform.scale(
                                  scale: 1.15 - 0.15 * open,
                                  child: Icon(_icons[tab].$2, color: C.accent(context), size: 30),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    );
                  },
                ),
              ),
            ]);
          }),
        ),
      ]),
    );
  }

  /// Frosted-glass capsule.
  Widget _glass(BuildContext context, {required double width, required Widget child}) => Container(
        width: width,
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: C.bar(context).withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: C.line(context).withValues(alpha: 0.7)),
              ),
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
        ),
      );

  /// The three tabs with the pill that slides, stretches like liquid, then settles with a bounce.
  Widget _items(BuildContext context, double full) {
    const pad = 6.0;
    final item = (full - pad * 2) / 3;
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        final t = _slide.value;
        final pos = from + (tab - from) * Curves.easeOutBack.transform(t);
        final stretch = math.sin(math.pi * t) * item * 0.38 * (tab - from).abs().clamp(0, 1);
        final squash = 1 - math.sin(math.pi * t) * 0.14;
        return Stack(children: [
          PositionedDirectional(
            start: pad + pos * item - stretch / 2,
            top: pad + (62 * (1 - squash)) / 2,
            width: item + stretch,
            height: 62 * squash,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: C.soft(context),
                borderRadius: BorderRadius.circular(34),
                boxShadow: [BoxShadow(color: C.accent(context).withValues(alpha: 0.18 * math.sin(math.pi * t)), blurRadius: 16)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(pad),
            child: Row(children: [for (var i = 0; i < 3; i++) _item(context, i)]),
          ),
        ]);
      },
    );
  }

  Widget _item(BuildContext context, int i) {
    final on = tab == i;
    final (icon, active, label) = _icons[i];
    final color = on ? C.accent(context) : C.ink(context);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _go(i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedScale(
            scale: on ? 1.18 : 1,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Icon(on ? active : icon, key: ValueKey(on), color: color, size: 27),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w700, color: color),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}

/// Open a selection (used everywhere).
void openPoem(BuildContext context, Poem p) {
  Navigator.of(context).push(MaterialPageRoute(settings: RouteSettings(name: '/p/${p.id}'), builder: (_) => PoemScreen(poem: p)));
}

/// On a laptop or a wide screen: the app sits in a centred column, with a
/// quiet panel beside it carrying the name and the verse of the day.
class WideFrame extends StatelessWidget {
  final Widget child;
  const WideFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final wide = w >= 900;
    if (wideMode.value != wide) {
      WidgetsBinding.instance.addPostFrameCallback((_) => wideMode.value = wide);
    }
    if (!wide) return child;
    final col = (w * 0.56).clamp(560.0, 880.0);
    final verse = Library.poemOfDay();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: dark ? const Color(0xFF0E0C09) : const Color(0xFFEAE4D8),
        child: Row(children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.accent(context), width: 2)),
                  child: Text('منتقيات\nالشعر',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: verseFont, fontSize: 16, height: 1.1, fontWeight: FontWeight.w700, color: C.accent(context), decoration: TextDecoration.none)),
                ),
                const SizedBox(height: 22),
                Text('منتقيات الشعر', style: TextStyle(fontFamily: uiFont, fontSize: 34, fontWeight: FontWeight.w700, color: C.ink(context), decoration: TextDecoration.none)),
                const SizedBox(height: 6),
                Text('مختارات من عيون الشعر العربي، مرتبة على الأبواب والشعراء والعصور، مع متون طالب العلم.',
                    style: TextStyle(fontFamily: uiFont, fontSize: 17, height: 1.7, fontWeight: FontWeight.normal, color: C.muted(context), decoration: TextDecoration.none)),
                const SizedBox(height: 22),
                const SideNav(),
                const SizedBox(height: 26),
                Text('بيت اليوم', style: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w700, color: C.accent(context), decoration: TextDecoration.none)),
                const SizedBox(height: 8),
                for (final h in verse.firstVerse)
                  Text(h, style: TextStyle(fontFamily: verseFont, fontSize: 27, height: 1.9, fontWeight: FontWeight.normal, color: C.ink(context), decoration: TextDecoration.none)),
                const SizedBox(height: 6),
                Text(verse.poet, style: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.normal, color: C.muted(context), decoration: TextDecoration.none)),
              ]),
            ),
            ),
          ),
          Container(
            width: col,
            margin: const EdgeInsets.symmetric(vertical: 18).copyWith(left: 28),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: C.line(context)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, 12))],
            ),
            child: MediaQuery(
              data: mq.copyWith(size: Size(col, mq.size.height - 36)),
              child: child,
            ),
          ),
        ]),
      ),
    );
  }
}

/// The tabs and the search, inside the side panel on wide screens.
class SideNav extends StatelessWidget {
  const SideNav({super.key});
  static const items = [
    (Icons.wb_sunny_outlined, Icons.wb_sunny, 'اليوم'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'تصفّح'),
    (Icons.account_circle_outlined, Icons.account_circle, 'حسابك'),
  ];
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: shellTab,
        builder: (context, tab, _) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(children: [
            for (var i = 0; i < items.length; i++)
              _tile(context, tab == i ? items[i].$2 : items[i].$1, items[i].$3, tab == i, () {
                navKey.currentState?.popUntil((r) => r.isFirst);
                shellTab.value = i;
              }),
            _tile(context, Icons.search_rounded, 'بحث', false, () => navKey.currentState?.push(MaterialPageRoute(builder: (_) => const SearchScreen()))),
          ]),
        ),
      );

  Widget _tile(BuildContext context, IconData icon, String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: on ? C.soft(context) : C.bar(context).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                Icon(icon, color: on ? C.accent(context) : C.ink(context), size: 26),
                const SizedBox(width: 14),
                Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w700, color: on ? C.accent(context) : C.ink(context))),
              ]),
            ),
          ),
        ),
      );
}
