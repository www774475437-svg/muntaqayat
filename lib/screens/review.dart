import 'package:flutter/material.dart';

import '../services/review.dart';
import '../ui.dart';

/// خانة المراجعة للمطوّر فقط: الأبيات المعلّقة، وكل بيت له نشر أو إخفاء أو حذف.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  Widget build(BuildContext context) {
    final list = Review.pending;
    return Scaffold(
      appBar: AppBar(title: Text('مراجعة الأبيات (${list.length})')),
      body: list.isEmpty
          ? const Center(child: Text('لا توجد أبيات تنتظر المراجعة'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final x = list[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('القصيدة ${x['poem']} — البيت ${x['verse']}', style: TextStyle(color: C.muted(context))),
                      const SizedBox(height: 6),
                      Text(x['text']!, style: const TextStyle(fontSize: 17, height: 1.8)),
                      const SizedBox(height: 6),
                      Text('سبب المراجعة: ${x['reason']}', style: TextStyle(color: C.accent(context))),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: FilledButton(onPressed: () => setState(() => Review.publish(x['key']!)), child: const Text('نشر'))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(onPressed: () => setState(() => Review.hide(x['key']!)), child: const Text('إخفاء'))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(onPressed: () => setState(() => Review.delete(x['key']!)), child: const Text('حذف'))),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
