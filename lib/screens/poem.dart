import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data.dart';
import '../main.dart';
import '../ui.dart';
import 'extras.dart';
import 'plus.dart';
import 'lists.dart';

const siteUrl = 'https://www774475437-svg.github.io/muntaqayat/';

String poemLink(Poem p) => '$siteUrl#/p/${p.id}';

/// The copy layout used in the channel: each verse on two lines (the second
/// indented), «..» between verses, and «،.🪶» at the very end.
String formatVerses(List<List<String>> lines) {
  const rlm = '\u200F';
  final verses = [
    for (final l in lines)
      l.length > 1 ? '$rlm${l[0].trim()}\n         $rlm${l[1].trim()}' : '$rlm${l[0].trim()}',
  ];
  var text = verses.join('\n..\n').trimRight();
  text = text.replaceFirst(RegExp(r'[،,.\s]+$'), '');
  return '$text،.🪶';
}

/// For WhatsApp: no hidden direction marks or indentation, a blank line
/// between verses and «،.🪶» at the end.
String formatWhatsApp(List<List<String>> lines) {
  var text = [for (final l in lines) l.map((h) => h.trim()).join('\n')].join('\n\n').trimRight();
  text = text.replaceFirst(RegExp(r'[،,.\s]+$'), '');
  return '$text،.🪶';
}

void copyVerses(BuildContext context, List<List<String>> lines, {bool whatsapp = false}) {
  Clipboard.setData(ClipboardData(text: whatsapp ? formatWhatsApp(lines) : formatVerses(lines)));
  final what = lines.length > 1 ? Ar.verses(lines.length) : 'البيت';
  toast(context, 'تمّ نسخ $what${whatsapp ? ' لواتساب' : ''}');
}

