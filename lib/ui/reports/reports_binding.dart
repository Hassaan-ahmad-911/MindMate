import 'package:get/get.dart';

import '../../Data/repositories/assessment_repository.dart';
import '../../Data/repositories/break_repository.dart';
import '../../Data/repositories/journal_repository.dart';
import '../../Data/repositories/meditation_repository.dart';
import '../../Data/repositories/mood_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../../Data/repositories/report_repository.dart';
import '../assessments/assessment_binding.dart';
import '../journal/journal_binding.dart';

/// Registers the [ReportRepository] over the other modules' repositories.
/// A module that is not registered is simply left out of the reports.
class ReportsBinding extends Bindings {
  @override
  void dependencies() {
    JournalBinding().dependencies();
    AssessmentBinding().dependencies();
    Get.lazyPut<ReportRepository>(
      () => ReportRepository(
        moods: _find<MoodRepository>(),
        meditation: _find<MeditationRepository>(),
        breaks: _find<BreakRepository>(),
        journal: _find<JournalRepository>(),
        assessments: _find<AssessmentRepository>(),
        profile: _find<ProfileRepository>(),
      ),
      fenix: true,
    );
  }

  static T? _find<T>() => Get.isRegistered<T>() ? Get.find<T>() : null;
}
