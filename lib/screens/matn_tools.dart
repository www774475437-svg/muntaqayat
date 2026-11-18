import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data.dart';
import '../services/device.dart';
import '../services/pdf_image.dart';
import '../ui.dart';
import 'lists.dart';

// ------------------------------------------------------------ memorization map

/// The whole matn as coloured squares: green = firm, yellow = due for review,
/// grey = not memorized yet.
class MemoryMapScreen extends StatelessWidget {
  final Matn matn;
  const MemoryMapScreen({super.key, required this.matn});

  static const green = Color(0xFF2F6B4F), yellow = Color(0xFFD9A21B);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final n = matn.lines.length;
          var g = 0, y = 0;
          for (var v = 1; v <= n; v++) {
            final s = Store.i.stateOf(matn.id, v);
            if (s == 2) g++;
            if (s == 1) y++;
          }
          return Scaffold(
            appBar: AppBar(title: const Text('خريطة الحفظ')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              Text(matn.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.accent(context))),
              const SizedBox(height: 10),
              Wrap(spacing: 14, runSpacing: 6, children: [
                _legend(context, green, 'محفوظ ثابت (${Ar.num(g)})'),
                _legend(context, yellow, 'يحتاج مراجعة (${Ar.num(y)})'),
                _legend(context, C.line(context), 'لم يُحفظ (${Ar.num(n - g - y)})'),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (var v = 1; v <= n; v++) _cell(context, v),
              ]),
              const SizedBox(height: 16),
              Text('اضغط أي مربع لترى بيته. المراجعة الذكية تذكّرك بالبيت بعد يوم، ثم ٣ أيام، ثم أسبوع، ثم أسبوعين، ثم شهر.',
                  style: TextStyle(color: C.muted(context), height: 1.6)),
            ]),
          );
        },
      );

  Widget _cell(BuildContext context, int v) {
    final s = Store.i.stateOf(matn.id, v);
    final c = s == 2 ? green : (s == 1 ? yellow : C.line(context));
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 34),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            VerseLines(matn.lines[v - 1], size: 22, number: v),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Store.i.setMemorized(matn.id, v, s == 0);
                Navigator.pop(context);
              },
              child: Text(s == 0 ? 'علّمه محفوظاً' : 'أزل علامة الحفظ'),
            ),
          ]),
        ),
      ),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
        child: Text(Ar.num(v), style: TextStyle(fontSize: v > 999 ? 9 : 11, color: s == 0 ? C.muted(context) : Colors.white)),
      ),
    );
  }

  Widget _legend(BuildContext context, Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 5),
        Text(t, style: TextStyle(color: C.ink(context))),
      ]);
}

// ------------------------------------------------------------ listen & repeat

/// Reads each verse aloud several times so the student repeats after it.
/// (Recorded recitations replace the phone voice when they are added.)
class ListenScreen extends StatefulWidget {
  final Matn matn;
  const ListenScreen({super.key, required this.matn});
  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  final tts = FlutterTts();
  late RangeValues range;
  int current = 0; // 1-based verse being read, 0 = stopped
  int round = 0;
  bool playing = false;
  double rate = 0.4;

  @override
  void initState() {
    super.initState();
    final n = widget.matn.lines.length.toDouble();
    range = RangeValues(1, n < 5 ? n : 5);
    tts.setLanguage('ar');
    tts.awaitSpeakCompletion(true);
  }

  @override
  void dispose() {
    playing = false;
    tts.stop();
    super.dispose();
  }

  Future<void> _play() async {
    setState(() => playing = true);
    await tts.setSpeechRate(rate);
    for (var v = range.start.round(); v <= range.end.round() && playing; v++) {
      for (var r = 1; r <= Store.i.repeat && playing; r++) {
        if (!mounted) return;
        setState(() {
          current = v;
          round = r;
        });
        await tts.speak(widget.matn.lines[v - 1].join('، '));
        await Future.delayed(const Duration(milliseconds: 900));
      }
    }
    if (mounted) {
      setState(() {
        playing = false;
        current = 0;
      });
    }
  }