/// Choose: copy for Telegram (the channel layout) or for WhatsApp.
void copySheet(BuildContext context, List<List<String>> lines) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(lines.length > 1 ? 'نسخ ${Ar.verses(lines.length)}' : 'نسخ البيت', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ListTile(
          leading: const Icon(Icons.send_rounded),
          title: const Text('نسخ لتيليجرام'),
          subtitle: const Text('بتنسيق القناة: «..» بين الأبيات'),
          onTap: () {
            Navigator.pop(c);
            copyVerses(context, lines);
          },
        ),
        ListTile(
          leading: const Icon(Icons.chat_rounded),
          title: const Text('نسخ لواتساب'),
          subtitle: const Text('سطر فارغ بين الأبيات'),
          onTap: () {
            Navigator.pop(c);
            copyVerses(context, lines, whatsapp: true);
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

class PoemScreen extends StatefulWidget {
  final Poem poem;
  final bool fromLink;
  const PoemScreen({super.key, required this.poem, this.fromLink = false});
  @override
  State<PoemScreen> createState() => _PoemScreenState();
}

class _PoemScreenState extends State<PoemScreen> {
  Poem get p => widget.poem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Store.i.opened(p.id));
  }

  void _back() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final related = Library.related(p);
    final meta = [
      if (p.era.isNotEmpty) p.era,
      if (p.death.isNotEmpty) 'تُوفي ${p.death}',
      if (p.rhyme.isNotEmpty) 'القافية: ${p.rhyme}',
      p.chapterName,
    ].join(' · ');
    return ListenableBuilder(listenable: Store.i, builder: (context, _) => Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 60), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Row(children: [
              _circle(context, Icons.arrow_forward_rounded, _back),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: C.bar(context),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    onPressed: () => Store.i.toggleLike(p.id),
                    icon: Icon(Store.i.liked(p.id) ? Icons.favorite : Icons.favorite_border, color: Store.i.liked(p.id) ? C.accent(context) : C.ink(context)),
                  ),
                  IconButton(
                    tooltip: 'نسخ المقطع كاملاً',
                    onPressed: () => copySheet(context, p.shown),
                    icon: Icon(Icons.copy_all_rounded, color: C.ink(context)),
                  ),
                  IconButton(onPressed: () => shareSheet(context, p, p.firstVerse), icon: Icon(Icons.ios_share_rounded, color: C.ink(context))),
                  IconButton(onPressed: () => _more(context), icon: Icon(Icons.more_horiz_rounded, color: C.ink(context))),
                  IconButton(onPressed: () => _font(context), icon: Text('أء', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink(context)))),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: () => openPoet(context, p.poet),
                child: Text(p.poet,
                    style: TextStyle(
                      fontSize: 20,
                      color: C.accent(context),
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dashed,
                      decorationColor: C.accent(context).withValues(alpha: 0.5),
                    )),
              ),
              const SizedBox(height: 6),
              Text(Ar.verses(p.verseCount), style: TextStyle(fontSize: 15.5, color: C.muted(context))),
              const SizedBox(height: 4),
              Text(meta, style: TextStyle(fontSize: 14.5, color: C.muted(context), height: 1.5)),

                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    if (p.fromBook) const MarkBadge.book(),
                    if (p.anyVerified) const MarkBadge.verified(),
                    if (p.status.isNotEmpty) StatusBadge(p.status),
                    if (p.src == 'add') const Tag('من خارج الكتاب'),
                  ]),
                ),
              if (p.poetNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(p.poetNote, style: TextStyle(fontSize: 14, color: C.accent(context))),
                ),
              if (Store.i.noteOf(p.id).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SoftCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => _note(context),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.edit_note_rounded, color: C.accent(context)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(Store.i.noteOf(p.id), style: TextStyle(fontSize: 15, height: 1.6, color: C.ink(context)))),
                    ]),
                  ),
                ),
              Divider(height: 30, color: C.line(context)),
            ]),
          ),
          // Long-press to select any part of the verses; tap a verse for its actions.
          SelectionArea(
            child: Column(children: [
              for (var i = 0; i < p.lines.length; i++)
                if (!p.deletedVerse(i + 1) && (!p.hiddenVerse(i + 1) || Store.i.developer))
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _verseActions(context, p.lines[i]),
                    child: Opacity(
                      opacity: p.hiddenVerse(i + 1) ? 0.4 : 1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 6, 14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: VerseLines(p.lines[i], size: 27, number: p.lines.length > 1 ? i + 1 : null)),
                          if (!Store.i.developer && p.verifiedVerse(i + 1))
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Tooltip(message: 'بيت موثّق', child: Icon(Icons.verified_rounded, size: 19, color: verifiedBlue)),
                            ),
                          if (Store.i.developer) ...[
                            VerifyButton('p:${p.id}:${i + 1}', what: 'هذا البيت'),
                            IconButton(
                              tooltip: p.hiddenVerse(i + 1) ? 'إظهار البيت' : 'إخفاء البيت',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                final h = !p.hiddenVerse(i + 1);
                                Store.i.setHidden('p:${p.id}:${i + 1}', h);
                                toast(context, h ? 'أُخفي البيت عن القرّاء' : 'عاد البيت ظاهراً');
                              },
                              icon: Icon(p.hiddenVerse(i + 1) ? Icons.visibility_off_rounded : Icons.visibility_outlined, size: 19, color: C.muted(context)),
                            ),
                          ],
                          IconButton(
                            tooltip: 'نسخ البيت',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => copySheet(context, [p.lines[i]]),
                            icon: Icon(Icons.copy_rounded, size: 18, color: C.muted(context)),
                          ),
                        ]),
                      ),
                    ),
                  ),
            ]),
          ),
          if (p.lines.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                onPressed: () => copySheet(context, p.shown),
                icon: const Icon(Icons.copy_all_rounded),
                label: Text('نسخ الأبيات كلها (${Ar.verses(p.shown.length)})', style: const TextStyle(fontSize: 16)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
            child: Row(children: [
              ActionChip(
                avatar: Icon(Icons.auto_awesome_rounded, size: 18, color: C.accent(context)),
                label: const Text('الشرح'),
                onPressed: () => _soon(context, 'شرح الأبيات من كتب الشُّرّاح ومعاجم اللغة، مع ذكر المصدر — قريباً بإذن الله.'),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: Icon(Icons.school_outlined, size: 18, color: C.accent(context)),
                label: const Text('وضع الحفظ'),
                onPressed: () => push(context, MemorizeScreen(poem: p)),
              ),
            ]),
          ),
          if (Store.i.developer) _review(context),
          if (related.isNotEmpty) ...[
            SectionTitle('من الباب نفسه', onMore: () => openList(context, p.chapterName, Library.ofChapter(p.chapter))),
            TwoColumns(poems: related, onTap: (x) => openPoem(context, x)),
          ],
        ]),
      ),
    ));
  }

  Widget _review(BuildContext context) {
    final ok = Store.i.isReviewed(p.id);
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? const Color(0x1A2F6B4F) : const Color(0x1AB3261E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ok ? const Color(0xFF2F6B4F) : const Color(0xFFB3261E)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('للمطوّر فقط — المراجعة (صفحة ${Ar.num(p.page)} من الكتاب)', style: const TextStyle(fontWeight: FontWeight.w700)),
        if (p.flags.isNotEmpty) Text('ملاحظات الاستخراج: ${p.flags.join('، ')}', style: TextStyle(color: C.muted(context))),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: ok ? const Color(0xFF2F6B4F) : C.accent(context)),
          onPressed: () => Store.i.toggleReviewed(p.id),
          icon: Icon(ok ? Icons.verified_rounded : Icons.check_rounded),
          label: Text(ok ? 'تمّ التحقق ✓ (اضغط للإلغاء)' : 'تمّ التحقق من هذا المقطع'),
        ),
      ]),
    );
  }

  Widget _circle(BuildContext context, IconData icon, VoidCallback onTap) => Material(
        color: C.bar(context),
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black26,
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 52, height: 52, child: Icon(icon, color: C.ink(context)))),
      );

  void _verseActions(BuildContext context, List<String> line) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 12), child: VerseLines(line, size: 21)),
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: const Text('معاني كلمات البيت'),
            onTap: () {
              Navigator.pop(c);
              wordMeanings(context, line);
            },
          ),
          if (p.lines.length > 1)
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: Text('نسخ المقطع كاملاً (${Ar.verses(p.lines.length)})'),
              onTap: () {
                Navigator.pop(c);
                copySheet(context, p.shown);
              },
            ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('نسخ هذا البيت وحده'),
            onTap: () {
              Navigator.pop(c);
              copySheet(context, [line]);
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_quote_rounded),
            title: const Text('اقتبسه في صفحتي'),
            onTap: () {
              Navigator.pop(c);
              soonSheet(context, 'الاقتباس في صفحتك', 'تنشر البيت في صفحتك الشخصية وقسم «الاقتباسات» (عشرة اقتباسات في اليوم). تُفعَّل مع الحسابات قريباً بإذن الله.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('مشاركة البيت صورة'),
            onTap: () {
              Navigator.pop(c);
              shareSheet(context, p, line);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_add_outlined),
            title: const Text('حفظ في مجموعة'),
            onTap: () {
              Navigator.pop(c);
              collectionSheet(context, p);
            },
          ),
        ]),
      ),
    );
  }

  /// The ⋯ menu: a card that opens in place, under the button.
  void _more(BuildContext context) {
    HapticFeedback.selectionClick();
    final liked = Store.i.liked(p.id);
    final note = Store.i.noteOf(p.id);
    final cols = Store.i.collections.keys.toList();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (c, anim, _, __) {
        final t = Curves.easeOutBack.transform(anim.value);
        Widget row(IconData icon, String text, VoidCallback onTap, {Color? color, bool faint = false}) => InkWell(
              onTap: () {
                Navigator.pop(c);
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                child: Row(children: [
                  Icon(icon, size: 24, color: color ?? (faint ? C.muted(c) : C.ink(c))),
                  const SizedBox(width: 14),
                  Expanded(child: Text(text, style: TextStyle(fontSize: 17, height: 1.35, color: color ?? (faint ? C.muted(c) : C.ink(c))))),
                ]),
              ),
            );
        Widget line() => Divider(height: 14, indent: 20, endIndent: 20, color: C.line(c));
        return SafeArea(
          child: Align(
            alignment: AlignmentDirectional.topEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 62, end: 14, start: 60),
              child: Opacity(
                opacity: anim.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * t,
                  alignment: AlignmentDirectional.topEnd.resolve(Directionality.of(c)),
                  child: Material(
                    color: C.bar(c),
                    elevation: 18,
                    shadowColor: Colors.black38,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: C.line(c))),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 330),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          row(Icons.copy_all_rounded, 'نسخ المقطع كاملاً', () => copySheet(context, p.shown)),
                          row(Icons.check_circle_outline_rounded, 'تحديد الأبيات', () => toast(context, 'اضغط مطوّلاً على البيت ثم اسحب لتحديد ما تريد')),
                          row(Icons.image_outlined, 'مشاركة صورة', () => shareSheet(context, p, p.firstVerse)),
                          row(Icons.link_rounded, 'مشاركة الرابط', () => Share.share('${formatVerses(p.shown)}\n\n${poemLink(p)}')),
                          line(),
                          row(Icons.edit_note_rounded, note.isEmpty ? 'إضافة ملاحظة على المقطع' : 'ملاحظتك على المقطع', () => _note(context)),
                          if (cols.isEmpty)
                            row(Icons.create_new_folder_outlined, 'لا مجموعات بعد. أنشئ واحدة', () => collectionSheet(context, p), faint: true)
                          else
                            row(Icons.bookmark_add_outlined, 'حفظ في مجموعة', () => collectionSheet(context, p)),
                          row(Icons.school_outlined, 'احفظه غيباً', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemorizeScreen(poem: p)))),
                          line(),
                          if (liked)
                            row(Icons.remove_circle_outline_rounded, 'إزالة من الإعجاب', () => Store.i.toggleLike(p.id), color: const Color(0xFFD9534F))
                          else
                            row(Icons.favorite_border_rounded, 'أعجبني', () => Store.i.toggleLike(p.id)),
                          line(),
                          row(Icons.feedback_outlined, 'أبلغ عن مشكلة', () => suggest(context, 'مشكلة في المقطع رقم ${p.id} (${p.poet}):\n')),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _note(BuildContext context) {
    final c = TextEditingController(text: Store.i.noteOf(p.id));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (b) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.viewInsetsOf(b).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('ملاحظتك على المقطع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(b))),
          const SizedBox(height: 4),
          Text('لا يراها غيرك، وتبقى في جوالك.', style: TextStyle(color: C.muted(b))),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            autofocus: true,
            minLines: 3,
            maxLines: 7,
            decoration: InputDecoration(filled: true, fillColor: C.card(b), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              Store.i.setNote(p.id, c.text);
              Navigator.pop(b);
            },
            child: const Text('حفظ'),
          ),
        ]),
      ),
    );
  }

  void _font(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => ListenableBuilder(
        listenable: Store.i,
        builder: (c, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Text('حجم الخط', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Slider(value: Store.i.fontScale, min: 0.8, max: 1.5, divisions: 7, onChanged: Store.i.setFontScale),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إظهار التشكيل'),
              value: Store.i.tashkeel,
              onChanged: Store.i.setTashkeel,
            ),
          ]),
        ),
      ),
    );
  }
}

