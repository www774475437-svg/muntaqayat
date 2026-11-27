import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../ui.dart';
import 'cloud_ui.dart';
import 'forum.dart';
import 'lists.dart';
import 'plus.dart' show PlusScreen;
import 'qawafi.dart' show MemberScreen;

/// What a member gained since he last looked: followers, likes, replies, tests, warnings.
/// There is no server pushing these: the numbers are read when the app opens and when the page is opened.
class Notifs {
  static final fresh = ValueNotifier<int>(0);
  static int followers = 0, likes = 0;
  static List<Doc> posts = [], replies = [], tests = [];

  /// The developer only: what readers wrote to him.
  static List<Doc> inbox = [];
  static int get inboxNew => [for (final m in inbox) if (_at(m['at']) > _seen('devmsg')) m].length;

  /// Readers whose latest message has no reply yet.
  static int get inboxWaiting {
    final seen = <String>{};
    var n = 0;
    for (final m in inbox) {
      if (seen.add('${m['uid']}') && '${m['reply'] ?? ''}'.isEmpty) n++;
    }
    return n;
  }

  /// He opened «من راسلني»: the bell stops counting what is there now.
  static void inboxSeen() {
    final id = Cloud.i.uid;
    if (_p == null || id.isEmpty) return;
    _p!.setInt('nf:devmsg:$id', DateTime.now().millisecondsSinceEpoch);
    fresh.value = max(0, fresh.value - _inboxCounted);
    _inboxCounted = 0;
  }

  static int _inboxCounted = 0;
  static bool loaded = false;
  static Future<void>? _job;
  static SharedPreferences? _p;

  static int _seen(String k) => _p?.getInt('nf:$k:${Cloud.i.uid}') ?? 0;
  static int get newFollowers => max(0, followers - _seen('followers'));
  static int get newLikes => max(0, likes - _seen('likes'));
  static List<Doc> get newReplies => [for (final m in replies) if (_at(m['replyAt']) > _seen('at')) m];
  static List<Map> get newWarns => [for (final w in Cloud.i.warns) if (_at(w['at']) > _seen('at')) w];
  static int get newTests => max(0, tests.length - _seen('tests'));
  static int _at(dynamic v) => v is num ? v.toInt() : 0;

  static Future<void> load({bool force = false}) => _job ??= _load(force).whenComplete(() => _job = null);

