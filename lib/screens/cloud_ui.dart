import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../services/device.dart';
import '../ui.dart';
import 'boards.dart';
import 'golden.dart';
import 'group_challenge.dart';
import 'lists.dart';
import 'vault.dart';
import 'majlis.dart';
import 'majlis_plus.dart';
import 'mutun.dart';
import 'poem.dart';
import 'qawafi.dart' show titlePresets, earlyTitle, bronze, MemberScreen, DraftsScreen;
import 'sharh.dart';

// Screens that talk to the server: accounts, quotes, tests by number,
// messages, reports, subscribers and statistics.

Widget _section(BuildContext context, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
    );

Widget _row(BuildContext context, IconData icon, String title, String sub, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          RoundIcon(icon, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context))),
              if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 13.5, color: C.muted(context), height: 1.5)),
            ]),
          ),
          Icon(Icons.chevron_left_rounded, color: C.muted(context)),
        ]),
      ),
    );

int _n(dynamic v) => v is num ? (v < 0 ? 0 : v.toInt()) : 0;

String ago(dynamic ms) {
  if (ms is! num) return '';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms.toInt()));
  if (d.inMinutes < 2) return 'الآن';
  if (d.inHours < 1) return 'قبل ${Ar.num(d.inMinutes)} دقيقة';
  if (d.inDays < 1) return 'قبل ${Ar.num(d.inHours)} ساعة';
  return 'قبل ${Ar.num(d.inDays)} يوماً';
}

/// Asks the reader to sign in with Google when a feature needs an account.
Future<bool> needAccount(BuildContext context, [String why = '']) async {
  if (Cloud.i.signedIn) return true;
  final go = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ادخل بحسابك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${why.isEmpty ? '' : '$why\n\n'}تدخل ${Cloud.onApple ? 'بحساب Apple أو جوجل' : 'بحساب جوجل'} بضغطة واحدة، فيكون لك رقم شخصي ثابت من سبعة أرقام. لا نطلب كلمة مرور، ولا يظهر بريدك لأحد من القرّاء.',
            style: const TextStyle(fontSize: 16, height: 1.7)),
        const SizedBox(height: 16),
        if (Cloud.onApple) ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => Navigator.pop(c, 'apple'),
            icon: const Icon(Icons.apple, size: 24),
            label: const Text('ادخل بحساب Apple', style: TextStyle(fontSize: 17)),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => Navigator.pop(c, 'google'),
          icon: const Icon(Icons.login_rounded),
          label: const Text('ادخل بحساب جوجل', style: TextStyle(fontSize: 17)),
        ),
      ]),
    ),
  );
  if (go == null || !context.mounted) return false;
  final err = await Cloud.i.signIn(apple: go == 'apple');
  if (!context.mounted) return false;
  if (err != null) {
    toast(context, err);
    return false;
  }
  toast(context, 'أهلاً بك. رقمك الشخصي: ${Cloud.i.publicId}');
  return true;
}

// ------------------------------------------------------------ profile

/// Old way in. The one personal page is [MemberScreen]: the reader's own page holds his
/// numbers, achievements and account as well. With no account, he is asked to sign in.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Cloud.i,
        builder: (context, _) {
          final c = Cloud.i;
          if (c.signedIn) return MemberScreen(uid: c.uid, name: c.name, publicId: c.publicId);
          return Scaffold(
            appBar: AppBar(title: const Text('صفحتك الشخصية')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: RoundIcon(Icons.person_rounded, size: 84)),
                const SizedBox(height: 14),
                Text('ادخل بحسابك لتكون لك صفحة شخصية برقم ثابت: ديوانك واقتباساتك وأوسمتك ومتابعوك.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 16.5, height: 1.7, color: C.muted(context))),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => needAccount(context),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(Cloud.signInLabel, style: const TextStyle(fontSize: 17)),
                ),
              ]),
            ),
          );
        },
      );
}

/// «إنجازاتي» in the reader's own page: بيوت الذهب, his numbers and what he memorized.
class MyAchievements extends StatelessWidget {
  const MyAchievements({super.key});

  Widget _stat(BuildContext context, String n, String label) => Expanded(
        child: Column(children: [
          Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.accent(context))),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = Store.i, c = Cloud.i;
    final memo = s.memorized.values.fold<int>(0, (a, b) => a + b.length);
    final joined = c.profile['joined'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Row(children: [
          _stat(context, Ar.num(_n(c.profile['points'])), 'نقطة'),
          _stat(context, Ar.num(memo), 'بيتاً حفظه'),
          _stat(context, Ar.num(_n(c.profile['streak'])), 'يوماً متتالياً'),
          _stat(context, Ar.num(s.days.length), 'يوماً'),
          _stat(context, Ar.num(s.likes.length), 'إعجاب'),
        ]),
      ),
      const SizedBox(height: 10),
      const GoldenSummary(),
      const SizedBox(height: 10),
      _row(context, Icons.map_outlined, 'خريطة قراءتي', 'قرأت ${Ar.num(ReadingMapScreen.percent())}٪ من الكتاب', () => push(context, const ReadingMapScreen())),
      _row(context, Icons.bookmark_border_rounded, 'المحفوظات', 'حفظت ${Ar.verses(memo)}', () => push(context, const MutunScreen())),
      _row(context, Icons.people_outline_rounded, 'شعرائي', '${Ar.num(s.followed.length)} من الشعراء تتابعهم', () => push(context, const MyPoetsScreen())),
      if (c.hasTitle('الشارح')) _row(context, Icons.menu_book_rounded, 'شروحي', 'ما شرحته من الأبيات', () => push(context, SharhListScreen(uid: c.uid, name: c.name))),
      _row(context, Icons.workspace_premium_outlined, 'اطلب شارة', 'الشارح، المقتبس، شاعر موثّق…', () => requestBadge(context)),
      if (joined is num)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('سجّلت ${ago(joined)}. تُحدَّث الأرقام على الخادم مرة في اليوم.', textAlign: TextAlign.center, style: TextStyle(color: C.muted(context), fontSize: 13.5)),
        ),
    ]);
  }
}

/// «خريطة قراءتي»: how much of every chapter of the book the reader has opened.
class ReadingMapScreen extends StatelessWidget {
  const ReadingMapScreen({super.key});

  static int percent() {
    final all = Library.poems.length;
    if (all == 0) return 0;
    return Library.poems.where((p) => (Store.i.reads[p.id] ?? 0) > 0).length * 100 ~/ all;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final r = Store.i.reads;
          final all = Library.poems.length;
          final done = Library.poems.where((p) => (r[p.id] ?? 0) > 0).length;
          final bySection = <int, List<Chapter>>{};
          for (final c in Library.chapters) {
            bySection.putIfAbsent(c.section, () => []).add(c);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('خريطة قراءتي')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('قرأت ${Ar.num(done)} من ${Ar.num(all)} مقطعاً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: all == 0 ? 0 : done / all, minHeight: 10, borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 6),
                  Text('${Ar.num(all == 0 ? 0 : done * 100 ~/ all)}٪ من «${Library.book}». يُحسب المقطع مقروءاً إذا فتحته.', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                ]),
              ),
              for (final e in bySection.entries) ...[
                if (e.key >= 0 && e.key < Library.sections.length) _section(context, Library.sections[e.key]),
                for (final c in e.value) _chapter(context, c, r),
              ],
            ]),
          );
        },
      );

  Widget _chapter(BuildContext context, Chapter c, Map<int, int> r) {
    final list = Library.ofChapter(c.index);
    if (list.isEmpty) return const SizedBox.shrink();
    final done = list.where((p) => (r[p.id] ?? 0) > 0).length;
    final full = done == list.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        onTap: () => openList(context, c.name, list),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(c.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context)))),
            if (full) const Icon(Icons.check_circle_rounded, size: 18, color: bookGreen),
            const SizedBox(width: 6),
            Text('${Ar.num(done)} / ${Ar.num(list.length)}', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: done / list.length, minHeight: 6, borderRadius: BorderRadius.circular(4), color: full ? bookGreen : null),
        ]),
      ),
    );
  }
}

/// «حسابي» in the reader's own page: whom he follows, his page's background, signing out.
class MyAccount extends StatelessWidget {
  const MyAccount({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Cloud.i;
    void home() => Navigator.of(context).popUntil((r) => r.isFirst);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c.banned || c.suspended || c.warns.isNotEmpty) ...[
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.banned ? 'حسابك محظور عن النشر' : (c.suspended ? 'حسابك موقوف مؤقتاً عن النشر' : 'وصلك إنذار'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFFB3261E))),
            if ((c.banned || c.suspended) && c.blockReason.isNotEmpty) Text('السبب: ${c.blockReason}', style: TextStyle(height: 1.6, color: C.ink(context))),
            for (final w in c.warns.reversed.take(3)) Text('• ${w['text']} (${ago(w['at'])})', style: TextStyle(height: 1.6, color: C.ink(context))),
            TextButton(onPressed: () => push(context, const MessageDevScreen()), child: const Text('راسل المطوّر للمراجعة')),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      _row(context, Icons.people_outline_rounded, 'من أتابعهم', 'ابحث عن أي شخص برقمه الشخصي', () => push(context, const FollowingScreen())),
      if (Store.i.feature('pubOwn')) _row(context, Icons.inventory_2_outlined, 'مسودّاتي', 'شعرك المحفوظ عندك قبل نشره', () => push(context, const DraftsScreen())),
      if (Vault.backgrounds) _row(context, Icons.wallpaper_rounded, 'خلفية صفحتي', 'تظهر أعلى صفحتك لكل من يزورها', () => push(context, const MyBackgroundScreen())),
      _row(context, Icons.mark_email_unread_outlined, 'راسل المطوّر', '', () => push(context, const MessageDevScreen())),
      Wrap(spacing: 6, runSpacing: 6, children: [
        if (c.isDev) const Tag('حساب المطوّر'),
        if (c.plus) const Tag('مشترك'),
      ]),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('تسجيل الخروج'),
              content: const Text('تخرج من حسابك على هذا الجهاز. إعجاباتك ومجموعاتك تبقى في الجهاز.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('اخرج')),
              ],
            ),
          );
          if (ok != true) return;
          await c.signOut();
          if (!context.mounted) return;
          toast(context, 'خرجت من حسابك');
          home();
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('تسجيل الخروج', style: TextStyle(fontSize: 16.5)),
      ),
      const SizedBox(height: 4),
      TextButton.icon(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('حذف الحساب'),
              content: const Text('يُحذف حسابك وكل ما فيه على الخادم: اسمك ورقمك الشخصي ونقاطك وما نشرته ورسائلك، خلال ثلاثين يوماً، ولا يُسترجع بعدها. ما في جوالك من إعجابات ومجموعات يبقى في الجوال.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(d, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)), child: const Text('احذف حسابي')),
              ],
            ),
          );
          if (ok != true) return;
          final done = await c.requestDeletion();
          if (!context.mounted) return;
          toast(context, done ? 'وصل طلب الحذف، وخرجت من حسابك' : 'تعذّر الإرسال. حاول مرة أخرى.');
          if (done) home();
        },
        icon: const Icon(Icons.delete_forever_outlined, color: Color(0xFFB3261E)),
        label: const Text('احذف حسابي', style: TextStyle(color: Color(0xFFB3261E))),
      ),
    ]);
  }
}

