import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user theme choice on device (light / dark / follow system).
class ThemePreferences extends ChangeNotifier {
  static const _prefKey = 'rc_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    _mode = _parse(raw) ?? ThemeMode.system;
    _loaded = true;
    notifyListeners();
  }

  /// Updates UI immediately; writes preference in the background.
  void setMode(ThemeMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_prefKey, _encode(value)),
    );
  }

  static ThemeMode? _parse(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  String get modeLabel {
    switch (_mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}