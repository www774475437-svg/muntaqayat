import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'lists.dart';
import 'mutun.dart';
import 'poem.dart';

// ------------------------------------------------------------ أمثال من الشعر

/// Verses that became proverbs, from two classical collections.
class AmthalScreen extends StatefulWidget {
  const AmthalScreen({super.key});
  @override
  State<AmthalScreen> createState() => _AmthalScreenState();
}

class _AmthalScreenState extends State<AmthalScreen> {
  static List<List<dynamic>>? _all; // [poet, first, second, source]
  String q = '';
  String? poet;

  @override
  void initState() {
    super.initState();
    if (_all == null) {
      rootBundle.loadString('assets/data/amthal.json').then((raw) {
        _all = [for (final x in jsonDecode(raw) as List) x as List<dynamic>];
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    if (all == null) return Scaffold(appBar: AppBar(title: const Text('أمثال من الشعر')), body: const Center(child: CircularProgressIndicator()));
    final counts = <String, int>{};
    for (final x in all) {
      final p = x[0] as String;
      if (p.isNotEmpty) counts[p] = (counts[p] ?? 0) + 1;
    }
    final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final nq = Ar.norm(q);
    final rows = [
      for (final x in all)
        if ((poet == null || x[0] == poet) && (nq.isEmpty || Ar.norm('${x[1]} ${x[2]}').contains(nq))) x
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('أمثال من الشعر')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'ابحث في ${Ar.num(all.length)} بيتاً سائراً',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: C.card(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(label: const Text('الكل'), selected: poet == null, onSelected: (_) => setState(() => poet = null)),
            ),
            for (final e in top.take(40))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(label: Text('${e.key} ${Ar.num(e.value)}'), selected: poet == e.key, onSelected: (_) => setState(() => poet = e.key)),
              ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
            itemCount: rows.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'من كتابَي «التمثيل والمحاضرة» للثعالبي و«الأمثال السائرة من شعر المتنبي» للصاحب بن عبّاد، بنصّ المكتبة الشاملة بلا تشكيل. نُقلت آلياً، وقد يقع في نسبة بعضها خطأ.',
                    style: TextStyle(fontSize: 13, height: 1.6, color: C.muted(context)),
                  ),
                );
              }
              final x = rows[i - 1];
              final line = [x[1] as String, x[2] as String];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        VerseLines(line, size: 20),
                        if ((x[0] as String).isNotEmpty) Text(x[0] as String, style: TextStyle(fontSize: 13.5, color: C.accent(context))),
                      ]),
                    ),
                    IconButton(onPressed: () => copySheet(context, [line]), icon: Icon(Icons.copy_rounded, size: 19, color: C.muted(context))),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------ حِكَم قصيرة للحالات

/// One-verse selections, ready to copy or share as a picture.
class HikamScreen extends StatefulWidget {
  const HikamScreen({super.key});
  @override
  State<HikamScreen> createState() => _HikamScreenState();
}

class _HikamScreenState extends State<HikamScreen> {
  late List<Poem> items = Library.poems.where((p) => p.shown.length == 1 && p.shown.first.length == 2).toList()..shuffle();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('حِكَم قصيرة للحالات'),
          actions: [IconButton(tooltip: 'غيّر الترتيب', onPressed: () => setState(() => items.shuffle()), icon: const Icon(Icons.shuffle_rounded))],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
          itemCount: items.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('${Ar.verses(items.length)} مفردة، كل بيت قائم بنفسه: انسخه لحالتك أو شاركه صورة.', style: TextStyle(color: C.muted(context))),
              );
            }
            final p = items[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
                onTap: () => openPoem(context, p),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  VerseLines(p.shown.first, size: 21),
                  Row(children: [
                    Expanded(child: Text('${p.poet} · ${p.chapterName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: C.accent(context)))),
                    IconButton(tooltip: 'نسخ', onPressed: () => copySheet(context, p.shown), icon: Icon(Icons.copy_rounded, size: 19, color: C.muted(context))),
                    IconButton(tooltip: 'صورة', onPressed: () => shareSheet(context, p, p.shown.first), icon: Icon(Icons.image_outlined, size: 20, color: C.muted(context))),
                  ]),
                ]),
              ),
            );
          },
        ),
      );
}