/// «من أتابعهم» and the search by personal number.
class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});
  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  final ctl = TextEditingController();
  bool busy = false;

  Future<void> _find([String? id]) async {
    id ??= ctl.text.trim();
    if (id.length != 7) {
      toast(context, 'الرقم الشخصي سبعة أرقام');
      return;
    }
    if (!await needAccount(context, 'البحث بالرقم الشخصي يحتاج حساباً.')) return;
    setState(() => busy = true);
    final u = await Cloud.i.findUser(id);
    if (!mounted) return;
    setState(() => busy = false);
    if (u == null) {
      toast(context, 'لا يوجد حساب بهذا الرقم');
      return;
    }
    push(context, UserScreen(user: u));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Cloud.i,
        builder: (context, _) {
          final f = Cloud.i.following;
          return Scaffold(
            appBar: AppBar(title: const Text('من أتابعهم')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: ctl,
                    keyboardType: TextInputType.number,
                    maxLength: 7,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(hintText: 'الرقم الشخصي، مثل: 1234567', counterText: ''),
                    onSubmitted: (_) => _find(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: busy ? null : _find, child: Text(busy ? '…' : 'بحث')),
              ]),
              const SizedBox(height: 14),
              if (f.isEmpty) const EmptyNote(Icons.people_outline_rounded, 'لم تتابع أحداً بعد. ابحث برقم شخصي ثم اضغط «تابعه».'),
              for (final e in f.entries) _row(context, Icons.person_outline_rounded, e.value, 'رقمه: ${e.key}', () => _find(e.key)),
            ]),
          );
        },
      );
}

/// Another reader's page.
/// Opens, for the developer or a supervisor, everything he may do to one reader:
/// powers, badges, warning, suspension, ban and subscription.
Future<void> openUserAdmin(BuildContext context, String uid) async {
  final u = await Cloud.i.userByUid(uid);
  if (!context.mounted) return;
  if (u == null) {
    toast(context, 'تعذّر فتح حسابه. تحقّق من الإنترنت.');
    return;
  }
  push(context, UserScreen(user: u, admin: true));
}

class UserScreen extends StatefulWidget {
  final Doc user;

  /// Only the supervision card, opened from a conversation or a forum message.
  final bool admin;
  const UserScreen({super.key, required this.user, this.admin = false});
  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  Doc get user => widget.user;
  String get uid => '${user['uid']}';
  late final Future<int> followers = Cloud.i.followersCount(uid);

  Future<void> _plus(bool on, String kind) async {
    final ok = await Cloud.i.setPlus(uid, on, kind: kind);
    if (ok) {
      setState(() {
        user['plus'] = on;
        if (on) user['plusKind'] = kind;
      });
    }
    if (mounted) toast(context, !ok ? 'تعذّر' : (on ? 'صار مشتركاً ($kind)' : 'أُلغي اشتراكه'));
  }

  Future<String?> _reason(String title, {String hint = 'السبب (يراه صاحب الحساب)'}) {
    final t = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(controller: t, minLines: 2, maxLines: 5, autofocus: true, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, t.text.trim()), child: const Text('تأكيد')),
        ],
      ),
    );
  }

  Map get g => (user['grants'] as Map?) ?? {};
  List<String> get _titles => [for (final t in g['titles'] as List? ?? const []) '$t'];

  Future<void> _setTitles(List<String> t) async {
    final ok = await Cloud.i.setTitles(uid, t);
    if (ok) _g('titles', t);
    if (mounted) toast(context, ok ? 'حُفظت الشارات' : 'تعذّر الحفظ');
  }

  /// The badges sheet: the ready ones as chips, or one he writes.
  Future<void> _pickTitles() async {
    final chosen = [..._titles];
    final custom = TextEditingController();
    final saved = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (s) => StatefulBuilder(
        builder: (s, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(s).bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('شارات ${user['name'] ?? 'قارئ'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('تظهر تحت اسمه في صفحته، وبجانب اسمه في المنتدى والاقتباسات والتحديات.', style: TextStyle(color: C.muted(s), height: 1.5)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in {...titlePresets.keys, ...chosen})
                  FilterChip(
                    avatar: Icon(titlePresets[t] ?? Icons.workspace_premium_rounded, size: 18, color: t == earlyTitle ? bronze : null),
                    label: Text(t),
                    selected: chosen.contains(t),
                    onSelected: (on) => set(() => on ? chosen.add(t) : chosen.remove(t)),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: custom, maxLength: 20, decoration: const InputDecoration(hintText: 'شارة أخرى تكتبها', counterText: ''))),
                IconButton(
                  onPressed: () {
                    final t = custom.text.trim();
                    if (t.isNotEmpty && !chosen.contains(t)) set(() => chosen.add(t));
                    custom.clear();
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ]),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(s, chosen), child: const Text('احفظ الشارات')),
            ]),
          ),
        ),
      ),
    );
    if (saved != null && mounted) await _setTitles(saved);
  }
  // the warning / suspension / ban buttons stay folded behind one button
  bool _tools = false;
  void _g(String k, dynamic v) => setState(() => user['grants'] = {...g, k: v});

  Widget _moderation(BuildContext context) {
    final c = Cloud.i;
    final banned = user['banned'] == true;
    final until = _n(g['until']);
    final suspended = until > DateTime.now().millisecondsSinceEpoch;
    final device = '${user['device'] ?? ''}';
    final devBanned = c.bannedDevices.contains(device);
    final warns = [for (final w in g['warns'] as List? ?? []) w as Map];
    Widget b(String t, VoidCallback f) => OutlinedButton(onPressed: f, child: Text(t));
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الإشراف', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 4),
        Text(
          banned
              ? 'محظور الحساب ${ago(g['at'])}${'${g['reason'] ?? ''}'.isEmpty ? '' : ' · السبب: ${g['reason']}'}'
              : suspended
                  ? 'موقوف مؤقتاً: بقي ${Ar.num(((until - DateTime.now().millisecondsSinceEpoch) / 86400000).ceil())} يوماً${'${g['reason'] ?? ''}'.isEmpty ? '' : ' · السبب: ${g['reason']}'}'
                  : 'لا حظر عليه.',
          style: TextStyle(height: 1.6, color: banned || suspended ? const Color(0xFFB3261E) : C.muted(context)),
        ),
        if (devBanned) const Text('هاتفه محظور.', style: TextStyle(color: Color(0xFFB3261E))),
        if (g['noMsg'] == true) const Text('مراسلته للمطوّر موقوفة.', style: TextStyle(color: Color(0xFFB3261E))),
        for (final w in warns.reversed.take(5)) Text('• إنذار ${ago(w['at'])}: ${w['text']}', style: TextStyle(height: 1.6, color: C.ink(context))),
        const SizedBox(height: 8),
        if (c.isDev)
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => push(context, ModPermsScreen(uid: uid, name: '${user['name'] ?? 'قارئ'}')),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: Text(c.mods.containsKey(uid) ? 'صلاحياته في الإشراف' : 'اجعله مشرفاً وحدّد صلاحياته'),
            ),
          ),
        if (c.isDev) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(foregroundColor: bronze),
              onPressed: () => _setTitles(_titles.contains(earlyTitle) ? (_titles..remove(earlyTitle)) : [earlyTitle, ..._titles]),
              icon: const Icon(Icons.looks_one_rounded),
              label: Text(_titles.contains(earlyTitle) ? 'انزع شارة «من الأوائل»' : 'امنحه شارة «من الأوائل» (البرونزية)'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickTitles,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(_titles.isEmpty ? 'امنحه شارات' : 'شاراته: ${_titles.join('، ')}'),
            ),
          ),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _tools = !_tools),
            icon: Icon(_tools ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            label: Text(_tools ? 'أخفِ الأزرار' : 'الإنذار والإيقاف والحظر والاشتراك'),
          ),
        ),
        if (_tools)
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (c.can('حظر') || c.can('إيقاف')) ...[
            b('إنذار', () async {
              final r = await _reason('إنذار مكتوب', hint: 'خالفتَ في كذا…');
              if (r == null || r.isEmpty) return;
              final ok = await c.warnUser(uid, r);
              if (ok) _g('warns', [...warns, {'text': r, 'at': DateTime.now().millisecondsSinceEpoch}]);
              if (context.mounted) toast(context, ok ? 'وصله الإنذار' : 'تعذّر');
            }),
            if (!suspended)
              for (final d in const [3, 7, 30])
                b('إيقاف ${Ar.num(d)} أيام', () async {
                  final r = await _reason('إيقاف مؤقت ${Ar.num(d)} أيام');
                  if (r == null) return;
                  final ok = await c.suspendUser(uid, d, r);
                  if (ok) {
                    _g('until', DateTime.now().millisecondsSinceEpoch + d * 86400000);
                    _g('reason', r);
                  }
                  if (context.mounted) toast(context, ok ? 'أُوقف مؤقتاً' : 'تعذّر');
                })
            else
              b('ارفع الإيقاف', () async {
                if (await c.suspendUser(uid, 0, '')) _g('until', 0);
              }),
            if (c.can('حظر')) b(banned ? 'ارفع حظر الحساب' : 'احظر الحساب', () async {
              final r = banned ? '' : await _reason('حظر الحساب');
              if (r == null) return;
              final ok = await c.banUser(uid, !banned, r);
              if (ok) {
                setState(() => user['banned'] = !banned);
                _g('reason', r);
                _g('at', DateTime.now().millisecondsSinceEpoch);
              }
              if (context.mounted) toast(context, !ok ? 'تعذّر' : (banned ? 'رُفع الحظر' : 'حُظر الحساب'));
            }),
            if (device.isNotEmpty && c.isDev)
              b(devBanned ? 'ارفع حظر الهاتف' : 'احظر هاتفه', () {
                c.banDevice(device, !devBanned);
                setState(() {});
              }),
            if (c.isDev) b(g['noMsg'] == true ? 'اسمح بمراسلتي' : 'امنع مراسلتي', () async {
              final on = g['noMsg'] != true;
              if (await c.setNoMsg(uid, on)) _g('noMsg', on);
            }),
          ],
          if (c.isDev) ...[
            if (user['plus'] == true && user['plusKind'] == 'مدفوع')
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('اشتراكه مدفوع: لا يُلغى.'))
            else if (user['plus'] == true)
              b('ألغِ اشتراك الهدية', () => _plus(false, ''))
            else ...[
              b('اشتراك هدية منّي', () => _plus(true, 'هدية')),
              b('اشتراك مدفوع', () => _plus(true, 'مدفوع')),
            ],
          ],
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = '${user['publicId']}', name = '${user['name'] ?? 'قارئ'}';
    return ListenableBuilder(
      listenable: Cloud.i,
      builder: (context, _) {
        final c = Cloud.i;
        final following = c.following.containsKey(id);
        final mine = uid == c.uid;
        if (widget.admin) {
          return Scaffold(
            appBar: AppBar(title: Text('إدارة: $name')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 140), children: [
              Text('رقمه: $id', style: TextStyle(color: C.muted(context))),
              const SizedBox(height: 8),
              _moderation(context),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => push(context, UserScreen(user: user)),
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('صفحته كاملة'),
              ),
            ]),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(name), actions: [
            if (!mine)
              IconButton(
                tooltip: 'إبلاغ',
                icon: const Icon(Icons.flag_outlined),
                onPressed: () async {
                  final ok = await c.report('اسم', id, name, ofUid: uid);
                  if (context.mounted) toast(context, ok ? 'وصل بلاغك إلى المطوّر' : 'تعذّر الإرسال');
                },
              ),
          ]),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
            SoftCard(
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Majlis.rankColors[Majlis.rankIndex(Majlis.levelOf(_n(user['points'])))], width: 3)),
                  child: const RoundIcon(Icons.person_rounded, size: 64),
                ),
                const SizedBox(height: 6),
                Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.ink(context))),
                Text('رقمه الشخصي: $id', style: TextStyle(color: C.muted(context))),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                  RankBadge(_n(user['points'])),
                  if (user['plus'] == true) Tag('مشترك${c.isDev ? ' · ${user['plusKind'] ?? 'هدية'}' : ''}'),
                  if (user['banned'] == true) const Tag('محظور عن النشر'),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => push(context, FollowListScreen(title: 'متابِعو $name', load: () => c.followers(uid))),
                      child: Column(children: [
                        FutureBuilder<int>(future: followers, builder: (_, s) => Text(Ar.num(s.data ?? 0), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.ink(context)))),
                        Text('المتابِعون', style: TextStyle(fontSize: 13, color: C.muted(context))),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => push(context, FollowListScreen(title: 'يتابعهم $name', load: () => c.usersByUid(List<String>.from(user['following'] as List? ?? [])))),
                      child: Column(children: [
                        Text(Ar.num((user['following'] as List? ?? []).length), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.ink(context))),
                        Text('يتابع', style: TextStyle(fontSize: 13, color: C.muted(context))),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: Column(children: [
                      Text(Ar.num(_n(user['poets'])), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.ink(context))),
                      Text('الشعراء', style: TextStyle(fontSize: 13, color: C.muted(context))),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('${Ar.num(_n(user['points']))} نقطة · حفظ ${Ar.verses(_n(user['memo']))} · ${Ar.num(_n(user['streak']))} يوماً متتالياً',
                    textAlign: TextAlign.center, style: TextStyle(color: C.muted(context))),
                if (!mine) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.center, children: [
                    following
                        ? OutlinedButton(onPressed: () => c.follow(id, name, false, ofUid: uid), child: const Text('ألغِ المتابعة'))
                        : FilledButton(onPressed: () => c.follow(id, name, true, ofUid: uid), child: const Text('تابعه')),
                    if (Store.i.feature('duel'))
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picks = Majlis.pick();
                          final duel = await c.newDuel(user, picks);
                          if (!context.mounted) return;
                          if (duel == null) {
                            toast(context, 'تعذّر إنشاء المبارزة');
                            return;
                          }
                          push(context, ChallengeScreen(picks: picks, duel: duel));
                        },
                        icon: const Icon(Icons.sports_kabaddi_rounded),
                        label: const Text('بارزه'),
                      ),
                    if (c.isDev)
                      OutlinedButton.icon(
                        onPressed: () => push(context, DevChatScreen(msgs: const [], user: user)),
                        icon: const Icon(Icons.forum_outlined),
                        label: const Text('راسله'),
                      ),
                  ]),
                ],
              ]),
            ),
            if (!mine && (c.isDev || c.can('حظر') || c.can('إيقاف'))) ...[const SizedBox(height: 10), _moderation(context)],
            _section(context, 'اقتباساته'),
            QuotesList(of: uid),
          ]),
        );
      },
    );
  }
}

