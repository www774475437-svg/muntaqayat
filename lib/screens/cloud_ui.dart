import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../services/device.dart';
import '../ui.dart';
import 'lists.dart';
import 'mutun.dart';
import 'poem.dart';

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
  final go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ادخل بحسابك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${why.isEmpty ? '' : '$why\n\n'}تدخل بحساب جوجل بضغطة واحدة، فيكون لك رقم شخصي ثابت من سبعة أرقام. لا نطلب كلمة مرور، ولا يظهر بريدك لأحد من القرّاء.',
            style: const TextStyle(fontSize: 16, height: 1.7)),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => Navigator.pop(c, true),
          icon: const Icon(Icons.login_rounded),
          label: const Text('ادخل بحساب جوجل', style: TextStyle(fontSize: 17)),
        ),
      ]),
    ),
  );
  if (go != true || !context.mounted) return false;
  final err = await Cloud.i.signIn();
  if (!context.mounted) return false;
  if (err != null) {
    toast(context, err);
    return false;
  }
  toast(context, 'أهلاً بك. رقمك الشخصي: ${Cloud.i.publicId}');
  return true;
}

// ------------------------------------------------------------ profile

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Cloud.i, Store.i]),
        builder: (context, _) {
          final s = Store.i, c = Cloud.i;
          final memo = s.memorized.values.fold<int>(0, (a, b) => a + b.length);
          final joined = c.profile['joined'];
          return Scaffold(
            appBar: AppBar(title: const Text('صفحتك الشخصية')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              SoftCard(
                child: Column(children: [
                  const RoundIcon(Icons.person_rounded, size: 72),
                  const SizedBox(height: 8),
                  Text(c.signedIn ? c.name : 'لم تدخل بعد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.ink(context))),
                  const SizedBox(height: 4),
                  if (c.signedIn && c.publicId.isNotEmpty)
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: c.publicId));
                        toast(context, 'نُسخ رقمك الشخصي');
                      },
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('رقمك الشخصي: ${c.publicId}', style: TextStyle(fontSize: 16, color: C.accent(context), fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 16, color: C.muted(context)),
                      ]),
                    )
                  else
                    Text('رقمك الشخصي: ٧ أرقام ثابتة لا تتغير', style: TextStyle(color: C.muted(context))),
                  if (c.isDev) ...[
                    const SizedBox(height: 6),
                    const Tag('حساب المطوّر'),
                  ],
                  const SizedBox(height: 14),
                  Row(children: [
                    _stat(context, Ar.num(s.likes.length), 'إعجاب'),
                    _stat(context, Ar.num(_n(c.profile['points'])), 'نقطة'),
                    _stat(context, Ar.num(memo), 'بيتاً حفظه'),
                    _stat(context, Ar.num(s.days.length), 'يوماً'),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: c.signedIn
                        ? OutlinedButton.icon(onPressed: () => _rename(context), icon: const Icon(Icons.edit_outlined), label: const Text('غيّر اسمك'))
                        : FilledButton.icon(
                            onPressed: () => needAccount(context),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('ادخل بحساب جوجل'),
                          ),
                  ),
                ]),
              ),
              _section(context, 'في صفحتك'),
              _row(context, Icons.format_quote_rounded, 'اقتباساتي', 'ما نشرته من أبيات (عشرة في اليوم)', () async {
                if (await needAccount(context) && context.mounted) push(context, QuotesScreen(of: c.uid, title: 'اقتباساتي'));
              }),
              _row(context, Icons.bookmark_border_rounded, 'المحفوظات', 'حفظت ${Ar.verses(memo)}', () => push(context, const MutunScreen())),
              _row(context, Icons.people_outline_rounded, 'من أتابعهم', 'ابحث عن أي شخص برقمه الشخصي', () => push(context, const FollowingScreen())),
              _row(context, Icons.local_fire_department_outlined, 'الأيام المتتالية', '${Ar.num(_n(c.profile['streak']))} يوماً متتالياً في المجلس', () {}),
              if (joined is num)
                _row(context, Icons.event_outlined, 'تاريخ التسجيل', ago(joined), () {}),
              const SizedBox(height: 8),
              Text('تُحدَّث أرقام صفحتك على الخادم مرة في اليوم، لا لحظة بلحظة.', style: TextStyle(color: C.muted(context), fontSize: 13.5)),
              if (c.signedIn) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () async {
                    await c.signOut();
                    if (context.mounted) toast(context, 'خرجت من حسابك');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('اخرج من الحساب'),
                ),
              ],
            ]),
          );
        },
      );

  Widget _stat(BuildContext context, String n, String label) => Expanded(
        child: Column(children: [
          Text(n, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.accent(context))),
          Text(label, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
        ]),
      );

  void _rename(BuildContext context) {
    final t = TextEditingController(text: Cloud.i.name);
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('اسمك الظاهر للناس'),
        content: TextField(controller: t, maxLength: 20, decoration: const InputDecoration(hintText: 'اسم لائق')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(d);
              final ok = await Cloud.i.setName(t.text);
              if (context.mounted) toast(context, ok ? 'حُفظ الاسم' : 'تعذّر الحفظ');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
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
class UserScreen extends StatelessWidget {
  final Doc user;
  const UserScreen({super.key, required this.user});
  @override
  Widget build(BuildContext context) {
    final id = '${user['publicId']}', name = '${user['name'] ?? 'قارئ'}';
    return ListenableBuilder(
      listenable: Cloud.i,
      builder: (context, _) {
        final following = Cloud.i.following.containsKey(id);
        return Scaffold(
          appBar: AppBar(title: Text(name), actions: [
            IconButton(
              tooltip: 'إبلاغ',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () async {
                final ok = await Cloud.i.report('اسم', id, name, ofUid: '${user['uid']}');
                if (context.mounted) toast(context, ok ? 'وصل بلاغك إلى المطوّر' : 'تعذّر الإرسال');
              },
            ),
          ]),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
            SoftCard(
              child: Column(children: [
                const RoundIcon(Icons.person_rounded, size: 64),
                const SizedBox(height: 6),
                Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.ink(context))),
                Text('رقمه الشخصي: $id', style: TextStyle(color: C.muted(context))),
                const SizedBox(height: 10),
                Text('${Ar.num(_n(user['points']))} نقطة · حفظ ${Ar.verses(_n(user['memo']))} · ${Ar.num(_n(user['streak']))} يوماً متتالياً',
                    textAlign: TextAlign.center, style: TextStyle(color: C.ink(context))),
                const SizedBox(height: 10),
                following
                    ? OutlinedButton(onPressed: () => Cloud.i.follow(id, name, false), child: const Text('ألغِ المتابعة'))
                    : FilledButton(onPressed: () => Cloud.i.follow(id, name, true), child: const Text('تابعه')),
                if (Cloud.i.isDev) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(
                      onPressed: () async {
                        final on = user['banned'] != true;
                        final ok = await Cloud.i.setBanned('${user['uid']}', on);
                        if (ok) user['banned'] = on;
                        if (context.mounted) toast(context, !ok ? 'تعذّر' : (on ? 'حُظر عن النشر' : 'رُفع الحظر'));
                      },
                      child: Text(user['banned'] == true ? 'ارفع الحظر' : 'احظره عن النشر'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final on = user['plus'] != true;
                        final ok = await Cloud.i.setPlus('${user['uid']}', on);
                        if (ok) user['plus'] = on;
                        if (context.mounted) toast(context, !ok ? 'تعذّر' : (on ? 'صار مشتركاً' : 'أُلغي اشتراكه'));
                      },
                      child: Text(user['plus'] == true ? 'ألغِ اشتراكه' : 'اجعله مشتركاً'),
                    ),
                  ]),
                ],
              ]),
            ),
            _section(context, 'اقتباساته'),
            QuotesList(of: '${user['uid']}'),
          ]),
        );
      },
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
              icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border, color: liked ? const Color(0xFFB3261E) : null),
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
                      child: const Text('ادخل بحساب جوجل'),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Expanded(child: Text('${(r as Map)['name']} · ${r['publicId']}', style: TextStyle(color: C.ink(context)))),
                            Text('${Ar.num(_n(r['r']))} من ${Ar.num(_n(r['t']))}', style: TextStyle(fontWeight: FontWeight.w700, color: C.accent(context))),
                          ]),
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

