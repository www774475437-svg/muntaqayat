import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data.dart';

/// The morning «بيت الصباح» notification and the «بيت اليوم» widget.
class Device {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _first = 10, _days = 14;

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
}
