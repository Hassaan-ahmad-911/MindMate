import 'programme_schedule.dart';
import 'user_settings.dart';

/// What a reminder is for.
enum ReminderKind { mood, journal, practice, checkIns, merged, test }

/// One reminder in the plan. Times are local.
class PlannedReminder {
  const PlannedReminder({
    required this.at,
    required this.kind,
    this.assessmentIds = const <String>[],
    this.programme = false,
    this.parts = const <PlannedReminder>[],
  });

  final DateTime at;
  final ReminderKind kind;

  /// For [ReminderKind.checkIns]: the check-ins due that day.
  final List<String> assessmentIds;

  /// For [ReminderKind.checkIns]: from the hospital programme's schedule.
  final bool programme;

  /// For [ReminderKind.merged]: the reminders it stands for.
  final List<PlannedReminder> parts;

  /// What a tap opens (see `ReminderTargets`).
  String get payload {
    switch (kind) {
      case ReminderKind.mood:
        return ReminderTargets.mood;
      case ReminderKind.journal:
        return ReminderTargets.journal;
      case ReminderKind.practice:
        return ReminderTargets.practice;
      case ReminderKind.checkIns:
        if (!programme) {
          return ReminderTargets.hub;
        }
        final String? single = singleShortCheckIn;
        return single == null
            ? ReminderTargets.today
            : '${ReminderTargets.checkInPrefix}$single';
      case ReminderKind.merged:
        return ReminderTargets.today;
      case ReminderKind.test:
        return ReminderTargets.reminders;
    }
  }

  /// The 3-day check or the wellbeing check on its own, else null.
  String? get singleShortCheckIn {
    if (assessmentIds.length != 1) {
      return null;
    }
    final String id = assessmentIds.single;
    return id == 'phq4' || id == 'who5' ? id : null;
  }

  /// For the "Next reminder" card: "Mood check-in", "Practice", ...
  String get label {
    switch (kind) {
      case ReminderKind.mood:
        return 'Mood check-in';
      case ReminderKind.journal:
        return 'Journal prompt';
      case ReminderKind.practice:
        return 'Practice';
      case ReminderKind.checkIns:
        return switch (singleShortCheckIn) {
          'phq4' => '3-day check',
          'who5' => 'Wellbeing check',
          _ => 'Check-in',
        };
      case ReminderKind.merged:
        return parts.map((PlannedReminder p) => p.label).join(' and ');
      case ReminderKind.test:
        return 'Test reminder';
    }
  }
}

/// The payloads a reminder carries, and what each opens.
class ReminderTargets {
  const ReminderTargets._();

  static const String mood = 'mood';
  static const String journal = 'journal';
  static const String practice = 'practice';
  static const String today = 'today';
  static const String hub = 'hub';
  static const String reminders = 'reminders';
  static const String checkInPrefix = 'checkin:';
}

/// Everything the planner needs. Pure data: no Firebase, no plugin.
class ReminderInputs {
  const ReminderInputs({
    required this.settings,
    required this.now,
    this.moodDoneToday = false,
    this.journalDoneToday = false,
    this.practiceDoneToday = false,
    this.programme,
    this.joinedAt,
    this.lastDone = const <String, DateTime>{},
    this.retakeDays = const <String, int>{},
  });

  final ReminderSettings settings;
  final DateTime now;
  final bool moodDoneToday;
  final bool journalDoneToday;

  /// A meditation or a short break finished today.
  final bool practiceDoneToday;

  /// The hospital programme's schedule; null for someone not in one.
  final ProgrammeConfig? programme;
  final DateTime? joinedAt;

  /// The newest `completedAt` of each check-in.
  final Map<String, DateTime> lastDone;

  /// Each check-in's `retakeDays` (for people not in a programme).
  final Map<String, int> retakeDays;

  bool get inProgramme => programme != null && joinedAt != null;
}

/// The plan: every reminder kept after the rules ([singles], before merging,
/// for the Today page) and what is actually scheduled ([notifications]).
class ReminderPlan {
  const ReminderPlan({required this.singles, required this.notifications});

  static const ReminderPlan empty = ReminderPlan(
    singles: <PlannedReminder>[],
    notifications: <PlannedReminder>[],
  );

  final List<PlannedReminder> singles;
  final List<PlannedReminder> notifications;

  PlannedReminder? get next =>
      notifications.isEmpty ? null : notifications.first;
}

