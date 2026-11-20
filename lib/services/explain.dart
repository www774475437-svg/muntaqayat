import 'package:firebase_ai/firebase_ai.dart';

/// شرح البيت بالذكاء الاصطناعي عبر Firebase AI Logic (مزوّد Gemini Developer API).
/// يعمل على الخطة المجانية ما دام المشروع غير مرتبط بحساب الفوترة.
/// كل شرح يُعرض مع عبارة «شرح آلي تحت مراجعة المطوّر».
class Explain {
  static GenerativeModel? _model;

  static GenerativeModel get _m => _model ??= FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');

  /// Returns the explanation in Arabic, or null when the service fails.
  static Future<String?> verse(List<String> line) async {
    final text = line.where((h) => h.trim().isNotEmpty).join(' ... ');
    if (text.isEmpty) return null;
    final prompt = 'اشرح هذا البيت من الشعر العربي شرحاً موجزاً للقارئ العادي: معنى المفردات الصعبة، والمقصود من البيت. '
        'اكتب بالعربية الفصحى في أربعة أسطر كحد أقصى، ولا تذكر اسم الشاعر ولا تنسب البيت إلى قصيدة.\n\nالبيت: $text';
    try {
      final r = await _m.generateContent([Content.text(prompt)]);
      final out = r.text?.trim();
      return (out == null || out.isEmpty) ? null : out;
    } catch (_) {
      return null;
    }
  }
}
