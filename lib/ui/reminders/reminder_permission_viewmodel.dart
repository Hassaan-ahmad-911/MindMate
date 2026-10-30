import 'package:get/get.dart';

import '../app/app_routes.dart';
import 'reminder_controller.dart';

/// "Gentle reminders": ask for notification permission, or not now. Either
/// way the page is not shown again, and Home comes next.
class ReminderPermissionViewModel extends GetxController {
  ReminderPermissionViewModel(
    this._reminders, {
    this.fromHome = false,
    void Function()? leave,
  }) : _leave = leave;

  final ReminderController _reminders;

  /// Opened over Home (existing users) rather than at the end of setup.
  final bool fromHome;
  final void Function()? _leave;

  final RxBool isAsking = false.obs;

  /// "Turn on reminders": the phone's own question, then Home whatever the
  /// answer.
  Future<void> turnOn() async {
    if (isAsking.value) {
      return;
    }
    isAsking.value = true;
    await _reminders.markPermissionPageShown();
    await _reminders.requestPermission();
    isAsking.value = false;
    _goOn();
  }

  /// "Not now": Home without asking.
  Future<void> notNow() async {
    await _reminders.markPermissionPageShown();
    _goOn();
  }

  void _goOn() {
    final void Function()? leave = _leave;
    if (leave != null) {
      leave();
    } else if (fromHome) {
      Get.back<void>();
    } else {
      Get.offAllNamed<void>(AppRoutes.home);
    }
  }
}
