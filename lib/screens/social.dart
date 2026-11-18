import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../services/device.dart';
import '../ui.dart';
import 'lists.dart';
import 'mutun.dart';
import 'plus.dart';

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

// ------------------------------------------------------------ profile

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    final memo = s.memorized.values.fold<int>(0, (a, b) => a + b.length);
    return Scaffold(
      appBar: AppBar(title: const Text('صفحتك الشخصية')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        SoftCard(
          child: Column(children: [
            const RoundIcon(Icons.person_rounded, size: 72),
            const SizedBox(height: 8),
            Text('اسمك يظهر هنا', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.ink(context))),
            const SizedBox(height: 4),
            Text('رقمك الشخصي: ٧ أرقام ثابتة لا تتغير', style: TextStyle(color: C.muted(context))),
            const SizedBox(height: 14),
            Row(children: [
              _stat(context, Ar.num(s.likes.length), 'إعجاب'),
              _stat(context, '٠', 'اقتباس'),
              _stat(context, Ar.num(memo), 'بيتاً حفظه'),
              _stat(context, Ar.num(s.days.length), 'يوماً'),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => needsServer(context, 'تسجيل الدخول برقم شخصي من سبعة أرقام، وصفحة فيها اقتباساتك وما حفظت وأيامك المتتالية وتاريخ تسجيلك.'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('أنشئ حسابك'),
              ),
            ),
          ]),
        ),
        _section(context, 'في صفحتك'),
        _row(context, Icons.format_quote_rounded, 'اقتباساتي', 'ما نشرته من أبيات (عشرة في اليوم)', () => needsServer(context)),
        _row(context, Icons.bookmark_border_rounded, 'المحفوظات', 'ما حفظته من أبيات وقصائد', () => needsServer(context)),
        _row(context, Icons.people_outline_rounded, 'من أتابعهم', 'ابحث عن أي شخص برقمه الشخصي', () => _findById(context)),
        _row(context, Icons.local_fire_department_outlined, 'الأيام المتتالية', 'شارة لكل من يداوم على القراءة', () => needsServer(context)),
        _row(context, Icons.event_outlined, 'تاريخ التسجيل', '', () => needsServer(context)),
        const SizedBox(height: 8),
        Text('تُحدَّث أرقام صفحتك كل ست ساعات دفعة واحدة، لا لحظة بلحظة.', style: TextStyle(color: C.muted(context), fontSize: 13.5)),
      ]),
    );
  }

  Widget _stat(BuildContext context, String n, String label) => Expanded(
        child: Column(children: [
          Text(n, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.accent(context))),
          Text(label, style: TextStyle(fontSize: 12.5, color: C.muted(context))),
        ]),
      );

  void _findById(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('ابحث برقم شخصي'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          maxLength: 7,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'مثل: 1234567'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              Navigator.pop(d);
              needsServer(context, 'تفتح صفحة صاحب الرقم: اسمه واقتباساته، وتتابعه أو تبلّغ عنه.');
            },
            child: const Text('بحث'),
          ),
        ],
      ),
    );
  }
}

/// «الاقتباسات»: people's published verses.
class QuotesScreen extends StatelessWidget {
  const QuotesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الاقتباسات')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
          Text('أبيات ينشرها القرّاء في صفحاتهم، تظهر هنا فوراً، ويُعجب بها الناس ويشاركونها. اضغط اسم صاحبها لترى اقتباساته.',
              style: TextStyle(color: C.muted(context), height: 1.6)),
          const SizedBox(height: 14),
          for (final p in Library.dailyPicks(3, salt: 11))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const RoundIcon(Icons.person_outline_rounded, size: 36),
                    const SizedBox(width: 8),
                    Expanded(child: Text('مثال: اسم القارئ', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context)))),
                    IconButton(
                      tooltip: 'إبلاغ',
                      onPressed: () => needsServer(context, 'يصل البلاغ إلى المطوّر ليحظر الأسماء والمنشورات المسيئة.'),
                      icon: Icon(Icons.flag_outlined, color: C.muted(context)),
                    ),
                  ]),
                  VerseLines(p.firstVerse, size: 20),
                  Row(children: [
                    IconButton(onPressed: () => needsServer(context), icon: const Icon(Icons.favorite_border)),
                    IconButton(onPressed: () => needsServer(context), icon: const Icon(Icons.repeat_rounded)),
                    const Spacer(),
                    Text(p.poet, style: TextStyle(color: C.muted(context))),
                  ]),
                ]),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => needsServer(context, 'تنشر حتى عشرة اقتباسات في اليوم.'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('انشر اقتباساً'),
          ),
        ]),
      );
}

