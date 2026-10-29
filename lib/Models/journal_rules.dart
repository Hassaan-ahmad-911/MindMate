import 'dart:math';

import 'journal_content.dart';
import 'journal_model.dart';

/// The prompt card on Journal home: which label and which prompt.
class JournalPromptPicker {
  const JournalPromptPicker._();

  /// "This morning's prompt" 05:00-11:59, "Today's prompt" 12:00-16:59,
  /// "Tonight's prompt" 17:00-04:59.
  static String label(DateTime now) {
    if (now.hour >= 5 && now.hour < 12) {
      return "This morning's prompt";
    }
    if (now.hour >= 12 && now.hour < 17) {
      return "Today's prompt";
    }
    return "Tonight's prompt";
  }

  /// The prompts that fit the time of day: morning or any in the morning,
  /// any in the afternoon, evening or any at night.
  static List<JournalPrompt> pool(List<JournalPrompt> prompts, DateTime now) {
    final Set<String> allowed;
    if (now.hour >= 5 && now.hour < 12) {
      allowed = <String>{'morning', 'any'};
    } else if (now.hour >= 12 && now.hour < 17) {
      allowed = <String>{'any'};
    } else {
      allowed = <String>{'evening', 'any'};
    }
    final List<JournalPrompt> fitting = prompts
        .where((JournalPrompt p) => allowed.contains(p.when))
        .toList(growable: false);
    return fitting.isEmpty ? prompts : fitting;
  }

  /// The same prompt all day: chosen from the date, not the time.
  static JournalPrompt today(List<JournalPrompt> prompts, DateTime now) {
    final List<JournalPrompt> candidates = pool(prompts, now);
    final int day = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(2024)).inDays;
    return candidates[day % candidates.length];
  }

  /// Another prompt from the same pool, never [current] again.
  static JournalPrompt shuffle(
    List<JournalPrompt> prompts,
    DateTime now,
    JournalPrompt current, {
    Random? random,
  }) {
    final List<JournalPrompt> others = pool(
      prompts,
      now,
    ).where((JournalPrompt p) => p.text != current.text).toList();
    if (others.isEmpty) {
      return current;
    }
    return others[(random ?? Random()).nextInt(others.length)];
  }
}

/// Dates on the journal screens.
class JournalDates {
  const JournalDates._();

  static const List<String> _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static DateTime dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// "21:40".
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  /// "Thursday 8 October · 21:40".
  static String longDateTime(DateTime date) =>
      '${_weekdays[date.weekday - 1]} ${date.day} '
      '${_months[date.month - 1]} · ${time(date)}';

  /// "October".
  static String monthName(DateTime date) => _months[date.month - 1];

  /// "Today", "Yesterday", then "Mon 5 Oct".
  static String groupLabel(DateTime date, DateTime now) {
    final int days = dayOf(now).difference(dayOf(date)).inDays;
    if (days == 0) {
      return 'Today';
    }
    if (days == 1) {
      return 'Yesterday';
    }
    return '${_weekdays[date.weekday - 1].substring(0, 3)} ${date.day} '
        '${_months[date.month - 1].substring(0, 3)}';
  }

  /// [entries] (newest first) in groups under [groupLabel].
  static List<JournalDayGroup> group(List<JournalModel> entries, DateTime now) {
    final List<JournalDayGroup> groups = <JournalDayGroup>[];
    for (final JournalModel entry in entries) {
      final String label = groupLabel(entry.createdAt, now);
      if (groups.isEmpty || groups.last.label != label) {
        groups.add(JournalDayGroup(label, <JournalModel>[]));
      }
      groups.last.entries.add(entry);
    }
    return groups;
  }

  /// Start of the month holding [date], and of the month after.
  static DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

  static DateTime nextMonthStart(DateTime date) =>
      DateTime(date.year, date.month + 1);

  /// Week 1 is days 1-7, week 2 days 8-14 ... week 5 days 29-31.
  static int weekOfMonth(DateTime date) => (date.day - 1) ~/ 7 + 1;

  /// How many weeks [month] has under [weekOfMonth]: 4 or 5.
  static int weeksInMonth(DateTime month) {
    final DateTime lastDay = DateTime(month.year, month.month + 1, 0);
    return weekOfMonth(lastDay);
  }
}

class JournalDayGroup {
  JournalDayGroup(this.label, this.entries);

  final String label;
  final List<JournalModel> entries;
}

/// The two kinds of writing chosen by default on "How do you want to write?".
class JournalDefaults {
  const JournalDefaults._();

  /// After-shift debrief from 17:00 to 04:59, otherwise Free write.
  static String templateFor(DateTime now) {
    return now.hour >= 17 || now.hour < 5
        ? JournalTypes.afterShift
        : JournalTypes.free;
  }
}

/// The practice suggested on the Saved screen.
class JournalPracticePicker {
  const JournalPracticePicker._();

