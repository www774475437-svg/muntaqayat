import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

export 'cloud_ui.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../services/review.dart';
import '../ui.dart';
import 'cloud_ui.dart';
import 'lists.dart';
import 'vault.dart';
import 'marks.dart';
import 'mutun.dart';
import 'review.dart';
import 'plus.dart';
import 'poem.dart' show siteUrl;

/// Everything here needs accounts (Firebase). The screens are complete;
/// actions that need the server say «يُفعَّل قريباً» until it is linked.
void needsServer(BuildContext context, [String what = '']) => soonSheet(
      context,
      'يُفعَّل قريباً بإذن الله',
      '${what.isEmpty ? '' : '$what\n\n'}هذه الميزة تحتاج الحسابات وقاعدة البيانات، وتعمل مباشرة حين نربط التطبيق بفايربيس.',
    );

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

// ------------------------------------------------------------ teacher

String testLink(String matn, int from, int to, TestMode mode) => '$siteUrl#/t/$matn/$from-$to/${mode.index}';

const _modeNames = modeNames;

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});
  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final picked = <String>{};
  String? matnId;
  RangeValues range = const RangeValues(1, 1);
  TestMode mode = TestMode.half;
  final idCtl = TextEditingController(), nameCtl = TextEditingController();

  Matn? get matn => matnId == null ? null : Library.mutun.firstWhere((x) => x.id == matnId);
  int get from => range.start.round();
  int get to => range.end.round();

  void _log(String how) {
    final m = matn!;
    Store.i.logTest({
      'at': DateTime.now().millisecondsSinceEpoch,
      'matn': m.id,
      'title': m.title,
      'from': from,
      'to': to,
      'mode': mode.index,
      'how': how,
      'students': picked.toList(),
    });
  }

  String _name(String id) => Store.i.studentNames[id] ?? 'طالب · $id';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final ready = Library.mutun.where((m) => m.ready).toList();
          final m = matn;
          return Scaffold(
              appBar: AppBar(
                title: const Text('خانة المعلّم'),
                bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'اختبار جديد'), Tab(text: 'طلابي'), Tab(text: 'السجل')]),
              ),
              body: TabBarView(controller: _tabs, children: [
                // ---------------- new test
                ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                  SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '١. اختر المنظومة والأبيات وطريقة الاختبار.\n'
                      '٢. اضغط «معاينة» لترى الاختبار كما يراه الطالب.\n'
                      '٣. أرسله برابط (يعمل الآن): يفتحه الطالب فيختبر، ثم يرسل لك نتيجته ملوّنة كما كتبها.\n'
                      '٤. أو أرسله بالرقم الشخصي لطلابك (حتى ٣٠) فيصلهم «لديك اختبار» في «اختباراتي»، وتصلك نتائجهم في «نتائج طلابي».',
                      style: TextStyle(fontSize: 14.5, height: 1.7, color: C.ink(context)),
                    ),
                  ),
                  _section(context, 'المنظومة'),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final x in ready)
                      ChoiceChip(
                        selected: matnId == x.id,
                        label: Text(x.title),
                        onSelected: (_) => setState(() {
                          matnId = x.id;
                          range = RangeValues(1, x.lines.length < 10 ? x.lines.length.toDouble() : 10);
                        }),
                      ),
                  ]),
                  if (m != null) ...[
                    _section(context, 'الأبيات: من ${Ar.num(from)} إلى ${Ar.num(to)} (${Ar.verses(to - from + 1)})'),
                    if (m.lines.length > 1)
                      RangeSlider(
                        values: range,
                        min: 1,
                        max: m.lines.length.toDouble(),
                        divisions: m.lines.length - 1,
                        labels: RangeLabels(Ar.num(from), Ar.num(to)),
                        onChanged: (v) => setState(() => range = v),
                      ),
                    Row(children: [
                      Expanded(child: _numField('من البيت', from, (n) => setState(() => range = RangeValues(n.clamp(1, to).toDouble(), range.end)))),
                      const SizedBox(width: 10),
                      Expanded(child: _numField('إلى البيت', to, (n) => setState(() => range = RangeValues(range.start, n.clamp(from, m.lines.length).toDouble())))),
                      const SizedBox(width: 10),
                      TextButton(onPressed: () => setState(() => range = RangeValues(1, m.lines.length.toDouble())), child: const Text('كلها')),
                    ]),
                    const SizedBox(height: 6),
                    VerseLines(m.lines[from - 1], size: 17, number: from),
                    if (to != from) VerseLines(m.lines[to - 1], size: 17, number: to),
                  ],
                  _section(context, 'طريقة الاختبار'),
                  for (final e in _modeNames.entries)
                    RadioListTile(dense: true, value: e.key, groupValue: mode, onChanged: (v) => setState(() => mode = v!), title: Text(e.value)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: m == null ? null : () => push(context, WritingTestScreen(matn: m, verses: [for (var i = from; i <= to; i++) i], mode: mode)),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('معاينة كما يراه الطالب'),
                  ),
                  _section(context, 'أرسل برابط'),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: m == null
                            ? null
                            : () {
                                _log('رابط');
                                Share.share('اختبار في «${m.title}» من البيت ${Ar.num(from)} إلى ${Ar.num(to)}.\nافتح الرابط واكتب ما حفظت، ثم أرسل لي النتيجة:\n${testLink(m.id, from, to, mode)}');
                              },
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('أرسل الرابط'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: m == null
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: testLink(m.id, from, to, mode)));
                              _log('رابط');
                              toast(context, 'نُسخ رابط الاختبار');
                            },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('انسخه'),
                    ),
                  ]),
                  _section(context, 'أو بالرقم الشخصي (${Ar.num(picked.length)} من ٣٠)'),
                  if (s.students.isEmpty)
                    Text('أضف طلابك من تبويب «طلابي» ثم اخترهم هنا.', style: TextStyle(color: C.muted(context)))
                  else
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final id in s.students)
                        FilterChip(
                          selected: picked.contains(id),
                          label: Text(_name(id)),
                          onSelected: (v) => setState(() {
                            if (v && picked.length >= 30) return;
                            v ? picked.add(id) : picked.remove(id);
                          }),
                        ),
                    ]),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: picked.isEmpty || m == null
                        ? () => toast(context, 'اختر المنظومة والطلاب أولاً')
                        : () async {
                            if (!await needAccount(context, 'إرسال الاختبار بالأرقام يحتاج حساباً.')) return;
                            final (err, n) = await Cloud.i.sendTest(ids: picked.toList(), matn: m.id, title: m.title, from: from, to: to, mode: mode.index);
                            if (!context.mounted) return;
                            if (err != null) {
                              toast(context, err);
                              return;
                            }
                            _log('رقم');
                            toast(context, 'وصل الاختبار إلى ${Ar.num(n)} طالب');
                          },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('أرسل إلى أرقامهم'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      if (!await needAccount(context)) return;
                      final err = await Cloud.i.sendMessage('أطلب اختباراً آخر بالأرقام اليوم.', kind: 'test');
                      if (context.mounted) toast(context, err ?? 'وصل طلبك إلى المطوّر، وسيردّ عليك في «راسل المطوّر»');
                    },
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('طلب اختبار آخر اليوم'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (await needAccount(context) && context.mounted) push(context, const SentTestsScreen());
                    },
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('نتائج طلابي'),
                  ),
                ]),
                // ---------------- my students
                ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                  Text('أضف طلابك بأسمائهم وأرقامهم الشخصية، لتختارهم في الاختبارات وتراجع معهم.', style: TextStyle(color: C.muted(context), height: 1.6)),
                  const SizedBox(height: 10),
                  TextField(controller: nameCtl, decoration: _dec(context, 'اسم الطالب')),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: idCtl,
                        keyboardType: TextInputType.number,
                        maxLength: 7,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _dec(context, 'رقمه الشخصي (٧ أرقام)').copyWith(counterText: ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        var id = idCtl.text.trim();
                        final name = nameCtl.text.trim();
                        if (id.isEmpty && name.isEmpty) return;
                        if (id.isNotEmpty && id.length != 7) {
                          toast(context, 'الرقم الشخصي سبعة أرقام');
                          return;
                        }
                        // A student without a number yet gets a local placeholder.
                        if (id.isEmpty) id = 'بلا رقم ${s.students.length + 1}';
                        s.addStudents([id]);
                        if (name.isNotEmpty) s.setStudentName(id, name);
                        idCtl.clear();
                        nameCtl.clear();
                      },
                      child: const Text('أضف'),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  if (s.students.isEmpty) const EmptyNote(Icons.groups_outlined, 'لا طلاب بعد.'),
                  for (final id in s.students)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                        child: Row(children: [
                          const RoundIcon(Icons.person_outline_rounded, size: 40),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.studentNames[id] ?? 'طالب', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: C.ink(context))),
                              Text('$id · اختُبر ${Ar.num(s.testLog.where((t) => (t['students'] as List).contains(id)).length)} مرة', style: TextStyle(fontSize: 13, color: C.muted(context))),
                            ]),
                          ),
                          IconButton(
                            tooltip: 'راجع معه',
                            onPressed: () => _reviewWith(context, id),
                            icon: Icon(Icons.replay_rounded, color: C.accent(context)),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () => setState(() {
                              picked.remove(id);
                              s.removeStudent(id);
                              s.setStudentName(id, '');
                            }),
                            icon: Icon(Icons.delete_outline_rounded, color: C.muted(context)),
                          ),
                        ]),
                      ),
                    ),
                ]),
                // ---------------- log
                ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                  if (s.testLog.isEmpty) const EmptyNote(Icons.history_rounded, 'لم ترسل اختباراً بعد. كل اختبار ترسله يُسجَّل هنا.'),
                  for (final t in s.testLog)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => setState(() {
                          matnId = t['matn'] as String;
                          range = RangeValues((t['from'] as num).toDouble(), (t['to'] as num).toDouble());
                          mode = TestMode.values[(t['mode'] as num).toInt()];
                          picked
                            ..clear()
                            ..addAll([for (final x in t['students'] as List) x as String].where(s.students.contains));
                          _tabs.animateTo(0);
                        }),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${t['title']} · من ${Ar.num((t['from'] as num).toInt())} إلى ${Ar.num((t['to'] as num).toInt())}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
                          Text('${_modeNames[TestMode.values[(t['mode'] as num).toInt()]]} · ${t['how']} · ${_date((t['at'] as num).toInt())}',
                              style: TextStyle(fontSize: 13, color: C.muted(context))),
                          if ((t['students'] as List).isNotEmpty)
                            Text('الطلاب: ${[for (final x in t['students'] as List) _name(x as String)].join('، ')}', style: TextStyle(fontSize: 13, color: C.accent(context))),
                          Text('اضغط لتعيد الاختبار نفسه', style: TextStyle(fontSize: 12, color: C.muted(context))),
                        ]),
                      ),
                    ),
                ]),
              ]),
          );
        },
      );

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${Ar.num(d.day)}/${Ar.num(d.month)}/${Ar.num(d.year)}';
  }

  InputDecoration _dec(BuildContext context, String hint) =>
      InputDecoration(hintText: hint, filled: true, fillColor: C.card(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));

  Widget _numField(String label, int value, void Function(int) set) => TextFormField(
        key: ValueKey('$label$value'),
        initialValue: '$value',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        onFieldSubmitted: (v) {
          final n = int.tryParse(v);
          if (n != null) set(n);
        },
      );

  /// Review face to face: pick what he memorized, then listen to him verse by verse.
  void _reviewWith(BuildContext context, String id) {
    final ready = Library.mutun.where((m) => m.ready).toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (b) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(18, 0, 18, 30), children: [
          Text('راجع مع ${_name(id)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(b))),
          Text('اختر المنظومة: تظهر أبياتها والشطر الثاني مخفي، فتسمع منه وتتابع.', style: TextStyle(color: C.muted(b), height: 1.6)),
          const SizedBox(height: 8),
          for (final m in ready)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(m.title),
              subtitle: Text(Ar.verses(m.lines.length)),
              onTap: () {
                Navigator.pop(b);
                Store.i.logTest({
                  'at': DateTime.now().millisecondsSinceEpoch,
                  'matn': m.id,
                  'title': m.title,
                  'from': 1,
                  'to': m.lines.length,
                  'mode': TestMode.half.index,
                  'how': 'مراجعة',
                  'students': [id],
                });
                push(context, ListenToStudentScreen(matn: m, student: _name(id)));
              },
            ),
        ]),
      ),
    );
  }
}

