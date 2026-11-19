import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../services/cloud.dart';
import 'cloud_ui.dart';
import '../ui.dart';

void soonSheet(BuildContext context, String title, String text) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(fontSize: 17, height: 1.7)),
      ]),
    ),
  );
}

/// The small «منتقيات+» chip at the top of «اليوم».
class PlusChip extends StatelessWidget {
  const PlusChip({super.key});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.bar(context),
      borderRadius: BorderRadius.circular(30),
      elevation: 3,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PlusScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, color: C.accent(context), size: 20),
            const SizedBox(width: 6),
            Text('منتقيات+', style: TextStyle(fontFamily: verseFont, fontSize: 19, fontWeight: FontWeight.w700, color: C.accent(context))),
          ]),
        ),
      ),
    );
  }
}

class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key});
  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  int plan = 1;

  @override
  Widget build(BuildContext context) {
    final features = [
      (Icons.manage_search_rounded, 'من قائل هذا البيت؟', 'الصق بيتاً أو قصيدة فيُعرف قائلها بدقة مع المصدر'),
      (Icons.menu_book_rounded, 'الشروح الكاملة', 'شرح الأبيات من كتب الشُّرّاح ومعاجم اللغة، مع المصدر والصفحة'),
      (Icons.school_outlined, 'اختبارات بلا حد للمعلّم', 'اختبر طلابك كل يوم ما شئت، والمجاني اختبار واحد في اليوم'),
      (Icons.mark_email_unread_outlined, 'راسل المطوّر', 'عشرون رسالة في اليوم، والمجاني رسالة واحدة'),
      (Icons.palette_outlined, 'ألوان حصرية لبطاقات الأبيات', 'ليل، وزمرد، وعقيق، وألوان أخرى'),
      (Icons.folder_copy_outlined, 'مجموعات بلا حد', 'أنشئ من المجموعات ما تشاء'),
      (Icons.favorite_rounded, 'إثراء الديوان', 'اشتراكك يدعم توثيق النصوص وتصحيح نسبتها وإضافة شعراء جدد'),
    ];
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        Icon(Icons.workspace_premium_rounded, size: 46, color: C.accent(context)),
        Center(child: Text('منتقيات+', style: TextStyle(fontFamily: verseFont, fontSize: 44, fontWeight: FontWeight.w700, color: C.ink(context)))),
        const SizedBox(height: 14),
        for (final f in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              RoundIcon(f.$1, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.$2, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.ink(context))),
                  Text(f.$3, style: TextStyle(fontSize: 14.5, color: C.muted(context), height: 1.5)),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Row(children: [
          _plan(context, 0, 'شهري', 'قريباً', 'في الشهر'),
          const SizedBox(width: 12),
          _plan(context, 1, 'سنوي', 'قريباً', 'في السنة'),
        ]),
        const SizedBox(height: 12),
        const BookDesignCard(),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: () => soonSheet(context, 'قريباً بإذن الله', 'الاشتراك والدفع من داخل المتجر يُفتحان في تحديث قادم. شكراً لدعمك.\n\nلا إعلانات في التطبيق أبداً.'),
          child: const Text('اشترك', style: TextStyle(fontSize: 18)),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ليس الآن', style: TextStyle(fontSize: 16))),
      ]),
    );
  }

  Widget _plan(BuildContext context, int i, String name, String price, String per) {
    final on = plan == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => plan = i),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: on ? C.soft(context) : C.card(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: on ? C.accent(context) : C.line(context), width: on ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
            const SizedBox(height: 6),
            Text(price, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: on ? C.accent(context) : C.ink(context))),
            Text(per, style: TextStyle(fontSize: 14, color: C.muted(context))),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: on ? C.accent(context) : C.muted(context)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Paid book design: the buyer pays $20 per design, then the developer