/// Builds the reminders for the next 14 days. All the rules live here.
///
/// 1. Mood, journal and practice at their times on each day, today's skipped
///    when it is already done.
/// 2. Check-ins due, at the mood time (19:00 when the mood reminder is off):
///    - in a hospital programme: on the day one falls due (first-week spread
///      included) and once more the next day;
///    - otherwise: on the day `retakeDays` comes round after the last result,
///      and once more 7 days later; never-taken ones get none.
///    Several on one day are one reminder.
/// 3. Days not chosen and quiet hours are skipped (never moved).
/// 4. Past ones are dropped, then reminders less than 60 minutes apart merge
///    into one at the earliest time, and the plan is capped at 60.
class ReminderPlanner {
  const ReminderPlanner._();

  static const int windowDays = 14;
  static const int cap = 60;
  static const Duration mergeWithin = Duration(minutes: 60);
  static const String checkInFallbackTime = '19:00';

  /// The programme's extra reminder, the day after a check-in falls due.
  static const int programmeRepeatAfter = 1;

  /// Outside a programme: one more reminder this many days after.
  static const int retakeRepeatAfter = 7;

  static ReminderPlan plan(ReminderInputs i) {
    final ReminderSettings s = i.settings;
    final DateTime today = ProgrammeSchedule.dayOf(i.now);
    final DateTime end = ProgrammeSchedule.addDays(today, windowDays);
    final List<PlannedReminder> all = <PlannedReminder>[];

    void daily(ReminderKind kind, ReminderSlot slot, bool doneToday) {
      final String? time = slot.time;
      if (!slot.on || time == null) {
        return;
      }
      for (int d = 0; d < windowDays; d += 1) {
        if (d == 0 && doneToday) {
          continue;
        }
        all.add(
          PlannedReminder(
            at: _at(ProgrammeSchedule.addDays(today, d), time),
            kind: kind,
          ),
        );
      }
    }

    daily(ReminderKind.mood, s.mood, i.moodDoneToday);
    daily(ReminderKind.journal, s.journal, i.journalDoneToday);
    daily(ReminderKind.practice, s.practice, i.practiceDoneToday);

    if (s.checkinsDue.on) {
      final String time = s.mood.on && s.mood.time != null
          ? s.mood.time!
          : checkInFallbackTime;
      final Map<DateTime, List<String>> byDay = <DateTime, List<String>>{};
      void remind(DateTime day, String id) {
        if (!day.isBefore(today) && day.isBefore(end)) {
          (byDay[day] ??= <String>[]).add(id);
        }
      }

      final ProgrammeConfig? config = i.programme;
      final DateTime? joinedAt = i.joinedAt;
      if (config != null && joinedAt != null) {
        for (final ProgrammeItem item in config.required) {
          final DateTime due = ProgrammeSchedule.dueDay(
            id: item.assessmentId,
            everyDays: item.everyDays,
            joinedAt: joinedAt,
            lastDone: i.lastDone[item.assessmentId],
          );
          remind(due, item.assessmentId);
          remind(
            ProgrammeSchedule.addDays(due, programmeRepeatAfter),
            item.assessmentId,
          );
        }
      } else {
        for (final MapEntry<String, DateTime> e in i.lastDone.entries) {
          final int? every = i.retakeDays[e.key];
          if (every == null || every < 1) {
            continue;
          }
          final DateTime due = ProgrammeSchedule.addDays(
            ProgrammeSchedule.dayOf(e.value),
            every,
          );
          remind(due, e.key);
          remind(ProgrammeSchedule.addDays(due, retakeRepeatAfter), e.key);
        }
      }
      final List<DateTime> days = byDay.keys.toList()..sort();
      for (final DateTime day in days) {
        all.add(
          PlannedReminder(
            at: _at(day, time),
            kind: ReminderKind.checkIns,
            assessmentIds: List<String>.unmodifiable(byDay[day]!),
            programme: i.inProgramme,
          ),
        );
      }
    }

    final List<PlannedReminder> kept =
        all
            .where(
              (PlannedReminder r) =>
                  s.days.contains(r.at.weekday) &&
                  !s.quietHours.covers(_hhmm(r.at)) &&
                  r.at.isAfter(i.now),
            )
            .toList()
          ..sort(
            (PlannedReminder a, PlannedReminder b) => a.at.compareTo(b.at),
          );

    return ReminderPlan(
      singles: List<PlannedReminder>.unmodifiable(kept),
      notifications: List<PlannedReminder>.unmodifiable(merge(kept).take(cap)),
    );
  }