  /// Heavy: self-compassion break. Mixed from 17:00: Leaving work at work.
  /// Mixed before 17:00: the 3-step pause. Light or unknown: nothing.
  static String? practiceFor(
    JournalTone? tone,
    DateTime now,
    JournalPracticeSuggestions suggestions,
  ) {
    switch (tone) {
      case JournalTone.heavy:
        return suggestions.heavy;
      case JournalTone.mixed:
        return now.hour >= 17
            ? (suggestions.mixedFrom17 ?? suggestions.mixed)
            : suggestions.mixed;
      case JournalTone.light:
        return suggestions.light;
      case null:
        return null;
    }
  }
}

/// How a topic reads inside a sentence, e.g. "You wrote about your team".
class JournalTopicWords {
  const JournalTopicWords._();

  static const Map<String, String> _phrases = <String, String>{
    'Workload': 'your workload',
    'Night shift': 'night shifts',
    'Patients': 'patients',
    'Team': 'your team',
    'Sleep': 'sleep',
    'Family': 'your family',
    'Health': 'your health',
    'Exercise': 'exercise',
    'Rest day': 'rest days',
  };

  static String phrase(String topic) => _phrases[topic] ?? topic.toLowerCase();
}

/// A topic and how many entries mention it.
class JournalTopicCount {
  const JournalTopicCount(this.topic, this.count);

  final String topic;
  final int count;
}

/// One week's tone counts for the "Tone by week" chart.
class JournalWeekTones {
  const JournalWeekTones({
    required this.week,
    required this.light,
    required this.mixed,
    required this.heavy,
  });

  final int week;
  final int light;
  final int mixed;
  final int heavy;

  int get total => light + mixed + heavy;
}

/// Everything on the "Your writing" screen, worked out from one month's
/// entries. Nothing here is stored.
class JournalInsights {
  const JournalInsights({
    required this.entryCount,
    required this.daysWritten,
    required this.mostCommonTone,
    required this.weeks,
    required this.topTopics,
  });

  /// Fewer entries than this shows only the tiles.
  static const int minEntriesForPatterns = 3;

  final int entryCount;
  final int daysWritten;

  /// Null when no entry has a tone.
  final JournalTone? mostCommonTone;
  final List<JournalWeekTones> weeks;

  /// At most 4, most mentioned first.
  final List<JournalTopicCount> topTopics;

  bool get showPatterns => entryCount >= minEntriesForPatterns;

  factory JournalInsights.from(List<JournalSummary> entries, DateTime month) {
    final Set<DateTime> days = <DateTime>{};
    final Map<JournalTone, int> toneCounts = <JournalTone, int>{};
    final int weekCount = JournalDates.weeksInMonth(month);
    final List<List<int>> weekly = List<List<int>>.generate(
      weekCount,
      (_) => <int>[0, 0, 0],
    );

    for (final JournalSummary entry in entries) {
      days.add(JournalDates.dayOf(entry.createdAt));
      final JournalTone? tone = entry.tone;
      if (tone == null) {
        continue;
      }
      toneCounts[tone] = (toneCounts[tone] ?? 0) + 1;
      final int week = JournalDates.weekOfMonth(entry.createdAt);
      if (week >= 1 && week <= weekCount) {
        weekly[week - 1][tone.index] += 1;
      }
    }

    JournalTone? mostCommon;
    int best = 0;
    // Ties go to Mixed, then Heavy, then Light: the gentlest summary.
    for (final JournalTone tone in <JournalTone>[
      JournalTone.mixed,
      JournalTone.heavy,
      JournalTone.light,
    ]) {
      final int count = toneCounts[tone] ?? 0;
      if (count > best) {
        best = count;
        mostCommon = tone;
      }
    }

    return JournalInsights(
      entryCount: entries.length,
      daysWritten: days.length,
      mostCommonTone: mostCommon,
      weeks: List<JournalWeekTones>.generate(
        weekCount,
        (int i) => JournalWeekTones(
          week: i + 1,
          light: weekly[i][JournalTone.light.index],
          mixed: weekly[i][JournalTone.mixed.index],
          heavy: weekly[i][JournalTone.heavy.index],
        ),
      ),
      topTopics: topicCounts(entries).take(4).toList(growable: false),
    );
  }

  /// How many entries mention each topic, most first.
  static List<JournalTopicCount> topicCounts(List<JournalSummary> entries) {
    final Map<String, int> counts = <String, int>{};
    for (final JournalSummary entry in entries) {
      for (final String topic in entry.topics.toSet()) {
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
    }
    final List<JournalTopicCount> list = counts.entries
        .map((MapEntry<String, int> e) => JournalTopicCount(e.key, e.value))
        .toList();
    list.sort((JournalTopicCount a, JournalTopicCount b) {
      final int byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.topic.compareTo(b.topic);
    });
    return list;
  }

  /// The line under an entry: the entry's own topic that appears in the most
  /// entries this month, if that is 3 or more. Null otherwise.
  static JournalTopicCount? topicLineFor(
    JournalModel entry,
    List<JournalSummary> monthEntries,
  ) {
    if (entry.topics.isEmpty) {
      return null;
    }
    JournalTopicCount? best;
    for (final JournalTopicCount count in topicCounts(monthEntries)) {
      if (entry.topics.contains(count.topic) && count.count >= 3) {
        if (best == null || count.count > best.count) {
          best = count;
        }
      }
    }
    return best;
  }
}
