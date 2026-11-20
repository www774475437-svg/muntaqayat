import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data.dart';
import '../main.dart' show shellTab;
import '../services/cloud.dart';
import '../ui.dart';
import 'cloud_ui.dart';
import 'lists.dart';
import 'majlis.dart';
import 'majlis_plus.dart';
import 'medals.dart';
import 'poem.dart';

// «قوافي»: the middle tab. A wall of verses that scrolls one page at a time:
// verses quoted from the library and poems the members wrote themselves.
// Poetry only (no prose), no comments, no pictures.

String _since(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${Hijri.gMonths[d.month - 1]} ${Ar.num(d.year)}';
}

int _n(dynamic v) => v is num ? (v < 0 ? 0 : v.toInt()) : 0;

const meters = [
  'الطويل', 'المديد', 'البسيط', 'الوافر', 'الكامل', 'الهزج', 'الرجز', 'الرمل', //
  'السريع', 'المنسرح', 'الخفيف', 'المضارع', 'المقتضب', 'المجتث', 'المتقارب', 'المتدارك',
];

const purposes = [
  'الحكمة', 'الزهد والرقائق', 'المدح', 'الرثاء', 'الفخر والحماسة', 'الوصف', //
  'الإخوانيات', 'الحنين والوطن', 'الشكوى', 'النصيحة', 'الاعتذار', 'المناسبات',
];

const countries = [
  ('🇸🇦', 'السعودية'), ('🇾🇪', 'اليمن'), ('🇪🇬', 'مصر'), ('🇸🇾', 'سوريا'), ('🇮🇶', 'العراق'), //
  ('🇯🇴', 'الأردن'), ('🇵🇸', 'فلسطين'), ('🇱🇧', 'لبنان'), ('🇰🇼', 'الكويت'), ('🇦🇪', 'الإمارات'),
  ('🇶🇦', 'قطر'), ('🇧🇭', 'البحرين'), ('🇴🇲', 'عُمان'), ('🇸🇩', 'السودان'), ('🇱🇾', 'ليبيا'),
  ('🇹🇳', 'تونس'), ('🇩🇿', 'الجزائر'), ('🇲🇦', 'المغرب'), ('🇲🇷', 'موريتانيا'), ('🇸🇴', 'الصومال'),
  ('🇹🇷', 'تركيا'), ('🇺🇸', 'أمريكا'), ('🇬🇧', 'بريطانيا'), ('🌍', 'بلد آخر'),
];

String flagOf(String country) => countries.where((c) => c.$2 == country).map((c) => c.$1).firstOrNull ?? '';

/// The colours a reader may choose for his monogram (no pictures in the app).
const inks = [
  Color(0xFF8C4A2F), Color(0xFFB08A3E), Color(0xFF2F6B4F), Color(0xFF23395B), //
  Color(0xFF5B2A4E), Color(0xFF1E1B16), Color(0xFF7A2626), Color(0xFF3E5C66),
];
const inkNames = ['حِنّاء', 'ذهب', 'زمرّد', 'ليل', 'شفق', 'حِبر', 'عقيق', 'رماد البحر'];

/// The first letter of the name, written large in ruqʿa inside rings.
class Monogram extends StatelessWidget {
  final String name;
  final int hue;
  final int points;
  final double size;
  const Monogram({super.key, required this.name, this.hue = 0, this.points = 0, this.size = 44});

  static String letter(String name) {
    var n = name.trim();
    if (n.startsWith('ال') && n.length > 2) n = n.substring(2);
    return n.isEmpty ? 'ق' : String.fromCharCode(n.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final ink = inks[hue.clamp(0, inks.length - 1)];
    final ring = Majlis.rankColors[Majlis.rankIndex(Majlis.levelOf(points))];
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.045),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: max(1.2, size * 0.035))),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Color.lerp(ink, Colors.white, 0.18)!, ink], center: const Alignment(-0.3, -0.4), radius: 1.1),
          boxShadow: [BoxShadow(color: ink.withValues(alpha: 0.35), blurRadius: size * 0.18, offset: Offset(0, size * 0.06))],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: size * 0.08),
          child: Text(letter(name),
              style: TextStyle(fontFamily: 'ArefRuqaa', fontSize: size * 0.5, height: 1, fontWeight: FontWeight.w700, color: const Color(0xFFFBF3DF))),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ the items on the wall

class WallItem {
  final Doc? post; // a published post
  final Poem? poem; // a verse from the library
  final int verse;
  const WallItem.post(Doc this.post)
      : poem = null,
        verse = 0;
  const WallItem.library(Poem this.poem, this.verse) : post = null;

  bool get own => post?['kind'] == 'own';
  Poem? get source => poem ?? (post == null || own ? null : Library.byId[_n(post!['poem'])]);
  String get key => post != null ? 'p${post!['id']}' : 'l${poem!.id}:$verse';

  /// The verses shown on the page.
  List<List<String>> get lines {
    if (own) {
      return [
        for (final l in post!['lines'] as List? ?? [])
          if (l is Map) [for (final h in ['${l['a'] ?? ''}', '${l['b'] ?? ''}']) if (h.trim().isNotEmpty) h]
      ];
    }
    if (post != null) return [<String>['${post!['a']}', if ('${post!['b'] ?? ''}'.isNotEmpty) '${post!['b']}']];
    final p = poem!;
    final out = <List<String>>[p.lines[verse]];
    if (verse + 1 < p.lines.length && !p.gone(verse + 2) && p.lines[verse].length > 1) out.add(p.lines[verse + 1]);
    return out;
  }

  String get poet => own ? '${post!['name']}' : (post != null ? '${post!['poet']}' : poem!.poet);
}

/// A poem written by a member, as a [Poem] so the share card can draw it.
Poem asPoem(Doc post, List<List<String>> lines) => Poem.fromJson({
      'id': 0,
      'ch': 0,
      'sec': 0,
      'page': 0,
      'lines': lines,
      'notes': <String>[],
      'poet': '${post['name']}',
      'flags': <String>[],
      'src': 'member',
    });

/// Open the page of the member who wrote or quoted the post.
void openMember(BuildContext context, {required String uid, required String name, String publicId = ''}) =>
    push(context, MemberScreen(uid: uid, name: name, publicId: publicId));

// ------------------------------------------------------------ the tab

class QawafiScreen extends StatefulWidget {
  const QawafiScreen({super.key});
  @override
  State<QawafiScreen> createState() => _QawafiScreenState();
}

class _QawafiScreenState extends State<QawafiScreen> {
  static const filters = ['استكشف', 'أشعار الأعضاء', 'اقتباسات', 'أتابعهم'];
  int filter = 0;
  String purpose = '';
  bool loading = true;
  List<Doc> posts = [];
  List<WallItem> items = [];
  final _rnd = Random();
  final _seen = <String>{};
  PageController _page = PageController();

