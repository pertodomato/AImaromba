import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeService with ChangeNotifier {
  static const _box = 'app_prefs';
  static const _key = 'is_dark';

  bool _isDark = true;
  bool get isDark => _isDark;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_box)) {
      await Hive.openBox(_box);
    }
    final b = Hive.box(_box);
    _isDark = b.get(_key, defaultValue: true) as bool;
  }

  Future<void> setDark(bool value) async {
    _isDark = value;
    final b = Hive.box(_box);
    await b.put(_key, value);
    notifyListeners();
  }

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;
}