/// A list of readers (followers, following…): every name opens its page.
class FollowListScreen extends StatelessWidget {
  final String title;
  final Future<List<Doc>> Function() load;
  const FollowListScreen({super.key, required this.title, required this.load});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: FutureBuilder<List<Doc>>(
          future: load(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final list = snap.data ?? [];
            if (list.isEmpty) return const EmptyNote(Icons.people_outline_rounded, 'لا أحد هنا بعد.');
            return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              for (final u in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => push(context, UserScreen(user: u)),
                    child: Row(children: [
                      const RoundIcon(Icons.person_outline_rounded, size: 44),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${u['name'] ?? 'قارئ'}', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context))),
                          Text('رقمه: ${u['publicId']}', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
                        ]),
                      ),
                      RankBadge(_n(u['points']), small: true),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}

/// The poets the reader follows.
class MyPoetsScreen extends StatelessWidget {
  const MyPoetsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final names = Store.i.followed.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('شعرائي')),
      body: names.isEmpty
          ? const EmptyNote(Icons.person_search_outlined, 'لم تتابع شاعراً بعد. افتح صفحة أي شاعر واضغط «متابعة».')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              for (final n in names) _row(context, Icons.history_edu_rounded, n, '', () => push(context, PoetScreen(name: n))),
            ]),
    );
  }
}

/// «المبارزات»: the same five verses for two; the higher score wins.
/// The five verses of a duel, in order.
List<(Poem, int)> duelPicks(Doc d) => [
      for (final k in d['picks'] as List? ?? [])
        if (Library.byId[int.tryParse('$k'.split(':').first)] != null) (Library.byId[int.parse('$k'.split(':').first)]!, int.parse('$k'.split(':').last))
    ];

/// The other person in a duel, from my side.
String duelOtherUid(Doc d) => d['teacher'] == Cloud.i.uid ? '${(d['students'] as List? ?? ['']).first}' : '${d['teacher']}';

bool duelHasUid(Doc d, String uid) => d['teacher'] == uid || (d['students'] as List? ?? []).contains(uid);

/// Plays each duel one after another. Moving from one person's challenge to the next happens here.
Future<void> playDuels(BuildContext context, List<Doc> list) async {
  for (final d in list) {
    final picks = duelPicks(d);
    if (picks.length != 5) continue;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChallengeScreen(picks: picks, duel: '${d['id']}')));
    if (!context.mounted) return;
  }
}

class DuelsScreen extends StatefulWidget {
  const DuelsScreen({super.key});
  @override
  State<DuelsScreen> createState() => _DuelsScreenState();
}

class _DuelsScreenState extends State<DuelsScreen> {
  Future<List<Doc>> job = Cloud.i.duels();
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // A short chime on entering the arena.
    _player.play(AssetSource('sounds/enter.wav'), volume: 0.5).catchError((_) {});
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  List<(Poem, int)> _picks(Doc d) => [
        for (final k in d['picks'] as List? ?? [])
          if (Library.byId[int.tryParse('$k'.split(':').first)] != null) (Library.byId[int.parse('$k'.split(':').first)]!, int.parse('$k'.split(':').last))
      ];

  /// Counts my wins once for the «الغالب» medal.
  void _countWins(List<Doc> list) {
    final m = Store.i.majlis;
    final counted = [...(m['duelsCounted'] as List? ?? [])];
    var wins = 0;
    for (final d in list) {
      final r = d['results'] as Map? ?? {};
      if (r.length < 2 || counted.contains(d['id'])) continue;
      final mine = _n((r[Cloud.i.uid] as Map?)?['r']);
      final other = r.entries.where((e) => e.key != Cloud.i.uid).map((e) => _n((e.value as Map)['r'])).fold(0, (a, b) => a > b ? a : b);
      counted.add(d['id']);
      if (mine > other) wins++;
    }
    if (counted.length != (m['duelsCounted'] as List? ?? []).length) {
      m['duelsCounted'] = counted.length > 200 ? counted.sublist(counted.length - 200) : counted;
      final st = Map<String, dynamic>.from(Majlis.st);
      st['duelWins'] = _n(st['duelWins']) + wins;
      m['st'] = st;
      Store.i.saveMajlis();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المبارزات'), actions: [
          IconButton(tooltip: 'المتصدرون', onPressed: () => push(context, const BoardsScreen()), icon: const Icon(Icons.emoji_events_outlined)),
          IconButton(onPressed: () => setState(() => job = Cloud.i.duels()), icon: const Icon(Icons.refresh_rounded)),
        ]),
        body: !Cloud.i.signedIn
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('المبارزة تحتاج حساباً، لتتحدى صديقك برقمه الشخصي.', textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () async {
                        if (await needAccount(context) && mounted) setState(() => job = Cloud.i.duels());
                      },
                      child: Text(Cloud.signInLabel),
                    ),
                  ]),
                ),
              )
            : FutureBuilder<List<Doc>>(
                future: job,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                  final list = snap.data ?? [];
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _countWins(list);
                    _publish(list);
                  });
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(colors: [Color(0xFF2A211A), Color(0xFF4A3622)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                        border: Border.all(color: const Color(0xFFD9B45A)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.sports_kabaddi_rounded, size: 40, color: Color(0xFFD9B45A)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('ساحة المبارزات', style: TextStyle(fontFamily: 'ArefRuqaa', fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFFF3DFA6))),
                            Text('تحدَّ صديقاً، أو نازل الجميع في تحدي الأسبوع والجمعة.', style: TextStyle(fontSize: 13.5, height: 1.6, color: Colors.white.withValues(alpha: 0.8))),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    const GroupChallenges(),
                    const SizedBox(height: 12),
                    SoftCard(
                      padding: const EdgeInsets.all(14),
                      child: Text('لتبارز صديقاً: افتح «من أتابعهم» من صفحتك، ابحث برقمه الشخصي، ثم اضغط «بارزه». تلعبان الأبيات الخمسة نفسها.', style: TextStyle(height: 1.7, color: C.ink(context))),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(onPressed: () => push(context, const FollowingScreen()), icon: const Icon(Icons.search_rounded), label: const Text('ابحث برقم شخصي')),
                    _statsCard(context, list),
                    if (_pending(list).isNotEmpty) ...[
                      _section(context, 'تحديات تنتظر ردّك (${Ar.num(_pending(list).length)})'),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('ابدأ كل التحديات'),
                          onPressed: () async {
                            await playDuels(context, _pending(list));
                            if (mounted) setState(() => job = Cloud.i.duels());
                          },
                        ),
                      ),
                      for (final d in _pending(list)) _card(context, d),
                    ],
                    if (list.isEmpty) const EmptyNote(Icons.sports_kabaddi_rounded, 'لا مبارزات بعد.'),
                    for (final d in list.where((d) => !_pending(list).contains(d))) _card(context, d),
                  ]);
                },
              ),
      );

  /// Publishes my duel totals for the board: challenges sent, finished, and won.
  void _publish(List<Doc> list) {
    final me = Cloud.i.uid;
    var sent = 0, done = 0, won = 0;
    for (final d in list) {
      final r = d['results'] as Map? ?? {};
      final mine = r[me] as Map?;
      if (d['teacher'] == me) {
        sent++;
      }
      if (mine == null) continue;
      done++;
      final others = r.entries.where((e) => e.key != me).toList();
      if (others.isEmpty) continue;
      if (_n(mine['r']) > _n((others.first.value as Map)['r'])) won++;
    }
    Cloud.i.publishStats({'duelSent': sent, 'duelDone': done, 'duelWon': won});
  }

  /// Challenges sent to me that I have not played yet, shown first.
  List<Doc> _pending(List<Doc> list) => [
        for (final d in list)
          if (d['teacher'] != Cloud.i.uid && (d['results'] as Map? ?? {})[Cloud.i.uid] == null) d
      ];

  /// My numbers: how many challenges I sent and finished, my wins and losses,
  /// and the win rate among the finished ones. A duel counts only when both finished.
  Widget _statsCard(BuildContext context, List<Doc> list) {
    final me = Cloud.i.uid;
    var sent = 0, sentDone = 0, played = 0, won = 0, lost = 0, waiting = 0, both = 0;
    for (final d in list) {
      final r = d['results'] as Map? ?? {};
      final mine = r[me] as Map?;
      if (d['teacher'] == me) {
        sent++;
        if (mine != null) sentDone++;
      } else if (mine == null) {
        waiting++;
      }
      if (mine == null) continue;
      played++;
      final others = r.entries.where((e) => e.key != me).toList();
      if (others.isEmpty) continue;
      final a = _n(mine['r']), b = _n((others.first.value as Map)['r']);
      both++;
      if (a > b) won++;
      if (a < b) lost++;
    }
    int pct(int a, int b) => b == 0 ? 0 : (a * 100 / b).round();
    final finished = both;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('إحصائياتك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
          const SizedBox(height: 8),
          Text('أرسلتَ ${Ar.num(sent)} تحدياً، أنجزتَ ${Ar.num(sentDone)} منها (${Ar.num(pct(sentDone, sent))}٪)', style: TextStyle(height: 1.7, color: C.ink(context))),
          Text('فزتَ في ${Ar.num(won)}، وخسرتَ في ${Ar.num(lost)}، ونسبة فوزك ${Ar.num(pct(won, finished))}٪ من المكتملة', style: TextStyle(height: 1.7, color: C.ink(context))),
          if (waiting > 0) Text('لديك ${Ar.num(waiting)} تحدياً بانتظار ردّك', style: TextStyle(height: 1.7, color: C.accent(context), fontWeight: FontWeight.w700)),
          if (both > 0) ...[
            const SizedBox(height: 10),
            WinBar(won: won, lost: lost, tied: both - won - lost),
          ],
        ]),
      ),
      const SizedBox(height: 6),
    ]);
  }

  Widget _card(BuildContext context, Doc d) {
    final me = Cloud.i.uid;
    final iStarted = d['teacher'] == me;
    final r = d['results'] as Map? ?? {};
    final mine = r[me] as Map?;
    final otherE = r.entries.where((e) => e.key != me).toList();
    final other = otherE.isEmpty ? null : otherE.first.value as Map;
    final otherName = iStarted ? '${d['oppName'] ?? 'صاحبك'}' : '${d['teacherName'] ?? 'صاحبك'}';
    final picks = _picks(d);
    String verdict() {
      if (mine == null) return iStarted ? 'لم تُكمل تحديك بعد' : 'بانتظار ردّك: العب لترى النتيجة';
      if (other == null) return 'أكملتَ. ننتظر $otherName';
      final a = _n(mine['r']), b = _n(other['r']);
      return a > b ? 'فزتَ على $otherName' : (a == b ? 'تعادلتما' : 'فاز $otherName');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => push(context, DuelPersonScreen(uid: duelOtherUid(d), name: otherName, publicId: '${iStarted ? d['oppPublicId'] ?? '' : d['teacherPublicId'] ?? ''}')),
                child: Text(
                  'مع $otherName${(iStarted ? d['oppPublicId'] : d['teacherPublicId']) == null ? '' : '  ·  ${(iStarted ? d['oppPublicId'] : d['teacherPublicId'])}'}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context)),
                ),
              ),
            ),
            Text(ago(d['at']), style: TextStyle(fontSize: 12, color: C.muted(context))),
          ]),
          Text(verdict(), style: TextStyle(color: C.accent(context), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Column(children: [
                ShapeBadge(size: 64, fraction: mine == null ? 0 : _n(mine['r']) / 100, seed: '${d['id']}'.hashCode),
                const Text('أنت'),
              ]),
            ),
            Expanded(
              child: Column(children: [
                // The other side stays hidden until I have played.
                ShapeBadge(size: 64, fraction: mine == null || other == null ? 0 : _n(other['r']) / 100, seed: '${d['id']}'.hashCode),
                Text(otherName, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          if (mine == null && picks.length == 5) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChallengeScreen(picks: picks, duel: '${d['id']}')));
                if (mounted) setState(() => job = Cloud.i.duels());
              },
              child: const Text('العب المبارزة'),
            ),
          ],
        ]),
      ),
    );
  }
}