/// The teacher follows the text while the student recites.
class ListenToStudentScreen extends StatefulWidget {
  final Matn matn;
  final String student;
  const ListenToStudentScreen({super.key, required this.matn, required this.student});
  @override
  State<ListenToStudentScreen> createState() => _ListenToStudentScreenState();
}

class _ListenToStudentScreenState extends State<ListenToStudentScreen> {
  final marks = <int, bool>{}; // verse → correct?
  @override
  Widget build(BuildContext context) {
    final m = widget.matn;
    final ok = marks.values.where((x) => x).length, bad = marks.length - ok;
    return Scaffold(
      appBar: AppBar(title: Text('مراجعة ${widget.student}')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: Text(m.title, style: TextStyle(fontWeight: FontWeight.w700, color: C.accent(context)))),
            Text('أصاب ${Ar.num(ok)} · أخطأ ${Ar.num(bad)}', style: TextStyle(color: C.ink(context))),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
            itemCount: m.lines.length,
            itemBuilder: (context, i) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
              decoration: BoxDecoration(
                color: marks[i] == null ? null : (marks[i]! ? const Color(0x142F6B4F) : const Color(0x14B3261E)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Expanded(child: VerseLines(m.lines[i], size: 19, number: i + 1)),
                IconButton(onPressed: () => setState(() => marks[i] = true), icon: Icon(Icons.check_circle_outline_rounded, color: marks[i] == true ? const Color(0xFF2F6B4F) : C.muted(context))),
                IconButton(onPressed: () => setState(() => marks[i] = false), icon: Icon(Icons.highlight_off_rounded, color: marks[i] == false ? const Color(0xFFB3261E) : C.muted(context))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Opened from a teacher's link: …/#/t/<matn>/<from>-<to>/<mode>
class TestLinkScreen extends StatelessWidget {
  final Matn matn;
  final int from, to;
  final TestMode mode;
  const TestLinkScreen({super.key, required this.matn, required this.from, required this.to, required this.mode});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('لديك اختبار')),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 40), children: [
          SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(matn.title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: C.ink(context))),
              Text(matn.author, style: TextStyle(color: C.muted(context))),
              const SizedBox(height: 8),
              Text('من البيت ${Ar.num(from)} إلى ${Ar.num(to)} (${Ar.verses(to - from + 1)})', style: TextStyle(fontSize: 16, color: C.accent(context), fontWeight: FontWeight.w700)),
              Text('الطريقة: ${_modeNames[mode]}', style: TextStyle(color: C.ink(context))),
            ]),
          ),
          const SizedBox(height: 12),
          Text('١. اكتب ما حفظت في الخانات من غير أن تنظر.\n٢. اضغط «تحقّق» فيتلوّن الصحيح بالأخضر والخطأ بالأحمر.\n٣. اضغط «أرسل النتيجة» وأرسلها لمعلّمك.',
              style: TextStyle(fontSize: 15.5, height: 1.8, color: C.ink(context))),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => WritingTestScreen(matn: matn, verses: [for (var i = from; i <= to; i++) i], mode: mode))),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('ابدأ الاختبار', style: TextStyle(fontSize: 17)),
          ),
        ]),
      );
}

