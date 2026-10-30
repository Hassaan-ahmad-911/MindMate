import '../../Models/assessment_definition.dart';
import '../../Models/break_log.dart';
import '../../Models/hospital_programme.dart';
import '../../Models/meditation_log_entry.dart';
import '../../Models/mood_model.dart';
import '../../Models/programme_schedule.dart';
import '../../Models/reminder_plan.dart';
import '../../Models/user_settings.dart';
import '../../services/reminder_local_store.dart';
import 'assessment_repository.dart';
import 'auth_repository.dart';
import 'break_repository.dart';
import 'journal_repository.dart';
import 'meditation_repository.dart';
import 'mood_repository.dart';
import 'settings_repository.dart';
import 'wellbeing_programme_repository.dart';

/// Everything the reminders and the Today page are built from, read once
/// per rebuild.
class ReminderSnapshot {
  const ReminderSnapshot({
    required this.inputs,
    this.hideText = false,
    this.programmeRows,
    this.checkInsDue = const <String, String>{},
    this.questionCounts = const <String, int>{},
    this.moodLoggedAt,
    this.practiceDoneLine,
  });

  final ReminderInputs inputs;
  final bool hideText;

  /// `ProgrammeSchedule.today` for someone in a hospital, else null.
  final List<ScheduleRow>? programmeRows;

  /// People not in a programme: check-ins due again, id -> name.
  final Map<String, String> checkInsDue;
  final Map<String, int> questionCounts;
  final DateTime? moodLoggedAt;

  /// "Leaving work at work · 8 min".
  final String? practiceDoneLine;
}

/// Reads what the reminders need from the other modules. Never writes.
class ReminderRepository {
  ReminderRepository({
    required AuthRepository auth,
    required SettingsRepository settings,
    required MoodRepository moods,
    required MeditationRepository meditation,
    required BreakRepository breaks,
    required AssessmentRepository assessments,
    required WellbeingProgrammeRepository programme,
    required JournalRepository Function() journal,
    ReminderLocalStore? local,
  }) : _auth = auth,
       _settings = settings,
       _moods = moods,
       _meditation = meditation,
       _breaks = breaks,
       _assessments = assessments,
       _programme = programme,
       _journal = journal,
       _local = local ?? ReminderLocalStore();

  final AuthRepository _auth;
  final SettingsRepository _settings;
  final MoodRepository _moods;
  final MeditationRepository _meditation;
  final BreakRepository _breaks;
  final AssessmentRepository _assessments;
  final WellbeingProgrammeRepository _programme;
  final JournalRepository Function() _journal;
  final ReminderLocalStore _local;

  bool get signedIn => _auth.currentUser != null;

  Future<bool> permissionAsked() => _local.permissionAsked();

  Future<void> setPermissionAsked() => _local.setPermissionAsked();

  Future<bool> permissionPageShown() => _local.permissionPageShown();

  Future<void> setPermissionPageShown() => _local.setPermissionPageShown();

  /// Each part is read on its own; a part that fails counts as "nothing".
  Future<ReminderSnapshot> load(DateTime now) async {
    final UserSettings settings = await _settings.load();
    final DateTime today = ProgrammeSchedule.dayOf(now);
    final DateTime tomorrow = ProgrammeSchedule.addDays(today, 1);

    Future<T> safe<T>(Future<T> Function() read, T fallback) async {
      try {
        return await read();
      } catch (_) {
        return fallback;
      }
    }

    final List<MoodModel> moods = await safe(
      () => _moods.getMoodsBetween(today, tomorrow),
      const <MoodModel>[],
    );
    final bool journalToday = await safe(
      () async =>
          (await _journal().getEntriesBetween(today, tomorrow)).isNotEmpty,
      false,
    );
    final List<MeditationLogEntry> practices = (await safe(
      () => _meditation.getLogsBetween(today, tomorrow),
      const <MeditationLogEntry>[],
    )).where((MeditationLogEntry e) => e.completed).toList();
    final List<BreakLogEntry> breaks = (await safe(
      () => _breaks.getBreaksBetween(today, tomorrow),
      const <BreakLogEntry>[],
    )).where((BreakLogEntry e) => e.completed).toList();

    final HospitalMembership? member = await safe(
      _programme.getMembership,
      null,
    );
    final ProgrammeConfig? config = member == null
        ? null
        : await safe(_programme.getConfig, null);
    final Map<String, DateTime> lastDone = await safe(
      _programme.getLastDone,
      const <String, DateTime>{},
    );
    final AssessmentContent? content = await safe<AssessmentContent?>(
      _assessments.loadContent,
      null,
    );

    DateTime? moodAt;
    for (final MoodModel m in moods) {
      if (moodAt == null || m.date.isAfter(moodAt)) {
        moodAt = m.date;
      }
    }

    String? practiceLine;
    if (practices.isNotEmpty) {
      final MeditationLogEntry last = practices.reduce(
        (MeditationLogEntry a, MeditationLogEntry b) =>
            b.endedAt.isAfter(a.endedAt) ? b : a,
      );
      final int minutes = (last.secondsPractised / 60).round();
      practiceLine = minutes > 0 ? '${last.title} · $minutes min' : last.title;
    } else if (breaks.isNotEmpty) {
      practiceLine = 'A short break';
    }

    final Map<String, int> retakeDays = <String, int>{
      for (final AssessmentDefinition d
          in content?.assessments ?? const <AssessmentDefinition>[])
        d.id: d.retakeDays,
    };
    final ReminderInputs inputs = ReminderInputs(
      settings: settings.reminders,
      now: now,
      moodDoneToday: moodAt != null,
      journalDoneToday: journalToday,
      practiceDoneToday: practices.isNotEmpty || breaks.isNotEmpty,
      programme: config,
      joinedAt: config == null ? null : member?.joinedAt,
      lastDone: lastDone,
      retakeDays: retakeDays,
    );

    // People not in a programme: the check-ins whose retake day has come.
    final Map<String, String> due = <String, String>{};
    if (!inputs.inProgramme && content != null) {
      for (final MapEntry<String, DateTime> e in lastDone.entries) {
        final AssessmentDefinition? def = content.byId(e.key);
        if (def == null) {
          continue;
        }
        final DateTime dueDay = ProgrammeSchedule.addDays(
          ProgrammeSchedule.dayOf(e.value),
          def.retakeDays,
        );
        if (!dueDay.isAfter(today)) {
          due[def.id] = def.checkTitle;
        }
      }
    }

    return ReminderSnapshot(
      inputs: inputs,
      hideText: settings.hideReminderText,
      programmeRows: inputs.inProgramme
          ? ProgrammeSchedule.today(
              config: config!,
              joinedAt: inputs.joinedAt!,
              lastDone: lastDone,
              lastMood: moodAt,
              now: now,
            )
          : null,
      checkInsDue: due,
      questionCounts: <String, int>{
        for (final AssessmentDefinition d
            in content?.assessments ?? const <AssessmentDefinition>[])
          d.id: d.items.length,
      },
      moodLoggedAt: moodAt,
      practiceDoneLine: practiceLine,
    );
  }
}
