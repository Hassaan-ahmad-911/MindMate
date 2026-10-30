import 'programme_schedule.dart';
import 'reminder_plan.dart';
import 'user_settings.dart';

/// What a Today row is.
enum TodayKind { mood, journal, practice, checkIn }

/// One row on the Today page.
class TodayItem {
  const TodayItem({
    required this.kind,
    required this.title,
    required this.line,
    required this.payload,
    this.time,
  });

  final TodayKind kind;
  final String title;
  final String line;

  /// What "Start" opens (see [ReminderTargets]).
  final String payload;

  /// "21:30" for "Later today".
  final String? time;
}

/// The three sections of the Today page.
class TodaySections {
  const TodaySections({
    this.ready = const <TodayItem>[],
    this.later = const <TodayItem>[],
    this.done = const <TodayItem>[],
  });

  static const TodaySections empty = TodaySections();

  final List<TodayItem> ready;
  final List<TodayItem> later;
  final List<TodayItem> done;

  /// Nothing waiting: "Nothing waiting right now. Take a breath."
  bool get nothingWaiting => ready.isEmpty && later.isEmpty;
}

/// Builds the Today page from the same inputs as the reminders, plus what
/// was saved today. Pure.
class TodayBuilder {
  const TodayBuilder._();

  /// [programmeRows] are `ProgrammeSchedule.today` for someone in a
  /// hospital, else null. [checkInsDue] (people not in a programme) are the
  /// check-ins whose retake day has come: id -> name. [questionCounts] and
  /// the practice line fill in the details.
  static TodaySections build({
    required ReminderInputs inputs,
    List<ScheduleRow>? programmeRows,
    Map<String, String> checkInsDue = const <String, String>{},
    Map<String, int> questionCounts = const <String, int>{},
    DateTime? moodLoggedAt,
    String? practiceDoneLine,
  }) {
    final ReminderSettings s = inputs.settings;
    final DateTime now = inputs.now;
    final List<TodayItem> ready = <TodayItem>[];
    final List<TodayItem> later = <TodayItem>[];
    final List<TodayItem> done = <TodayItem>[];

    bool timePassed(String time) =>
        SettingsTime.minutes(time) <= now.hour * 60 + now.minute;

    // Mood: always on the list for hospital staff (one a day is asked for).
    if (inputs.moodDoneToday) {
      done.add(
        TodayItem(
          kind: TodayKind.mood,
          title: 'Mood check-in',
          line: moodLoggedAt == null
              ? 'Logged today'
              : 'Logged at ${_hhmm(moodLoggedAt)}',
          payload: ReminderTargets.mood,
        ),
      );
    } else if (inputs.inProgramme ||
        (s.mood.on && s.mood.time != null && timePassed(s.mood.time!))) {
      ready.add(
        const TodayItem(
          kind: TodayKind.mood,
          title: 'Mood check-in',
          line: 'About 10 seconds',
          payload: ReminderTargets.mood,
        ),
      );
    } else if (s.mood.on && s.mood.time != null) {
      later.add(
        TodayItem(
          kind: TodayKind.mood,
          title: 'Mood check-in',
          line: 'At ${s.mood.time}',
          payload: ReminderTargets.mood,
          time: s.mood.time,
        ),
      );
    }

    // The programme's check-ins, or the ones due again.
    for (final ScheduleRow row in programmeRows ?? const <ScheduleRow>[]) {
      if (row.isMood) {
        continue;
      }
      final String id = row.startId!;
      final int questions = row.assessmentIds.fold<int>(
        0,
        (int sum, String a) => sum + (questionCounts[a] ?? 0),
      );
      final TodayItem item = TodayItem(
        kind: TodayKind.checkIn,
        title: row.label,
        line: row.done
            ? 'Done today'
            : id == 'phq4' && row.assessmentIds.length == 1
            ? '$questions questions · about 30 seconds'
            : questions > 0
            ? '$questions questions'
            : 'A few minutes',
        payload: '${ReminderTargets.checkInPrefix}$id',
      );
      (row.done ? done : ready).add(item);
    }
    if (programmeRows == null) {
      for (final MapEntry<String, String> e in checkInsDue.entries) {
        final int questions = questionCounts[e.key] ?? 0;
        ready.add(
          TodayItem(
            kind: TodayKind.checkIn,
            title: e.value,
            line: questions > 0 ? '$questions questions' : 'A few minutes',
            payload: '${ReminderTargets.checkInPrefix}${e.key}',
          ),
        );
      }
    }

    void slot(
      TodayKind kind,
      ReminderSlot value,
      bool isDone,
      String title,
      String readyLine,
      String doneLine,
      String payload,
    ) {
      if (isDone) {
        done.add(
          TodayItem(kind: kind, title: title, line: doneLine, payload: payload),
        );
        return;
      }
      final String? time = value.time;
      if (!value.on || time == null) {
        return;
      }
      if (timePassed(time)) {
        ready.add(
          TodayItem(
            kind: kind,
            title: title,
            line: readyLine,
            payload: payload,
          ),
        );
      } else {
        later.add(
          TodayItem(
            kind: kind,
            title: title,
            line: 'At $time',
            payload: payload,
            time: time,
          ),
        );
      }
    }

    final bool evening = now.hour >= ReminderWording.eveningHour;
    slot(
      TodayKind.journal,
      s.journal,
      inputs.journalDoneToday,
      'Journal prompt',
      evening ? "Tonight's prompt" : "Today's prompt",
      'Written today',
      ReminderTargets.journal,
    );
    slot(
      TodayKind.practice,
      s.practice,
      inputs.practiceDoneToday,
      'Practice',
      'A short calm practice',
      practiceDoneLine ?? 'Done today',
      ReminderTargets.practice,
    );

    later.sort(
      (TodayItem a, TodayItem b) => SettingsTime.minutes(
        a.time!,
      ).compareTo(SettingsTime.minutes(b.time!)),
    );
    return TodaySections(ready: ready, later: later, done: done);
  }

  static String _hhmm(DateTime t) => SettingsTime.format(t.hour, t.minute);
}