void _soon(BuildContext context, String text) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Text(text, style: const TextStyle(fontSize: 17, height: 1.7)),
    ),
  );
}

/// Send a suggestion to the developer (Telegram).
void suggest(BuildContext context, String start) {
  Clipboard.setData(ClipboardData(text: start));
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => const Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Text(
        'أرسل اقتراحك أو تصحيحك إلى المطوّر على تيليجرام: t.me/alhsaar4\nنسختُ لك رقم المقطع، فالصقه في رسالتك.',
        style: TextStyle(fontSize: 17, height: 1.7),
      ),
    ),
  );
}

void collectionSheet(BuildContext context, Poem p) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => ListenableBuilder(
      listenable: Store.i,
      builder: (c, _) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('حفظ في مجموعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final name in Store.i.collections.keys)
            CheckboxListTile(
              title: Text(name),
              subtitle: Text(Ar.selections(Store.i.collections[name]!.length)),
              value: Store.i.collections[name]!.contains(p.id),
              onChanged: (_) => Store.i.toggleIn(name, p.id),
            ),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('مجموعة جديدة'),
            onTap: () async {
              final name = await askName(c, 'اسم المجموعة', 'مثلاً: أبيات الحكمة');
              if (name != null) {
                Store.i.createCollection(name);
                Store.i.toggleIn(name, p.id);
              }
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    ),
  );
}

