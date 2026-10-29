/// One check-in in the hospital programme's schedule.
class ProgrammeItem {
  const ProgrammeItem({
    required this.assessmentId,
    required this.everyDays,
    this.label = '',
  });

  final String assessmentId;
  final int everyDays;

  /// "3-day check", "Low mood", ... Empty for optional items.
  final String label;

  factory ProgrammeItem.fromMap(Map<String, dynamic> map) {
    final Object? id = map['assessmentId'];
    final Object? every = map['everyDays'];
    if (id is! String || id.isEmpty || every is! num || every < 1) {
      throw const FormatException('A programme item needs an id and days.');
    }
    final Object? label = map['label'];
    return ProgrammeItem(
      assessmentId: id,
      everyDays: every.toInt(),
      label: label is String ? label : '',
    );
  }
}

/// The `programme` section of `assessments_content.json`.
class ProgrammeConfig {
  const ProgrammeConfig({
    this.moodEveryDays = 1,
    required this.required,
    this.optional = const <ProgrammeItem>[],
  });

  final int moodEveryDays;
  final List<ProgrammeItem> required;

  /// Never shown in "Today's check-ins" (the workplace questionnaire).
  final List<ProgrammeItem> optional;

  factory ProgrammeConfig.fromMap(Map<String, dynamic> map) {
    List<ProgrammeItem> items(Object? raw) => List<ProgrammeItem>.unmodifiable(
      (raw as List? ?? const <Object>[]).map(
        (Object? i) => ProgrammeItem.fromMap((i as Map).cast()),
      ),
    );
    final Object? mood = map['mood'];
    final Object? moodDays = mood is Map ? mood['everyDays'] : null;
    return ProgrammeConfig(
      moodEveryDays: moodDays is num && moodDays >= 1 ? moodDays.toInt() : 1,
      required: items(map['required']),
      optional: items(map['optional']),
    );
  }
}

/// One line of "Today's check-ins": Mood, one check-in, or two check-ins
/// that are due together ("Low mood and worry").
class ScheduleRow {
  const ScheduleRow({
    required this.label,
    required this.assessmentIds,
    required this.done,
  });

  /// The mood row has no check-ins.
  const ScheduleRow.mood({required this.done})
    : label = 'Mood',
      assessmentIds = const <String>[];

  final String label;
  final List<String> assessmentIds;
  final bool done;

  bool get isMood => assessmentIds.isEmpty;

  /// The check-in "Start" opens (the first of a pair).
  String? get startId => isMood ? null : assessmentIds.first;

  /// Mood and the one-minute check-ins.
  bool get isShort =>
      isMood ||
      assessmentIds.every(
        (String id) => ProgrammeSchedule.shortIds.contains(id),
      );
}

/// One line of the schedule on "Your hospital": every required check-in,
/// how often, and when it is next due.
class ScheduleOverviewRow {
  const ScheduleOverviewRow({
    required this.label,
    required this.everyDays,
    required this.nextDue,
    required this.doneToday,
  });

  final String label;
  final int everyDays;

  /// A local date (midnight).
  final DateTime nextDue;
  final bool doneToday;
}

/// When each required check-in is due. Pure: every date comes in as an
/// argument, so it is easy to test. All dates are local calendar days.
///
/// - Due = the day of the last completed one + `everyDays`.
/// - Never taken: counted from the day the user joined, spread over the
///   first week (day 1: Mood, the 3-day check and Wellbeing; day 2: low mood
///   and worry; day 4: burnout and stress). The first check-in's WHO-5 is a
///   normal Wellbeing result, so Wellbeing is usually done on day 1 already.
/// - A check-in taken early simply moves its own next date.
class ProgrammeSchedule {
  const ProgrammeSchedule._();

  /// Days after joining when a never-taken check-in is first due.
  static const Map<String, int> firstWeekOffset = <String, int>{
    'phq4': 0,
    'who5': 0,
    'phq9': 1,
    'gad7': 1,
    'cbi': 3,
    'pss10': 3,
  };

  /// Check-ins shown as one row when they are due together.
  static const List<List<String>> pairs = <List<String>>[
    <String>['phq9', 'gad7'],
    <String>['cbi', 'pss10'],
  ];

  static const Map<String, String> pairLabels = <String, String>{
    'phq9': 'Low mood and worry',
    'cbi': 'Burnout and stress',
  };

  /// The one-minute check-ins ("One short check left").
  static const Set<String> shortIds = <String>{'phq4', 'who5'};

  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  static DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The local day [id] is next due.
  static DateTime dueDay({
    required String id,
    required int everyDays,
    required DateTime joinedAt,
    DateTime? lastDone,
  }) {
    if (lastDone != null) {
      return addDays(dayOf(lastDone), everyDays);
    }
    return addDays(dayOf(joinedAt), firstWeekOffset[id] ?? 0);
  }

