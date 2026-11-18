import 'package:flutter/foundation.dart';

class Device {
  static Future<void> init() async {}
  static Future<void> refresh() async {}
  static const build = 0;
  static final update = ValueNotifier<int?>(null);
  static Future<void> checkUpdate() async {}
  static Future<(int, int, int)?> downloads() async => null;
}
