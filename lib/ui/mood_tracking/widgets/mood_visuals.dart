import 'package:flutter/material.dart';

import '../../../Models/mood_catalog.dart';
import '../../shared/mindmate_theme.dart';

/// Colours for each mood group, all taken from the shared palette.
class MoodVisuals {
  const MoodVisuals._();

  static Gradient gradientFor(MoodGroup group) {
    switch (group) {
      case MoodGroup.good:
        return AppBlends.gold;
      case MoodGroup.between:
        return AppBlends.lightBlue;
      case MoodGroup.hard:
        return AppBlends.blue;
    }
  }

  /// Icon and text colour on top of [gradientFor].
  static Color foregroundFor(MoodGroup group) {
    return group == MoodGroup.hard ? Colors.white : AppColors.headerBlue;
  }

  /// Calendar dots and legend.
  static Color dotColorFor(MoodGroup group) {
    switch (group) {
      case MoodGroup.good:
        return AppColors.accent;
      case MoodGroup.between:
        return AppColors.secondary;
      case MoodGroup.hard:
        // Navy would vanish on the Dark page, so Dark uses the brand blue.
        return MindMateColors.current.isDark
            ? AppColors.primary
            : AppColors.headerBlue;
    }
  }
}

/// Dates and times in the style used by the mood screens, e.g.
/// "Tuesday, 6 October" or "Today, 8:10".
class MoodFormat {
  const MoodFormat._();

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

  static String weekday(DateTime date) => _weekdays[date.weekday - 1];

  static String shortWeekday(DateTime date) => weekday(date).substring(0, 3);

  static String weekdayLetter(DateTime date) => weekday(date)[0];

  static String month(DateTime date) => _months[date.month - 1];

  static String shortMonth(DateTime date) => month(date).substring(0, 3);

  /// "Tuesday, 6 October".
  static String longDate(DateTime date) =>
      '${weekday(date)}, ${date.day} ${month(date)}';

  /// "October 2026".
  static String monthYear(DateTime date) => '${month(date)} ${date.year}';

  /// "8:10" or "21:40".
  static String time(DateTime date) =>
      '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

  /// "Today, 6 October" or "Monday, 5 October".
  static String dayHeader(DateTime day, {required DateTime now}) {
    if (_sameDay(day, now)) {
      return 'Today, ${day.day} ${month(day)}';
    }
    return longDate(day);
  }

  /// "Today, 8:10", "Mon, 21:40" within the last week, else "28 Sep, 9:05".
  static String entryWhen(DateTime date, {required DateTime now}) {
    if (_sameDay(date, now)) {
      return 'Today, ${time(date)}';
    }
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(date.year, date.month, date.day);
    if (today.difference(day).inDays < 7) {
      return '${shortWeekday(date)}, ${time(date)}';
    }
    return '${date.day} ${shortMonth(date)}, ${time(date)}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
