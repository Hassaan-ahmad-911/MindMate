import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/meditation_repository.dart';
import '../../Data/repositories/mood_repository.dart';
import '../../Models/meditation_log_entry.dart';
import '../../Models/meditation_models.dart';
import '../../Models/meditation_stats.dart';
import '../../Models/meditation_suggester.dart';
import '../../Models/mood_model.dart';
import '../../Models/mood_stats.dart';
import '../app/app_routes.dart';

/// The meditation library: this week's numbers, a suggested practice, and the
/// list of practices with its filters.
class MeditationViewModel extends GetxController {
  /// [clock] gives the current time; tests pass their own.
  MeditationViewModel(
    this._repository,
    this._moodRepository, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MeditationRepository _repository;
  final MoodRepository _moodRepository;
  final DateTime Function() _clock;

  final RxBool isLoading = true.obs;
  final RxBool hasLoadError = false.obs;
  final RxList<MeditationGroup> groups = <MeditationGroup>[].obs;
  final RxList<MeditationSession> sessions = <MeditationSession>[].obs;

  /// The group the list is filtered to. Null means "All".
  final RxnString selectedGroupId = RxnString();

  /// Practices from the last 90 days, newest first.
  final RxList<MeditationLogEntry> logs = <MeditationLogEntry>[].obs;

  /// False until the history has loaded, so the tiles do not show a
  /// misleading 0.
  final RxBool statsLoaded = false.obs;

  /// Null until everything the suggestion depends on has loaded.
  final Rxn<MeditationSuggestion> suggestion = Rxn<MeditationSuggestion>();

  MoodModel? _latestMoodToday;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  int get minutesThisWeek =>
      MeditationStats.minutesThisWeek(logs, now: _clock());

  int get sessionsThisWeek =>
      MeditationStats.sessionsThisWeek(logs, now: _clock());

  int get streak => MeditationStats.streak(logs, now: _clock());

  /// The practices for the selected filter, in list order.
  List<MeditationSession> get visibleSessions {
    final String? groupId = selectedGroupId.value;
    if (groupId == null) {
      return sessions.toList(growable: false);
    }
    return sessions
        .where((MeditationSession session) => session.groupId == groupId)
        .toList(growable: false);
  }

  /// The title of the group a practice belongs to.
  String groupTitleFor(MeditationSession session) {
    for (final MeditationGroup group in groups) {
      if (group.id == session.groupId) {
        return group.title;
      }
    }
    return '';
  }

  void selectGroup(String? groupId) {
    selectedGroupId.value = groupId;
  }

  Future<void> load() async {
    isLoading.value = sessions.isEmpty;
    try {
      await _repository.loadContent();
      groups.assignAll(_repository.groups);
      sessions.assignAll(_repository.sessions);
      hasLoadError.value = false;
    } catch (_) {
      hasLoadError.value = true;
      isLoading.value = false;
      return;
    }
    isLoading.value = false;

    await Future.wait(<Future<void>>[_loadLogs(), _loadLatestMoodToday()]);
    _updateSuggestion();
  }

  void openSession(MeditationSession session) {
    Get.toNamed(AppRoutes.meditationDetails, arguments: session.id);
  }

  void openSuggestion() {
    final MeditationSuggestion? current = suggestion.value;
    if (current != null) {
      openSession(current.session);
    }
  }

  /// Called when a practice has just been saved (or its feeling updated), so
  /// the numbers are right before the history is loaded again.
  void recordLog(MeditationLogEntry entry) {
    final int index = logs.indexWhere(
      (MeditationLogEntry log) => log.id == entry.id,
    );
    if (index >= 0) {
      logs[index] = entry;
    } else {
      logs.insert(0, entry);
    }
    _updateSuggestion();
  }

  Future<void> _loadLogs() async {
    try {
      logs.assignAll(await _repository.getRecentLogs(now: _clock()));
      statsLoaded.value = true;
    } catch (_) {
      // The tiles keep showing a dash.
    }
  }

  Future<void> _loadLatestMoodToday() async {
    try {
      final DateTime today = MoodStats.dayOf(_clock());
      final List<MoodModel> moods = await _moodRepository.getMoodsBetween(
        today,
        MoodStats.addDays(today, 1),
      );
      // Newest first.
      _latestMoodToday = moods.isEmpty ? null : moods.first;
    } catch (_) {
      // Without the mood, the suggestion falls back to the time of day.
      _latestMoodToday = null;
    }
  }

  void _updateSuggestion() {
    suggestion.value = MeditationSuggester.suggest(
      sessions: sessions.toList(growable: false),
      now: _clock(),
      completedCounts: MeditationStats.completedCounts(logs),
      latestMoodToday: _latestMoodToday,
    );
  }
}
