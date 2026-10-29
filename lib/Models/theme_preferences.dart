import 'package:flutter/material.dart';

/// What the user picked on the Theme screen.
enum AppThemeMode {
  light('light', 'Light'),
  dark('dark', 'Dark'),
  system('system', 'Match phone');

  const AppThemeMode(this.id, this.label);

  /// Stored on the phone.
  final String id;

  /// Shown on the Settings screen.
  final String label;

  static AppThemeMode fromId(String? id) {
    for (final AppThemeMode m in values) {
      if (m.id == id) {
        return m;
      }
    }
    return AppThemeMode.system;
  }
}

/// Decides Light or Dark. Pure, so every case can be tested.
class ThemeResolver {
  const ThemeResolver._();

  static const int sunsetHour = 19;
  static const int sunriseHour = 7;

  /// 19:00 up to (not including) 07:00.
  static bool isNight(DateTime now) =>
      now.hour >= sunsetHour || now.hour < sunriseHour;

  /// The mode handed to the app. "Dark after sunset" wins at night whatever
  /// the mode; otherwise the user's choice (system follows the phone).
  static ThemeMode effectiveMode(
    AppThemeMode mode, {
    required bool darkAfterSunset,
    required DateTime now,
  }) {
    if (darkAfterSunset && isNight(now)) {
      return ThemeMode.dark;
    }
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// What is on screen.
  static Brightness resolve(
    AppThemeMode mode, {
    required bool darkAfterSunset,
    required Brightness platform,
    required DateTime now,
  }) {
    switch (effectiveMode(mode, darkAfterSunset: darkAfterSunset, now: now)) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return platform;
    }
  }

  /// The next 07:00 or 19:00 after [now], when "Dark after sunset" flips.
  static DateTime nextBoundary(DateTime now) {
    final DateTime morning = DateTime(
      now.year,
      now.month,
      now.day,
      sunriseHour,
    );
    final DateTime evening = DateTime(now.year, now.month, now.day, sunsetHour);
    if (now.isBefore(morning)) {
      return morning;
    }
    if (now.isBefore(evening)) {
      return evening;
    }
    return DateTime(now.year, now.month, now.day + 1, sunriseHour);
  }

  /// The line at the bottom of the Theme screen.
  static String footer(
    AppThemeMode mode, {
    required bool darkAfterSunset,
    required Brightness platform,
    required DateTime now,
  }) {
    if (darkAfterSunset && isNight(now)) {
      return 'It is after 19:00, so MindMate is dark until 07:00.';
    }
    switch (mode) {
      case AppThemeMode.light:
        return 'MindMate stays light.';
      case AppThemeMode.dark:
        return 'MindMate stays dark.';
      case AppThemeMode.system:
        return platform == Brightness.dark
            ? 'Your phone is in dark mode, so MindMate is dark too.'
            : 'Your phone is in light mode, so MindMate is light too.';
    }
  }
}