  static Future<void> _load(bool force) async {
    _p ??= await SharedPreferences.getInstance();
    final c = Cloud.i;
    if (!c.signedIn) {
      fresh.value = 0;
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // Once every three hours is enough unless the member opens the page himself.
    if (!force && loaded && now - (_p!.getInt('nf:last') ?? 0) < 3 * 3600 * 1000) return;
    final r = await Future.wait([c.followersCount(c.uid), c.quotes(of: c.uid), c.myMessages(), c.myTests()]);
    followers = r[0] as int;
    posts = (r[1] as List<Doc>)..sort((a, b) => _at(b['likes']).compareTo(_at(a['likes'])));
    likes = posts.fold<int>(0, (s, q) => s + max(0, _at(q['likes'])));
    replies = [for (final m in r[2] as List<Doc>) if ('${m['reply'] ?? ''}'.isNotEmpty) m]..sort((a, b) => _at(b['replyAt']).compareTo(_at(a['replyAt'])));
    tests = r[3] as List<Doc>;
    inbox = c.isDev ? [for (final m in await c.allMessages()) if ('${m['uid']}' != c.uid) m] : [];
    _inboxCounted = inboxNew;
    loaded = true;
    _p!.setInt('nf:last', now);
    await Forum.i.peek();
    fresh.value = newFollowers + newLikes + newReplies.length + newWarns.length + newTests + forumNew + _inboxCounted;
  }

  /// Replies to me in the forum and private notes from its supervisors: these always reach the bell.
  static int get forumNew => Forum.i.visible ? Forum.i.repliesToMe.length + Forum.i.newNotes.length : 0;

  /// The member has seen the page: what is there now is no longer new.
  static void markSeen() {
    final id = Cloud.i.uid;
    if (_p == null || id.isEmpty || !loaded) return;
    _p!.setInt('nf:followers:$id', followers);
    _p!.setInt('nf:likes:$id', likes);
    _p!.setInt('nf:tests:$id', tests.length);
    _p!.setInt('nf:at:$id', DateTime.now().millisecondsSinceEpoch);
    fresh.value = _inboxCounted;
  }
}

/// The bell at the top of «اليوم», with a dot when something is new.
class BellButton extends StatefulWidget {
  const BellButton({super.key});
  @override
  State<BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<BellButton> {
  @override
  void initState() {
    super.initState();
    Notifs.load();
  }

  @override
  Widget build(BuildContext context) => Material(
        color: C.bar(context),
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black12,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => push(context, const NotifsScreen()),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: ValueListenableBuilder<int>(
              valueListenable: Notifs.fresh,
              builder: (context, n, _) => Stack(clipBehavior: Clip.none, children: [
                Icon(Icons.notifications_none_rounded, color: C.accent(context), size: 23),
                if (n > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFFB3261E), borderRadius: BorderRadius.circular(10)),
                      child: Text(n > 99 ? '+٩٩' : Ar.num(n), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.2)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
}

class NotifsScreen extends StatefulWidget {
  const NotifsScreen({super.key});
  @override
  State<NotifsScreen> createState() => _NotifsScreenState();
}

class _NotifsScreenState extends State<NotifsScreen> {
  late Future<void> job = Notifs.load(force: true);
  // What was new when the page opened stays marked while he reads it.
  int nf = 0, nl = 0, nt = 0;
  List<Doc> nr = [];
  List<Map> nw = [];

  @override
  void initState() {
    super.initState();
    job.then((_) {
      if (!mounted) return;
      setState(() {
        nf = Notifs.newFollowers;
        nl = Notifs.newLikes;
        nt = Notifs.newTests;
        nr = Notifs.newReplies;
        nw = Notifs.newWarns;
      });
      Notifs.markSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Cloud.i;
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: !c.signedIn
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.all(24), child: Text('ادخل بحسابك لترى متابعيك وإعجاباتهم والردود عليك.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.7, color: C.muted(context)))),
                FilledButton(
                  onPressed: () async {
                    if (await needAccount(context) && mounted) {
                      setState(() => job = Notifs.load(force: true));
                    }
                  },
                  child: const Text('الدخول'),
                ),
              ]),
            )
          : FutureBuilder<void>(
              future: job,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                final nothingNew = nf + nl + nt + nr.length + nw.length + Notifs.forumNew == 0;
                return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
                  Row(children: [
                    Expanded(child: _count(context, Icons.people_outline_rounded, 'المتابعون', Notifs.followers, nf, () => push(context, FollowListScreen(title: 'المتابِعون', load: () => c.followers(c.uid))))),
                    const SizedBox(width: 10),
                    Expanded(child: _count(context, Icons.thumb_up_alt_outlined, 'الإعجابات', Notifs.likes, nl, () => push(context, QuotesScreen(of: c.uid, title: 'اقتباساتي')))),
                  ]),
                  const SizedBox(height: 10),
                  _inboxRow(context),
                  const SectionTitle('الجديد'),
                  if (nothingNew) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('لا جديد منذ آخر مرة.', style: TextStyle(color: C.muted(context), fontSize: 15))),
                  if (nf > 0) _line(context, Icons.person_add_alt_1_outlined, 'تابعك ${Ar.num(nf)} منذ آخر مرة', () => push(context, FollowListScreen(title: 'المتابِعون', load: () => c.followers(c.uid)))),
                  if (nl > 0) _line(context, Icons.thumb_up_alt_outlined, 'نالت منشوراتك ${Ar.num(nl)} إعجاباً جديداً', () => push(context, QuotesScreen(of: c.uid, title: 'اقتباساتي'))),
                  for (final m in nr) _line(context, Icons.mark_chat_read_outlined, 'ردّ عليك المطوّر: ${m['reply']}', () => push(context, const MessageDevScreen())),
                  if (nt > 0) _line(context, Icons.assignment_outlined, 'وصلك ${Ar.num(nt)} اختباراً جديداً', () => push(context, const StudentTestsScreen())),
                  for (final w in nw) _line(context, Icons.warning_amber_rounded, 'إنذار: ${w['text']}', null),
                  if (Forum.i.visible) ...[
                    for (final m in Forum.i.repliesToMe) _line(context, Icons.forum_outlined, 'ردّ عليك ${m['name']} في المنتدى: ${m['text'] ?? ''}', () => push(context, const ForumScreen())),
                    for (final n in Forum.i.newNotes) _line(context, Icons.admin_panel_settings_outlined, 'من إشراف المنتدى: ${n['text']}', () => push(context, const ForumScreen())),
                  ],
                  if (Notifs.posts.any((q) => ((q['likes'] ?? 0) as num) > 0)) ...[
                    const SectionTitle('أكثر منشوراتك إعجاباً'),
                    for (final q in Notifs.posts.where((q) => ((q['likes'] ?? 0) as num) > 0).take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SoftCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Expanded(child: Text('${q['a'] ?? q['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: verseFont, fontSize: 17, color: C.ink(context)))),
                            const SizedBox(width: 10),
                            Icon(Icons.thumb_up_alt_outlined, size: 17, color: C.accent(context)),
                            const SizedBox(width: 4),
                            Text(Ar.num(((q['likes'] ?? 0) as num).toInt()), style: TextStyle(fontWeight: FontWeight.w700, color: C.accent(context))),
                          ]),
                        ),
                      ),
                  ],
                  const SectionTitle('الأوسمة والجوائز والعروض'),
                  _line(context, Icons.military_tech_outlined, 'أوسمتك ومستواك وجوائزك: في صفحتك الشخصية', () => push(context, MemberScreen(uid: c.uid, name: c.name, publicId: c.publicId))),
                  if (Store.i.plusOn) _line(context, Icons.local_offer_outlined, 'عرض انطلاق التطبيق: اشترك شهراً واحصل على الثاني مجاناً', () => push(context, const PlusScreen())),
                  if (Notifs.replies.isNotEmpty) ...[
                    const SectionTitle('ردود المطوّر'),
                    for (final m in Notifs.replies.take(5)) _line(context, Icons.mark_chat_read_outlined, '${m['reply']}', () => push(context, const MessageDevScreen())),
                  ],
                ]);
              },
            ),
    );
  }

  Widget _count(BuildContext context, IconData icon, String label, int n, int fresh, VoidCallback onTap) => SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: C.accent(context)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: C.muted(context), fontSize: 14.5)),
          ]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Ar.num(n), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: C.ink(context))),
            if (fresh > 0) ...[
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('+${Ar.num(fresh)}', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700))),
            ],
          ]),
        ]),
      );

  /// The long row under the two numbers: the developer's inbox, or the reader's letters to him.
  Widget _inboxRow(BuildContext context) {
    final dev = Cloud.i.isDev;
    final n = dev ? Notifs.inboxNew : nr.length;
    final wait = dev ? Notifs.inboxWaiting : 0;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: () async {
        if (dev) Notifs.inboxSeen();
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => dev ? const DevMessagesScreen() : const MessageDevScreen()));
        if (!mounted) return;
        if (dev) await Notifs.load(force: true);
        if (mounted) setState(() {});
      },
      child: Row(children: [
        Icon(Icons.mark_email_unread_outlined, size: 24, color: C.accent(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dev ? 'من راسلني' : 'مراسلة المطوّر', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
            Text(
              dev
                  ? (wait > 0 ? '${Ar.num(wait)} ينتظرون ردّك' : 'لا أحد ينتظر ردّك')
                  : (n > 0 ? 'ردّ عليك المطوّر' : 'اكتب له، ويصلك ردّه هنا'),
              style: TextStyle(fontSize: 13.5, color: C.muted(context)),
            ),
          ]),
        ),
        if (n > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFB3261E), borderRadius: BorderRadius.circular(12)),
            child: Text(Ar.num(n), style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_left_rounded, color: C.muted(context)),
      ]),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SoftCard(
          onTap: onTap,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, size: 21, color: C.accent(context)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, height: 1.5, color: C.ink(context)))),
            if (onTap != null) Icon(Icons.chevron_left_rounded, color: C.muted(context)),
          ]),
        ),
      );
}