/// A person's page in duels: the challenges between us, who won how many,
/// their pending challenges to me, and follow.
class DuelPersonScreen extends StatefulWidget {
  final String uid, name, publicId;
  const DuelPersonScreen({super.key, required this.uid, required this.name, required this.publicId});
  @override
  State<DuelPersonScreen> createState() => _DuelPersonScreenState();
}

class _DuelPersonScreenState extends State<DuelPersonScreen> {
  late Future<List<Doc>> job = Cloud.i.duels();

  @override
  Widget build(BuildContext context) {
    final title = widget.name.isEmpty ? widget.publicId : widget.name;
    return ListenableBuilder(
      listenable: Cloud.i,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: FutureBuilder<List<Doc>>(
          future: job,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final me = Cloud.i.uid;
            final between = <Doc>[for (final d in snap.data ?? <Doc>[]) if (duelHasUid(d, widget.uid)) d];
            var won = 0, lost = 0, tied = 0, pendingToMe = 0;
            for (final d in between) {
              final r = d['results'] as Map? ?? {};
              final a = r[me] as Map?;
              final b = r[widget.uid] as Map?;
              if (a == null && d['teacher'] != me) pendingToMe++;
              if (a == null || b == null) continue;
              final x = _n(a['r']), y = _n(b['r']);
              if (x > y) won++;
              if (x < y) lost++;
              if (x == y) tied++;
            }
            final pending = <Doc>[for (final d in between) if (d['teacher'] != me && (d['results'] as Map? ?? {})[me] == null) d];
            final following = Cloud.i.following.containsKey(widget.publicId);
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
                  if (widget.publicId.isNotEmpty) Text('رقمه: ${widget.publicId}', style: TextStyle(color: C.muted(context))),
                  const SizedBox(height: 10),
                  Text('المكتملة بينكما: فزتَ في ${Ar.num(won)}، وفاز في ${Ar.num(lost)}، وتعادلتما في ${Ar.num(tied)}', style: TextStyle(height: 1.7, color: C.ink(context))),
                  if (won + lost + tied > 0) ...[
                    const SizedBox(height: 8),
                    WinBar(won: won, lost: lost, tied: tied),
                  ],
                  if (pendingToMe > 0) Text('لديك ${Ar.num(pendingToMe)} تحدياً بانتظار ردّك منه', style: TextStyle(height: 1.7, color: C.accent(context), fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 10),
              if (pending.isNotEmpty)
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('ابدأ تحدياته (${Ar.num(pending.length)})'),
                  onPressed: () async {
                    await playDuels(context, pending);
                    if (mounted) setState(() => job = Cloud.i.duels());
                  },
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: Icon(following ? Icons.person_remove_outlined : Icons.person_add_alt_1_outlined),
                label: Text(following ? 'إلغاء الصداقة' : 'صادقه'),
                onPressed: widget.publicId.isEmpty
                    ? null
                    : () {
                        Cloud.i.follow(widget.publicId, widget.name, !following, ofUid: widget.uid);
                        setState(() {});
                      },
              ),
              const SizedBox(height: 16),
              for (final d in between) _card(context, d),
              if (between.isEmpty) const EmptyNote(Icons.sports_kabaddi_rounded, 'لا تحديات بينكما بعد.'),
            ]);
          },
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Doc d) {
    final r = d['results'] as Map? ?? {};
    final mine = r[Cloud.i.uid] as Map?;
    final other = r[widget.uid] as Map?;
    String verdict() {
      if (mine == null && d['teacher'] != Cloud.i.uid) return 'بانتظار ردّك';
      if (mine == null) return 'لم تُكمل تحديك بعد';
      if (other == null) return 'أكملتَ. ننتظره';
      final a = _n(mine['r']), b = _n(other['r']);
      return a > b ? 'فزتَ' : (a == b ? 'تعادلتما' : 'فاز ${widget.name}');
    }

    final picks = duelPicks(d);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(verdict(), style: TextStyle(fontWeight: FontWeight.w700, color: C.accent(context)))),
            Text(ago(d['at']), style: TextStyle(fontSize: 12, color: C.muted(context))),
          ]),
          if (mine == null && d['teacher'] != Cloud.i.uid && picks.length == 5) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChallengeScreen(picks: picks, duel: '${d['id']}')));
                if (mounted) setState(() => job = Cloud.i.duels());
              },
              child: const Text('العب المبارزة'),
            ),
          ],
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------ quotes

/// «الاقتباسات»: verses published by readers.
class QuotesScreen extends StatefulWidget {
  final String? of;
  final String title;
  const QuotesScreen({super.key, this.of, this.title = 'الاقتباسات'});
  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  var _k = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [
          IconButton(tooltip: 'تحديث', onPressed: () => setState(() => _k++), icon: const Icon(Icons.refresh_rounded)),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            if (!await needAccount(context, 'تنشر حتى عشرة اقتباسات في اليوم.') || !context.mounted) return;
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuotePickerScreen()));
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('انشر اقتباساً'),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
          if (widget.of == null)
            Text('أبيات ينشرها القرّاء، يُعجب بها الناس ويشاركونها. اضغط اسم صاحبها لترى اقتباساته.', style: TextStyle(color: C.muted(context), height: 1.6)),
          const SizedBox(height: 12),
          QuotesList(key: ValueKey(_k), of: widget.of, refresh: _k > 0),
        ]),
      );
}

class QuotesList extends StatefulWidget {
  final String? of;
  final bool refresh;
  const QuotesList({super.key, this.of, this.refresh = false});
  @override
  State<QuotesList> createState() => _QuotesListState();
}

class _QuotesListState extends State<QuotesList> {
  late final Future<List<Doc>> job = Cloud.i.quotes(of: widget.of, refresh: widget.refresh);
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Doc>>(
        future: job,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
          final list = snap.data ?? [];
          if (list.isEmpty) return const EmptyNote(Icons.format_quote_rounded, 'لا اقتباسات بعد. كن أول من ينشر بيتاً.');
          return ListenableBuilder(
            listenable: Cloud.i,
            builder: (context, _) => Column(children: [
              for (final q in list) _card(context, q, list),
            ]),
          );
        },
      );

  Widget _card(BuildContext context, Doc q, List<Doc> list) {
    final c = Cloud.i;
    final liked = c.likedQuotes.contains(q['id']);
    final mine = q['uid'] == c.uid;
    final poem = Library.byId[_n(q['poem'])];
    final line = <String>['${q['a']}', if ('${q['b']}'.isNotEmpty) '${q['b']}'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: poem == null ? null : () => push(context, PoemScreen(poem: poem)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const RoundIcon(Icons.person_outline_rounded, size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  if (!await needAccount(context) || !context.mounted) return;
                  final u = await c.findUser('${q['publicId']}');
                  if (u != null && context.mounted) push(context, UserScreen(user: u));
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${q['name']}', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
                  Text(ago(q['at']), style: TextStyle(fontSize: 12, color: C.muted(context))),
                ]),
              ),
            ),
            if (mine || c.isDev)
              IconButton(
                tooltip: 'حذف',
                onPressed: () async {
                  final ok = await c.deleteQuote('${q['id']}');
                  if (ok && mounted) setState(() => list.remove(q));
                },
                icon: Icon(Icons.delete_outline_rounded, color: C.muted(context)),
              )
            else
              IconButton(
                tooltip: 'إبلاغ',
                onPressed: () async {
                  if (!await needAccount(context)) return;
                  final ok = await c.report('اقتباس', '${q['id']}', '${q['name']}: ${q['a']}', ofUid: '${q['uid']}');
                  if (context.mounted) toast(context, ok ? 'وصل بلاغك إلى المطوّر' : 'تعذّر الإرسال');
                },
                icon: Icon(Icons.flag_outlined, color: C.muted(context)),
              ),
          ]),
          VerseLines(line, size: 20),
          Row(children: [
            IconButton(
              onPressed: () async {
                if (await needAccount(context)) c.likeQuote(q);
              },
              icon: Icon(liked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, color: liked ? const Color(0xFFB3261E) : null),
            ),
            Text(Ar.num(_n(q['likes'])), style: TextStyle(color: C.muted(context))),
            IconButton(
              tooltip: 'نسخ',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '${Store.i.show(line.join('\n'))}\n— ${q['poet']}'));
                toast(context, 'نُسخ البيت');
              },
              icon: const Icon(Icons.copy_rounded),
            ),
            const Spacer(),
            Text('${q['poet']}', style: TextStyle(color: C.muted(context))),
          ]),
        ]),
      ),
    );
  }
}

/// Choose a verse to publish.
class QuotePickerScreen extends StatefulWidget {
  const QuotePickerScreen({super.key});
  @override
  State<QuotePickerScreen> createState() => _QuotePickerScreenState();
}