  bool _started = false, _fetched = false;

  @override
  void initState() {
    super.initState();
    shellTab.addListener(_visit);
    Cloud.i.addListener(_cloud);
    _visit();
  }

  /// The wall is read from the server only when the reader opens the tab.
  void _visit() {
    if (shellTab.value == 2 && !_started) {
      _started = true;
      _load();
    }
  }

  void _cloud() {
    if (_started && !_fetched && Cloud.i.ready && mounted) _load();
  }

  @override
  void dispose() {
    shellTab.removeListener(_visit);
    Cloud.i.removeListener(_cloud);
    _page.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() => loading = true);
    if (Cloud.i.ready) _fetched = true;
    posts = await Cloud.i.wall(refresh: refresh);
    if (!mounted) return;
    _rebuild();
    setState(() => loading = false);
  }

  /// One verse from the library, never twice in a session.
  WallItem? _libraryVerse() {
    final all = Library.poems;
    if (all.isEmpty) return null;
    for (var tries = 0; tries < 40; tries++) {
      final p = all[_rnd.nextInt(all.length)];
      if (p.lines.isEmpty) continue;
      var v = _rnd.nextInt(p.lines.length);
      if (v.isOdd && p.lines.length > 1) v--;
      if (p.gone(v + 1)) continue;
      if (purpose.isNotEmpty && !_fits(p)) continue;
      final it = WallItem.library(p, v);
      if (_seen.add(it.key)) return it;
    }
    return null;
  }

  bool _fits(Poem p) {
    final want = Ar.norm(purpose.split(' ').first.replaceFirst('ال', ''));
    return Ar.norm(p.chapterName).contains(want);
  }

  bool _keep(Doc d) {
    final own = d['kind'] == 'own';
    if (filter == 1 && !own) return false;
    if (filter == 2 && own) return false;
    if (filter == 3) {
      final f = List<String>.from(Cloud.i.profile['following'] as List? ?? []);
      if (!f.contains(d['uid']) && !Cloud.i.following.containsKey('${d['publicId']}')) return false;
    }
    if (purpose.isNotEmpty) {
      if (own) return d['purpose'] == purpose;
      final p = Library.byId[_n(d['poem'])];
      return p != null && _fits(p);
    }
    return true;
  }

  void _rebuild() {
    _seen.clear();
    final mine = [for (final d in posts) if (_keep(d)) WallItem.post(d)];
    final out = <WallItem>[];
    final mix = filter == 0 || filter == 2;
    for (var i = 0; i < mine.length; i++) {
      out.add(mine[i]);
      if (mix && i.isOdd) {
        final l = _libraryVerse();
        if (l != null) out.add(l);
      }
    }
    if (mix) _more(out, 24);
    items = out;
    if (_page.hasClients) _page.jumpToPage(0);
  }

  void _more(List<WallItem> into, int n) {
    for (var i = 0; i < n; i++) {
      final l = _libraryVerse();
      if (l != null) into.add(l);
    }
  }

  Future<void> _onPage(int i) async {
    if (i < items.length - 6) return;
    final before = posts.length;
    if (!Cloud.i.wallEnd && Cloud.i.ready) {
      posts = await Cloud.i.wall(more: true);
      if (!mounted) return;
    }
    setState(() {
      for (final d in posts.skip(before)) {
        if (_keep(d)) items.add(WallItem.post(d));
      }
      if (filter == 0 || filter == 2) _more(items, 16);
    });
  }

  void _setFilter(int f) {
    if (f == filter && purpose.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      filter = f;
      _page.dispose();
      _page = PageController();
      _rebuild();
    });
  }

  Future<void> _pickPurpose() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('الغرض', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(label: const Text('كل الأغراض'), selected: purpose.isEmpty, onSelected: (_) => Navigator.pop(c, '')),
              for (final p in purposes) ChoiceChip(label: Text(p), selected: purpose == p, onSelected: (_) => Navigator.pop(c, p)),
            ]),
          ]),
        ),
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      purpose = r;
      _page.dispose();
      _page = PageController();
      _rebuild();
    });
  }

  Future<void> _publish() async {
    HapticFeedback.selectionClick();
    final r = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('انشر في «قوافي»', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('شعر فقط: لا نثر ولا صور.', style: TextStyle(color: C.muted(c))),
            const SizedBox(height: 16),
            _choice(c, Icons.edit_note_rounded, 'من شعري', 'قصيدة أو أبيات كتبتها أنت (قصيدتان في اليوم)', () => Navigator.pop(c, 0)),
            const SizedBox(height: 10),
            _choice(c, Icons.format_quote_rounded, 'اقتباس من المنتقيات', 'بيت من شعر التطبيق يظهر في صفحتك (عشرة في اليوم)', () => Navigator.pop(c, 1)),
          ]),
        ),
      ),
    );
    if (r == null || !mounted) return;
    if (!await needAccount(context, 'تنشر شعرك واقتباساتك فتظهر في صفحتك وفي «قوافي».') || !mounted) return;
    await push2(context, r == 0 ? const PublishOwnScreen() : const QuotePickerScreen());
    if (!mounted) return;
    posts = await Cloud.i.wall();
    if (mounted) setState(_rebuild);
  }

  Widget _choice(BuildContext c, IconData icon, String title, String sub, VoidCallback onTap) => Material(
        color: C.card(c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: C.line(c))),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon, size: 30, color: C.accent(c)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(c))),
                  Text(sub, style: TextStyle(fontSize: 13.5, color: C.muted(c))),
                ]),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        // the sideways filters must not shrink the bottom bar
        onNotification: (n) => n.metrics.axis == Axis.horizontal,
        child: Stack(children: [
          Positioned.fill(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(
                        child: EmptyNote(
                            Icons.history_edu_rounded, filter == 3 ? 'لا شيء ممن تتابعهم بعد. تابع القرّاء من صفحاتهم.' : 'لا شعر هنا بعد. كن أول من ينشر.'))
                    : PageView.builder(
                        controller: _page,
                        scrollDirection: Axis.vertical,
                        itemCount: items.length,
                        onPageChanged: _onPage,
                        itemBuilder: (context, i) => WallPage(
                          key: ValueKey(items[i].key),
                          item: items[i],
                          onGone: () => setState(() => items.removeAt(i)),
                        ),
                      ),
          ),
          // the filters along the top
          Positioned(
            top: top + 8,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                _pill(context, 'انشر', on: true, icon: Icons.edit_rounded, onTap: _publish),
                const SizedBox(width: 8),
                for (var i = 0; i < filters.length; i++) ...[
                  _pill(context, filters[i], selected: filter == i, onTap: () => _setFilter(i)),
                  const SizedBox(width: 8),
                ],
                _pill(context, purpose.isEmpty ? 'الغرض' : purpose, selected: purpose.isNotEmpty, icon: Icons.tune_rounded, onTap: _pickPurpose),
                const SizedBox(width: 8),
                _pill(context, '', icon: Icons.refresh_rounded, onTap: () => _load(refresh: true)),
                const SizedBox(width: 8),
                ListenableBuilder(
                  listenable: Cloud.i,
                  builder: (context, _) => GestureDetector(
                    onTap: () async {
                      if (!await needAccount(context, 'صفحتك فيها شعرك واقتباساتك ومن يتابعك.') || !context.mounted) return;
                      final c = Cloud.i;
                      openMember(context, uid: c.uid, name: c.name, publicId: c.publicId);
                    },
                    child: Monogram(name: Cloud.i.signedIn ? Cloud.i.name : 'ق', hue: _n(Cloud.i.profile['hue']), points: _n(Cloud.i.profile['points']), size: 42),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pill(BuildContext context, String text, {bool selected = false, bool on = false, IconData? icon, required VoidCallback onTap}) {
    final bg = on ? C.accent(context) : (selected ? C.ink(context) : C.bar(context).withValues(alpha: 0.9));
    final fg = on || selected ? (on ? Colors.white : C.bg(context)) : C.ink(context);
    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: on || selected ? Colors.transparent : C.line(context))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: text.isEmpty ? 10 : 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) Icon(icon, size: 18, color: fg),
            if (icon != null && text.isNotEmpty) const SizedBox(width: 6),
            if (text.isNotEmpty) Text(text, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }
}

Future<void> push2(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

// ------------------------------------------------------------ one page of the wall

class WallPage extends StatefulWidget {
  final WallItem item;
  final VoidCallback onGone;
  const WallPage({super.key, required this.item, required this.onGone});
  @override
  State<WallPage> createState() => _WallPageState();
}

class _WallPageState extends State<WallPage> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  WallItem get it => widget.item;

  @override
  void dispose() {
    _in.dispose();
    _burst.dispose();
    super.dispose();
  }

  bool get liked {
    if (it.post != null) return Cloud.i.likedQuotes.contains(it.post!['id']);
    return Store.i.liked(it.poem!.id);
  }

  int get likes => it.post != null ? _n(it.post!['likes']) : 0;

  Future<void> _like({bool fromTap = false}) async {
    if (fromTap && liked) {
      _burst.forward(from: 0);
      return;
    }
    HapticFeedback.lightImpact();
    if (it.post != null) {
      if (!await needAccount(context)) return;
      await Cloud.i.likeQuote(it.post!);
    } else {
      Store.i.toggleLike(it.poem!.id);
    }
    if (liked) _burst.forward(from: 0);
    if (mounted) setState(() {});
  }

  void _share() {
    final lines = it.lines;
    final src = it.source;
    if (src != null) {
      push(context, ShareCardScreen(poem: src, lines: lines));
    } else if (it.post != null) {
      push(context, ShareCardScreen(poem: asPoem(it.post!, lines), lines: lines.take(3).toList()));
    }
  }

  void _more() {
    final c = Cloud.i;
    final p = it.post;
    final mine = p != null && p['uid'] == c.uid;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('مشاركة النص'),
            onTap: () {
              Navigator.pop(s);
              final src = it.source;
              Share.share('${formatVerses(it.lines, mark: !c.noMark)}\n— ${it.poet}${src == null ? '' : '\n\n${poemLink(src)}'}');
            },
          ),
          if (it.source != null)
            ListTile(
              leading: const Icon(Icons.format_quote_rounded),
              title: const Text('اقتبسه في صفحتي'),
              onTap: () async {
                Navigator.pop(s);
                if (!await needAccount(context) || !mounted) return;
                final src = it.source!;
                final v = it.poem != null ? it.verse : _n(p?['v']);
                final err = await c.publishQuote(src, v);
                if (mounted) toast(context, err ?? 'نُشر اقتباسك في صفحتك');
              },
            ),
          if (p != null && !mine)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('إبلاغ'),
              onTap: () async {
                Navigator.pop(s);
                if (!await needAccount(context)) return;
                final ok = await c.report(it.own ? 'قصيدة عضو' : 'اقتباس', '${p['id']}', '${p['name']}: ${p['a']}', ofUid: '${p['uid']}');
                if (mounted) toast(context, ok ? 'وصل بلاغك إلى المشرفين' : 'تعذّر الإرسال');
              },
            ),
          if (p != null && (mine || c.can('مراجعة')))
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB3261E)),
              title: Text(mine ? 'احذف منشوري' : 'احذفه (إشراف)', style: const TextStyle(color: Color(0xFFB3261E))),
              onTap: () async {
                Navigator.pop(s);
                final ok = await c.deleteQuote('${p['id']}');
                if (!mounted) return;
                toast(context, ok ? 'حُذف' : 'تعذّر الحذف');
                if (ok) widget.onGone();
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = it.lines;
    final own = it.own;
    final p = it.post;
    final dark = C.dark(context);
    final paper = own ? (dark ? const Color(0xFF1F1A12) : const Color(0xFFFBF3DF)) : C.bg(context);
    final count = lines.length;
    final many = count > 4;
    final size = count <= 1 ? 27.0 : count <= 2 ? 25.0 : count <= 4 ? 22.0 : 20.0;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: Listenable.merge([Cloud.i, Store.i]),
      builder: (context, _) => GestureDetector(
        onDoubleTap: () => _like(fromTap: true),
        child: Container(
          color: paper,
          child: Stack(children: [
            // a quiet ornament behind the verses
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Ornament(C.accent(context).withValues(alpha: dark ? 0.07 : 0.06))))),
            // the verses
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, MediaQuery.paddingOf(context).top + 70, 28, 210 + bottom),
                child: Center(
                  child: SingleChildScrollView(
                    physics: many ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 46),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (own && '${p!['title'] ?? ''}'.isNotEmpty) ...[
                          Text('«${p['title']}»', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: C.accent(context), fontWeight: FontWeight.w700)),
                          const SizedBox(height: 14),
                        ],
                        for (var i = 0; i < lines.length && i < (many ? 8 : 4); i++)
                          _reveal(
                            i,
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(children: [
                                for (final h in lines[i])
                                  Text(Store.i.show(h),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontFamily: verseFont, fontSize: size * Store.i.fontScale, height: 1.85, color: C.ink(context))),
                              ]),
                            ),
                          ),
                        if (lines.length > (many ? 8 : 4))
                          TextButton(onPressed: _read, child: Text('بقية القصيدة (${Ar.verses(lines.length)})')),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            // the heart that blooms on a double tap
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _burst,
                  builder: (context, _) {
                    final t = _burst.value;
                    if (t == 0 || t == 1) return const SizedBox();
                    final s = Curves.elasticOut.transform(min(1, t * 1.6));
                    return Center(
                      child: Opacity(
                        opacity: t < 0.7 ? 1 : (1 - (t - 0.7) / 0.3),
                        child: Transform.scale(scale: 0.4 + s * 0.9, child: const Icon(Icons.favorite_rounded, size: 120, color: Color(0xFFB3261E))),
                      ),
                    );
                  },
                ),
              ),
            ),
            // the actions on the side
            PositionedDirectional(
              end: 8,
              bottom: 205 + bottom,
              child: Column(children: [
                _act(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, p != null ? Ar.num(likes) : '', _like,
                    color: liked ? const Color(0xFFB3261E) : null),
                _act(Icons.image_outlined, 'صورة', _share),
                _act(Icons.copy_rounded, 'نسخ', () => copyVerses(context, lines)),
                if (it.source != null) _act(Icons.menu_book_outlined, 'القصيدة', _read),
                _act(Icons.more_horiz_rounded, '', _more),
              ]),
            ),
            // who wrote it and where it comes from
            PositionedDirectional(
              start: 20,
              end: 20,
              bottom: 108 + bottom,
              child: _footer(context),
            ),
          ]),
        ),
      ),
    );
  }

  void _read() {
    final src = it.source;
    if (src != null) {
      push(context, PoemScreen(poem: src));
    } else if (it.own) {
      push(context, OwnPoemScreen(post: it.post!));
    }
  }

  Widget _reveal(int i, Widget child) => AnimatedBuilder(
        animation: _in,
        builder: (context, c) {
          final t = Curves.easeOutCubic.transform(((_in.value - i * 0.12) / 0.5).clamp(0.0, 1.0));
          return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: c));
        },
        child: child,
      );

  Widget _act(IconData icon, String label, VoidCallback onTap, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Column(children: [
            Icon(icon, size: 29, color: color ?? C.ink(context).withValues(alpha: 0.78)),
            if (label.isNotEmpty) Text(label, style: TextStyle(fontSize: 11.5, color: C.muted(context))),
          ]),
        ),
      );

  Widget _footer(BuildContext context) {
    final p = it.post;
    final src = it.source;
    final tags = <String>[
      if (it.own && '${p!['meter'] ?? ''}'.isNotEmpty) '${p['meter']}',
      if (it.own && '${p!['purpose'] ?? ''}'.isNotEmpty) '${p['purpose']}',
      if (src != null && src.era.isNotEmpty) src.era,
      if (src != null) src.chapterName,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        if (p != null) ...[
          GestureDetector(
            onTap: () => openMember(context, uid: '${p['uid']}', name: '${p['name']}', publicId: '${p['publicId'] ?? ''}'),
            child: Monogram(name: '${p['name']}', size: 34, hue: _n(p['hue'])),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () {
                if (it.own) {
                  openMember(context, uid: '${p!['uid']}', name: '${p['name']}', publicId: '${p['publicId'] ?? ''}');
                } else {
                  push(context, PoetScreen(name: it.poet));
                }
              },
              child: Text(it.poet, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: verseFont, fontSize: 21, fontWeight: FontWeight.w700, color: C.ink(context))),
            ),
            if (p != null && !it.own)
              GestureDetector(
                onTap: () => openMember(context, uid: '${p['uid']}', name: '${p['name']}', publicId: '${p['publicId'] ?? ''}'),
                child: Text('اقتبسه ${p['name']} · ${ago(p['at'])}', style: TextStyle(fontSize: 13, color: C.accent(context), fontWeight: FontWeight.w700)),
              )
            else if (it.own)
              Text('من شعره · ${ago(p!['at'])}', style: TextStyle(fontSize: 13, color: C.accent(context), fontWeight: FontWeight.w700))
            else
              Text('من المنتقيات', style: TextStyle(fontSize: 13, color: C.accent(context), fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
      if (tags.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tags.take(3)) Tag(t)]),
      ],
    ]);
  }
}