// ------------------------------------------------------------ رحلة العصور

int _year(String death) {
  const d = '٠١٢٣٤٥٦٧٨٩';
  final m = RegExp('[٠-٩]+').firstMatch(death);
  if (m == null) return -1;
  return int.parse(m.group(0)!.split('').map((c) => d.indexOf(c)).join());
}

/// A timeline from the Jahiliyya to the modern age, poet by poet.
class ErasJourneyScreen extends StatelessWidget {
  const ErasJourneyScreen({super.key});
  static const about = {
    'جاهلي': 'قبل الإسلام: المعلّقات وشعر الفروسية والحكمة.',
    'مخضرم': 'أدركوا الجاهلية والإسلام.',
    'صدر الإسلام': 'عصر النبوة والخلافة الراشدة.',
    'أموي': '٤١ – ١٣٢هـ: النقائض والغزل العذري.',
    'عباسي': '١٣٢ – ٦٥٦هـ: أزهى عصور الشعر.',
    'أندلسي': 'شعر الأندلس: الطبيعة والحنين ورثاء المدن.',
    'أيوبي': 'القرنان السادس والسابع.',
    'مملوكي': '٦٤٨ – ٩٢٣هـ.',
    'عثماني': 'من القرن العاشر إلى الثالث عشر.',
    'حديث': 'عصر الإحياء وما بعده.',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('رحلة العصور')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
          for (final era in Library.eras)
            if (Library.namedPoets.any((p) => p.era == era)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 6),
                child: Row(children: [
                  Container(width: 16, height: 16, decoration: BoxDecoration(color: C.accent(context), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('العصر ال$era', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.ink(context))),
                      Text(about[era] ?? '', style: TextStyle(fontSize: 13.5, color: C.muted(context))),
                    ]),
                  ),
                ]),
              ),
              for (final p in (Library.namedPoets.where((p) => p.era == era).toList()..sort((a, b) => _year(a.death).compareTo(_year(b.death)))))
                IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 7, end: 17),
                      child: Container(width: 2, color: C.line(context)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SoftCard(
                          padding: const EdgeInsets.all(12),
                          onTap: () => openPoet(context, p.name),
                          child: Row(children: [
                            Avatar(p.initial, size: 42),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
                                Text([if (p.death.isNotEmpty) 'ت ${p.death}', Ar.selections(p.count)].join(' · '), style: TextStyle(fontSize: 13, color: C.muted(context))),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
            ],
        ]),
      );
}

// ------------------------------------------------------------ قصائد لها قصة

class _Story {
  final String title, poet, text, source;
  final String? matn;
  const _Story(this.title, this.poet, this.text, this.source, {this.matn});
}

