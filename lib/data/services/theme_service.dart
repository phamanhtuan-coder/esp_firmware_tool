import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const _themeKey = 'app_theme_mode';
  final SharedPreferences _prefs;

  ThemeService(this._prefs);

  Future<bool> isDarkMode() async {
    return _prefs.getBool(_themeKey) ?? false;
  }

  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(_themeKey, isDark);
  }
}