/// talks with him inside the app and designs the book by hand.
class BookDesignCard extends StatelessWidget {
  const BookDesignCard({super.key});
  @override
  Widget build(BuildContext context) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const RoundIcon(Icons.auto_stories_rounded, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('تصميم كتاب باسمك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
                Text('التصميم الواحد: ٢٠ دولاراً', style: TextStyle(fontSize: 14.5, color: C.accent(context), fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Text('تدفع، ثم يتواصل معك المطوّر داخل التطبيق (أو تترك رقمك)، ويصمّم لك الكتاب بيده بأبياتك واسمك.',
              style: TextStyle(fontSize: 14.5, color: C.muted(context), height: 1.6)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DesignPreviewScreen())),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('اضغط هنا للمعاينة'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                // Until the payment link is added, the button opens the preview.
                onPressed: () async {
                  final link = Store.i.payLink;
                  if (link.isEmpty) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DesignPreviewScreen(fromPay: true)));
                    return;
                  }
                  if (!await needAccount(context, 'ليتواصل معك المطوّر بعد الدفع.')) return;
                  await Cloud.i.orderDesign('طلب تصميم كتاب');
                  launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('اطلب التصميم'),
              ),
            ),
          ]),
        ]),
      );
}

class DesignPreviewScreen extends StatelessWidget {
  final bool fromPay;
  const DesignPreviewScreen({super.key, this.fromPay = false});

  @override
  Widget build(BuildContext context) {
    final sample = Library.poems.firstWhere((p) => p.lines.length >= 3, orElse: () => Library.poems.first);
    final styles = [
      ('كلاسيكي', const Color(0xFF2B2520), const Color(0xFFB08A3E)),
      ('عقيقي', const Color(0xFF8C4A2F), const Color(0xFFF7F4EE)),
      ('زمرّدي', const Color(0xFF1F4D3E), const Color(0xFFE8D9A8)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('معاينة تصميم الكتاب')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        if (fromPay)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.soft(context), borderRadius: BorderRadius.circular(14)),
            child: const Text('الدفع يُفتح قريباً بإذن الله. هذه نماذج التصميم حتى ذلك الحين.'),
          ),
        Text('نماذج الأغلفة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 10),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: styles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _cover(styles[i].$1, styles[i].$2, styles[i].$3),
          ),
        ),
        const SizedBox(height: 18),
        Text('نموذج صفحة داخلية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: const Color(0xFFFBF7EE), border: Border.all(color: const Color(0xFFB08A3E)), borderRadius: BorderRadius.circular(6)),
          child: Column(children: [
            Text(sample.chapterName, style: const TextStyle(fontFamily: verseFont, fontSize: 20, color: Color(0xFF8C4A2F), fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(sample.poet, style: const TextStyle(fontSize: 14, color: Color(0xFF6E655C))),
            const SizedBox(height: 10),
            for (final l in sample.lines.take(4)) VerseLines(l, size: 19, color: const Color(0xFF2B2520)),
            const SizedBox(height: 8),
            const Text('— ١٢ —', style: TextStyle(color: Color(0xFF6E655C))),
          ]),
        ),
        const SizedBox(height: 18),
        Text('الخيارات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context))),
        for (final o in const [
          ('المقاس', 'A5 للطباعة، أو A4، أو مقاس الجوال'),
          ('الغلاف', 'كلاسيكي، عقيقي، زمرّدي، أو تصميم خاص'),
          ('الخط', 'أميري، أو نسخ، أو خط تختاره'),
          ('المحتوى', 'أبياتك من مجموعاتك، مرتبة على الأبواب أو الشعراء'),
          ('اسمك', 'على الغلاف وصفحة الإهداء'),
        ])
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle_outline_rounded), title: Text(o.$1), subtitle: Text(o.$2)),
        Text('تُضاف نماذج أخرى من كتاب «منتقيات الشعر» وغيره قريباً.', style: TextStyle(color: C.muted(context))),
      ]),
    );
  }

  Widget _cover(String name, Color bg, Color fg) => Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 4))]),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: fg.withValues(alpha: 0.8))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.local_florist_outlined, color: fg),
            const SizedBox(height: 8),
            Text('منتقيات\nشعرية', textAlign: TextAlign.center, style: TextStyle(fontFamily: verseFont, fontSize: 26, height: 1.2, color: fg, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('جمع: اسمك هنا', style: TextStyle(fontSize: 12, color: fg)),
            const SizedBox(height: 14),
            Text(name, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.8))),
          ]),
        ),
      );
}