/// A faint eight-pointed star behind the verses.
class _Ornament extends CustomPainter {
  final Color color;
  _Ornament(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final c = Offset(size.width / 2, size.height * 0.44);
    final r = min(size.width, size.height) * 0.42;
    for (final rot in [0.0, pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = rot + pi / 4 + i * pi / 2;
        final pt = c + Offset(cos(a) * r, sin(a) * r);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(c, r * 0.86, paint);
    canvas.drawCircle(c, r * 0.80, paint..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(_Ornament old) => old.color != color;
}

// ------------------------------------------------------------ a member's poem, whole

class OwnPoemScreen extends StatelessWidget {
  final Doc post;
  const OwnPoemScreen({super.key, required this.post});
  @override
  Widget build(BuildContext context) {
    final it = WallItem.post(post);
    final lines = it.lines;
    return ListenableBuilder(
      listenable: Cloud.i,
      builder: (context, _) {
        final liked = Cloud.i.likedQuotes.contains(post['id']);
        return Scaffold(
          appBar: AppBar(title: Text('${post['title'] ?? ''}'.isEmpty ? 'قصيدة' : '${post['title']}')),
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 60), children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => openMember(context, uid: '${post['uid']}', name: '${post['name']}', publicId: '${post['publicId'] ?? ''}'),
              child: Row(children: [
                Monogram(name: '${post['name']}', hue: _n(post['hue']), size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${post['name']}', style: TextStyle(fontFamily: verseFont, fontSize: 21, fontWeight: FontWeight.w700, color: C.ink(context))),
                    Text(ago(post['at']), style: TextStyle(color: C.muted(context))),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if ('${post['meter'] ?? ''}'.isNotEmpty) Tag('بحر ${post['meter']}'),
              if ('${post['purpose'] ?? ''}'.isNotEmpty) Tag('${post['purpose']}'),
              Tag(Ar.verses(lines.length)),
            ]),
            const SizedBox(height: 16),
            for (var i = 0; i < lines.length; i++) ...[
              VerseLines(lines[i], size: 22),
              if (i < lines.length - 1) Center(child: Text('..', style: TextStyle(fontSize: 20, color: C.accent(context)))),
            ],
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: () async {
                  if (await needAccount(context)) Cloud.i.likeQuote(post);
                },
                icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? const Color(0xFFB3261E) : null),
              ),
              Text(Ar.num(_n(post['likes'])), style: TextStyle(color: C.muted(context))),
              const SizedBox(width: 12),
              IconButton(tooltip: 'نسخ القصيدة', onPressed: () => copyVerses(context, lines), icon: const Icon(Icons.copy_rounded)),
              IconButton(
                tooltip: 'صورة',
                onPressed: () => push(context, ShareCardScreen(poem: asPoem(post, lines), lines: lines.take(3).toList())),
                icon: const Icon(Icons.image_outlined),
              ),
            ]),
          ]),
        );
      },
    );
  }
}

