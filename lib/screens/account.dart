import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'lists.dart';
import 'plus.dart';
import 'poem.dart';
import '../services/device.dart';

const developerPin = '7744';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final s = Store.i;
    final liked = Library.poems.where((p) => s.liked(p.id)).toList();
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 130), children: [
        Row(children: [
          const RoundIcon(Icons.person_rounded, size: 64),
          const SizedBox(width: 14),
          Expanded(child: Text('مكتبتك على هذا الجهاز', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: C.ink(context)))),
        ]),
        const SizedBox(height: 18),
        SoftCard(
          child: Column(children: [
            Row(children: [
              _stat(context, Ar.num(liked.length), 'إعجاب'),
              _stat(context, Ar.num(s.reads.length), 'مقطعاً قرأته'),
              _stat(context, Ar.num(s.days.length), 'يوماً'),
            ]),
            const SizedBox(height: 14),
            Text('سجّل دخولك لتبقى مكتبتك وشعراؤك ومجموعاتك معك على كل أجهزتك.',
                style: TextStyle(fontSize: 15, color: C.muted(context), height: 1.6)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => soonSheet(context, 'تسجيل الدخول', 'تسجيل الدخول والمزامنة بين الأجهزة، ونشر المختارات والإعجابات — قريباً بإذن الله.'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('تسجيل الدخول — قريباً', style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _group(context, [
          _tile(context, Icons.favorite_border, 'ما أعجبك', Ar.selections(liked.length),
              () => openList(context, 'ما أعجبك', liked)),
          _tile(context, Icons.folder_copy_outlined, 'مجموعاتي', Ar.num(s.collections.length), () => push(context, const CollectionsScreen())),
          _tile(context, Icons.people_outline_rounded, 'شعراؤك', '${Ar.num(s.followed.length)} شعراء', () => push(context, const FollowedScreen())),
        ]),
        const SizedBox(height: 14),
        _group(context, [
          _tile(context, Icons.workspace_premium_outlined, 'منتقيات+', 'الشروح والكتاب باسمك',
              () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PlusScreen()))),
          _tile(context, Icons.lightbulb_outline_rounded, 'اقترح بيتاً أو قصيدة', '', () => suggest(context, 'اقتراح بيت أو قصيدة:\n')),
        ]),
        const SizedBox(height: 14),
        _group(context, [
          _tile(context, Icons.settings_outlined, 'الإعدادات', 'المظهر والخط والتشكيل', () => push(context, const SettingsScreen())),
          if (s.developer)
            _tile(context, Icons.fact_check_outlined, 'قائمة المراجعة (للمطوّر)',
                'بقي ${Ar.num(Library.poems.where((p) => !s.isReviewed(p.id)).length)}', () => push(context, const ReviewScreen())),
        ]),
      ]),
    );
  }

  Widget _stat(BuildContext context, String n, String label) => Expanded(
        child: Column(children: [
          Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.accent(context))),
          Text(label, style: TextStyle(fontSize: 13.5, color: C.muted(context))),
        ]),
      );
}

Widget _group(BuildContext context, List<Widget> tiles) => Container(
      decoration: BoxDecoration(color: C.card(context), borderRadius: BorderRadius.circular(26), border: Border.all(color: C.line(context))),
      child: Column(children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 80, endIndent: 18, color: C.line(context)),
          tiles[i],
        ],
      ]),
    );

Widget _tile(BuildContext context, IconData icon, String title, String trailing, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          RoundIcon(icon, size: 50),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context)))),
          if (trailing.isNotEmpty) Text(trailing, style: TextStyle(fontSize: 14, color: C.muted(context))),
          Icon(Icons.chevron_left_rounded, color: C.muted(context)),
        ]),
      ),
    );

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final cols = Store.i.collections;
          return Scaffold(
            appBar: AppBar(title: const Text('مجموعاتي')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () async {
                final n = await askName(context, 'مجموعة جديدة', 'مثلاً: للحفظ');
                if (n != null) Store.i.createCollection(n);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('مجموعة جديدة'),
            ),
            body: cols.isEmpty
                ? const EmptyNote(Icons.folder_open_rounded, 'أنشئ مجموعة، ثم احفظ فيها الأبيات من زر «…» في صفحة المقطع.')
                : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
                    for (final e in cols.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SoftCard(
                          onTap: () => openList(context, e.key, [for (final id in e.value) if (Library.byId[id] != null) Library.byId[id]!]),
                          child: Row(children: [
                            const RoundIcon(Icons.folder_rounded, size: 48),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.key, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
                                Text(Ar.selections(e.value.length), style: TextStyle(color: C.muted(context))),
                              ]),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: Text('حذف «${e.key}»؟'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
                                    ],
                                  ),
                                );
                                if (ok == true) Store.i.deleteCollection(e.key);
                              },
                            ),
                          ]),
                        ),
                      ),
                  ]),
          );
        },
      );
}