const _stories = [
  _Story('«بانت سعاد» وعفو النبي ﷺ', 'كعب بن زهير',
      'كان كعب قد قال شعراً أهدر النبي صلى الله عليه وسلم به دمه. فلما ضاقت به الأرض قدم المدينة متخفياً، وجاء إلى النبي صلى الله عليه وسلم فأسلم واستأمنه، ثم أنشده لاميته التي أولها «بانت سعاد»، فعفا عنه. ويُروى أنه كساه بردته، ولذلك عُرفت بقصيدة البردة.',
      'السيرة النبوية لابن هشام'),
  _Story('عينية أبي ذؤيب في بنيه', 'أبو ذؤيب',
      'يُروى أن أبا ذؤيب هلك له خمسة بنين في عام واحد بالطاعون، وكانوا رجالاً لهم بأس. فقال عينيته المشهورة يرثيهم ويتصبّر، وفيها أبياته السائرة في المنية والتجلّد للشامتين. وعدّها العلماء بالشعر من أجود المراثي.',
      'الشعر والشعراء لابن قتيبة'),
  _Story('أبيات خُبيب قبل قتله', 'خُبيب',
      'أُسر خُبيب بن عدي رضي الله عنه يوم الرَّجيع وبيع بمكة. فلما خرجوا به من الحرم ليقتلوه استأذنهم أن يصلي ركعتين، فكان أول من سنّ الركعتين عند القتل، ثم قال أبياته وهو يُقدَّم للقتل.',
      'صحيح البخاري، والسيرة النبوية لابن هشام'),
  _Story('الخنساء وأخوها صخر', 'الخنساء',
      'كان صخر أخو الخنساء لأبيها، وكان حليماً جواداً محبوباً في قومه، وكان يواسيها بماله. جُرح في غزاة فمرض طويلاً ثم مات، فرثته الخنساء سنين طويلة حتى صار رثاؤها مضرب المثل.',
      'الشعر والشعراء لابن قتيبة'),
  _Story('رسالة ابن المبارك إلى الفُضيل', 'عبد الله بن المبارك',
      'كان ابن المبارك مرابطاً في الثغر يجاهد، والفضيل بن عياض مجاوراً بمكة يتعبّد. فكتب إليه ابن المبارك أبياته «يا عابد الحرمين» يذكر فضل الجهاد. فلما قرأها الفضيل بكى وقال: صدق أبو عبد الرحمن ونصحني.',
      'سير أعلام النبلاء للذهبي',
      matn: 'mubarak'),
  _Story('المعتمد بن عبّاد في أغمات', 'المعتمد',
      'كان المعتمد ملك إشبيلية، فخلعه المرابطون وحملوه أسيراً إلى أغمات بالمغرب. ودخل عليه بناته يوم عيد في ثياب رثّة وقد صرن يغزلن للناس بالأجرة، فقال أبياته التي أولها «فيما مضى كنتَ بالأعياد مسروراً».',
      'وفيات الأعيان لابن خلكان'),
  _Story('الحطيئة في سجن عمر', 'الحطيئة',
      'هجا الحطيئة الزبرقان بن بدر، فشكاه إلى عمر بن الخطاب رضي الله عنه فحبسه. فأرسل الحطيئة إلى عمر أبياتاً يستعطفه بصغاره، فرقّ له وأطلقه، وأخذ عليه ألا يهجو أحداً من المسلمين.',
      'الشعر والشعراء لابن قتيبة'),
  _Story('متمِّم يرثي أخاه مالكاً', 'متمم',
      'قُتل مالك بن نويرة في حروب الردة، فرثاه أخوه متمِّم بمراثٍ صارت مثلاً في رثاء الإخوة. ويُروى أن عمر بن الخطاب رضي الله عنه قال له: لو كنت أقول الشعر لرثيت أخي زيداً كما رثيت أخاك.',
      'طبقات فحول الشعراء لابن سلّام'),
  _Story('وفاء السموأل', 'السموأل',
      'يُروى أن امرأ القيس أودع السموأل دروعاً له حين قصد قيصر. فجاء ملك يطلبها، فتحصّن السموأل في حصنه الأبلق، فأخذ الملك ابناً له خارج الحصن وهدّده بقتله إن لم يسلّم الدروع. فأبى أن يخون أمانته فقُتل ابنه وهو ينظر، فضُرب به المثل: «أوفى من السموأل».',
      'الأغاني لأبي الفرج الأصفهاني'),
  _Story('حاتم يخاطب ماويّة', 'حاتم الطائي',
      'كانت ماويّة امرأة حاتم تلومه على إتلاف ماله في الضيفان والسائلين. فقال قصيدته التي يخاطبها فيها: إن المال يذهب ويجيء، ولا يبقى منه إلا الذكر الحسن.',
      'الشعر والشعراء لابن قتيبة'),
];