  /// "Today's check-ins": Mood, then every required check-in that is due
  /// today or overdue, or was done today. A pair in the same state is one
  /// row. [lastDone] maps an assessment id to its newest `completedAt`.
  static List<ScheduleRow> today({
    required ProgrammeConfig config,
    required DateTime joinedAt,
    required Map<String, DateTime> lastDone,
    required DateTime? lastMood,
    required DateTime now,
  }) {
    final DateTime today = dayOf(now);
    final List<ScheduleRow> rows = <ScheduleRow>[
      ScheduleRow.mood(done: lastMood != null && sameDay(lastMood, now)),
    ];

    // Each required check-in that belongs to today, and whether it is done.
    final Map<String, bool> todays = <String, bool>{};
    for (final ProgrammeItem item in config.required) {
      final DateTime? last = lastDone[item.assessmentId];
      if (last != null && sameDay(last, now)) {
        todays[item.assessmentId] = true;
        continue;
      }
      final DateTime due = dueDay(
        id: item.assessmentId,
        everyDays: item.everyDays,
        joinedAt: joinedAt,
        lastDone: last,
      );
      if (!due.isAfter(today)) {
        todays[item.assessmentId] = false;
      }
    }

    final Set<String> placed = <String>{};
    for (final ProgrammeItem item in config.required) {
      final String id = item.assessmentId;
      final bool? done = todays[id];
      if (done == null || placed.contains(id)) {
        continue;
      }
      final List<String>? pair = _pairOf(id);
      final String? partner = pair?.firstWhere((String p) => p != id);
      if (pair != null && partner != null && todays[partner] == done) {
        rows.add(
          ScheduleRow(
            label: pairLabels[pair.first] ?? item.label,
            assessmentIds: pair,
            done: done,
          ),
        );
        placed.addAll(pair);
      } else {
        rows.add(
          ScheduleRow(
            label: item.label,
            assessmentIds: <String>[id],
            done: done,
          ),
        );
        placed.add(id);
      }
    }
    return rows;
  }

  /// Every required check-in with its next date, pairs as one row, for
  /// "Your hospital". [scales] maps an id to its scale name ("PHQ-4").
  static List<ScheduleOverviewRow> overview({
    required ProgrammeConfig config,
    required DateTime joinedAt,
    required Map<String, DateTime> lastDone,
    required DateTime? lastMood,
    required DateTime now,
    Map<String, String> scales = const <String, String>{},
  }) {
    final bool moodToday = lastMood != null && sameDay(lastMood, now);
    final List<ScheduleOverviewRow> rows = <ScheduleOverviewRow>[
      ScheduleOverviewRow(
        label: 'Mood',
        everyDays: config.moodEveryDays,
        nextDue: moodToday
            ? addDays(dayOf(now), config.moodEveryDays)
            : dayOf(now),
        doneToday: moodToday,
      ),
    ];

    DateTime due(ProgrammeItem item) {
      final DateTime day = dueDay(
        id: item.assessmentId,
        everyDays: item.everyDays,
        joinedAt: joinedAt,
        lastDone: lastDone[item.assessmentId],
      );
      // Overdue shows as today.
      return day.isBefore(dayOf(now)) ? dayOf(now) : day;
    }

    bool doneToday(ProgrammeItem item) {
      final DateTime? last = lastDone[item.assessmentId];
      return last != null && sameDay(last, now);
    }

    final Set<String> placed = <String>{};
    for (final ProgrammeItem item in config.required) {
      final String id = item.assessmentId;
      if (placed.contains(id)) {
        continue;
      }
      final List<String>? pair = _pairOf(id);
      final List<ProgrammeItem> members = pair == null
          ? <ProgrammeItem>[item]
          : config.required
                .where((ProgrammeItem i) => pair.contains(i.assessmentId))
                .toList();
      placed.addAll(members.map((ProgrammeItem i) => i.assessmentId));

      final String label = members.length > 1
          ? members
                .map((ProgrammeItem i) => scales[i.assessmentId] ?? i.label)
                .join(' and ')
          : scales[id] == null
          ? item.label
          : '${item.label} (${scales[id]})';
      final List<DateTime> dues = members.map(due).toList()..sort();
      rows.add(
        ScheduleOverviewRow(
          label: label,
          everyDays: item.everyDays,
          nextDue: dues.first,
          doneToday: members.every(doneToday),
        ),
      );
    }
    return rows;
  }

  static List<String>? _pairOf(String id) {
    for (final List<String> pair in pairs) {
      if (pair.contains(id)) {
        return pair;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Wording.
  // ---------------------------------------------------------------------------

  /// "1 of 2 done. One short check left." or "All done for today. Thank you."
  static String cardLine(List<ScheduleRow> rows) {
    final List<ScheduleRow> left = rows
        .where((ScheduleRow r) => !r.done)
        .toList();
    if (left.isEmpty) {
      return 'All done for today. Thank you.';
    }
    final int done = rows.length - left.length;
    final String rest = left.length == 1
        ? (left.first.isShort ? 'One short check left.' : 'One check left.')
        : '${left.length} checks left.';
    return '$done of ${rows.length} done. $rest';
  }

  /// The robot's speech bubble when something is left, else null.
  static String? bubble(List<ScheduleRow> rows) {
    final int left = rows.where((ScheduleRow r) => !r.done).length;
    if (left == 0) {
      return null;
    }
    return left == 1 ? '1 check-in left today' : '$left check-ins left today';
  }

  /// "Every day", "Every 3 days", "Every week", "Every 2 weeks", "Every
  /// month".
  static String frequency(int days) {
    if (days == 1) {
      return 'Every day';
    }
    if (days == 7) {
      return 'Every week';
    }
    if (days % 7 == 0) {
      return 'Every ${days ~/ 7} weeks';
    }
    if (days == 30) {
      return 'Every month';
    }
    return 'Every $days days';
  }

  static const List<String> _weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "Done today", "Today", "Fri" (within the week) or "3 Nov".
  static String dueLabel(ScheduleOverviewRow row, DateTime now) {
    if (row.doneToday) {
      return 'Done today';
    }
    final DateTime today = dayOf(now);
    if (!row.nextDue.isAfter(today)) {
      return 'Today';
    }
    if (row.nextDue.isBefore(addDays(today, 7))) {
      return _weekdays[row.nextDue.weekday - 1];
    }
    return dayMonth(row.nextDue);
  }

  /// "12 Oct 2026".
  static String fullDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// "3 Nov".
  static String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';
}
