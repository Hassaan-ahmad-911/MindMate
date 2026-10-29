import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

import '../../Data/repositories/mood_repository.dart';
import '../../Models/mood_catalog.dart';
import '../../Models/mood_model.dart';
import '../../Models/mood_stats.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../shared/app_feedback.dart';
import 'mood_tracking_viewmodel.dart';

/// History: a month calendar plus all entries, 30 at a time.
class MoodHistoryViewModel extends GetxController {
  /// [initialDay] opens the calendar on that day's month with the day
  /// selected (used by Reports).
  MoodHistoryViewModel(this._moodRepository, {DateTime? initialDay}) {
    if (initialDay != null && !initialDay.isAfter(DateTime.now())) {
      visibleMonth.value = _monthOf(initialDay);
      selectedDay.value = MoodStats.dayOf(initialDay);
    }
  }

  final MoodRepository _moodRepository;

  static const int pageSize = 30;

  /// First day of the month shown in the calendar.
  final Rx<DateTime> visibleMonth = _monthOf(DateTime.now()).obs;

  /// Entries for every day visible in the calendar grid.
  final RxList<MoodModel> calendarEntries = <MoodModel>[].obs;
  final RxBool isCalendarLoading = false.obs;

  /// When set, the list shows only this day's entries.
  final Rxn<DateTime> selectedDay = Rxn<DateTime>();

  /// When set, the list shows only this group.
  final Rxn<MoodGroup> filter = Rxn<MoodGroup>();