Future<String?> askName(BuildContext context, String title, String hint) {
  final ctl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctl, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctl.text.trim().isEmpty ? null : ctl.text.trim()),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- sharing

class _Style {
  final String name;
  final Color bg, ink, mark;
  const _Style(this.name, this.bg, this.ink, this.mark);
}

const _styles = [
  _Style('ورق', Color(0xFFF7F4EE), Color(0xFF1E1B16), Color(0xFF8C4A2F)),
  _Style('ليل', Color(0xFF15181F), Color(0xFFF1EBDF), Color(0xFFD9B26A)),
  _Style('زمرد', Color(0xFF123B33), Color(0xFFF4EFE3), Color(0xFFE2C27A)),
  _Style('عقيق', Color(0xFF5B1F1F), Color(0xFFF7EDE3), Color(0xFFF0C48A)),
];

void shareSheet(BuildContext context, Poem p, List<String> line) {
  Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => ShareCardScreen(poem: p, line: line)));
}

class ShareCardScreen extends StatefulWidget {
  final Poem poem;
  final List<String> line;
  const ShareCardScreen({super.key, required this.poem, required this.line});
  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _key = GlobalKey();
  int style = 0;
  bool busy = false;

  Future<void> _share() async {
    setState(() => busy = true);
    try {
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'muntaqayat-${widget.poem.id}.png')],
        text: '${widget.poem.poet} — منتقيات الشعر\n${poemLink(widget.poem)}',
      );
    } catch (e) {
      if (mounted) toast(context, 'تعذّرت المشاركة');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _styles[style];
    return Scaffold(
      appBar: AppBar(title: const Text('مشاركة صورة')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        RepaintBoundary(
          key: _key,
          child: Container(
            padding: const EdgeInsets.fromLTRB(26, 34, 26, 22),
            decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.line[0], style: TextStyle(fontFamily: verseFont, fontSize: 25, height: 1.9, color: s.ink),
                  textAlign: widget.line.length == 1 ? TextAlign.center : TextAlign.start),
              if (widget.line.length > 1)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 40),
                  child: Text(widget.line[1], style: TextStyle(fontFamily: verseFont, fontSize: 25, height: 1.9, color: s.ink)),
                ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.poem.poet, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: s.ink)),
                    if (widget.poem.era.isNotEmpty)
                      Text('العصر ${widget.poem.era}', style: TextStyle(fontSize: 12.5, color: s.ink.withValues(alpha: 0.7))),
                  ]),
                ),
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: s.mark, width: 1.6)),
                  child: Text('منتقيات\nالشعر',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: verseFont, fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w700, color: s.mark)),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(alignment: WrapAlignment.center, spacing: 10, children: [
          for (var i = 0; i < _styles.length; i++)
            ChoiceChip(
              label: Text(_styles[i].name),
              selected: style == i,
              avatar: CircleAvatar(backgroundColor: _styles[i].bg, radius: 9),
              onSelected: (_) => setState(() => style = i),
            ),
        ]),
        const SizedBox(height: 22),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: busy ? null : _share,
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(busy ? 'جارٍ التجهيز…' : 'مشاركة', style: const TextStyle(fontSize: 17)),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- memorizing

