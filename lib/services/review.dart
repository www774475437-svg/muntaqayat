import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data.dart';

/// أبيات معلّقة للمراجعة: تُخفى عن القرّاء حتى يقرّر المطوّر نشرها أو حذفها.
/// الإخفاء والحذف يُحفظان في Store.i (يتزامنان مع السحابة كبقية الإخفاءات).
class Review {
  static List<Map<String, String>> items = [];
  static Map<String, String> decided = {};

  static Future<void> load() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/data/review.json')) as Map<String, dynamic>;
      items = [for (final x in j['items'] as List) Map<String, String>.from((x as Map).map((k, v) => MapEntry(k as String, '$v')))];
    } catch (_) {
      items = [];
    }
    final p = await SharedPreferences.getInstance();
    decided = Map<String, String>.from(jsonDecode(p.getString('reviewDecisions') ?? '{}') as Map);
  }

  static void _save() {
    SharedPreferences.getInstance().then((p) => p.setString('reviewDecisions', jsonEncode(decided)));
  }

  /// يُستدعى بعد تحميل المكتبة والإعدادات: يخفي كل بيت لم يُقرَّر بعد.
  static void applyPending() {
    for (final x in items) {
      final k = x['key']!;
      if (decided.containsKey(k)) continue;
      if (!Store.i.hidden.contains(k) && !Store.i.deleted.contains(k)) Store.i.setHidden(k, true);
    }
  }

  static List<Map<String, String>> get pending => [for (final x in items) if (!Store.i.deleted.contains(x['key']) && !decided.containsKey(x['key'])) x];

  static void publish(String key) {
    decided[key] = 'pub';
    _save();
    Store.i.setHidden(key, false);
  }

  static void hide(String key) {
    decided[key] = 'hide';
    _save();
    Store.i.setHidden(key, true);
  }

  static void delete(String key) {
    decided[key] = 'del';
    _save();
    Store.i.deleteForGood(key);
  }
}
