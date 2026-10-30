import 'dart:async';

import 'package:get/get.dart';

import '../../Models/programme_schedule.dart';
import '../../Models/today_items.dart';
import '../app/app_routes.dart';
import 'reminder_controller.dart';

/// "Today", from the Home bell: what is ready now, later today and done,
/// from the same data as the reminders.
class TodayViewModel extends GetxController {
  TodayViewModel(this._reminders, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ReminderController _reminders;
  final DateTime Function() _clock;

  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(reload());
  }

  Future<void> reload() async {
    isLoading.value = true;
    await _reminders.rebuildNow();
    isLoading.value = false;
  }

  TodaySections get sections => _reminders.today.value;

  static const List<String> _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// "Thursday 29 October".
  String get dateLine {
    final DateTime d = ProgrammeSchedule.dayOf(_clock());
    return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  /// "Start": the item's own screen; comes back here afterwards.
  Future<void> start(TodayItem item) async {
    await Get.toNamed<void>(ReminderController.routeFor(item.payload));
    unawaited(reload());
  }

  void openReminders() => Get.toNamed<void>(AppRoutes.settingsReminders);

  void openMeditation() => Get.toNamed<void>(AppRoutes.meditation);
}
