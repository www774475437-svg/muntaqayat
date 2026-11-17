import 'package:flutter/material.dart';

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
      (Icons.menu_book_rounded, 'الشروح الكاملة', 'شرح الأبيات من كتب الشُّرّاح ومعاجم اللغة، مع المصدر والصفحة'),
      (Icons.picture_as_pdf_outlined, 'كتابك باسمك', 'اجمع أبياتك في مجموعة، واختر تصميماً، فيُصنع لك كتاب PDF باسمك'),
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
        SoftCard(
          child: Row(children: [
            const RoundIcon(Icons.picture_as_pdf_rounded, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('كتاب PDF باسمك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
                Text('الكتاب الواحد: ٢٠ دولاراً', style: TextStyle(fontSize: 14.5, color: C.muted(context))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: () => soonSheet(context, 'قريباً بإذن الله', 'الاشتراك والدفع من داخل المتجر يُفتحان في تحديث قادم. شكراً لدعمك.'),
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