// ------------------------------------------------------------ publishing one's own poetry

class PublishOwnScreen extends StatefulWidget {
  const PublishOwnScreen({super.key});
  @override
  State<PublishOwnScreen> createState() => _PublishOwnScreenState();
}

class _PublishOwnScreenState extends State<PublishOwnScreen> {
  final title = TextEditingController();
  final rows = <(TextEditingController, TextEditingController)>[(TextEditingController(), TextEditingController())];
  String meter = '';
  String purpose = '';
  bool pledge = false;
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    for (final r in rows) {
      r.$1.dispose();
      r.$2.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final lines = [
      for (final r in rows)
        if (r.$1.text.trim().isNotEmpty) [r.$1.text.trim(), if (r.$2.text.trim().isNotEmpty) r.$2.text.trim()]
    ];
    String? err;
    if (lines.isEmpty) {
      err = 'اكتب بيتاً واحداً على الأقل.';
    } else if (lines.any((l) => l.length < 2)) {
      err = 'لكل بيت شطران: أكمل العجز في كل بيت.';
    } else if (!pledge) {
      err = 'أقرّ أولاً بأن الشعر لك.';
    }
    if (err != null) {
      toast(context, err);
      return;
    }
    setState(() => busy = true);
    final r = await Cloud.i.publishOwn(title: title.text, lines: lines, meter: meter, purpose: purpose);
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, r ?? 'نُشرت قصيدتك');
    if (r == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final left = Cloud.i.ownLeft;
    return Scaffold(
      appBar: AppBar(title: const Text('انشر من شعرك')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 120), children: [
        Text('شعر فقط، كتبته أنت. بقي لك اليوم ${Ar.num(left < 0 ? 0 : left)} من قصيدتين.', style: TextStyle(color: C.muted(context), height: 1.6)),
        const SizedBox(height: 14),
        TextField(controller: title, maxLength: 40, decoration: const InputDecoration(labelText: 'عنوان القصيدة (اختياري)')),
        const SizedBox(height: 6),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Column(children: [
                Row(children: [
                  Text('البيت ${Ar.num(i + 1)}', style: TextStyle(fontWeight: FontWeight.w700, color: C.accent(context))),
                  const Spacer(),
                  if (rows.length > 1)
                    IconButton(
                      tooltip: 'احذف البيت',
                      onPressed: () => setState(() => rows.removeAt(i)),
                      icon: Icon(Icons.close_rounded, color: C.muted(context)),
                    ),
                ]),
                TextField(
                  controller: rows[i].$1,
                  maxLength: 90,
                  style: const TextStyle(fontFamily: verseFont, fontSize: 19),
                  decoration: const InputDecoration(hintText: 'الصدر', counterText: ''),
                ),
                TextField(
                  controller: rows[i].$2,
                  maxLength: 90,
                  style: const TextStyle(fontFamily: verseFont, fontSize: 19),
                  decoration: const InputDecoration(hintText: 'العجز', counterText: ''),
                ),
              ]),
            ),
          ),
        if (rows.length < 60)
          OutlinedButton.icon(
            onPressed: () => setState(() => rows.add((TextEditingController(), TextEditingController()))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('أضف بيتاً'),
          ),
        const SizedBox(height: 16),
        Text('البحر', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ChoiceChip(label: const Text('لا أدري'), selected: meter.isEmpty, onSelected: (_) => setState(() => meter = '')),
          for (final m in meters) ChoiceChip(label: Text(m), selected: meter == m, onSelected: (_) => setState(() => meter = m)),
        ]),
        const SizedBox(height: 16),
        Text('الغرض', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in purposes) ChoiceChip(label: Text(m), selected: purpose == m, onSelected: (_) => setState(() => purpose = purpose == m ? '' : m)),
        ]),
        const SizedBox(height: 14),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: pledge,
          onChanged: (v) => setState(() => pledge = v ?? false),
          title: const Text('أقرّ أن هذا الشعر لي، وأنه خالٍ مما يخالف الشرع والأدب.'),
          subtitle: const Text('يراجع المشرفون ما يُنشر، ويُحذف المخالف.'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: busy ? null : _send,
          icon: const Icon(Icons.send_rounded),
          label: Text(busy ? 'جارٍ النشر…' : 'انشر', style: const TextStyle(fontSize: 17)),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------ the member's page

class MemberScreen extends StatefulWidget {
  final String uid;
  final String name;
  final String publicId;
  const MemberScreen({super.key, required this.uid, required this.name, this.publicId = ''});
  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  Doc? user;
  List<Doc> posts = [];
  bool loading = true;
  int tab = 0; // 0 his poetry, 1 his quotes
  int sort = 0; // 0 newest, 1 most liked
  Future<int>? followers;
  int followersN = 0;

  bool get mine => widget.uid == Cloud.i.uid && Cloud.i.signedIn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = Cloud.i;
    final r = await Future.wait([c.userByUid(widget.uid), c.quotes(of: widget.uid)]);
    if (!mounted) return;
    setState(() {
      user = r[0] as Doc?;
      posts = r[1] as List<Doc>;
      loading = false;
      followers = c.signedIn ? c.followersCount(widget.uid) : null;
      followers?.then((v) {
        if (mounted) setState(() => followersN = v);
      });
      if (posts.where((p) => p['kind'] == 'own').isEmpty) tab = 1;
    });
  }

  Doc get u => mine ? {...Cloud.i.profile, 'uid': Cloud.i.uid} : (user ?? {});
  String get name => '${u['name'] ?? widget.name}'.trim().isEmpty ? widget.name : '${u['name'] ?? widget.name}';
  String get publicId => '${u['publicId'] ?? widget.publicId}';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Cloud.i, Store.i]),
        builder: (context, _) {
          final c = Cloud.i;
          final own = posts.where((p) => p['kind'] == 'own').toList();
          final quotes = posts.where((p) => p['kind'] != 'own').toList();
          final likes = posts.fold<int>(0, (a, p) => a + _n(p['likes']));
          return Scaffold(
            appBar: AppBar(title: Text(name), actions: [
              IconButton(
                tooltip: 'المزيد',
                icon: const Icon(Icons.more_horiz_rounded),
                onPressed: () => _menu(context),
              ),
            ]),
            body: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), children: [
                    _head(context),
                    const SizedBox(height: 14),
                    _stats(context, own.length, quotes.length, likes),
                    const SizedBox(height: 10),
                    MedalsRow(
                      name: name,
                      counts: medalCounts(user: u, own: own.length, quotes: quotes.length, likes: likes, followers: followersN),
                    ),
                    const SizedBox(height: 12),
                    _favVerse(context),
                    _fingerprint(context, own, quotes),
                    const SizedBox(height: 10),
                    Row(children: [
                      _tabBtn(context, 'ديوانه ${Ar.num(own.length)}', 0),
                      const SizedBox(width: 8),
                      _tabBtn(context, 'اقتباساته ${Ar.num(quotes.length)}', 1),
                      const Spacer(),
                      PopupMenuButton<int>(
                        tooltip: 'الترتيب',
                        initialValue: sort,
                        onSelected: (v) => setState(() => sort = v),
                        itemBuilder: (_) => const [PopupMenuItem(value: 0, child: Text('الأحدث')), PopupMenuItem(value: 1, child: Text('الأكثر إعجاباً'))],
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(children: [
                            Icon(Icons.sort_rounded, color: C.muted(context)),
                            const SizedBox(width: 4),
                            Text(sort == 0 ? 'الأحدث' : 'الأكثر إعجاباً', style: TextStyle(color: C.muted(context))),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ..._list(context, tab == 0 ? own : quotes),
                    if (!c.signedIn) ...[
                      const SizedBox(height: 16),
                      Text('ادخل بحسابك لترى المتابِعين وتفاصيل الصفحة كاملة.', textAlign: TextAlign.center, style: TextStyle(color: C.muted(context))),
                    ],
                  ]),
          );
        },
      );

  Widget _head(BuildContext context) {
    final c = Cloud.i;
    final country = '${u['country'] ?? ''}';
    final bio = '${u['bio'] ?? ''}';
    final poets = List<String>.from(u['favPoets'] as List? ?? []);
    final following = c.following.containsKey(publicId);
    final joined = u['joined'];
    return Column(children: [
      const SizedBox(height: 8),
      Monogram(name: name, hue: _n(u['hue']), points: _n(u['points']), size: 118),
      const SizedBox(height: 12),
      Text(name, textAlign: TextAlign.center, style: TextStyle(fontFamily: verseFont, fontSize: 32, fontWeight: FontWeight.w700, color: C.ink(context), height: 1.3)),
      const SizedBox(height: 4),
      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
        if (country.isNotEmpty) Text('${flagOf(country)} $country', style: TextStyle(fontSize: 16, color: C.muted(context))),
        if (publicId.isNotEmpty)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: publicId));
              toast(context, 'نُسخ الرقم الشخصي');
            },
            child: Text('#$publicId', style: TextStyle(fontSize: 16, color: C.muted(context))),
          ),
      ]),
      if (bio.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(bio, textAlign: TextAlign.center, style: TextStyle(fontFamily: verseFont, fontSize: 19, height: 1.7, color: C.ink(context))),
      ],
      if (poets.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('شعرائي: ', style: TextStyle(fontSize: 16, color: C.muted(context))),
          for (var i = 0; i < poets.length; i++) ...[
            InkWell(
              onTap: () => push(context, PoetScreen(name: poets[i])),
              child: Text(poets[i], style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context))),
            ),
            if (i < poets.length - 1) Text(' · ', style: TextStyle(color: C.muted(context))),
          ],
        ]),
      ],
      const SizedBox(height: 10),
      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
        if (posts.any((p) => p['kind'] == 'own')) _badge(context, Icons.history_edu_rounded, 'شاعر', const Color(0xFFB08A3E)),
        if (u['plus'] == true) _badge(context, Icons.workspace_premium_outlined, 'مشترك', const Color(0xFF2F6B4F)),
        if (u['points'] != null) RankBadge(_n(u['points']), small: true),
        if (joined is num)
          Text('عضو منذ ${_since(joined.toInt())}', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
      ]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (mine)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.ink(context), foregroundColor: C.bg(context), padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14)),
            onPressed: () async {
              await push2(context, const EditMemberScreen());
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('حرّر صفحتك', style: TextStyle(fontSize: 16.5)),
          )
        else
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: following ? C.soft(context) : C.ink(context),
              foregroundColor: following ? C.ink(context) : C.bg(context),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            ),
            onPressed: () async {
              if (!await needAccount(context, 'تتابع القرّاء فيظهر شعرهم في «أتابعهم».')) return;
              c.follow(publicId, name, !following, ofUid: widget.uid);
              setState(() => followers = c.followersCount(widget.uid));
              followers?.then((v) {
                if (mounted) setState(() => followersN = v);
              });
            },
            child: Text(following ? 'تتابعه' : 'متابعة', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: 'شارك الصفحة',
          onPressed: () => Share.share('صفحة $name في «منتقيات الشعر»\nرقمه الشخصي: $publicId\n$siteUrl'),
          icon: const Icon(Icons.ios_share_rounded),
        ),
      ]),
    ]);
  }

  Widget _badge(BuildContext context, IconData icon, String t, Color col) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: col.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: col, width: 1.1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: col),
          const SizedBox(width: 4),
          Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: col)),
        ]),
      );

  Widget _stats(BuildContext context, int own, int quotes, int likes) {
    final c = Cloud.i;
    Widget cell(Widget n, String label, [VoidCallback? onTap]) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [n, const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 13, color: C.muted(context)))]),
            ),
          ),
        );
    final st = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.ink(context));
    final fol = List<String>.from(u['following'] as List? ?? []);
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Row(children: [
        cell(Text(Ar.num(own), style: st), 'القصائد', () => setState(() => tab = 0)),
        cell(Text(Ar.num(quotes), style: st), 'الاقتباسات', () => setState(() => tab = 1)),
        cell(
          followers == null ? Text('—', style: st) : FutureBuilder<int>(future: followers, builder: (_, s) => Text(Ar.num(s.data ?? 0), style: st)),
          'المتابِعون',
          c.signedIn ? () => push(context, FollowListScreen(title: 'متابِعو $name', load: () => c.followers(widget.uid))) : null,
        ),
        cell(Text(Ar.num(fol.length), style: st), 'يتابع', c.signedIn ? () => push(context, FollowListScreen(title: 'يتابعهم $name', load: () => c.usersByUid(fol))) : null),
        cell(Text(Ar.num(likes), style: st), 'الإعجابات'),
      ]),
    );
  }

  Widget _favVerse(BuildContext context) {
    final f = u['favVerse'];
    if (f is! Map || '${f['a'] ?? ''}'.isEmpty) return const SizedBox();
    final line = <String>['${f['a']}', if ('${f['b'] ?? ''}'.isNotEmpty) '${f['b']}'];
    final poem = Library.byId[_n(f['poem'])];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: poem == null ? null : () => push(context, PoemScreen(poem: poem)),
        child: Column(children: [
          Text('بيتي المفضّل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.accent(context))),
          const SizedBox(height: 6),
          for (final h in line)
            Text(Store.i.show(h), textAlign: TextAlign.center, style: TextStyle(fontFamily: verseFont, fontSize: 23 * Store.i.fontScale, height: 1.8, color: C.ink(context))),
          const SizedBox(height: 4),
          Text('${f['poet'] ?? ''}', style: TextStyle(color: C.muted(context))),
        ]),
      ),
    );
  }

  /// «بصمته الشعرية»: what the page tells about the reader's taste.
  Widget _fingerprint(BuildContext context, List<Doc> own, List<Doc> quotes) {
    String top(Iterable<String> xs) {
      final m = <String, int>{};
      for (final x in xs) {
        if (x.trim().isNotEmpty) m[x] = (m[x] ?? 0) + 1;
      }
      if (m.isEmpty) return '';
      return (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    }

    final quoted = [for (final q in quotes) Library.byId[_n(q['poem'])]].whereType<Poem>().toList();
    final meter = top(own.map((p) => '${p['meter'] ?? ''}'));
    final purpose = top(own.map((p) => '${p['purpose'] ?? ''}'));
    final poet = top(quoted.map((p) => p.poet).where((x) => x != 'بلا نسبة'));
    final era = top(quoted.map((p) => p.era));
    final eras = <String, int>{};
    for (final p in quoted) {
      if (p.era.isNotEmpty) eras[p.era] = (eras[p.era] ?? 0) + 1;
    }
    final cells = [
      if (meter.isNotEmpty) ('يكتب على', meter),
      if (purpose.isNotEmpty) ('أغراضه', purpose),
      if (poet.isNotEmpty) ('شاعره الأقرب', poet),
      if (era.isNotEmpty) ('عصره الأقرب', era),
    ];
    if (cells.isEmpty) return const SizedBox();
    final total = eras.values.fold<int>(0, (a, b) => a + b);
    final sorted = eras.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    const shades = [Color(0xFF8C4A2F), Color(0xFFB08A3E), Color(0xFF7B746A), Color(0xFFB9B1A4), Color(0xFFD8D1C4)];
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.fingerprint_rounded, color: C.accent(context)),
          const SizedBox(width: 6),
          Text('بصمته الشعرية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
        ]),
        const SizedBox(height: 10),
        Wrap(runSpacing: 14, children: [
          for (final c in cells)
            FractionallySizedBox(
              widthFactor: 0.5,
              child: Column(children: [
                Text(c.$1, style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                const SizedBox(height: 2),
                Text(c.$2, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: verseFont, fontSize: 22, color: C.ink(context))),
              ]),
            ),
        ]),
        if (total > 0) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(children: [
                for (var i = 0; i < sorted.length && i < 5; i++) Expanded(flex: max(1, sorted[i].value * 100 ~/ total), child: ColoredBox(color: shades[i])),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 4, children: [
            for (var i = 0; i < sorted.length && i < 5; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: shades[i], shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${Ar.num(sorted[i].value * 100 ~/ total)}٪ ${sorted[i].key}', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
              ]),
          ]),
          const SizedBox(height: 2),
          Text('من عصور ما اقتبسه', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted(context))),
        ],
      ]),
    );
  }

  Widget _tabBtn(BuildContext context, String t, int i) {
    final on = tab == i;
    return Material(
      color: on ? C.accent(context) : C.soft(context),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => setState(() => tab = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(t, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: on ? Colors.white : C.ink(context))),
        ),
      ),
    );
  }

  List<Widget> _list(BuildContext context, List<Doc> list) {
    if (list.isEmpty) {
      return [
        EmptyNote(tab == 0 ? Icons.history_edu_rounded : Icons.format_quote_rounded,
            tab == 0 ? (mine ? 'لم تنشر من شعرك بعد. انشر من «قوافي».' : 'لم ينشر من شعره بعد.') : (mine ? 'لم تقتبس بعد.' : 'لا اقتباسات بعد.')),
      ];
    }
    final l = [...list];
    if (sort == 1) l.sort((a, b) => _n(b['likes']).compareTo(_n(a['likes'])));
    return [
      for (final p in l)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _card(context, p),
        ),
    ];
  }

  Widget _card(BuildContext context, Doc p) {
    final it = WallItem.post(p);
    final lines = it.lines;
    final own = it.own;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      onTap: () {
        if (own) {
          push(context, OwnPoemScreen(post: p));
        } else if (it.source != null) {
          push(context, PoemScreen(poem: it.source!));
        }
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (own && '${p['title'] ?? ''}'.isNotEmpty)
          Text('${p['title']}', style: TextStyle(fontFamily: verseFont, fontSize: 21, fontWeight: FontWeight.w700, color: C.ink(context))),
        if (lines.isNotEmpty) Text(Store.i.show(lines.first.first), style: TextStyle(fontFamily: verseFont, fontSize: own ? 18 : 21, height: 1.8, color: own ? C.muted(context) : C.ink(context))),
        if (!own && lines.isNotEmpty && lines.first.length > 1)
          Text(Store.i.show(lines.first[1]), style: TextStyle(fontFamily: verseFont, fontSize: 21, height: 1.8, color: C.ink(context))),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text(
              [
                if (own) Ar.verses(lines.length) else '${p['poet']}',
                if (own && '${p['meter'] ?? ''}'.isNotEmpty) '${p['meter']}',
                ago(p['at']),
              ].join('  ·  '),
              style: TextStyle(fontSize: 13, color: C.muted(context)),
            ),
          ),
          const Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFB3261E)),
          const SizedBox(width: 3),
          Text(Ar.num(_n(p['likes'])), style: const TextStyle(color: Color(0xFFB3261E))),
        ]),
      ]),
    );
  }

  void _menu(BuildContext context) {
    final c = Cloud.i;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (publicId.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.tag_rounded),
              title: Text('انسخ الرقم الشخصي ($publicId)'),
              onTap: () {
                Navigator.pop(s);
                Clipboard.setData(ClipboardData(text: publicId));
                toast(context, 'نُسخ');
              },
            ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('حسابي وأرقامي'),
              onTap: () {
                Navigator.pop(s);
                push(context, const ProfileScreen());
              },
            ),
          if (!mine && user != null)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('إبلاغ عن الصفحة'),
              onTap: () async {
                Navigator.pop(s);
                final ok = await c.report('اسم', publicId, name, ofUid: widget.uid);
                if (context.mounted) toast(context, ok ? 'وصل بلاغك إلى المشرفين' : 'تعذّر الإرسال');
              },
            ),
          if (!mine && user != null && (c.isDev || c.can('حظر')))
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('الإشراف وتفاصيل الحساب'),
              onTap: () {
                Navigator.pop(s);
                push(context, UserScreen(user: user!));
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------ editing one's page

class EditMemberScreen extends StatefulWidget {
  const EditMemberScreen({super.key});
  @override
  State<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends State<EditMemberScreen> {
  final c = Cloud.i;
  late final name = TextEditingController(text: c.name);
  late final bio = TextEditingController(text: '${c.profile['bio'] ?? ''}');
  late String country = '${c.profile['country'] ?? ''}';
  late List<String> poets = List<String>.from(c.profile['favPoets'] as List? ?? []);
  late Map? fav = c.profile['favVerse'] as Map?;
  late int hue = _n(c.profile['hue']);
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => busy = true);
    var ok = true;
    if (name.text.trim() != c.name && name.text.trim().isNotEmpty) ok = await c.setName(name.text.trim());
    ok = await c.setProfile({
          'bio': bio.text.trim(),
          'country': country,
          'favPoets': poets,
          'favVerse': fav ?? {},
          'hue': hue,
        }) &&
        ok;
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, ok ? 'حُفظت صفحتك' : 'تعذّر الحفظ. تحقّق من الإنترنت.');
    if (ok) Navigator.pop(context);
  }

  Future<void> _pickPoet() async {
    final r = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _PoetPicker()));
    if (r != null && !poets.contains(r)) setState(() => poets = [...poets, r].take(3).toList());
  }

  Future<void> _pickVerse() async {
    final r = await Navigator.of(context).push<Map>(MaterialPageRoute(builder: (_) => const _VersePicker()));
    if (r != null) setState(() => fav = r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حرّر صفحتك')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 60), children: [
        Center(child: Monogram(name: name.text.isEmpty ? c.name : name.text, hue: hue, points: _n(c.profile['points']), size: 104)),
        const SizedBox(height: 8),
        Text('لا صور في التطبيق: حرف اسمك الأول يُكتب بخط الرقعة، فاختر لونه.', textAlign: TextAlign.center, style: TextStyle(color: C.muted(context))),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < inks.length; i++)
            ChoiceChip(
              avatar: CircleAvatar(backgroundColor: inks[i], radius: 9),
              label: Text(inkNames[i]),
              selected: hue == i,
              onSelected: (_) => setState(() => hue = i),
            ),
        ]),
        const SizedBox(height: 18),
        TextField(controller: name, maxLength: 20, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'اسمك الظاهر للناس')),
        TextField(
          controller: bio,
          maxLength: 120,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'نبذة قصيرة أو بيت تحبه'),
        ),
        const SizedBox(height: 8),
        Text('بلدك', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ChoiceChip(label: const Text('لا أذكره'), selected: country.isEmpty, onSelected: (_) => setState(() => country = '')),
          for (final x in countries) ChoiceChip(label: Text('${x.$1} ${x.$2}'), selected: country == x.$2, onSelected: (_) => setState(() => country = x.$2)),
        ]),
        const SizedBox(height: 18),
        Text('شعرائي (ثلاثة على الأكثر)', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in poets) InputChip(label: Text(p), onDeleted: () => setState(() => poets = [...poets]..remove(p))),
          if (poets.length < 3) ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('أضف شاعراً'), onPressed: _pickPoet),
        ]),
        const SizedBox(height: 18),
        Text('بيتي المفضّل', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 6),
        if (fav != null && '${fav!['a'] ?? ''}'.isNotEmpty)
          SoftCard(
            padding: const EdgeInsets.all(14),
            onTap: _pickVerse,
            child: Column(children: [
              VerseLines(['${fav!['a']}', if ('${fav!['b'] ?? ''}'.isNotEmpty) '${fav!['b']}'], size: 18),
              Text('${fav!['poet'] ?? ''}', style: TextStyle(color: C.muted(context))),
            ]),
          )
        else
          OutlinedButton.icon(onPressed: _pickVerse, icon: const Icon(Icons.format_quote_rounded), label: const Text('اختر بيتاً من المنتقيات')),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: busy ? null : _save,
          child: Text(busy ? 'جارٍ الحفظ…' : 'احفظ', style: const TextStyle(fontSize: 17)),
        ),
      ]),
    );
  }
}