class _QuotePickerScreenState extends State<QuotePickerScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final n = Ar.norm(q);
    final liked = Library.poems.where((p) => Store.i.likes.contains(p.id));
    final found = n.length < 2
        ? [...liked, ...Library.poems.where((p) => !Store.i.likes.contains(p.id)).take(40)]
        : Library.poems.where((p) => Ar.norm(p.poet).contains(n) || p.lines.any((l) => Ar.norm(l.join(' ')).contains(n))).take(60).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('اختر بيتاً لتنشره')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        TextField(
          decoration: const InputDecoration(hintText: 'ابحث بكلمة من البيت أو باسم الشاعر', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 6),
        Text('بقي لك اليوم ${Ar.num(Cloud.i.quotesLeft < 0 ? 0 : Cloud.i.quotesLeft)} من ١٠. اضغط البيت لتنشره.', style: TextStyle(color: C.muted(context))),
        const SizedBox(height: 10),
        for (final p in found)
          for (var i = 0; i < p.lines.length && i < (n.length < 2 ? 2 : 40); i++)
            if (!p.gone(i + 1) && (n.length < 2 || Ar.norm(p.lines[i].join(' ')).contains(n) || Ar.norm(p.poet).contains(n) && i < 2))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () async {
                    final err = await Cloud.i.publishQuote(p, i);
                    if (!context.mounted) return;
                    toast(context, err ?? 'نُشر اقتباسك');
                    if (err == null) Navigator.pop(context);
                  },
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

// ------------------------------------------------------------ tests by personal number

const modeNames = {TestMode.all: 'يكتب الأبيات كلها', TestMode.alternate: 'بيت ظاهر وبيت مخفي', TestMode.half: 'شطر ظاهر وشطر مخفي'};

/// What the student sees: «لديك اختبار».
class StudentTestsScreen extends StatefulWidget {
  const StudentTestsScreen({super.key});
  @override
  State<StudentTestsScreen> createState() => _StudentTestsScreenState();
}

class _StudentTestsScreenState extends State<StudentTestsScreen> {
  Future<List<Doc>> job = Cloud.i.myTests();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Cloud.i,
        builder: (context, _) {
          final c = Cloud.i;
          return Scaffold(
            appBar: AppBar(title: const Text('اختباراتي'), actions: [
              IconButton(tooltip: 'تحديث', onPressed: () => setState(() => job = c.myTests()), icon: const Icon(Icons.refresh_rounded)),
            ]),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              if (!c.signedIn)
                SoftCard(
                  child: Column(children: [
                    const Text('ادخل بحسابك ليصلك اختبار معلّمك برقمك الشخصي.', textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () async {
                        if (await needAccount(context) && mounted) setState(() => job = c.myTests());
                      },
                      child: Text(Cloud.signInLabel),
                    ),
                  ]),
                )
              else ...[
                SoftCard(
                  padding: const EdgeInsets.all(14),
                  child: Text('رقمك الشخصي: ${c.publicId}\nأعطه معلّمك ليرسل لك الاختبار.', style: TextStyle(fontSize: 16, height: 1.7, color: C.ink(context))),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Doc>>(
                  future: job,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
                    final list = snap.data ?? [];
                    if (list.isEmpty) return const EmptyNote(Icons.assignment_outlined, 'لا اختبارات الآن. حين يرسل لك معلّمك اختباراً يظهر هنا «لديك اختبار».');
                    return Column(children: [for (final t in list) _test(context, t)]);
                  },
                ),
              ],
              const SizedBox(height: 10),
              SoftCard(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'للطالب:\n'
                  '١. أعطِ معلّمك رقمك الشخصي من صفحتك.\n'
                  '٢. حين يصلك الاختبار افتحه واكتب ما حفظت في الخانات.\n'
                  '٣. اضغط «تحقّق» فتظهر نتيجتك، وتصل معلّمك مباشرة.',
                  style: TextStyle(fontSize: 15, height: 1.7, color: C.ink(context)),
                ),
              ),
            ]),
          );
        },
      );

  Widget _test(BuildContext context, Doc t) {
    final matn = Library.mutun.where((m) => m.id == t['matn']).firstOrNull;
    final from = _n(t['from']), to = _n(t['to']);
    final res = (t['results'] as Map?)?[Cloud.i.uid] as Map?;
    final mode = TestMode.values[_n(t['mode']).clamp(0, TestMode.values.length - 1).toInt()];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(res == null ? 'لديك اختبار' : 'اختبار أدّيته', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context)))),
            Text(ago(t['at']), style: TextStyle(fontSize: 12.5, color: C.muted(context))),
          ]),
          Text('${t['title']} · من البيت ${Ar.num(from)} إلى ${Ar.num(to)}', style: TextStyle(fontSize: 16, color: C.ink(context))),
          Text('المعلّم: ${t['teacherName']} · ${modeNames[mode]}', style: TextStyle(color: C.muted(context))),
          if (res != null) Text('نتيجتك: ${Ar.num(_n(res['r']))} كلمة صحيحة من ${Ar.num(_n(res['t']))}', style: TextStyle(color: C.ink(context), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (matn == null || from < 1 || to > matn.lines.length)
            Text('حدّث التطبيق لتفتح هذا الاختبار.', style: TextStyle(color: C.muted(context)))
          else
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WritingTestScreen(matn: matn, verses: [for (var i = from; i <= to; i++) i], mode: mode, cloudTest: '${t['id']}')));
                if (mounted) setState(() => job = Cloud.i.myTests());
              },
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(res == null ? 'ابدأ الاختبار' : 'أعد الاختبار'),
            ),
        ]),
      ),
    );
  }
}

/// The teacher: results of the tests sent by personal number.
class SentTestsScreen extends StatefulWidget {
  const SentTestsScreen({super.key});
  @override
  State<SentTestsScreen> createState() => _SentTestsScreenState();
}

class _SentTestsScreenState extends State<SentTestsScreen> {
  Future<List<Doc>> job = Cloud.i.sentTests();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('نتائج طلابي'), actions: [
          IconButton(tooltip: 'تحديث', onPressed: () => setState(() => job = Cloud.i.sentTests()), icon: const Icon(Icons.refresh_rounded)),
        ]),
        body: FutureBuilder<List<Doc>>(
          future: job,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final list = snap.data ?? [];
            if (list.isEmpty) return const EmptyNote(Icons.assignment_outlined, 'لم ترسل اختباراً بالأرقام بعد.');
            return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              for (final t in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${t['title']} · من ${Ar.num(_n(t['from']))} إلى ${Ar.num(_n(t['to']))}', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context))),
                      Text('${ago(t['at'])} · أُرسل إلى ${Ar.num((t['students'] as List? ?? []).length)} طالب', style: TextStyle(color: C.muted(context))),
                      const Divider(),
                      if ((t['results'] as Map? ?? {}).isEmpty) Text('لم يختبر أحد بعد.', style: TextStyle(color: C.muted(context))),
                      for (final r in (t['results'] as Map? ?? {}).values)
                        InkWell(
                          onTap: () => push(context, TestErrorsScreen(result: Map<String, dynamic>.from(r as Map), title: '${t['title']}')),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Expanded(child: Text('${(r as Map)['name']} · ${r['publicId']}', style: TextStyle(color: C.ink(context)))),
                              Text('${Ar.num(_n(r['r']))} من ${Ar.num(_n(r['t']))}', style: TextStyle(fontWeight: FontWeight.w700, color: C.accent(context))),
                              Icon(Icons.chevron_left_rounded, size: 18, color: C.muted(context)),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}

// ------------------------------------------------------------ messages to the developer

/// One conversation as bubbles: (from the developer?, text, time).
List<(bool, String, int)> _thread(List<Doc> msgs, [List inbox = const []]) {
  final out = <(bool, String, int)>[
    // What the developer wrote first (and his warnings).
    for (final x in inbox) (true, '${(x as Map)['text']}', _n(x['at']))
  ];
  for (final m in msgs) {
    out.add((false, '${m['text']}', _n(m['at'])));
    final r = m['replies'];
    if (r is List && r.isNotEmpty) {
      for (final x in r) {
        out.add((true, '${(x as Map)['text']}', _n(x['at'])));
      }
    } else if ('${m['reply'] ?? ''}'.isNotEmpty) {
      out.add((true, '${m['reply']}', _n(m['replyAt'])));
    }
  }
  out.sort((a, b) => a.$3.compareTo(b.$3));
  return out;
}

class _Bubbles extends StatelessWidget {
  final List<(bool, String, int)> items;

  /// True when the developer is the one looking.
  final bool dev;
  const _Bubbles(this.items, {this.dev = false});
  @override
  Widget build(BuildContext context) => ListView(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        children: [
          for (final (fromDev, text, at) in items.reversed)
            Align(
              alignment: fromDev == dev ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration: BoxDecoration(
                  color: fromDev == dev ? C.accent(context) : C.card(context),
                  border: fromDev == dev ? null : Border.all(color: C.line(context)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (fromDev && !dev) Text('المطوّر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.accent(context))),
                  SelectableText(text, style: TextStyle(fontSize: 16.5, height: 1.6, color: fromDev == dev ? Colors.white : C.ink(context))),
                  Text(ago(at), style: TextStyle(fontSize: 11, color: fromDev == dev ? Colors.white70 : C.muted(context))),
                ]),
              ),
            ),
        ],
      );
}

class _ChatInput extends StatelessWidget {
  final TextEditingController ctl;
  final bool busy;
  final String hint;
  final VoidCallback onSend;
  const _ChatInput({required this.ctl, required this.busy, required this.hint, required this.onSend});
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: ctl,
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: C.card(context),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: C.line(context))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: busy ? null : onSend, icon: const Icon(Icons.send_rounded)),
          ]),
        ),
      );
}

/// The reader's conversation with the developer.
class MessageDevScreen extends StatefulWidget {
  const MessageDevScreen({super.key});
  @override
  State<MessageDevScreen> createState() => _MessageDevScreenState();
}

class _MessageDevScreenState extends State<MessageDevScreen> {
  final c = TextEditingController();
  List<Doc>? msgs;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Cloud.i.refreshProfile();
    final m = await Cloud.i.myMessages();
    if (mounted) setState(() => msgs = m);
  }

  Future<void> _send() async {
    if (!await needAccount(context, 'لتصلك ردود المطوّر في حسابك.')) return;
    setState(() => busy = true);
    final err = await Cloud.i.sendMessage(c.text);
    if (err == null) {
      c.clear();
      await _load();
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) toast(context, err);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Cloud.i,
        builder: (context, _) {
          final k = Cloud.i;
          final left = k.messagesLeft < 0 ? 0 : k.messagesLeft;
          return Scaffold(
            appBar: AppBar(title: const Text('راسل المطوّر'), actions: [
              IconButton(tooltip: 'تحديث', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ]),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  !k.signedIn
                      ? 'رسالة واحدة في اليوم مجاناً، وعشرون للمشتركين. يصلك الرد هنا.'
                      : k.isDev
                          ? 'أنت المطوّر. رسائل القرّاء في «خانة المطوّر».'
                          : k.plus
                              ? 'أنت مشترك: بقي لك اليوم ${Ar.num(left)} من ٢٠ رسالة.'
                              : 'المجاني رسالة واحدة في اليوم (بقي ${Ar.num(left)})، وللمشتركين عشرون. يصلك الرد هنا.',
                  style: TextStyle(color: C.muted(context), height: 1.6),
                ),
              ),
              Expanded(
                child: !k.signedIn
                    ? const EmptyNote(Icons.forum_outlined, 'اكتب رسالتك في الأسفل. سنطلب منك الدخول بحسابك ليصلك الرد.')
                    : msgs == null
                        ? const Center(child: CircularProgressIndicator())
                        : msgs!.isEmpty && (k.grants['inbox'] as List? ?? []).isEmpty
                            ? const EmptyNote(Icons.forum_outlined, 'لا رسائل بعد. اكتب رسالتك في الأسفل.')
                            : _Bubbles(_thread(msgs!, k.grants['inbox'] as List? ?? [])),
              ),
              _ChatInput(ctl: c, busy: busy, hint: 'اكتب رسالتك', onSend: _send),
            ]),
          );
        },
      );
}