class MessageDevScreen extends StatefulWidget {
  const MessageDevScreen({super.key});
  @override
  State<MessageDevScreen> createState() => _MessageDevScreenState();
}

class _MessageDevScreenState extends State<MessageDevScreen> {
  final c = TextEditingController();
  Future<List<Doc>> job = Cloud.i.myMessages();
  bool busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('راسل المطوّر')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
          Text('ثلاث رسائل في اليوم مجاناً، وبلا حد للمشتركين. يصلك الرد هنا داخل التطبيق.', style: TextStyle(color: C.muted(context), height: 1.6)),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'اكتب رسالتك',
              filled: true,
              fillColor: C.card(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () async {
                    if (!await needAccount(context, 'لتصلك ردود المطوّر في حسابك.')) return;
                    setState(() => busy = true);
                    final err = await Cloud.i.sendMessage(c.text);
                    if (!mounted) return;
                    setState(() {
                      busy = false;
                      if (err == null) {
                        c.clear();
                        job = Cloud.i.myMessages();
                      }
                    });
                    toast(context, err ?? 'وصلت رسالتك');
                  },
            icon: const Icon(Icons.send_rounded),
            label: const Text('أرسل'),
          ),
          _section(context, 'رسائلك'),
          FutureBuilder<List<Doc>>(
            future: job,
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator();
              if (list.isEmpty) return Text('لا رسائل بعد.', style: TextStyle(color: C.muted(context)));
              return Column(children: [for (final m in list) _MessageCard(m)]);
            },
          ),
        ]),
      );
}