  /// All entries loaded so far, newest first.
  final RxList<MoodModel> entries = <MoodModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxBool hasLoadError = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(refreshAll());
  }

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  bool get canGoToNextMonth =>
      visibleMonth.value.isBefore(_monthOf(DateTime.now()));

  /// Monday on or before the first of the visible month.
  DateTime get gridStart {
    final DateTime first = visibleMonth.value;
    return MoodStats.addDays(first, -(first.weekday - 1));
  }

  /// Number of calendar rows needed for the visible month.
  int get gridRows {
    final DateTime first = visibleMonth.value;
    final int daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    return ((first.weekday - 1 + daysInMonth) / 7).ceil();
  }

  /// Day group for each day in the calendar that has entries.
  Map<DateTime, MoodGroup> get calendarDayGroups {
    return MoodStats.dayScores(calendarEntries).map(
      (DateTime day, double score) =>
          MapEntry<DateTime, MoodGroup>(day, MoodStats.groupForDayScore(score)),
    );
  }

  /// Entries for the list below the calendar, after the day and group filter.
  List<MoodModel> get visibleEntries {
    final DateTime? day = selectedDay.value;
    final Iterable<MoodModel> source = day == null
        ? entries
        : calendarEntries.where(
            (MoodModel entry) => MoodStats.isSameDay(entry.date, day),
          );
    final MoodGroup? group = filter.value;
    return source
        .where((MoodModel entry) => group == null || entry.group == group)
        .toList(growable: false);
  }

  /// [visibleEntries] grouped by day, newest first.
  List<MoodDayEntries> get groupedEntries {
    final List<MoodDayEntries> groups = <MoodDayEntries>[];
    for (final MoodModel entry in visibleEntries) {
      final DateTime day = MoodStats.dayOf(entry.date);
      if (groups.isEmpty || groups.last.day != day) {
        groups.add(MoodDayEntries(day, <MoodModel>[]));
      }
      groups.last.entries.add(entry);
    }
    return groups;
  }

  Future<void> refreshAll() async {
    await Future.wait(<Future<void>>[_loadCalendar(), _loadFirstPage()]);
  }

  void previousMonth() {
    final DateTime month = visibleMonth.value;
    visibleMonth.value = DateTime(month.year, month.month - 1);
    selectedDay.value = null;
    unawaited(_loadCalendar());
  }

  void nextMonth() {
    if (!canGoToNextMonth) {
      return;
    }
    final DateTime month = visibleMonth.value;
    visibleMonth.value = DateTime(month.year, month.month + 1);
    selectedDay.value = null;
    unawaited(_loadCalendar());
  }

  /// Tapping the selected day again clears it.
  void selectDay(DateTime day) {
    if (day.isAfter(DateTime.now())) {
      return;
    }
    final DateTime? current = selectedDay.value;
    selectedDay.value = current != null && MoodStats.isSameDay(current, day)
        ? null
        : MoodStats.dayOf(day);
  }

  void clearSelectedDay() => selectedDay.value = null;

  void setFilter(MoodGroup? group) => filter.value = group;

  Future<void> loadMore() async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value) {
      return;
    }
    if (entries.isEmpty) {
      return;
    }

    isLoadingMore.value = true;
    try {
      final List<MoodModel> page = await _moodRepository.getMoodPage(
        before: entries.last.date,
        limit: pageSize,
      );
      entries.addAll(page);
      hasMore.value = page.length == pageSize;
    } catch (error) {
      showMindMateSnackBar('History', moodErrorMessage(error));
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<bool> updateNote(MoodModel entry, String note) async {
    final String trimmed = note.trim();
    try {
      await _moodRepository.updateMoodNote(entry.id, trimmed);
      final MoodModel updated = entry.copyWith(note: trimmed);
      _replace(entries, updated);
      _replace(calendarEntries, updated);
      if (Get.isRegistered<MoodTrackingViewModel>()) {
        Get.find<MoodTrackingViewModel>().replaceEntry(updated);
      }
      showMindMateSnackBar('Note saved', 'Your note was updated.');
      return true;
    } catch (error) {
      showMindMateSnackBar('Could not save note', moodErrorMessage(error));
      return false;
    }
  }

  Future<bool> deleteEntry(MoodModel entry) async {
    try {
      await _moodRepository.deleteMood(entry.id);
      entries.removeWhere((MoodModel item) => item.id == entry.id);
      calendarEntries.removeWhere((MoodModel item) => item.id == entry.id);
      if (Get.isRegistered<MoodTrackingViewModel>()) {
        Get.find<MoodTrackingViewModel>().removeEntry(entry.id);
      }
      if (Get.isRegistered<HomeViewModel>()) {
        unawaited(Get.find<HomeViewModel>().refreshQuiet());
      }
      showMindMateSnackBar('Entry deleted', 'The mood entry was removed.');
      return true;
    } catch (error) {
      showMindMateSnackBar('Could not delete', moodErrorMessage(error));
      return false;
    }
  }

  Future<void> _loadCalendar() async {
    if (Firebase.apps.isEmpty) {
      return;
    }
    final DateTime month = visibleMonth.value;
    final DateTime start = gridStart;
    final DateTime end = MoodStats.addDays(start, gridRows * 7);

    isCalendarLoading.value = true;
    try {
      final List<MoodModel> loaded = await _moodRepository.getMoodsBetween(
        start,
        end,
      );
      // Ignore a late answer for a month the user already left.
      if (visibleMonth.value == month) {
        calendarEntries.assignAll(loaded);
      }
    } catch (error) {
      showMindMateSnackBar('History', moodErrorMessage(error));
    } finally {
      isCalendarLoading.value = false;
    }
  }

  Future<void> _loadFirstPage() async {
    if (Firebase.apps.isEmpty) {
      hasMore.value = false;
      return;
    }

    isLoading.value = true;
    try {
      final List<MoodModel> page = await _moodRepository.getMoodPage(
        limit: pageSize,
      );
      entries.assignAll(page);
      hasMore.value = page.length == pageSize;
      hasLoadError.value = false;
    } catch (error) {
      hasLoadError.value = true;
      showMindMateSnackBar('History', moodErrorMessage(error));
    } finally {
      isLoading.value = false;
    }
  }

  void _replace(RxList<MoodModel> list, MoodModel updated) {
    final int index = list.indexWhere(
      (MoodModel item) => item.id == updated.id,
    );
    if (index >= 0) {
      list[index] = updated;
    }
  }
}

class MoodDayEntries {
  MoodDayEntries(this.day, this.entries);

  final DateTime day;
  final List<MoodModel> entries;
}