/// «فحص الاختبار»: what one student wrote in each verse he missed, beside the correct text.
class TestErrorsScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final String title;
  const TestErrorsScreen({super.key, required this.result, required this.title});
  @override
  Widget build(BuildContext context) {
    final r = _n(result['r']), t = _n(result['t']);
    final errors = [for (final e in result['errors'] as List? ?? const []) if (e is Map) e];
    return Scaffold(
      appBar: AppBar(title: Text('فحص اختبار ${result['name'] ?? ''}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        SoftCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
            const SizedBox(height: 4),
            Text('${Ar.num(r)} كلمة صحيحة من ${Ar.num(t)} · ${Ar.num(t == 0 ? 0 : (r * 100 / t).round())}٪ · ${ago(result['at'])}', style: TextStyle(color: C.muted(context))),
            const SizedBox(height: 8),
            WinBar(won: r, lost: t - r, tied: 0, labels: const ('صحيح', 'خطأ أو ناقص', '')),
          ]),
        ),
        const SizedBox(height: 12),
        if (result['errors'] == null)
          const EmptyNote(Icons.fact_check_outlined, 'هذا الاختبار أُرسل قبل إضافة مواضع الخطأ، فلا تفاصيل له.')
        else if (errors.isEmpty)
          const EmptyNote(Icons.verified_outlined, 'لم يخطئ في شيء.')
        else ...[
          Text('مواضع الخطأ: ${Ar.num(errors.length)} بيتاً', style: TextStyle(fontWeight: FontWeight.w700, color: C.accent(context))),
          const SizedBox(height: 8),
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('البيت ${Ar.num(_n(e['v']))}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted(context))),
                  const SizedBox(height: 4),
                  Text('كتب: ${'${e['w'] ?? ''}'.isEmpty ? '— (تركه فارغاً)' : e['w']}', style: const TextStyle(fontSize: 16, height: 1.7, color: Color(0xFFB3261E))),
                  Text('الصحيح: ${e['c'] ?? ''}', style: const TextStyle(fontSize: 16, height: 1.7, color: Color(0xFF2F6B4F))),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------ developer lists

class _DevList extends StatefulWidget {
  final String title, empty;
  final IconData icon;
  final Future<List<Doc>> Function() load;
  final Widget Function(BuildContext, Doc, VoidCallback reload) item;
  const _DevList({required this.title, required this.empty, required this.icon, required this.load, required this.item});
  @override
  State<_DevList> createState() => _DevListState();
}

class _DevListState extends State<_DevList> {
  late Future<List<Doc>> job = widget.load();
  void reload() => setState(() => job = widget.load());
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded))]),
        body: !Cloud.i.isDev
            ? const EmptyNote(Icons.lock_outline_rounded, 'ادخل بحساب المطوّر (www774475437@gmail.com) من «صفحتك الشخصية» لتظهر هذه القائمة.')
            : FutureBuilder<List<Doc>>(
                future: job,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                  final list = snap.data ?? [];
                  if (list.isEmpty) return EmptyNote(widget.icon, widget.empty);
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [for (final x in list) widget.item(context, x, reload)]);
                },
              ),
      );
}

Future<void> _openUser(BuildContext context, String publicId) async {
  final u = await Cloud.i.findUser(publicId);
  if (u != null && context.mounted) push(context, UserScreen(user: u));
}

/// The developer: one row for each reader, newest first.
class DevMessagesScreen extends StatefulWidget {
  const DevMessagesScreen({super.key});
  @override
  State<DevMessagesScreen> createState() => _DevMessagesScreenState();
}

class _DevMessagesScreenState extends State<DevMessagesScreen> {
  List<Doc>? all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await Cloud.i.allMessages();
    if (mounted) setState(() => all = m);
  }

  @override
  Widget build(BuildContext context) {
    final by = <String, List<Doc>>{};
    for (final m in all ?? <Doc>[]) {
      by.putIfAbsent('${m['uid']}', () => []).add(m);
    }
    // Each list is newest first, as the server returned it.
    final chats = by.values.toList()..sort((a, b) => _n(b.first['at']).compareTo(_n(a.first['at'])));
    bool waiting(List<Doc> c) => _thread(c).last.$1 == false;
    final nWait = chats.where(waiting).length;
    return Scaffold(
      appBar: AppBar(title: const Text('الرسائل'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: !Cloud.i.isDev
          ? const EmptyNote(Icons.lock_outline_rounded, 'ادخل بحساب المطوّر من «صفحتك الشخصية» لتظهر الرسائل.')
          : all == null
              ? const Center(child: CircularProgressIndicator())
              : chats.isEmpty
                  ? const EmptyNote(Icons.mark_email_unread_outlined, 'لا رسائل بعد.')
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
                      Text('${Ar.num(chats.length)} محادثة · ${Ar.num(nWait)} تنتظر ردّك', style: TextStyle(color: C.muted(context))),
                      const SizedBox(height: 8),
                      for (final c in chats)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SoftCard(
                            padding: const EdgeInsets.all(14),
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DevChatScreen(msgs: c)));
                              _load();
                            },
                            child: Row(children: [
                              // the circle opens his page; the rest of the row opens the conversation
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _openUser(context, '${c.first['publicId']}'),
                                child: const Padding(padding: EdgeInsets.all(4), child: RoundIcon(Icons.person_outline_rounded, size: 46)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text('${c.first['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context)))),
                                    Text(ago(c.first['at']), style: TextStyle(fontSize: 12, color: C.muted(context))),
                                  ]),
                                  Text(_thread(c).last.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.muted(context))),
                                  Text('رقمه: ${c.first['publicId']} · ${Ar.num(c.length)} رسالة', style: TextStyle(fontSize: 12, color: C.muted(context))),
                                ]),
                              ),
                              if (waiting(c)) ...[const SizedBox(width: 8), const Tag('ينتظر ردّك')],
                            ]),
                          ),
                        ),
                    ]),
    );
  }
}

/// The developer's conversation with one reader.
class DevChatScreen extends StatefulWidget {
  final List<Doc> msgs;

  /// The reader's account, when the developer starts the conversation from his page.
  final Doc? user;
  const DevChatScreen({super.key, required this.msgs, this.user});
  @override
  State<DevChatScreen> createState() => _DevChatScreenState();
}

class _DevChatScreenState extends State<DevChatScreen> {
  final c = TextEditingController();
  bool busy = false;
  late Doc? user = widget.user;
  late List inbox = [...((widget.user?['grants'] as Map?)?['inbox'] as List? ?? [])];
  late List<Doc> msgs = widget.msgs;
  String get name => '${user?['name'] ?? (msgs.isEmpty ? 'قارئ' : msgs.first['name'])}';
  String get publicId => '${user?['publicId'] ?? (msgs.isEmpty ? '' : msgs.first['publicId'])}';

  @override
  void initState() {
    super.initState();
    final uidOf = user?['uid'];
    if (msgs.isEmpty && uidOf != null) {
      Cloud.i.messagesOf('$uidOf').then((m) {
        if (mounted && m.isNotEmpty) setState(() => msgs = m);
      });
    }
    if (user == null && publicId.isNotEmpty) {
      Cloud.i.findUser(publicId).then((u) {
        if (mounted && u != null) {
          setState(() {
            user = u;
            inbox = [...((u['grants'] as Map?)?['inbox'] as List? ?? [])];
          });
        }
      });
    }
  }

  Future<void> _send() async {
    final text = c.text.trim();
    if (text.isEmpty) return;
    setState(() => busy = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    bool ok;
    if (msgs.isNotEmpty) {
      // The reply hangs on the reader's latest message (the list is newest first).
      final last = msgs.first;
      ok = await Cloud.i.reply('${last['id']}', text);
      if (ok) {
        last['replies'] = [
          ...(last['replies'] as List? ?? []),
          {'text': text, 'at': now}
        ];
      }
    } else {
      ok = user != null && await Cloud.i.inboxSend('${user!['uid']}', text);
      if (ok) inbox.add({'text': text, 'at': now});
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok) c.clear();
    });
    if (!ok) toast(context, 'تعذّر الإرسال');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name),
            Text('رقمه: $publicId', style: TextStyle(fontSize: 12.5, color: C.muted(context))),
          ]),
          actions: [
            if (user != null && (Cloud.i.isDev || Cloud.i.can('حظر') || Cloud.i.can('إيقاف')))
              IconButton(
                tooltip: 'إدارته: الحظر والصلاحيات والشارات',
                onPressed: () => push(context, UserScreen(user: user!, admin: true)),
                icon: const Icon(Icons.menu_rounded),
              ),
            IconButton(
              tooltip: 'صفحته',
              onPressed: () => user != null ? push(context, UserScreen(user: user!)) : _openUser(context, publicId),
              icon: const Icon(Icons.badge_outlined),
            ),
            if (msgs.isNotEmpty)
              IconButton(
                tooltip: 'احذف المحادثة',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => showDialog(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('حذف المحادثة كلها؟'),
                    content: const Text('تُحذف رسائله وردودك، ولا يمكن التراجع.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
                        onPressed: () async {
                          Navigator.pop(d);
                          for (final m in msgs) {
                            await Cloud.i.deleteMessage('${m['id']}');
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('احذف'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: msgs.isEmpty && inbox.isEmpty
                ? const EmptyNote(Icons.forum_outlined, 'اكتب له أول رسالة. تصله في «راسل المطوّر».')
                : _Bubbles(_thread(msgs, inbox), dev: true),
          ),
          _ChatInput(ctl: c, busy: busy, hint: 'اكتب رسالتك له', onSend: _send),
        ]),
      );
}

/// The developer and supervisors: banned, suspended and warned readers.
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});
  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  int tab = 0;
  late Future<List<Doc>> job = Cloud.i.flagged(0);
  void _load() => setState(() => job = Cloud.i.flagged(tab));
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المخالفون'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
        body: !Cloud.i.can('حظر')
            ? const EmptyNote(Icons.lock_outline_rounded, 'هذه القائمة للمطوّر ومشرفي الحظر.')
            : Column(children: [
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, label: Text('المحظورون')),
                    ButtonSegment(value: 1, label: Text('الموقوفون مؤقتاً')),
                    ButtonSegment(value: 2, label: Text('المنذَرون')),
                  ],
                  selected: {tab},
                  onSelectionChanged: (v) {
                    tab = v.first;
                    _load();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('افتح أي اسم لترى متى ولماذا، ولتنذره أو توقفه أو تحظر حسابه أو هاتفه، أو ترفع ذلك. والمحظور يستطيع مراسلتك للمراجعة ما لم تمنعه.',
                      style: TextStyle(fontSize: 13.5, height: 1.6, color: C.muted(context))),
                ),
                Expanded(
                  child: FutureBuilder<List<Doc>>(
                    future: job,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                      final list = snap.data ?? [];
                      if (list.isEmpty) return const EmptyNote(Icons.verified_user_outlined, 'لا أحد في هذه القائمة.');
                      return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
                        for (final u in list)
                          _row(
                            context,
                            tab == 0 ? Icons.block_rounded : (tab == 1 ? Icons.timer_outlined : Icons.warning_amber_rounded),
                            '${u['name']} · ${u['publicId']}',
                            tab == 2
                                ? '${Ar.num(_n((u['grants'] as Map?)?['nWarn']))} إنذاراً · آخرها: ${((u['grants'] as Map?)?['warns'] as List? ?? [{}]).last['text'] ?? ''}'
                                : '${ago((u['grants'] as Map?)?['at'])} · السبب: ${(u['grants'] as Map?)?['reason'] ?? 'لم يُذكر'}',
                            () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserScreen(user: u)));
                              _load();
                            },
                          ),
                      ]);
                    },
                  ),
                ),
              ]),
      );
}

/// The developer adds supervisors by email and chooses what each may do.
class ModsScreen extends StatelessWidget {
  const ModsScreen({super.key});
  static const perms = ['حظر', 'إيقاف', 'بلاغات', 'رسائل', 'مراجعة', 'توثيق', 'تحرير', 'إخفاء'];

  /// Every power a supervisor can be given.
  static List<String> get allPerms => [...perms, 'شواهد', for (final s in Library.shawahidScholars) 'شواهد: $s', 'كتب الشعر', 'منتدى'];

