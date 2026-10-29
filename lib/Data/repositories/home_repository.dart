import 'package:shared_preferences/shared_preferences.dart';

/// What the dashboard remembers on the phone between launches. It holds no
/// user data: only the day the app was last opened, as a plain date.
class HomeRepository {
  static const String _lastOpenDayKey = 'home_last_open_day';

  /// The day the dashboard was last shown, as `yyyy-MM-dd`, or null.
  Future<String?> lastOpenDay() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOpenDayKey);
  }

  Future<void> setLastOpenDay(String day) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenDayKey, day);
  }
}