  /// Reminders less than 60 minutes after the first of a group become one
  /// "A couple of gentle reminders" at the earliest time. [sorted] is in
  /// time order.
  static List<PlannedReminder> merge(List<PlannedReminder> sorted) {
    final List<PlannedReminder> out = <PlannedReminder>[];
    int i = 0;
    while (i < sorted.length) {
      final PlannedReminder first = sorted[i];
      final List<PlannedReminder> group = <PlannedReminder>[first];
      int j = i + 1;
      while (j < sorted.length &&
          sorted[j].at.difference(first.at) < mergeWithin) {
        group.add(sorted[j]);
        j += 1;
      }
      out.add(
        group.length == 1
            ? first
            : PlannedReminder(
                at: first.at,
                kind: ReminderKind.merged,
                parts: List<PlannedReminder>.unmodifiable(group),
              ),
      );
      i = j;
    }
    return out;
  }

  static DateTime _at(DateTime day, String hhmm) {
    final int m = SettingsTime.minutes(hhmm);
    return DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
  }

  static String _hhmm(DateTime t) => SettingsTime.format(t.hour, t.minute);
}

/// The exact words of every reminder. Never journal text, mood names,
/// scores, questionnaire names or anything about the user's health.
class ReminderWording {
  const ReminderWording._();

  static const String hiddenTitle = 'MindMate';
  static const String hiddenBody = 'You have a gentle reminder.';

  /// From this hour, mood says "tonight" and journal "Tonight's prompt".
  static const int eveningHour = 17;

  static ({String title, String body}) of(
    PlannedReminder r, {
    required bool hidden,
  }) {
    if (hidden) {
      return (title: hiddenTitle, body: hiddenBody);
    }
    final bool evening = r.at.hour >= eveningHour;
    switch (r.kind) {
      case ReminderKind.mood:
        return (
          title: evening
              ? 'How are you feeling tonight?'
              : 'How are you feeling today?',
          body: 'A quick check-in takes about 10 seconds.',
        );
      case ReminderKind.journal:
        return (
          title: 'A moment to write?',
          body: evening
              ? "Tonight's prompt is ready."
              : "Today's prompt is ready.",
        );
      case ReminderKind.practice:
        return (
          title: 'A calm minute?',
          body: 'A short practice is ready when you are.',
        );
      case ReminderKind.checkIns:
        if (!r.programme) {
          return (
            title: 'A short check-in is ready',
            body: 'A few minutes, whenever suits you.',
          );
        }
        return switch (r.singleShortCheckIn) {
          'phq4' => (
            title: 'Your 3-day check is ready',
            body: '4 questions, about 30 seconds.',
          ),
          'who5' => (
            title: 'A short wellbeing check is ready',
            body: '5 questions, about a minute.',
          ),
          _ => (
            title: 'Your check-in is ready',
            body: 'A few minutes, whenever suits you.',
          ),
        };
      case ReminderKind.merged:
        return (
          title: 'A couple of gentle reminders',
          body: "Open MindMate to see what's ready.",
        );
      case ReminderKind.test:
        return (
          title: 'This is a test reminder',
          body: 'Your reminders will look like this.',
        );
    }
  }

  /// "Today 20:00 · Mood check-in", "Tomorrow 07:30 · Practice",
  /// "Fri 20:00 · ..." within the week, else "3 Nov 20:00 · ...".
  static String nextLine(PlannedReminder r, DateTime now) {
    final DateTime today = ProgrammeSchedule.dayOf(now);
    final DateTime day = ProgrammeSchedule.dayOf(r.at);
    // Rounded, so a 23-hour day (clock change) still counts as one.
    final int days = (day.difference(today).inHours / 24).round();
    final String when = days <= 0
        ? 'Today'
        : days == 1
        ? 'Tomorrow'
        : days < 7
        ? ProgrammeSchedule.dueLabel(
            ScheduleOverviewRow(
              label: '',
              everyDays: 1,
              nextDue: day,
              doneToday: false,
            ),
            now,
          )
        : ProgrammeSchedule.dayMonth(day);
    final String label = r.kind == ReminderKind.merged
        ? 'A couple of reminders'
        : r.label;
    return '$when ${SettingsTime.format(r.at.hour, r.at.minute)} · $label';
  }
}
