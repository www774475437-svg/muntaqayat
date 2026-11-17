import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'lists.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ctl = TextEditingController();
  String q = '';
  final _stt = SpeechToText();
  bool _sttReady = false, listening = false;

  Future<void> _voice() async {
    if (listening) {
      await _stt.stop();
      setState(() => listening = false);
      return;
    }
    try {
      _sttReady = _sttReady ||
          await _stt.initialize(
            onStatus: (st) {
              if ((st == 'done' || st == 'notListening') && mounted) setState(() => listening = false);
            },
            onError: (_) {
              if (mounted) setState(() => listening = false);
            },
          );
    } catch (_) {
      _sttReady = false;
    }
    if (!mounted) return;
    if (!_sttReady) {
      toast(context, 'البحث بالصوت غير متاح على هذا الجهاز');
      return;
    }
    setState(() => listening = true);
    await _stt.listen(
      localeId: 'ar-SA',
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          ctl.text = r.recognizedWords;
          q = r.recognizedWords;
        });
        if (r.finalResult) Store.i.addRecent(r.recognizedWords);
      },
    );
  }

  @override
  void dispose() {
    _stt.cancel();
    ctl.dispose();
    super.dispose();
  }

  // Words people search for and the chapters they mean.
  static const _topics = {
    'عزه النفس': 'العزة والكرامة',
    'الكرامه': 'العزة والكرامة',
    'القوه': 'الشجاعة والجبن',
    'الشجاعه': 'الشجاعة والجبن',
    'الصديق': 'الأخوة والصداقة',
    'الاصدقاء': 'الأخوة والصداقة',
    'الام': 'الأمومة وتربية الأبناء',
    'الموت': 'ذكر الموت والآخرة',
    'الحزن': 'الشدائد والابتلاء',
    'الهم': 'الفرج بعد الشدة',
    'الامل': 'الأمل والطموح',
    'العلم': 'طلب العلم',
    'الوطن': 'الغربة والحنين إلى الوطن',
    'الفراق': 'الرحيل والفراق',
    'الشوق': 'الاشتياق والحنين',
    'المال': 'الفقر والغنى',
    'الصبر': 'الصبر والجلد',
    'الكرم': 'الكرم والجود',
    'الدنيا': 'الزهد في الدنيا',
    'الخيانه': 'الغدر والخيانة',
  };

  @override
  Widget build(BuildContext context) {
    final nq = Ar.norm(q.trim());
    final words = nq.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final chapters = nq.isEmpty
        ? <Chapter>[]
        : Library.chapters.where((c) {
            final n = Ar.norm(c.name);
            if (words.every(n.contains)) return true;
            final t = _topics[nq];
            return t != null && c.name == t;
          }).toList();
    final poets = nq.isEmpty ? <Poet>[] : Library.namedPoets.where((p) => words.every(Ar.norm(p.name).contains)).toList();
    final poems = nq.length < 2
        ? <Poem>[]
        : Library.poems.where((p) {
            final t = Ar.norm(p.plainText);
            return words.every(t.contains);
          }).toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: ctl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => q = v),
          onSubmitted: (v) => Store.i.addRecent(v),
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: 'ابحث عن بيت أو شاعر أو باب…',
            border: InputBorder.none,
            suffixIcon: q.isEmpty
                ? IconButton(
                    tooltip: 'البحث بالصوت',
                    icon: Icon(listening ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                        color: listening ? const Color(0xFFB3261E) : null),
                    onPressed: _voice,
                  )
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      ctl.clear();
                      q = '';
                    }),
                  ),
          ),
        ),
      ),
      body: listening && nq.isEmpty
          ? const EmptyNote(Icons.mic_rounded, 'أسمعك… قل شيئاً من البيت أو اسم الشاعر.')
          : nq.isEmpty
              ? _start(context)
              : _results(context, chapters, poets, poems),
    );
  }

  Widget _start(BuildContext context) {
    final recent = Store.i.recent;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
      if (recent.isNotEmpty) ...[
        Row(children: [
          Expanded(child: Text('عمليات بحث سابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context)))),
          TextButton(onPressed: () => setState(Store.i.clearRecent), child: const Text('مسح')),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in recent) ActionChip(label: Text(r), onPressed: () => _set(r)),
        ]),
        const SizedBox(height: 20),
      ],
      Text('جرّب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in ['عزة النفس', 'الصبر', 'الصديق', 'الموت', 'الأم', 'المتنبي', 'الشافعي', 'الدنيا', 'العلم'])
          ActionChip(label: Text(s), onPressed: () => _set(s)),
      ]),
    ]);
  }

  void _set(String s) {
    ctl.text = s;
    setState(() => q = s);
    Store.i.addRecent(s);
  }

  Widget _results(BuildContext context, List<Chapter> chapters, List<Poet> poets, List<Poem> poems) {
    if (chapters.isEmpty && poets.isEmpty && poems.isEmpty) {
      return const EmptyNote(Icons.search_off_rounded, 'لا نتائج. جرّب كلمة أخرى من البيت، أو اسم الشاعر، أو موضوعاً مثل «الصبر».');
    }
    return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
      if (chapters.isNotEmpty) ...[
        _head(context, 'الأبواب'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in chapters)
              ActionChip(
                avatar: Icon(Icons.menu_book_outlined, size: 18, color: C.accent(context)),
                label: Text(c.name),
                onPressed: () {
                  Store.i.addRecent(q);
                  openList(context, c.name, Library.ofChapter(c.index));
                },
              ),
          ]),
        ),
      ],
      if (poets.isNotEmpty) ...[
        _head(context, 'الشعراء'),
        for (final p in poets.take(8))
          ListTile(
            leading: Avatar(p.initial, size: 42),
            title: Text(p.name),
            subtitle: Text([if (p.era.isNotEmpty) p.era, Ar.selections(p.count)].join(' · ')),
            onTap: () {
              Store.i.addRecent(q);
              openPoet(context, p.name);
            },
          ),
      ],
      if (poems.isNotEmpty) ...[
        _head(context, 'الأبيات (${Ar.num(poems.length)})'),
        TwoColumns(
          poems: poems.take(60).toList(),
          onTap: (p) {
            Store.i.addRecent(q);
            openPoem(context, p);
          },
        ),
      ],
    ]);
  }

  Widget _head(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
      );
}