// ------------------------------------------------------------ teacher

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});
  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  final picked = <String>{};
  final mutun = <String>{};
  TestMode mode = TestMode.half;
  final idCtl = TextEditingController();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final ready = Library.mutun.where((m) => m.ready).toList();
          return Scaffold(
            appBar: AppBar(title: const Text('خانة المعلّم')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.teacher,
                onChanged: s.setTeacher,
                title: const Text('أنا معلّم (تفعيل خانة المعلّم)', style: TextStyle(fontSize: 17)),
              ),
              SoftCard(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'طريقة الاختبار:\n'
                  '١. اطلب من كل طالب رقمه الشخصي (من صفحته في التطبيق).\n'
                  '٢. أضف من طالب واحد إلى ثلاثين طالباً بأرقامهم، فيظهر اسم كل طالب.\n'
                  '٣. اختر المنظومة (أو منظومتين) وطريقة الاختبار.\n'
                  '٤. اضغط «معاينة» لترى الاختبار كما يراه الطالب، ثم «أرسل».\n'
                  '٥. يصل الطالبَ فوراً «لديك اختبار»، وحين ينهيه تصلك نتيجته ملفاً ملوّناً: الصحيح أخضر والخطأ أحمر، وما كتبه بنصّه، والصحيح بعد كل بيت.\n\n'
                  'المجاني: اختبار واحد في اليوم، والمشترك بلا حد.',
                  style: TextStyle(fontSize: 15, height: 1.7, color: C.ink(context)),
                ),
              ),
              _section(context, 'الطلاب (${Ar.num(picked.length)} من ٣٠)'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: idCtl,
                    keyboardType: TextInputType.number,
                    maxLength: 7,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'الرقم الشخصي للطالب',
                      counterText: '',
                      filled: true,
                      fillColor: C.card(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final id = idCtl.text.trim();
                    if (id.length != 7) {
                      toast(context, 'الرقم الشخصي سبعة أرقام');
                      return;
                    }
                    if (picked.length >= 30) {
                      toast(context, 'الحد ثلاثون طالباً في الاختبار الواحد');
                      return;
                    }
                    s.addStudents([id]);
                    setState(() => picked.add(id));
                    idCtl.clear();
                  },
                  child: const Text('أضف'),
                ),
              ]),
              const SizedBox(height: 8),
              if (s.students.isEmpty)
                Text('لم تضف طلاباً بعد. يُحفظ هنا كل من أضفته لتختاره مرة أخرى.', style: TextStyle(color: C.muted(context)))
              else
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final id in s.students)
                    FilterChip(
                      selected: picked.contains(id),
                      label: Text('طالب · $id'),
                      onSelected: (v) => setState(() {
                        if (v && picked.length >= 30) return;
                        v ? picked.add(id) : picked.remove(id);
                      }),
                      onDeleted: () => setState(() {
                        picked.remove(id);
                        s.removeStudent(id);
                      }),
                    ),
                ]),
              _section(context, 'المنظومة (واحدة أو اثنتان)'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in ready)
                  FilterChip(
                    selected: mutun.contains(m.id),
                    label: Text(m.title),
                    onSelected: (v) => setState(() {
                      if (v && mutun.length >= 2) return;
                      v ? mutun.add(m.id) : mutun.remove(m.id);
                    }),
                  ),
              ]),
              _section(context, 'طريقة الاختبار'),
              RadioListTile(value: TestMode.all, groupValue: mode, onChanged: (v) => setState(() => mode = v!), title: const Text('يكتب الأبيات كلها')),
              RadioListTile(value: TestMode.alternate, groupValue: mode, onChanged: (v) => setState(() => mode = v!), title: const Text('بيت ظاهر وبيت مخفي')),
              RadioListTile(value: TestMode.half, groupValue: mode, onChanged: (v) => setState(() => mode = v!), title: const Text('شطر ظاهر وشطر مخفي')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: mutun.isEmpty
                        ? null
                        : () {
                            final m = Library.mutun.firstWhere((x) => x.id == mutun.first);
                            final n = m.lines.length < 6 ? m.lines.length : 6;
                            push(context, WritingTestScreen(matn: m, verses: [for (var i = 1; i <= n; i++) i], mode: mode));
                          },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('معاينة'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: picked.isEmpty || mutun.isEmpty
                        ? () => toast(context, 'اختر الطلاب والمنظومة أولاً')
                        : () => needsServer(context, 'يصل الاختبار إلى ${Ar.num(picked.length)} طالب فوراً.'),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('أرسل الاختبار'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => needsServer(context, 'يصل طلبك إلى المطوّر في خانته فيتواصل معك.'),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('طلب اختبار آخر اليوم'),
              ),
              _section(context, 'النتائج'),
              _row(context, Icons.picture_as_pdf_outlined, 'نتائج طلابي', 'ملف ملوّن لكل طالب: ما كتبه والصحيح', () => needsServer(context)),
            ]),
          );
        },
      );
}

