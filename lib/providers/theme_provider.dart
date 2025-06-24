import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/default_theme.dart';

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
  
  // Constructor that initializes theme preference from shared preferences
  ThemeProvider() {
    _loadThemePreference();
  }
  
  // Load saved theme preference from shared preferences
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themePreferenceKey) ?? _systemThemeKey;
    
    setThemeMode(_getThemeModeFromString(themeString), notify: false);
  }
  
  // Save theme preference to shared preferences
  Future<void> _saveThemePreference(String themeString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePreferenceKey, themeString);
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
        // For now, we only have a light theme implemented
        // In the future, you can return a dark theme here
        return AppTheme.defaultTheme;
      case ThemeMode.system:
      default:
        // For now, we only have a light theme implemented
        // In the future, you can return dark theme based on system brightness
        return AppTheme.defaultTheme;
    }
  }
}