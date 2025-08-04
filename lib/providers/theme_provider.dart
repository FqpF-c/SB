import 'package:flutter/material.dart';
import '../theme/default_theme.dart';
import '../secure_storage.dart'; // ✅ Use secure storage instead of SharedPreferences

class ThemeProvider with ChangeNotifier {
  // Theme mode keys
  static const String _themePreferenceKey = 'theme_preference';
  static const String _lightThemeKey = 'light';
  static const String _darkThemeKey = 'dark';
  static const String _systemThemeKey = 'system';

  // Current theme mode
  ThemeMode _themeMode = ThemeMode.system;

  // Getter for the current theme mode
  ThemeMode get themeMode => _themeMode;

  // Getter for checking if dark mode is active
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Constructor that initializes theme preference from secure storage
  ThemeProvider() {
    _loadThemePreference();
  }

  // Load saved theme preference from secure storage
  Future<void> _loadThemePreference() async {
    final themeString = await SecureStorage.read(_themePreferenceKey) ?? _systemThemeKey;
    setThemeMode(_getThemeModeFromString(themeString), notify: false);
  }

  // Save theme preference to secure storage
  Future<void> _saveThemePreference(String themeString) async {
    await SecureStorage.write(_themePreferenceKey, themeString);
  }

  // Convert string to ThemeMode
  ThemeMode _getThemeModeFromString(String themeString) {
    switch (themeString) {
      case _lightThemeKey:
        return ThemeMode.light;
      case _darkThemeKey:
        return ThemeMode.dark;
      case _systemThemeKey:
      default:
        return ThemeMode.system;
    }
  }

  // Convert ThemeMode to string
  String _getStringFromThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _lightThemeKey;
      case ThemeMode.dark:
        return _darkThemeKey;
      case ThemeMode.system:
      default:
        return _systemThemeKey;
    }
  }

  // Set the theme mode
  void setThemeMode(ThemeMode mode, {bool notify = true}) {
    _themeMode = mode;
    _saveThemePreference(_getStringFromThemeMode(mode));

    if (notify) {
      notifyListeners();
    }
  }

  // Toggle between light and dark mode
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }

  // Set to light mode
  void setLightMode() {
    setThemeMode(ThemeMode.light);
  }

  // Set to dark mode
  void setDarkMode() {
    setThemeMode(ThemeMode.dark);
  }

  // Set to system mode
  void setSystemMode() {
    setThemeMode(ThemeMode.system);
  }

  // Get the active theme based on the current mode and system brightness
  ThemeData getActiveTheme(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;

    switch (_themeMode) {
      case ThemeMode.light:
        return AppTheme.defaultTheme;
      case ThemeMode.dark:
        return AppTheme.defaultTheme; // Replace with dark theme when implemented
      case ThemeMode.system:
      default:
        return AppTheme.defaultTheme; // Add brightness check when dark theme is ready
    }
  }
}
