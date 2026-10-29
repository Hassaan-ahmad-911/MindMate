import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/break_log.dart';
import '../../Models/journal_model.dart';
import '../../Models/meditation_log_entry.dart';
import '../../Models/mood_model.dart';
import '../../Models/user_profile.dart';
import 'assessment_repository.dart';
import 'break_repository.dart';
import 'journal_repository.dart';
import 'meditation_repository.dart';
import 'mood_repository.dart';
import 'profile_repository.dart';

/// The data sources a report reads.
enum ReportSource { moods, practice, journal, breaks, checkIns }

/// What one source gave for a time range: its items, or that it failed, or
/// that the module is not in the app (then it is left out of the reports).
class SourceResult<T> {
  const SourceResult.loaded(List<T> this.items)
    : failed = false,
      available = true;

  const SourceResult.failed() : items = null, failed = true, available = true;

  const SourceResult.missing()
    : items = null,
      failed = false,
      available = false;

  final List<T>? items;
  final bool failed;
  final bool available;

  bool get ok => items != null;
}

/// Reads, never writes. Everything goes through the other modules'
/// repositories; a null repository means that module is not built yet.
class ReportRepository {
  ReportRepository({
    MoodRepository? moods,
    MeditationRepository? meditation,
    BreakRepository? breaks,
    JournalRepository? journal,
    AssessmentRepository? assessments,
    ProfileRepository? profile,
  }) : _moods = moods,
       _meditation = meditation,
       _breaks = breaks,
       _journal = journal,
       _assessments = assessments,
       _profile = profile;

  final MoodRepository? _moods;
  final MeditationRepository? _meditation;
  final BreakRepository? _breaks;
  final JournalRepository? _journal;
  final AssessmentRepository? _assessments;
  final ProfileRepository? _profile;

  bool has(ReportSource source) {
    switch (source) {
      case ReportSource.moods:
        return _moods != null;
      case ReportSource.practice:
        return _meditation != null;
      case ReportSource.journal:
        return _journal != null;
      case ReportSource.breaks:
        return _breaks != null;
      case ReportSource.checkIns:
        return _assessments != null;
    }
  }

  static Future<SourceResult<T>> _load<T>(
    Object? repo,
    Future<List<T>> Function() read,
  ) async {
    if (repo == null) {
      return SourceResult<T>.missing();
    }
    try {
      return SourceResult<T>.loaded(await read());
    } catch (_) {
      return SourceResult<T>.failed();
    }
  }

  Future<SourceResult<MoodModel>> moods(DateTime start, DateTime end) =>
      _load(_moods, () => _moods!.getMoodsBetween(start, end));

  Future<SourceResult<MeditationLogEntry>> practice(
    DateTime start,
    DateTime end,
  ) => _load(_meditation, () => _meditation!.getLogsBetween(start, end));

  /// Title, tone, topics and date only: never the text.
  Future<SourceResult<JournalSummary>> journal(DateTime start, DateTime end) =>
      _load(_journal, () => _journal!.getEntriesBetween(start, end));

  Future<SourceResult<BreakLogEntry>> breaks(DateTime start, DateTime end) =>
      _load(_breaks, () => _breaks!.getBreaksBetween(start, end));

  /// Scores and ranges only: never the answers.
  Future<SourceResult<AssessmentSummary>> checkIns(
    DateTime start,
    DateTime end,
  ) => _load(_assessments, () => _assessments!.getResultsBetween(start, end));

  /// The newest result of each questionnaire in the range and the one before.
  Future<SourceResult<AssessmentLatest>> latestCheckIns(
    DateTime start,
    DateTime end,
  ) => _load(_assessments, () => _assessments!.getLatestBetween(start, end));

  Future<AssessmentContent?> checkInContent() async {
    try {
      return await _assessments?.loadContent();
    } catch (_) {
      return null;
    }
  }

  /// Name and role for the PDF header, or null if they cannot be read.
  Future<UserProfile?> profile() async {
    try {
      return await _profile?.getCurrentUserProfile();
    } catch (_) {
      return null;
    }
  }
}