  void _stop() {
    tts.stop();
    setState(() {
      playing = false;
      current = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.matn;
    final n = m.lines.length.toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('استمع وردّد')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        Text('يقرأ الجوال كل بيت مرات تختارها وأنت تردّد معه، ويُضاء البيت الذي يُقرأ. وحين تُضاف التسجيلات الصوتية بالقراءة الصحيحة تحلّ محلّ صوت الجوال.',
            style: TextStyle(color: C.muted(context), height: 1.6)),
        const SizedBox(height: 12),
        Text('من البيت ${Ar.num(range.start.round())} إلى ${Ar.num(range.end.round())}', style: TextStyle(color: C.ink(context))),
        if (n > 1)
          RangeSlider(
            values: range,
            min: 1,
            max: n,
            divisions: (n - 1).round(),
            onChanged: playing ? null : (v) => setState(() => range = v),
          ),
        Row(children: [
          Text('تكرار كل بيت:', style: TextStyle(color: C.ink(context))),
          const SizedBox(width: 10),
          SegmentedButton<int>(
            segments: [for (final k in [1, 3, 5, 7]) ButtonSegment(value: k, label: Text(Ar.num(k)))],
            selected: {Store.i.repeat},
            onSelectionChanged: playing ? null : (v) => setState(() => Store.i.setRepeat(v.first)),
          ),
        ]),
        Row(children: [
          Text('السرعة', style: TextStyle(color: C.ink(context))),
          Expanded(child: Slider(value: rate, min: 0.2, max: 0.7, onChanged: playing ? null : (v) => setState(() => rate = v))),
        ]),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
          onPressed: playing ? _stop : _play,
          icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
          label: Text(playing ? 'إيقاف' : 'ابدأ', style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(height: 14),
        for (var v = range.start.round(); v <= range.end.round(); v++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: v == current ? C.soft(context) : C.card(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: v == current ? C.accent(context) : C.line(context), width: v == current ? 2 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (v == current) Text('المرة ${Ar.num(round)} من ${Ar.num(Store.i.repeat)}', style: TextStyle(color: C.accent(context))),
              VerseLines(m.lines[v - 1], size: 21, number: v),
            ]),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------ explanations

String? youtubeId(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null) return null;
  if (u.host.contains('youtu.be')) return u.pathSegments.isEmpty ? null : u.pathSegments.first;
  if (u.host.contains('youtube.com')) {
    if (u.queryParameters['v'] != null) return u.queryParameters['v'];
    final i = u.pathSegments.indexWhere((s) => s == 'embed' || s == 'shorts' || s == 'live');
    if (i >= 0 && i + 1 < u.pathSegments.length) return u.pathSegments[i + 1];
  }
  return null;
}

/// «الشروح»: explanations of the matn (YouTube plays inside the app; books open).
class ShuruhSection extends StatelessWidget {
  final Matn matn;
  const ShuruhSection({super.key, required this.matn});

  @override
  Widget build(BuildContext context) {
    final mine = Store.i.shuruhOf(matn.id);
    final all = [...matn.links, ...mine];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('الشروح'),
      if (all.isEmpty)
        Text('تُضاف هنا شروح العلماء للمنظومة: دروس مرئية تعمل داخل التطبيق، وكتب الشروح.',
            style: TextStyle(color: C.muted(context), height: 1.6)),
      for (var i = 0; i < all.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            padding: const EdgeInsets.all(12),
            onTap: () => _open(context, all[i]),
            child: Row(children: [
              RoundIcon(youtubeId(all[i]['url'] ?? '') != null ? Icons.play_circle_outline_rounded : Icons.menu_book_rounded, size: 46),
              const SizedBox(width: 12),
              Expanded(child: Text(all[i]['title'] ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context)))),
              if (youtubeId(all[i]['url'] ?? '') != null)
                IconButton(
                  tooltip: 'افتح في يوتيوب',
                  onPressed: () => launchUrl(Uri.parse(all[i]['url']!), mode: LaunchMode.externalApplication),
                  icon: Icon(Icons.open_in_new_rounded, size: 20, color: C.muted(context)),
                ),
              if (Store.i.developer && i >= matn.links.length)
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () => Store.i.removeSharh(matn.id, i - matn.links.length),
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: C.muted(context)),
                ),
            ]),
          ),
        ),
      if (Store.i.developer)
        OutlinedButton.icon(
          onPressed: () => _add(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('أضف شرحاً (يوتيوب أو كتاب) — للمطوّر'),
        ),
    ]);
  }

  void _open(BuildContext context, Map<String, String> s) {
    final url = s['url'] ?? '';
    final id = youtubeId(url);
    if (id != null) {
      push(context, YouTubeScreen(title: s['title'] ?? '', id: id, url: url));
    } else if (url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _add(BuildContext context) {
    final t = TextEditingController(), u = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('شرح جديد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: t, decoration: const InputDecoration(labelText: 'العنوان، مثل: شرح ابن عثيمين')),
          TextField(controller: u, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'الرابط (يوتيوب أو ملف الكتاب)')),
          const SizedBox(height: 8),
          const Text('يظهر على جهازك الآن، ويظهر للجميع بعد ربط فايربيس.', style: TextStyle(fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (t.text.trim().isEmpty || u.text.trim().isEmpty) return;
              Store.i.addSharh(matn.id, t.text.trim(), u.text.trim());
              Navigator.pop(c);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

class YouTubeScreen extends StatefulWidget {
  final String title, id, url;
  const YouTubeScreen({super.key, required this.title, required this.id, required this.url});
  @override
  State<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends State<YouTubeScreen> {
  late final YoutubePlayerController _c =
      YoutubePlayerController.fromVideoId(videoId: widget.id, params: const YoutubePlayerParams(showFullscreenButton: true));

  @override
  void dispose() {
    _c.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: ListView(children: [
          YoutubePlayer(controller: _c, aspectRatio: 16 / 9),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('افتح في يوتيوب'),
              ),
            ),
          ),
        ]),
      );
}

// ------------------------------------------------------------ certificate

/// After memorizing a whole matn and scoring 9/10 or more in its writing test.
bool certificateReady(Matn m) =>
    m.lines.isNotEmpty && Store.i.memOf(m.id).length >= m.lines.length && (Store.i.best[m.id] ?? 0) >= 9;

class CertificateScreen extends StatefulWidget {
  final Matn matn;
  const CertificateScreen({super.key, required this.matn});
  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final _key = GlobalKey();
  late final name = TextEditingController(text: Store.i.certName);
  bool busy = false;

  Future<ui.Image> _image() async {
    final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    return b.toImage(pixelRatio: 2.5);
  }

  Future<void> _share(bool asPdf) async {
    setState(() => busy = true);
    try {
      final img = await _image();
      if (!asPdf) {
        final png = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
        await Share.shareXFiles([XFile.fromData(png, mimeType: 'image/png', name: 'shahada-${widget.matn.id}.png')]);
      } else {
        final rgba = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        final bytes = imagePdf(img.width, img.height, rgba, Device.zlib);
        await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'application/pdf', name: 'shahada-${widget.matn.id}.pdf')]);
      }
    } catch (_) {
      if (mounted) toast(context, 'تعذّر إنشاء الملف');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.matn;
    final ready = certificateReady(m);
    final score = Store.i.best[m.id] ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('شهادة إتمام الحفظ')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        if (!ready)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: const Text('معاينة للمطوّر: تُعطى الشهادة للطالب بعد أن يحفظ المنظومة كلها وينال ٩ من ١٠ أو أكثر في اختبار الكتابة عليها كلها.'),
          ),
        TextField(
          controller: name,
          onChanged: (v) => setState(() => Store.i.setCertName(v.trim())),
          decoration: InputDecoration(
            labelText: 'اكتب اسمك كما تريده في الشهادة',
            filled: true,
            fillColor: C.card(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        FittedBox(
          child: RepaintBoundary(
            key: _key,
            child: Certificate(name: name.text.trim().isEmpty ? 'اسم الطالب' : name.text.trim(), matn: m, score: ready ? score : 10),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: busy ? null : () => _share(true),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => _share(false),
              icon: const Icon(Icons.image_outlined),
              label: const Text('صورة'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class Certificate extends StatelessWidget {
  final String name;
  final Matn matn;
  final int score;
  const Certificate({super.key, required this.name, required this.matn, required this.score});

  static const ink = Color(0xFF2B2520), gold = Color(0xFFB08A3E), terra = Color(0xFF8C4A2F), paper = Color(0xFFFBF7EE);

  @override
  Widget build(BuildContext context) {
    final (hy, hm, hd) = Hijri.parts();
    final now = DateTime.now();
    TextStyle t(double s, {Color c = ink, FontWeight w = FontWeight.normal, String? f}) =>
        TextStyle(fontSize: s, color: c, fontWeight: w, fontFamily: f ?? verseFont, height: 1.5);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 840,
        height: 594,
        color: paper,
        padding: const EdgeInsets.all(18),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: gold, width: 3)),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: gold.withValues(alpha: 0.6), width: 1)),
            padding: const EdgeInsets.fromLTRB(40, 22, 40, 14),
            child: Column(children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: terra, width: 2)),
                child: Text('منتقيات\nالشعر', textAlign: TextAlign.center, style: t(17, c: terra, w: FontWeight.w700).copyWith(height: 1.1)),
              ),
              const SizedBox(height: 6),
              Text('شهادة إتمام حفظ', style: t(38, c: terra, w: FontWeight.w700)),
              Container(width: 220, height: 1.5, color: gold),
              const SizedBox(height: 14),
              Text('يشهد تطبيق «منتقيات الشعر» أنّ', style: t(21)),
              const SizedBox(height: 4),
              Text(name, style: t(40, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('أتمّ حفظ «${matn.title}»', textAlign: TextAlign.center, style: t(25, c: terra, w: FontWeight.w700)),
              Text('${matn.author}${matn.death.isEmpty ? '' : ' (ت ${matn.death})'} — ${Ar.num(matn.lines.length)} بيتاً',
                  style: t(18, c: const Color(0xFF6E655C))),
              const SizedBox(height: 6),
              Text('واجتاز اختبار الكتابة بدرجة ${Ar.num(score)} من ١٠', style: t(20)),
              const Spacer(),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('التاريخ', style: t(14, c: const Color(0xFF6E655C))),
                    Text('${Ar.num(hd)} ${Hijri.months[(hm - 1).clamp(0, 11)]} ${Ar.num(hy)} هـ', style: t(17)),
                    Text('${Ar.num(now.day)} ${Hijri.gMonths[now.month - 1]} ${Ar.num(now.year)} م', style: t(15, c: const Color(0xFF6E655C))),
                  ]),
                ),
                Column(children: [
                  const SizedBox(width: 180, height: 46), // the developer's signature goes here later
                  Container(width: 180, height: 1, color: ink),
                  Text('التوقيع', style: t(14, c: const Color(0xFF6E655C))),
                  Text('أبو عبد الرحمن أحمد الأثري', style: t(9.5, c: const Color(0xFF8A8178))),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