  /// What each power lets him do, in a few words.
  static const about = {
    'تحرير': 'يعدّل نص الأبيات وتشكيلها واسم الشاعر',
    'إخفاء': 'يخفي بيتاً عن القرّاء ويعيد ما أخفاه',
    'توثيق': 'يضع العلامة الزرقاء',
    'شواهد': 'يُظهر ويخفي شواهد العلماء كلهم',
    'كتب الشعر': 'يُظهر ويخفي أشعار الدواوين',
    'حظر': 'يحظر الحسابات',
    'إيقاف': 'ينذر ويوقف مؤقتاً',
    'بلاغات': 'يقرأ البلاغات',
    'رسائل': 'يقرأ الرسائل ويرد',
    'مراجعة': 'يحذف الاقتباسات المخالفة',
    'منتدى': 'يدير المنتدى',
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Cloud.i,
        builder: (context, _) {
          final mods = Cloud.i.mods;
          return Scaffold(
            appBar: AppBar(title: const Text('المشرفون')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                final t = TextEditingController();
                showDialog(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('بريد المشرف (حساب جوجل)'),
                    content: TextField(controller: t, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'name@gmail.com')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
                      FilledButton(
                        onPressed: () {
                          if (t.text.contains('@')) Cloud.i.setMod(t.text, const []);
                          Navigator.pop(d);
                        },
                        child: const Text('أضف'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('أضف مشرفاً'),
            ),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
              Text('أضف المشرف ببريده من هنا، أو من صفحته الشخصية (⋯ ثم «اجعله مشرفاً»)، ثم اختر صلاحياته. تظهر له الأزرار حين يدخل بحسابه. ما يصنعه كل مشرف تراه في «سجلّ المشرفين».',
                  style: TextStyle(color: C.muted(context), height: 1.6)),
              const SizedBox(height: 10),
              if (mods.isEmpty) const EmptyNote(Icons.admin_panel_settings_outlined, 'لا مشرفين بعد.'),
              for (final e in mods.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: e.key.contains('@')
                              ? Text(e.key, textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context)))
                              : Text('${Cloud.i.modNames[e.key] ?? 'مشرف من صفحته'}', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
                        ),
                        IconButton(onPressed: () => Cloud.i.setMod(e.key, null), icon: const Icon(Icons.delete_outline_rounded)),
                      ]),
                      Wrap(spacing: 6, children: [
                        for (final p in allPerms)
                          FilterChip(
                            label: Text(p),
                            selected: (e.value as List).contains(p),
                            onSelected: (on) {
                              final l = [for (final x in e.value as List) '$x'];
                              on ? l.add(p) : l.remove(p);
                              Cloud.i.setMod(e.key, l);
                            },
                          ),
                      ]),
                    ]),
                  ),
                ),
            ]),
          );
        },
      );
}

/// The developer gives one member, from his page, the powers he chooses.
class ModPermsScreen extends StatelessWidget {
  final String uid, name;
  const ModPermsScreen({super.key, required this.uid, required this.name});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Cloud.i,
        builder: (context, _) {
          final mine = [for (final x in (Cloud.i.mods[uid] as List? ?? const [])) '$x'];
          final isMod = Cloud.i.mods.containsKey(uid);
          return Scaffold(
            appBar: AppBar(title: const Text('صلاحيات المشرف')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.ink(context))),
              const SizedBox(height: 4),
              Text(isMod ? 'مشرف الآن. فعّل له ما تريد، وما يصنعه يُكتب في «سجلّ المشرفين».' : 'ليس مشرفاً بعد. فعّل أي صلاحية ليصير مشرفاً.',
                  style: TextStyle(color: C.muted(context), height: 1.6)),
              const SizedBox(height: 10),
              for (final p in ModsScreen.allPerms)
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(p),
                  subtitle: ModsScreen.about[p] == null ? null : Text(ModsScreen.about[p]!),
                  value: mine.contains(p),
                  onChanged: (on) {
                    final l = [...mine];
                    on ? l.add(p) : l.remove(p);
                    Cloud.i.setMod(uid, l, name: name);
                  },
                ),
              if (isMod) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Cloud.i.setMod(uid, null);
                    toast(context, 'أُزيل من المشرفين');
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('أزله من المشرفين'),
                ),
              ],
            ]),
          );
        },
      );
}

/// «سجلّ المشرفين»: what each supervisor did (edits, hiding, showing), newest first.
class ModLogScreen extends StatefulWidget {
  const ModLogScreen({super.key});
  @override
  State<ModLogScreen> createState() => _ModLogScreenState();
}

class _ModLogScreenState extends State<ModLogScreen> {
  late Future<List<Doc>> job = Cloud.i.modLog();
  String who = '';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('سجلّ المشرفين'),
          actions: [IconButton(onPressed: () => setState(() => job = Cloud.i.modLog()), icon: const Icon(Icons.refresh_rounded))],
        ),
        body: !Cloud.i.isDev
            ? const EmptyNote(Icons.lock_outline_rounded, 'هذه الصفحة للمطوّر.')
            : FutureBuilder<List<Doc>>(
                future: job,
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final all = snap.data!;
                  if (all.isEmpty) return const EmptyNote(Icons.history_rounded, 'لا شيء في السجلّ بعد.');
                  final counts = <String, int>{};
                  final names = <String, String>{};
                  for (final x in all) {
                    final u = '${x['uid']}';
                    counts[u] = (counts[u] ?? 0) + 1;
                    names[u] = '${x['name'] ?? ''}'.isEmpty ? '${x['email'] ?? u}' : '${x['name']}';
                  }
                  final list = who.isEmpty ? all : all.where((x) => '${x['uid']}' == who).toList();
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
                    Wrap(spacing: 6, runSpacing: 2, children: [
                      ChoiceChip(label: Text('الكل ${Ar.num(all.length)}'), selected: who.isEmpty, onSelected: (_) => setState(() => who = '')),
                      for (final u in counts.keys)
                        ChoiceChip(label: Text('${names[u]} ${Ar.num(counts[u]!)}'), selected: who == u, onSelected: (_) => setState(() => who = u)),
                    ]),
                    const SizedBox(height: 10),
                    for (final x in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SoftCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${names['${x['uid']}']} — ${x['what']}', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context)))),
                              Text(ago(x['at']), style: TextStyle(fontSize: 12.5, color: C.muted(context))),
                            ]),
                            if ('${x['text'] ?? ''}'.isNotEmpty)
                              Padding(padding: const EdgeInsets.only(top: 4), child: Text('${x['text']}', style: TextStyle(fontFamily: verseFont, fontSize: 17, color: C.ink(context)))),
                            if ('${x['email'] ?? ''}'.isNotEmpty)
                              Text('${x['email']}', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 12, color: C.muted(context))),
                          ]),
                        ),
                      ),
                  ]);
                },
              ),
      );
}

/// «البلاغات» in three parts: the open reports, the readers whose reports are
/// muted (with what they reported), and the archive of closed reports.
class DevReportsScreen extends StatefulWidget {
  const DevReportsScreen({super.key});
  @override
  State<DevReportsScreen> createState() => _DevReportsScreenState();
}

