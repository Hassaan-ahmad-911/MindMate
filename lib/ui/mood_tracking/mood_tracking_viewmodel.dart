import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

import '../../Data/repositories/mood_repository.dart';
import '../../Models/mood_catalog.dart';
import '../../Models/mood_model.dart';
import '../../Models/mood_stats.dart';
import '../app/app_routes.dart';
import '../shared/app_feedback.dart';
import 'widgets/mood_visuals.dart';

/// Mood home (the Mood tab). Holds the last [MoodStats.historyWindowDays]
/// days of entries, which the log flow and History keep up to date.
class MoodTrackingViewModel extends GetxController {
  MoodTrackingViewModel(this._moodRepository);

  final MoodRepository _moodRepository;

  /// Newest first.
  final RxList<MoodModel> entries = <MoodModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasLoadError = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(loadMoods());
  }

  String get todayLabel => MoodFormat.longDate(DateTime.now());

  int get streak => MoodStats.streak(
    entries.map((MoodModel entry) => entry.date),
    now: DateTime.now(),
  );

  List<MoodModel> get recentEntries => entries.take(2).toList(growable: false);

  /// One summary per day for the last 7 days, oldest first.
  List<MoodDaySummary> get lastSevenDays {
    final DateTime today = MoodStats.dayOf(DateTime.now());
    final Map<DateTime, double> scores = MoodStats.dayScores(entries);

    return List<MoodDaySummary>.generate(7, (int index) {
      final DateTime day = MoodStats.addDays(today, index - 6);
      final double? score = scores[day];
      MoodModel? latest;
      for (final MoodModel entry in entries) {
        if (MoodStats.isSameDay(entry.date, day)) {
          latest = entry;
          break;
        }
      }
      return MoodDaySummary(
        day: day,
        group: score == null ? null : MoodStats.groupForDayScore(score),
        latestMood: latest?.mood,
        isToday: index == 6,
      );
    });
  }

  Future<void> loadMoods({bool showErrorSnackbar = false}) async {
    if (Firebase.apps.isEmpty) {
      entries.clear();
      return;
    }

    isLoading.value = true;
    try {
      entries.assignAll(await _moodRepository.getRecentWindow());
      hasLoadError.value = false;
    } catch (error) {
      hasLoadError.value = true;
      if (showErrorSnackbar) {
        showMindMateSnackBar('Mood', moodErrorMessage(error));
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Called after a new entry is saved.
  void addEntry(MoodModel entry) {
    entries.insert(0, entry);
  }

  void replaceEntry(MoodModel entry) {
    final int index = entries.indexWhere(
      (MoodModel item) => item.id == entry.id,
    );
    if (index >= 0) {
      entries[index] = entry;
    }
  }

  void removeEntry(String id) {
    entries.removeWhere((MoodModel item) => item.id == id);
  }

  void startLogging() => Get.toNamed(AppRoutes.moodLog);

  void openHistory() => Get.toNamed(AppRoutes.moodHistory);

  void openInsights() => Get.toNamed(AppRoutes.moodInsights);
}

class MoodDaySummary {
  const MoodDaySummary({
    required this.day,
    required this.group,
    required this.latestMood,
    required this.isToday,
  });

  final DateTime day;

  /// Null when nothing was logged that day.
  final MoodGroup? group;
  final String? latestMood;
  final bool isToday;
}

/// A short, friendly message for a mood loading or saving error.
String moodErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return 'Please sign in again to continue.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
        return 'You seem to be offline. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
