import 'package:shared_preferences/shared_preferences.dart';

/// What the reminders remember on this phone: whether MindMate has asked
/// for notification permission, and whether the "Gentle reminders" page was
/// shown. Both belong to the phone, not to an account. No user data.
class ReminderLocalStore {
  static const String _askedKey = 'reminders_permission_asked';
  static const String _pageShownKey = 'reminders_permission_page_shown';

  Future<bool> permissionAsked() async =>
      (await SharedPreferences.getInstance()).getBool(_askedKey) ?? false;

  Future<void> setPermissionAsked() async =>
      (await SharedPreferences.getInstance()).setBool(_askedKey, true);

  Future<bool> permissionPageShown() async =>
      (await SharedPreferences.getInstance()).getBool(_pageShownKey) ?? false;

  Future<void> setPermissionPageShown() async =>
      (await SharedPreferences.getInstance()).setBool(_pageShownKey, true);
}