class _DevReportsScreenState extends State<DevReportsScreen> {
  late Future<List<Doc>> job = Cloud.i.reports();
  void reload() => setState(() => job = Cloud.i.reports());

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('البلاغات'),
            actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded))],
            bottom: const TabBar(tabs: [Tab(text: 'البلاغات'), Tab(text: 'محظورو الإبلاغ'), Tab(text: 'الأرشيف')]),
          ),
          body: !(Cloud.i.can('حظر') || Cloud.i.can('بلاغات'))
              ? const EmptyNote(Icons.lock_outline_rounded, 'هذه الصفحة للمطوّر ومشرفي الحظر والبلاغات.')
              : FutureBuilder<List<Doc>>(
                  future: job,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                    final all = snap.data ?? <Doc>[];
                    final muted = Cloud.i.mutedReporters;
                    bool trusted(Doc r) => (r['byTitles'] as List? ?? const []).any((t) => t == 'الكاشف' || t == 'المراقب');
                    final open = <Doc>[
                      for (final r in all) if (r['closed'] != true && !muted.contains('${r['by']}') && trusted(r)) r,
                      for (final r in all) if (r['closed'] != true && !muted.contains('${r['by']}') && !trusted(r)) r,
                    ];
                    final fromMuted = <Doc>[for (final r in all) if (r['closed'] != true && muted.contains('${r['by']}')) r];
                    final archive = <Doc>[for (final r in all) if (r['closed'] == true) r];
                    Widget list(List<Doc> l, String empty, int tab) => l.isEmpty
                        ? EmptyNote(Icons.flag_outlined, empty)
                        : ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), children: [for (final r in l) _item(context, r, tab)]);
                    return TabBarView(children: [
                      list(open, 'لا بلاغات.', 0),
                      list(fromMuted, 'لا بلاغات ممن حظرت بلاغاتهم.', 1),
                      list(archive, 'الأرشيف فارغ.', 2),
                    ]);
                  },
                ),
        ),
      );

  Widget _item(BuildContext context, Doc r, int tab) {
    final by = '${r['by'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('بلاغ عن ${r['kind']} · ${ago(r['at'])}', style: TextStyle(fontWeight: FontWeight.w700, color: C.accent(context))),
          Text('${r['text']}', style: TextStyle(fontSize: 16, height: 1.6, color: C.ink(context))),
          if ('${r['target'] ?? ''}'.isNotEmpty) Text('الموضع: ${r['target']}', style: TextStyle(fontSize: 13, color: C.muted(context))),
          Text('المبلِّغ: ${r['byName']}${(r['byTitles'] as List? ?? const []).isEmpty ? '' : ' (${(r['byTitles'] as List).join('، ')})'}', style: TextStyle(color: C.muted(context))),
          Wrap(spacing: 4, children: [
            if (tab != 2 && r['kind'] == 'اقتباس')
              TextButton(
                onPressed: () async {
                  await Cloud.i.deleteQuote('${r['target']}');
                  await Cloud.i.closeReport('${r['id']}');
                  reload();
                },
                child: const Text('احذف الاقتباس'),
              ),
            if (tab != 2 && '${r['ofUid'] ?? ''}'.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final ok = await Cloud.i.setBanned('${r['ofUid']}', true);
                  if (context.mounted) toast(context, ok ? 'حُظر صاحبه عن النشر' : 'تعذّر');
                },
                child: const Text('احظر صاحبه'),
              ),
            if (tab == 0 && by.isNotEmpty)
              TextButton(
                onPressed: () {
                  Cloud.i.muteReporter(by, true);
                  toast(context, 'لن تظهر بلاغاته هنا بعد الآن');
                  setState(() {});
                },
                child: const Text('احظر بلاغاته'),
              ),
            if (tab == 1) ...[
              TextButton(
                onPressed: () {
                  Cloud.i.muteReporter(by, false);
                  toast(context, 'عادت بلاغاته إلى القائمة');
                  setState(() {});
                },
                child: const Text('ارفع الحظر عن بلاغاته'),
              ),
              TextButton(
                onPressed: () async {
                  final ok = await Cloud.i.setBanned(by, true);
                  if (context.mounted) toast(context, ok ? 'حُظر المبلِّغ نهائياً' : 'تعذّر');
                },
                child: const Text('احظره نهائياً'),
              ),
            ],
            if (tab != 2)
              TextButton(
                onPressed: () async {
                  await Cloud.i.closeReport('${r['id']}');
                  reload();
                },
                child: const Text('إلى الأرشيف'),
              ),
            if (tab == 2) ...[
              TextButton(
                onPressed: () async {
                  await Cloud.i.closeReport('${r['id']}', closed: false);
                  reload();
                },
                child: const Text('أعد فتحه'),
              ),
              TextButton(
                onPressed: () async {
                  await Cloud.i.deleteReport('${r['id']}');
                  reload();
                },
                child: const Text('احذفه نهائياً'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

/// «الشارات وأصحابها»: choose a badge and see everyone who carries it.
class BadgeHoldersScreen extends StatefulWidget {
  const BadgeHoldersScreen({super.key});
  @override
  State<BadgeHoldersScreen> createState() => _BadgeHoldersScreenState();
}

class _BadgeHoldersScreenState extends State<BadgeHoldersScreen> {
  String title = titlePresets.keys.first;
  late Future<List<Doc>> job = Cloud.i.usersWithTitle(title);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الشارات وأصحابها')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          Text('تمنح الشارة من صفحة القارئ: افتح صفحته ثم «الشارات».', style: TextStyle(height: 1.7, color: C.muted(context))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in titlePresets.keys)
              ChoiceChip(
                label: Text(t),
                selected: title == t,
                onSelected: (_) => setState(() {
                  title = t;
                  job = Cloud.i.usersWithTitle(t);
                }),
              ),
          ]),
          const SizedBox(height: 14),
          FutureBuilder<List<Doc>>(
            future: job,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              final list = snap.data ?? <Doc>[];
              if (list.isEmpty) return EmptyNote(Icons.workspace_premium_outlined, 'لم تمنح شارة «$title» لأحد بعد.');
              return Column(children: [
                for (final x in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () => push(context, MemberScreen(uid: '${x['id']}', name: '${x['name'] ?? ''}', publicId: '${x['publicId'] ?? ''}')),
                      child: Row(children: [
                        Expanded(child: Text('${x['name'] ?? ''}'.trim().isEmpty ? '${x['publicId'] ?? ''}' : '${x['name']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context)))),
                        Text('${x['publicId'] ?? ''}', style: TextStyle(fontSize: 13, color: C.muted(context))),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
        ]),
      );
}

class DevOrdersScreen extends StatelessWidget {
  const DevOrdersScreen({super.key});
  @override
  Widget build(BuildContext context) => _DevList(
        title: 'طلبات تصميم الكتب',
        empty: 'لا طلبات بعد.',
        icon: Icons.auto_stories_outlined,
        load: Cloud.i.orders,
        item: (context, o, reload) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${o['name']} · ${o['publicId']}', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context)))),
                Tag('${o['status']}'),
              ]),
              Text(ago(o['at']), style: TextStyle(fontSize: 12, color: C.muted(context))),
              if ('${o['note'] ?? ''}'.isNotEmpty) SelectableText('${o['note']}', style: TextStyle(height: 1.6, color: C.ink(context))),
              Wrap(spacing: 4, children: [
                for (final s in const ['دفع', 'قيد التصميم', 'سُلّم'])
                  TextButton(
                    onPressed: () async {
                      await Cloud.i.setOrderStatus('${o['id']}', s);
                      reload();
                    },
                    child: Text(s),
                  ),
                TextButton(onPressed: () => _openUser(context, '${o['publicId']}'), child: const Text('صفحته')),
              ]),
            ]),
          ),
        ),
      );
}

/// The developer: subscribers, sorted by how they subscribed.
class SubscribersScreen extends StatefulWidget {
  const SubscribersScreen({super.key});
  @override
  State<SubscribersScreen> createState() => _SubscribersScreenState();
}

class _SubscribersScreenState extends State<SubscribersScreen> {
  List<Doc>? now, former;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await Cloud.i.subscribers(), b = await Cloud.i.formerSubscribers();
    if (mounted) {
      setState(() {
        now = a;
        former = b;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = now ?? <Doc>[];
    final paid = all.where((u) => u['plusKind'] == 'مدفوع').toList();
    final gift = all.where((u) => u['plusKind'] != 'مدفوع').toList();
    final list = [all, gift, paid, former ?? <Doc>[]][tab];
    Widget stat(String n, String label) => Expanded(
          child: Column(children: [
            Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.accent(context))),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('المشتركون'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: !Cloud.i.isDev
          ? const EmptyNote(Icons.lock_outline_rounded, 'ادخل بحساب المطوّر من «صفحتك الشخصية» لتظهر القائمة.')
          : now == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
                  SoftCard(
                    child: Row(children: [
                      stat(Ar.num(all.length), 'كل المشتركين'),
                      stat(Ar.num(gift.length), 'هدية منك'),
                      stat(Ar.num(paid.length), 'بالمال'),
                      stat(Ar.num((former ?? []).length), 'انتهى اشتراكهم'),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 0, label: Text('الكل')),
                        ButtonSegment(value: 1, label: Text('هدية منك')),
                        ButtonSegment(value: 2, label: Text('بالمال')),
                        ButtonSegment(value: 3, label: Text('انتهى')),
                      ],
                      selected: {tab},
                      onSelectionChanged: (v) => setState(() => tab = v.first),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('لتضيف مشتركاً: افتح صفحته (من رسائله، أو ابحث برقمه في «من أتابعهم») ثم اضغط «اشتراك هدية منّي» أو «اشتراك مدفوع». ولإلغائه اضغط «ألغِ اشتراكه» في صفحته.',
                      style: TextStyle(color: C.muted(context), height: 1.6)),
                  const SizedBox(height: 10),
                  if (list.isEmpty) const EmptyNote(Icons.workspace_premium_outlined, 'لا أحد في هذه القائمة.'),
                  for (final u in list)
                    _row(
                      context,
                      Icons.workspace_premium_outlined,
                      '${u['name']} · ${u['publicId']}',
                      tab == 3
                          ? 'انتهى اشتراكه ${ago(u['plusEnded'])} · كان ${u['plusKind'] ?? 'هدية'}'
                          : '${u['plusKind'] ?? 'هدية'} · اشترك ${ago(u['plusAt'])} · آخر دخول: ${u['lastDay'] == Store.today ? 'اليوم' : 'قبل ${Ar.num(Store.today - _n(u['lastDay']))} يوماً'}',
                      () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserScreen(user: u)));
                        _load();
                      },
                    ),
                ]),
    );
  }
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

String _dateOf(dynamic ms) {
  if (ms is! num) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
  return '${Ar.num(d.year)}/${Ar.num(d.month)}/${Ar.num(d.day)}';
}

/// When the reader was last seen: the exact time when known, otherwise the day.
String _lastSeen(Doc u) {
  if (u['lastAt'] is num) return ago(u['lastAt']);
  final d = u['lastDay'];
  if (d is! num) return 'غير معروف';
  final n = Store.today - d.toInt();
  return n <= 0 ? 'اليوم' : 'قبل ${Ar.num(n)} يوماً';
}

class _StatsScreenState extends State<StatsScreen> {
  late final Future<List<int>?> job = Cloud.i.stats();
  // 0 = newest first, 1 = last seen, 2 = most distinguished
  int tab = 0;
  int limit = 100;
  List<Doc>? people;

  static const _fields = ['joined', 'lastDay', 'points'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => people = null);
    var l = await Cloud.i.members(_fields[tab], limit: limit);
    if (tab == 1) {
      // inside one day, the exact last visit decides
      l = [...l]..sort((a, b) {
          final c = _n(b['lastDay']).compareTo(_n(a['lastDay']));
          return c != 0 ? c : _n(b['lastAt']).compareTo(_n(a['lastAt']));
        });
    }
    if (mounted) setState(() => people = l);
  }

  /// Why a reader counts as distinguished: how much he takes part.
  String _why(Doc u) {
    final parts = <String>[
      'نقاط ${Ar.num(_n(u['points']))}',
      if (_n(u['days']) > 0) '${Ar.num(_n(u['days']))} يوماً',
      if (_n(u['streak']) > 1) 'تتابع ${Ar.num(_n(u['streak']))}',
      if (_n(u['memo']) > 0) 'حفظ ${Ar.num(_n(u['memo']))}',
      if (_n(u['likes']) > 0) 'إعجابات ${Ar.num(_n(u['likes']))}',
      if (_n(u['poets']) > 0) 'شعراء ${Ar.num(_n(u['poets']))}',
    ];
    return parts.join(' · ');
  }

  Widget _stat(BuildContext context, String label, int v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: C.ink(context)))),
          Text(Ar.num(v), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.accent(context))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final list = people;
    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 140), children: [
        FutureBuilder<(int, int, int)?>(
          future: Device.downloads(),
          builder: (context, snap) {
            final d = snap.data;
            return SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('تحميلات ملف التطبيق (APK)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
                const SizedBox(height: 8),
                if (snap.connectionState != ConnectionState.done)
                  const LinearProgressIndicator()
                else if (d == null)
                  Text('تظهر في تطبيق الجوال (لا في الموقع)، وتحتاج اتصالاً بالإنترنت.', style: TextStyle(color: C.muted(context)))
                else ...[
                  Text('كل التحميلات: ${Ar.num(d.$1)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.accent(context))),
                  Text('تحميلات آخر نسخة (${Ar.num(d.$3)}): ${Ar.num(d.$2)}', style: TextStyle(color: C.ink(context))),
                ],
              ]),
            );
          },
        ),
        const SizedBox(height: 10),
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أصحاب الحسابات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
            const SizedBox(height: 6),
            FutureBuilder<List<int>?>(
              future: job,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator();
                final v = snap.data;
                if (v == null) return Text('ادخل بحساب المطوّر من «صفحتك الشخصية» لتظهر الأرقام.', style: TextStyle(color: C.muted(context)));
                int at(int i) => i < v.length ? v[i] : 0;
                return Column(children: [
                  _stat(context, 'كل من سجّل', at(0)),
                  const Divider(height: 14),
                  _stat(context, 'دخلوا اليوم', at(1)),
                  _stat(context, 'دخلوا هذا الأسبوع', at(2)),
                  _stat(context, 'دخلوا آخر ٣٠ يوماً', at(5)),
                  const Divider(height: 14),
                  _stat(context, 'سجّلوا اليوم', at(6)),
                  _stat(context, 'سجّلوا هذا الأسبوع', at(3)),
                  _stat(context, 'سجّلوا آخر ٣٠ يوماً', at(7)),
                  const Divider(height: 14),
                  _stat(context, 'المشتركون', at(4)),
                ]);
              },
            ),
            const SizedBox(height: 6),
            Text('تُحسب ممن دخل بحسابه فقط. الزوّار بلا حساب لا يُعدّون هنا.', style: TextStyle(color: C.muted(context), height: 1.6)),
          ]),
        ),
        if (Cloud.i.isDev) ...[
          const SizedBox(height: 14),
          Text('المسجّلون', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink(context))),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('الأحدث تسجيلاً')),
                ButtonSegment(value: 1, label: Text('آخر اتصال')),
                ButtonSegment(value: 2, label: Text('المتميزون')),
              ],
              selected: {tab},
              onSelectionChanged: (v) {
                tab = v.first;
                limit = 100;
                _load();
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tab == 0
                ? 'من سجّل حديثاً أولاً، مع تاريخ تسجيله.'
                : tab == 1
                    ? 'من دخل قبل قليل أولاً، ومتى كان آخر اتصال له.'
                    : 'مرتّبون بنقاطهم، والمتميز هو الأكثر مشاركة: نقاط وأياماً وحفظاً وإعجابات.',
            style: TextStyle(color: C.muted(context), height: 1.6),
          ),
          const SizedBox(height: 10),
          if (list == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (list.isEmpty)
            const EmptyNote(Icons.people_outline_rounded, 'لا أحد في هذه القائمة بعد.')
          else ...[
            for (var i = 0; i < list.length; i++)
              _row(
                context,
                tab == 2 && i < 10 && _n(list[i]['points']) > 0 ? Icons.military_tech_rounded : (list[i]['plus'] == true ? Icons.workspace_premium_outlined : Icons.person_outline_rounded),
                '${tab == 2 ? '${Ar.num(i + 1)}. ' : ''}${list[i]['name'] ?? ''} · ${list[i]['publicId'] ?? ''}${tab == 2 && i < 10 && _n(list[i]['points']) > 0 ? ' · متميز' : ''}',
                tab == 2
                    ? '${_why(list[i])}\nسجّل ${_dateOf(list[i]['joined'])} · آخر اتصال: ${_lastSeen(list[i])}'
                    : 'سجّل ${_dateOf(list[i]['joined']).isEmpty ? 'قبل ${Ar.num(Store.today - _n(list[i]['joinedDay']))} يوماً' : _dateOf(list[i]['joined'])} (${ago(list[i]['joined'])})\nآخر اتصال: ${_lastSeen(list[i])} · ${_why(list[i])}',
                () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserScreen(user: list[i])));
                },
              ),
            if (list.length >= limit)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    limit += 100;
                    _load();
                  },
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('عرض المزيد'),
                ),
              ),
          ],
        ],
      ]),
    );
  }
}

/// Shown instead of the app when the developer banned this phone.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.block_rounded, size: 64, color: Color(0xFFB3261E)),
              const SizedBox(height: 14),
              const Text('حُظر هذا الجهاز من «منتقيات الشعر»', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('إن رأيت أن الحظر خطأ فراسل المطوّر في تيليجرام: t.me/alhsaar4', textAlign: TextAlign.center, style: TextStyle(height: 1.7, color: C.muted(context))),
            ]),
          ),
        ),
      );
}