// ------------------------------------------------------------ developer hub

class DeveloperHub extends StatelessWidget {
  const DeveloperHub({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Store.i, Cloud.i]),
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('خانة المطوّر')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.icon(
                onPressed: () => push(context, const ReviewScreen()),
                icon: const Icon(Icons.rule_rounded),
                label: Text('مراجعة الأبيات المعلّقة (${Review.pending.length})'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.all(14),
                child: Cloud.i.isDev
                    ? Row(children: [
                        const Icon(Icons.verified_user_rounded, color: bookGreen),
                        const SizedBox(width: 10),
                        Expanded(child: Text('أنت داخل بحساب المطوّر. ما توثّقه أو تخفيه أو تحذفه يصل إلى كل المستخدمين.', style: TextStyle(height: 1.6, color: C.ink(context)))),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('ادخل بحساب جوجل ${Cloud.devEmail} ليتعرّف عليك الخادم، فيصل توثيقك وإخفاؤك إلى الجميع وتظهر لك الرسائل والبلاغات.',
                            style: TextStyle(height: 1.6, color: C.ink(context))),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            if (Cloud.i.signedIn) await Cloud.i.signOut();
                            if (context.mounted) await needAccount(context);
                          },
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('ادخل بحساب المطوّر'),
                        ),
                      ]),
              ),
            ),
            _row(context, Icons.verified_outlined, 'الموثّقة وغير الموثّقة', 'وثّق بالعلامة الزرقاء، أو أخفِ، ثم احذف', () => push(context, const MarksScreen())),
            _row(context, Icons.insights_rounded, 'الإحصائيات', 'من حمّل التطبيق ومن دخله', () => push(context, const StatsScreen())),
            _row(context, Icons.workspace_premium_outlined, 'المشتركون', 'قائمتهم ومدة اشتراكهم ومزاياهم', () => push(context, const SubscribersScreen())),
            _row(context, Icons.auto_stories_outlined, 'طلبات تصميم الكتب', 'من دفع ٢٠ دولاراً للتصميم', () => push(context, const DevOrdersScreen())),
            _row(context, Icons.mark_email_unread_outlined, 'الرسائل', 'رسائل المستخدمين وطلبات الاختبارات', () => push(context, const DevMessagesScreen())),
            _row(context, Icons.flag_outlined, 'البلاغات', 'الأسماء والمنشورات المبلّغ عنها، والحظر', () => push(context, const DevReportsScreen())),
            _row(context, Icons.gpp_bad_outlined, 'المخالفون', 'المحظورون والموقوفون مؤقتاً والمنذَرون', () => push(context, const ModerationScreen())),
            _row(context, Icons.admin_panel_settings_outlined, 'المشرفون', 'أضف مشرفين ببريدهم أو من صفحاتهم وحدّد صلاحياتهم', () => push(context, const ModsScreen())),
            _row(context, Icons.history_rounded, 'سجلّ المشرفين', 'ما صنعه كل مشرف: تحرير وإخفاء وإظهار', () => push(context, const ModLogScreen())),
            _row(context, Icons.workspace_premium_outlined, 'الشارات وأصحابها', 'كل شارة ومن منحتها له', () => push(context, const BadgeHoldersScreen())),
            if (Vault.ready) ...[
              _row(context, Icons.cloud_outlined, 'التخزين السحابي', 'كم استعملت من المساحة، وكم عليك', () => push(context, const StorageUsageScreen())),
              _row(context, Icons.image_search_outlined, 'خلفيات تنتظر المراجعة', 'لا تظهر صورة حتى تقبلها', () => push(context, const PendingBackgroundsScreen())),
            ],
            _row(context, Icons.link_rounded, 'رابط الدفع لتصميم الكتاب', Store.i.payLink.isEmpty ? 'لم يُضف بعد: زر الدفع يفتح المعاينة' : Store.i.payLink, () {
              final t = TextEditingController(text: Store.i.payLink);
              showDialog(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('رابط الدفع'),
                  content: TextField(controller: t, keyboardType: TextInputType.url, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'https://')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
                    FilledButton(
                      onPressed: () {
                        Store.i.setPayLink(t.text);
                        Navigator.pop(d);
                      },
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 28),
            Text('النشر في «قوافي»: شغّل وأوقف', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
            for (final (k, t, sub) in const [
              ('pubOwn', 'نشر الأعضاء من شعرهم', 'إذا أوقفته لا ينشر أحد من شعره.'),
              ('pubQuote', 'نشر الأعضاء الاقتباسات', 'إذا أوقفته لا ينشر أحد اقتباساً.'),
            ])
              SwitchListTile(contentPadding: EdgeInsets.zero, dense: true, value: Store.i.feature(k), onChanged: (v) => Store.i.setFeature(k, v), title: Text(t, style: const TextStyle(fontSize: 16)), subtitle: Text(sub)),
            const Divider(height: 28),
            Text('مجلس الشعر: شغّل وأوقف', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.accent(context))),
            for (final (k, t) in const [('tasks', 'المهام اليومية'), ('duel', 'المبارزات (مخفية حتى تشغّلها)'), ('train', 'التدريب (مخفي حتى تشغّله)'), ('friday', 'جولة الجمعة المضاعفة'), ('weekly', 'شاعر الأسبوع'), ('golden', 'بيت الذهب')])
              SwitchListTile(contentPadding: EdgeInsets.zero, dense: true, value: Store.i.feature(k), onChanged: (v) => Store.i.setFeature(k, v), title: Text(t, style: const TextStyle(fontSize: 16))),
            if (Vault.ready)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: Store.i.features['bg'] ?? false,
                onChanged: (v) => Store.i.setFeature('bg', v),
                title: const Text('خلفيات صفحات الأعضاء', style: TextStyle(fontSize: 16)),
                subtitle: const Text('مطفأة حتى تشغّلها. كل صورة تنتظر قبولك.'),
              ),
            const Divider(height: 28),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: Store.i.plusOn,
              onChanged: Store.i.setPlusOn,
              title: const Text('إظهار زر «منتقيات+» (الاشتراك)', style: TextStyle(fontSize: 17)),
              subtitle: const Text('إذا أطفأته اختفى عن غير المشتركين فقط، ويبقى للمشتركين مزاياهم. (يعمّ الجميع حين تكون داخلاً بحساب المطوّر)'),
            ),
          ]),
        ),
      );
}

