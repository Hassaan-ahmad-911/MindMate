import 'package:shared_preferences/shared_preferences.dart';

/// What the hospital programme remembers on this phone, per account: which
/// alerts were already shown, and the day the server last looked at the
/// user's check-ins. No health data.
class ProgrammeLocalStore {
  static String _seenKey(String uid) => 'programme_seen_alerts_$uid';

  static String _evaluatedKey(String uid) => 'programme_evaluated_day_$uid';

  Future<Set<String>> seenAlertIds(String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_seenKey(uid)) ?? const <String>[]).toSet();
  }

  Future<void> markAlertSeen(String uid, String alertId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> seen = prefs.getStringList(_seenKey(uid)) ?? <String>[];
    if (!seen.contains(alertId)) {
      // Keep the list short: older ids are past the window anyway.
      await prefs.setStringList(
        _seenKey(uid),
        <String>[...seen, alertId].reversed.take(50).toList().reversed.toList(),
      );
    }
  }

  /// The day of the last daily evaluation, as `yyyy-MM-dd`, or null.
  Future<String?> lastEvaluatedDay(String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_evaluatedKey(uid));
  }

  Future<void> setLastEvaluatedDay(String uid, String day) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_evaluatedKey(uid), day);
  }
}
