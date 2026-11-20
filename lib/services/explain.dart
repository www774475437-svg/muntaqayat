import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// شرح البيت بالذكاء الاصطناعي عبر Firebase AI Logic (مزوّد Gemini Developer API).
/// يعمل على الخطة المجانية ما دام المشروع غير مرتبط بحساب الفوترة.
/// كل شرح يُعرض مع عبارة «شرح آلي تحت مراجعة المطوّر».
class Explain {
  static GenerativeModel? _model;

  static GenerativeModel get _m => _model ??= FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');

  static const _cacheKey = 'explainCache';

  static Future<Map<String, String>> _cache() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  /// A verse explained before, read from the device without calling the service.
  static Future<String?> saved(String key) async => (await _cache())[key];

  /// Returns the saved explanation when there is one; otherwise asks the service once and saves the answer.
  static Future<String?> verse(String key, List<String> line) async {
    final hit = await saved(key);
    if (hit != null) return hit;
    final out = await _ask(line);
    if (out != null) {
      final m = await _cache();
      m[key] = out;
      final p = await SharedPreferences.getInstance();
      await p.setString(_cacheKey, jsonEncode(m));
    }
    return out;
  }

  static Future<String?> _ask(List<String> line) async {
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
