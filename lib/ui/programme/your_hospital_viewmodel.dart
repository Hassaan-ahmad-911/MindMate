import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/mood_repository.dart';
import '../../Data/repositories/wellbeing_programme_repository.dart';
import '../../Models/hospital_programme.dart';
import '../../Models/mood_model.dart';
import '../../Models/programme_schedule.dart';
import 'wellbeing_programme_controller.dart';

/// "Your hospital" in Settings: the hospital, the officer (never their
/// email), the required check-ins with their next dates, and past alerts.
class YourHospitalViewModel extends GetxController {
  YourHospitalViewModel(
    this._programme,
    this._repository,
    this._moods, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final WellbeingProgrammeController _programme;
  final WellbeingProgrammeRepository _repository;
  final MoodRepository _moods;
  final DateTime Function() _clock;

  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final Rxn<HospitalMembership> membership = Rxn<HospitalMembership>();
  final RxList<ScheduleOverviewRow> rows = <ScheduleOverviewRow>[].obs;
  final RxList<WellbeingAlert> alerts = <WellbeingAlert>[].obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final ProgrammeStatus? status = await _programme.loadStatus();
      if (status == null) {
        membership.value = await _programme.loadMembership();
        rows.clear();
      } else {
        membership.value = status.membership;
        final DateTime now = _clock();
        DateTime? lastMood;
        try {
          final List<MoodModel> recent = await _moods.getRecentWindow(now: now);
          lastMood = recent.isEmpty ? null : recent.first.date;
        } catch (_) {
          lastMood = null;
        }
        rows.assignAll(
          ProgrammeSchedule.overview(
            config: status.config,
            joinedAt: status.membership.joinedAt,
            lastDone: status.lastDone,
            lastMood: lastMood,
            now: now,
            scales: await _repository.getScales(),
          ),
        );
      }
    } catch (_) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
    try {
      alerts.assignAll(await _repository.getAlerts());
    } catch (_) {
      // The section stays hidden.
    }
  }

  DateTime get now => _clock();

  String joinedLine(HospitalMembership m) =>
      'Joined ${ProgrammeSchedule.fullDate(m.joinedAt)}';

  /// "12 Oct 2026: Dr. Sana Malik was asked to reach out".
  String alertLine(WellbeingAlert a) {
    final String officer = a.officerName.isEmpty
        ? 'Your wellbeing officer'
        : a.officerName;
    return '${ProgrammeSchedule.fullDate(a.sentAt)}: $officer was asked to '
        'reach out';
  }
}