class FollowedScreen extends StatelessWidget {
  const FollowedScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final list = Library.namedPoets.where((p) => Store.i.follows(p.name)).toList();
          return Scaffold(
            appBar: AppBar(title: const Text('شعراؤك')),
            body: list.isEmpty
                ? const EmptyNote(Icons.people_outline_rounded, 'افتح صفحة شاعر واضغط «أضِف إلى شعراؤك».')
                : ListView(children: [
                    for (final p in list)
                      ListTile(
                        leading: Avatar(p.initial, size: 44),
                        title: Text(p.name),
                        subtitle: Text([if (p.era.isNotEmpty) p.era, Ar.selections(p.count)].join(' · ')),
                        onTap: () => openPoet(context, p.name),
                      ),
                  ]),
          );
        },
      );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int taps = 0;

  Future<void> _unlock() async {
    final ctl = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('رمز المطوّر'),
        content: TextField(controller: ctl, autofocus: true, keyboardType: TextInputType.number, obscureText: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('دخول')),
        ],
      ),
    );
    if (!mounted) return;
    if (pin == developerPin) {
      Store.i.setDeveloper(true);
      toast(context, 'فُتح وضع المطوّر: قائمة المراجعة في «حسابك»');
    } else if (pin != null) {
      toast(context, 'الرمز غير صحيح');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          return Scaffold(
            appBar: AppBar(title: const Text('الإعدادات')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              Text('المظهر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('حسب الجهاز')),
                  ButtonSegment(value: 1, label: Text('فاتح')),
                  ButtonSegment(value: 2, label: Text('ليلي')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setTheme(v.first),
              ),
              const SizedBox(height: 22),
              Text('حجم خط الأبيات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
              Slider(value: s.fontScale, min: 0.8, max: 1.5, divisions: 7, onChanged: s.setFontScale),
              SoftCard(
                child: VerseLines(const ['وَما الدَهرُ إِلّا مِن رُواةِ قَلائِدي', 'إِذا قُلتُ شِعراً أَصبَحَ الدَهرُ مُنشِدا'], size: 22),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إظهار التشكيل', style: TextStyle(fontSize: 17)),
                value: s.tashkeel,
                onChanged: s.setTashkeel,
              ),
              if (!kIsWeb) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('بيت الصباح', style: TextStyle(fontSize: 17)),
                  subtitle: Text(s.morning
                      ? 'تنبيه كل يوم الساعة ${Ar.num(s.morningHour)}:${s.morningMinute.toString().padLeft(2, '0')}'
                      : 'تنبيه كل صباح ببيت جميل'),
                  value: s.morning,
                  onChanged: (v) async {
                    s.setMorning(v, s.morningHour, s.morningMinute);
                    await Device.refresh();
                  },
                ),
                if (s.morning)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: const Text('تغيير الوقت'),
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: s.morningHour, minute: s.morningMinute));
                        if (t == null) return;
                        s.setMorning(true, t.hour, t.minute);
                        await Device.refresh();
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('ولـ«بيت اليوم» على شاشة الجوال: اضغط مطوّلاً على الشاشة الرئيسية ← الأدوات (Widgets) ← منتقيات الشعر.',
                      style: TextStyle(fontSize: 13.5, color: C.muted(context), height: 1.6)),
                ),
              ],
              if (s.developer)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('وضع المطوّر', style: TextStyle(fontSize: 17)),
                  value: true,
                  onChanged: (_) => s.setDeveloper(false),
                ),
              const Divider(height: 34),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.send_rounded),
                title: const Text('تواصل مع المطوّر'),
                subtitle: const Text('أبو عبد الرحمن أحمد الأثري'),
                onTap: () => launchUrl(Uri.parse('https://t.me/alhsaar4'), mode: LaunchMode.externalApplication),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book_rounded),
                title: Text('عن الكتاب: «${Library.book}»'),
                subtitle: Text('جمع وترتيب ${Library.author} — ${Ar.num(Library.poems.length)} مقطعاً في ${Ar.num(Library.chapters.length)} باباً'),
              ),
              GestureDetector(
                onTap: () {
                  if (s.developer) return;
                  if (++taps >= 7) {
                    taps = 0;
                    _unlock();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: Text('منتقيات الشعر — الإصدار ١٫١', style: TextStyle(color: C.muted(context)))),
                ),
              ),
            ]),
          );
        },
      );
}

/// Developer-only list: every selection not yet marked as checked.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool flaggedOnly = true;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final all = Library.poems.where((p) => !Store.i.isReviewed(p.id)).toList();
          final list = flaggedOnly ? all.where((p) => p.flags.isNotEmpty).toList() : all;
          final done = Library.poems.length - all.length;
          return Scaffold(
            appBar: AppBar(title: const Text('قائمة المراجعة')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              Text('تمّ التحقق من ${Ar.num(done)} من ${Ar.num(Library.poems.length)}. افتح المقطع وقارنه بالكتاب، ثم اضغط «تمّ التحقق» فيخرج من القائمة.',
                  style: TextStyle(fontSize: 15, color: C.muted(context), height: 1.6)),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: done / Library.poems.length, minHeight: 6, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text('المشكوك فيها (${Ar.num(all.where((p) => p.flags.isNotEmpty).length)})')),
                  ButtonSegment(value: false, label: Text('الكل (${Ar.num(all.length)})')),
                ],
                selected: {flaggedOnly},
                onSelectionChanged: (v) => setState(() => flaggedOnly = v.first),
              ),
              const SizedBox(height: 10),
              for (final p in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.firstVerse.first, style: const TextStyle(fontFamily: verseFont, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('صفحة ${Ar.num(p.page)} · ${p.poet}${p.flags.isEmpty ? '' : ' · ${p.flags.join('، ')}'}'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => openPoem(context, p),
                ),
            ]),
          );
        },
      );
}