/// Hides the second hemistich until the reader taps it.
class MemorizeScreen extends StatefulWidget {
  final Poem poem;
  const MemorizeScreen({super.key, required this.poem});
  @override
  State<MemorizeScreen> createState() => _MemorizeScreenState();
}

class _MemorizeScreenState extends State<MemorizeScreen> {
  final shown = <int>{};
  @override
  Widget build(BuildContext context) {
    final lines = widget.poem.lines;
    return Scaffold(
      appBar: AppBar(title: const Text('وضع الحفظ')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 40), children: [
        Text('اقرأ الشطر الأول وحاول تذكّر الثاني، ثم اضغط عليه لتراه.', style: TextStyle(fontSize: 15, color: C.muted(context), height: 1.6)),
        const SizedBox(height: 14),
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: lines[i].length < 2
                ? VerseLines(lines[i], size: 24)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(Store.i.show(lines[i][0]), style: TextStyle(fontFamily: verseFont, fontSize: 24 * Store.i.fontScale, height: 1.9)),
                    GestureDetector(
                      onTap: () => setState(() => shown.contains(i) ? shown.remove(i) : shown.add(i)),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 38),
                        child: shown.contains(i)
                            ? Text(Store.i.show(lines[i][1]), style: TextStyle(fontFamily: verseFont, fontSize: 24 * Store.i.fontScale, height: 1.9, color: C.accent(context)))
                            : Container(
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: C.soft(context), borderRadius: BorderRadius.circular(14)),
                                child: Text('اضغط لإظهار الشطر الثاني', style: TextStyle(color: C.muted(context))),
                              ),
                      ),
                    ),
                  ]),
          ),
        OutlinedButton(
          onPressed: () => setState(() => shown.length == lines.length ? shown.clear() : shown.addAll(List.generate(lines.length, (i) => i))),
          child: Text(shown.length == lines.length ? 'إخفاء الكل' : 'إظهار الكل'),
        ),
      ]),
    );
  }
}