/// What the student sees: «لديك اختبار».
class StudentTestsScreen extends StatelessWidget {
  const StudentTestsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('اختباراتي')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
          const EmptyNote(Icons.assignment_outlined, 'لا اختبارات الآن. حين يرسل لك معلّمك اختباراً يظهر هنا «لديك اختبار».'),
          SoftCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              'للطالب:\n'
              '١. أعطِ معلّمك رقمك الشخصي من صفحتك.\n'
              '٢. حين يصلك الاختبار افتحه واكتب ما حفظت في الخانات.\n'
              '٣. اضغط «تحقّق» فتظهر نتيجتك، وتصل معلّمك كما كتبتها تماماً.',
              style: TextStyle(fontSize: 15, height: 1.7, color: C.ink(context)),
            ),
          ),
        ]),
      );
}

// ------------------------------------------------------------ messages to the developer

class MessageDevScreen extends StatelessWidget {
  const MessageDevScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = TextEditingController();
    return Scaffold(
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
          onPressed: () => needsServer(context),
          icon: const Icon(Icons.send_rounded),
          label: const Text('أرسل'),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------ developer hub

class DeveloperHub extends StatelessWidget {
  const DeveloperHub({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('خانة المطوّر')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
            _row(context, Icons.insights_rounded, 'الإحصائيات', 'من حمّل التطبيق ومن دخله', () => push(context, const StatsScreen())),
            _row(context, Icons.workspace_premium_outlined, 'المشتركون', 'قائمتهم ومدة اشتراكهم ومزاياهم', () => push(context, const SubscribersScreen())),
            _row(context, Icons.auto_stories_outlined, 'طلبات تصميم الكتب', 'من دفع ٢٠ دولاراً للتصميم', () => needsServer(context, 'يظهر هنا كل من دفع، فتراسله داخل التطبيق أو تراه رقمه.')),
            _row(context, Icons.mark_email_unread_outlined, 'الرسائل', 'رسائل المستخدمين وطلبات الاختبارات', () => needsServer(context)),
            _row(context, Icons.flag_outlined, 'البلاغات', 'الأسماء والمنشورات المبلّغ عنها، والحظر', () => needsServer(context)),
            const Divider(height: 28),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: Store.i.plusOn,
              onChanged: Store.i.setPlusOn,
              title: const Text('إظهار «منتقيات+» (الاشتراك)', style: TextStyle(fontSize: 17)),
              subtitle: const Text('إذا أطفأته اختفى عن غير المشتركين فقط، ويبقى للمشتركين مزاياهم. (يعمّ الجميع بعد ربط فايربيس)'),
            ),
          ]),
        ),
      );
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
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
              Text('من دخل التطبيق والموقع', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
              const SizedBox(height: 6),
              Text('اليوم، وهذا الأسبوع، والشهر، والمستخدمون الجدد، والمشتركون. تُجمع كل نصف ساعة في ملخّص واحد فتقرؤه أنت بقراءة واحدة مهما كثر المستخدمون.',
                  style: TextStyle(color: C.muted(context), height: 1.6)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => needsServer(context), child: const Text('يُفعَّل مع فايربيس')),
            ]),
          ),
        ]),
      );
}

class SubscribersScreen extends StatelessWidget {
  const SubscribersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المشتركون')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
          Text('لا يرى هذه الخانة غيرك.', style: TextStyle(color: C.muted(context))),
          const SizedBox(height: 10),
          SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('لكل مشترك هنا:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
              const SizedBox(height: 6),
              for (final t in const [
                'اسمه ورقمه الشخصي، وزر «راسله» داخل التطبيق',
                'كم شهراً اشترك، وهل كانت متتالية',
                'هل اشترك من قبل، ومتى انتهى اشتراكه',
                'زر «امنحه ميزة» تعطيه به مزايا إضافية',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.check_rounded, size: 18, color: C.accent(context)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(t, style: TextStyle(color: C.ink(context), height: 1.5))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          const EmptyNote(Icons.workspace_premium_outlined, 'لا مشتركين بعد. تظهر القائمة حين يُفتح الاشتراك ويُربط فايربيس.'),
        ]),
      );
}
