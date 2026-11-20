import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data.dart';

/// The morning «بيت الصباح» notification and the «بيت اليوم» widget.
class Device {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _first = 10, _days = 14, _evening = 40;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    await refresh();
  }

  /// The evening reminder of «بيت الذهب» and the three proverbs. Today's is
  /// left out once both are finished.
  static Future<void> _planEvening() async {
    try {
      for (var i = 0; i < _days; i++) {
        await _plugin.cancel(_evening + i);
      }
      final s = Store.i;
      if (!s.evening) return;
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      final now = DateTime.now();
      final run = s.majlis['goldenRun'];
      final goldenDone = run is Map && run['day'] == Store.today && run['done'] == true;
      var quizDone = false;
      try {
        final saved = jsonDecode((await SharedPreferences.getInstance()).getString('proverbQuiz') ?? '{}') as Map;
        final quizDay = DateTime(now.year, now.month, now.day).difference(DateTime(2026, 1, 1)).inDays;
        quizDone = saved['day'] == quizDay && !(saved['done'] as List).contains(0);
      } catch (_) {}
      for (var i = 0; i < _days; i++) {
        final at = DateTime(now.year, now.month, now.day + i, s.eveningHour, s.eveningMinute);
        if (!at.isAfter(now)) continue;
        if (i == 0 && goldenDone && quizDone) continue;
        await _plugin.zonedSchedule(
          _evening + i,
          'بيت الذهب بانتظارك',
          'بيت اليوم وأمثاله الثلاثة تنتهي بانتهاء اليوم.',
          tz.TZDateTime.from(at, tz.UTC),
          const NotificationDetails(
            android: AndroidNotificationDetails('golden_reminder', 'تذكير بيت الذهب',
                channelDescription: 'تذكير يومي ببيت الذهب وأمثال اليوم في الوقت الذي تختاره',
                importance: Importance.defaultImportance, priority: Priority.defaultPriority),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {}
  }

  /// Puts today's verse on the widget and plans the next two weeks of
  /// morning notifications (each day with that day's verse).
  static Future<void> refresh() async {
    try {
      final p = Library.poemOfDay();
      await HomeWidget.saveWidgetData<String>('verse', p.firstVerse.map(Ar.plain).join('\n'));
      await HomeWidget.saveWidgetData<String>('poet', p.poet);
      await HomeWidget.updateWidget(androidName: 'VerseWidgetProvider');
    } catch (_) {}
    if (!_ready) return;
    await _planEvening();
    try {
      for (var i = 0; i < _days; i++) {
        await _plugin.cancel(_first + i);
      }
      final s = Store.i;
      if (!s.morning) return;
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      final now = DateTime.now();
      for (var i = 0; i < _days; i++) {
        final day = DateTime(now.year, now.month, now.day + i, s.morningHour, s.morningMinute);
        if (!day.isAfter(now)) continue;
        final p = Library.poemOfDay(day);
        await _plugin.zonedSchedule(
          _first + i,
          'بيت الصباح — ${p.poet}',
          p.firstVerse.map(Ar.plain).join(' ... '),
          tz.TZDateTime.from(day, tz.UTC),
          const NotificationDetails(
            android: AndroidNotificationDetails('morning_verse', 'بيت الصباح',
                channelDescription: 'بيت من الشعر كل صباح في الوقت الذي تختاره',
                importance: Importance.defaultImportance, priority: Priority.defaultPriority),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {}
  }

  /// This build's number (set by the build workflow); 0 when unknown.
  static const build = int.fromEnvironment('BUILD');

  /// The number of the newest published build, when it is newer than this one.
  static final update = ValueNotifier<int?>(null);

  static Future<Object?> _get(String url) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final rq = await c.getUrl(Uri.parse(url));
      rq.headers.set('Accept', 'application/vnd.github+json');
      final rs = await rq.close();
      if (rs.statusCode != 200) return null;
      return jsonDecode(await rs.transform(utf8.decoder).join());
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }

  static const _api = 'https://api.github.com/repos/www774475437-svg/muntaqayat/releases';

  /// Looks once for a newer APK.
  static Future<void> checkUpdate() async {
    if (build == 0) return;
    final j = await _get('$_api/latest');
    if (j is! Map) return;
    final n = int.tryParse('${j['tag_name']}'.replaceAll(RegExp(r'[^0-9]'), ''));
    if (n != null && n > build) update.value = n;
  }

  /// (all APK downloads, downloads of the newest build, newest build number).
  static Future<(int, int, int)?> downloads() async {
    final j = await _get('$_api?per_page=100');
    if (j is! List) return null;
    var all = 0, last = 0, lastN = 0;
    for (final r in j) {
      final n = int.tryParse('${(r as Map)['tag_name']}'.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      var d = 0;
      for (final a in (r['assets'] as List? ?? [])) {
        d += ((a as Map)['download_count'] as num?)?.toInt() ?? 0;
      }
      all += d;
      if (n > lastN) {
        lastN = n;
        last = d;
      }
    }
    return (all, last, lastN);
  }

  static List<int>? zlib(List<int> data) => ZLibCodec(level: 6).encode(data);
}