class StoriesScreen extends StatelessWidget {
  const StoriesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('قصائد لها قصة')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
          for (final s in _stories)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink(context))),
                  const SizedBox(height: 6),
                  Text(s.text, style: TextStyle(fontSize: 15.5, height: 1.85, color: C.ink(context))),
                  const SizedBox(height: 6),
                  Text('المصدر: ${s.source}', style: TextStyle(fontSize: 13, color: C.muted(context))),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final poems = Library.poems.where((p) => Ar.plain(p.poet).contains(Ar.plain(s.poet))).toList();
                    final matn = s.matn == null ? null : Library.mutun.where((m) => m.id == s.matn && m.ready).firstOrNull;
                    return Wrap(spacing: 8, children: [
                      if (matn != null) OutlinedButton.icon(onPressed: () => push(context, MatnScreen(matn: matn)), icon: const Icon(Icons.menu_book_rounded, size: 18), label: const Text('اقرأ القصيدة')),
                      if (poems.isNotEmpty) OutlinedButton.icon(onPressed: () => openPoet(context, poems.first.poet), icon: const Icon(Icons.person_outline_rounded, size: 18), label: const Text('شعره في التطبيق')),
                    ]);
                  }),
                ]),
              ),
            ),
          Text('القصص مختصرة من كتب الأدب والسير المذكورة، بصياغة التطبيق.', style: TextStyle(fontSize: 13, color: C.muted(context))),
        ]),
      );
}

// ------------------------------------------------------------ بيت وجوابه

class AnswersScreen extends StatelessWidget {
  const AnswersScreen({super.key});
  static const pairs = [
    (
      'نقيضة الفخر بين الفرزدق وجرير',
      'افتخر الفرزدق بقومه بني دارم ومجاشع، فنقض عليه جرير قصيدته على وزنها وقافيتها.',
      'الفرزدق',
      ['إِنَّ الَّذي سَمَكَ السَماءَ بَنى لَنا', 'بَيتاً دَعائِمُهُ أَعَزُّ وَأَطوَلُ'],
      'جرير',
      ['أَخزى الَّذي سَمَكَ السَماءَ مُجاشِعاً', 'وَبَنى بِناءَكَ في الحَضيضِ الأَسفَلِ'],
    ),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('بيت وجوابه')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
          Text('المعارضات والنقائض: بيت قاله شاعر، فأجابه آخر على وزنه وقافيته.', style: TextStyle(color: C.muted(context), height: 1.6)),
          const SizedBox(height: 10),
          for (final p in pairs)
            SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.$1, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
                Text(p.$2, style: TextStyle(fontSize: 14.5, height: 1.6, color: C.muted(context))),
                const SizedBox(height: 10),
                Text('قال ${p.$3}:', style: TextStyle(color: C.accent(context), fontWeight: FontWeight.w700)),
                VerseLines(p.$4, size: 21),
                const SizedBox(height: 6),
                Row(children: [Icon(Icons.subdirectory_arrow_left_rounded, color: C.muted(context)), Text('فأجابه ${p.$5}:', style: TextStyle(color: C.accent(context), fontWeight: FontWeight.w700))]),
                VerseLines(p.$6, size: 21),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(onPressed: () => copySheet(context, [p.$4, p.$6]), icon: Icon(Icons.copy_rounded, size: 19, color: C.muted(context))),
                ),
              ]),
            ),
          const SizedBox(height: 12),
          Text('هذه البداية، وتُضاف أزواج أخرى بعد مقابلتها بالدواوين.', style: TextStyle(fontSize: 13, color: C.muted(context))),
        ]),
      );
}

// ------------------------------------------------------------ معاني الغريب

/// The words of a verse: tap one to look it up in the dictionary.
void wordMeanings(BuildContext context, List<String> line) {
  final words = <String>[];
  for (final w in line.join(' ').split(' ')) {
    final c = w.replaceAll(RegExp(r'[؟?!.،,:؛«»"()\[\]…*]'), '');
    if (Ar.plain(c).length > 2 && !words.contains(c)) words.add(c);
  }
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (b) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('معاني كلمات البيت', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(b))),
          Text('اضغط الكلمة فيُفتح معناها في المعجم (يحتاج إنترنت).', style: TextStyle(color: C.muted(b))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final w in words)
              ActionChip(
                label: Text(w, style: const TextStyle(fontFamily: verseFont, fontSize: 20)),
                onPressed: () => launchUrl(Uri.parse('https://www.almaany.com/ar/dict/ar-ar/${Uri.encodeComponent(Ar.plain(w))}/'), mode: LaunchMode.externalApplication),
              ),
          ]),
        ]),
      ),
    ),
  );
}