class _MessageCard extends StatelessWidget {
  final Doc m;
  final Widget? actions;
  const _MessageCard(this.m, {this.actions});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SoftCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(actions == null ? 'أنت' : '${m['name']} · ${m['publicId']}', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context)))),
              Text(ago(m['at']), style: TextStyle(fontSize: 12, color: C.muted(context))),
            ]),
            const SizedBox(height: 4),
            SelectableText('${m['text']}', style: TextStyle(fontSize: 16, height: 1.6, color: C.ink(context))),
            if ('${m['reply'] ?? ''}'.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: C.soft(context), borderRadius: BorderRadius.circular(12)),
                child: Text('ردّ المطوّر: ${m['reply']}', style: TextStyle(height: 1.6, color: C.ink(context))),
              ),
            if (actions != null) actions!,
          ]),
        ),
      );
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

Future<String?> _ask(BuildContext context, String title, [String initial = '']) {
  final t = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(controller: t, minLines: 2, maxLines: 6, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(d, t.text), child: const Text('حفظ')),
      ],
    ),
  );
}

Future<void> _openUser(BuildContext context, String publicId) async {
  final u = await Cloud.i.findUser(publicId);
  if (u != null && context.mounted) push(context, UserScreen(user: u));
}

class DevMessagesScreen extends StatelessWidget {
  const DevMessagesScreen({super.key});
  @override
  Widget build(BuildContext context) => _DevList(
        title: 'الرسائل',
        empty: 'لا رسائل بعد.',
        icon: Icons.mark_email_unread_outlined,
        load: Cloud.i.allMessages,
        item: (context, m, reload) => _MessageCard(
          m,
          actions: Row(children: [
            TextButton(
              onPressed: () async {
                final r = await _ask(context, 'ردّك على ${m['name']}', '${m['reply'] ?? ''}');
                if (r != null && await Cloud.i.reply('${m['id']}', r)) reload();
              },
              child: const Text('ردّ'),
            ),
            TextButton(onPressed: () => _openUser(context, '${m['publicId']}'), child: const Text('صفحته')),
            const Spacer(),
            IconButton(
              onPressed: () async {
                await Cloud.i.deleteMessage('${m['id']}');
                reload();
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ]),
        ),
      );
}

class DevReportsScreen extends StatelessWidget {
  const DevReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => _DevList(
        title: 'البلاغات',
        empty: 'لا بلاغات.',
        icon: Icons.flag_outlined,
        load: Cloud.i.reports,
        item: (context, r, reload) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('بلاغ عن ${r['kind']} · ${ago(r['at'])}', style: TextStyle(fontWeight: FontWeight.w700, color: C.accent(context))),
              Text('${r['text']}', style: TextStyle(fontSize: 16, height: 1.6, color: C.ink(context))),
              Text('المبلِّغ: ${r['byName']}', style: TextStyle(color: C.muted(context))),
              Wrap(spacing: 4, children: [
                if (r['kind'] == 'اقتباس')
                  TextButton(
                    onPressed: () async {
                      await Cloud.i.deleteQuote('${r['target']}');
                      await Cloud.i.closeReport('${r['id']}');
                      reload();
                    },
                    child: const Text('احذف الاقتباس'),
                  ),
                if ('${r['ofUid'] ?? ''}'.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final ok = await Cloud.i.setBanned('${r['ofUid']}', true);
                      if (context.mounted) toast(context, ok ? 'حُظر صاحبه عن النشر' : 'تعذّر');
                    },
                    child: const Text('احظر صاحبه'),
                  ),
                TextButton(
                  onPressed: () async {
                    await Cloud.i.closeReport('${r['id']}');
                    reload();
                  },
                  child: const Text('أغلق البلاغ'),
                ),
              ]),
            ]),
          ),
        ),
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

class SubscribersScreen extends StatelessWidget {
  const SubscribersScreen({super.key});
  @override
  Widget build(BuildContext context) => _DevList(
        title: 'المشتركون',
        empty: 'لا مشتركين بعد. لتجعل أحداً مشتركاً: ابحث برقمه من «من أتابعهم» ثم اضغط «اجعله مشتركاً».',
        icon: Icons.workspace_premium_outlined,
        load: Cloud.i.subscribers,
        item: (context, u, reload) => _row(
          context,
          Icons.workspace_premium_outlined,
          '${u['name']} · ${u['publicId']}',
          'مشترك ${ago(u['plusAt'])} · آخر دخول: ${u['lastDay'] == Store.today ? 'اليوم' : 'قبل ${Ar.num(Store.today - _n(u['lastDay']))} يوماً'}',
          () => push(context, UserScreen(user: u)),
        ),
      );
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final Future<List<int>?> job = Cloud.i.stats();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الإحصائيات')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
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
                  const labels = ['كل من سجّل', 'دخلوا اليوم', 'دخلوا هذا الأسبوع', 'الجدد هذا الأسبوع', 'المشتركون'];
                  return Column(children: [
                    for (var i = 0; i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Expanded(child: Text(labels[i], style: TextStyle(fontSize: 16, color: C.ink(context)))),
                          Text(Ar.num(v[i]), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.accent(context))),
                        ]),
                      ),
                  ]);
                },
              ),
              const SizedBox(height: 6),
              Text('تُحسب ممن دخل بحسابه فقط. الزوّار بلا حساب لا يُعدّون هنا.', style: TextStyle(color: C.muted(context), height: 1.6)),
            ]),
          ),
        ]),
      );
}