class _PoetPicker extends StatefulWidget {
  const _PoetPicker();
  @override
  State<_PoetPicker> createState() => _PoetPickerState();
}

class _PoetPickerState extends State<_PoetPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final n = Ar.norm(q);
    final list = Library.namedPoets.where((p) => n.isEmpty || Ar.norm(p.name).contains(n)).take(80).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('اختر شاعراً')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ابحث باسم الشاعر', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 8),
        for (final p in list)
          ListTile(
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([p.era, p.death].where((x) => x.isNotEmpty).join(' · ')),
            onTap: () => Navigator.pop(context, p.name),
          ),
      ]),
    );
  }
}

class _VersePicker extends StatefulWidget {
  const _VersePicker();
  @override
  State<_VersePicker> createState() => _VersePickerState();
}

class _VersePickerState extends State<_VersePicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final n = Ar.norm(q);
    final found = <(Poem, int)>[];
    final pool = n.length < 2 ? Library.poems.where((p) => Store.i.likes.contains(p.id)).followedBy(Library.poems.take(30)) : Library.poems;
    for (final p in pool) {
      for (var i = 0; i < p.lines.length && found.length < 80; i++) {
        if (p.gone(i + 1)) continue;
        if (n.length < 2 ? i < 1 : (Ar.norm(p.lines[i].join(' ')).contains(n) || (Ar.norm(p.poet).contains(n) && i < 2))) found.add((p, i));
      }
      if (found.length >= 80) break;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('اختر بيتك المفضّل')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ابحث بكلمة من البيت أو باسم الشاعر', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 10),
        for (final (p, i) in found)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              padding: const EdgeInsets.all(12),
              onTap: () => Navigator.pop(context, {
                'a': p.lines[i][0],
                'b': p.lines[i].length > 1 ? p.lines[i][1] : '',
                'poet': p.poet,
                'poem': p.id,
              }),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                VerseLines(p.lines[i], size: 18),
                Text(p.poet, style: TextStyle(fontSize: 13, color: C.accent(context))),
              ]),
            ),
          ),
      ]),
    );
  }
}
