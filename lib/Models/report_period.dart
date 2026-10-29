import 'mood_stats.dart';

enum ReportKind { week, month }

/// A report period: a Monday-to-Sunday week or a calendar month, in local
/// time. [end] is exclusive (midnight after the last day).
class ReportPeriod {
  const ReportPeriod._(this.kind, this.start, this.end);

  /// The week (Monday to Sunday) holding [day].
  factory ReportPeriod.week(DateTime day) {
    final DateTime start = weekStart(day);
    return ReportPeriod._(ReportKind.week, start, MoodStats.addDays(start, 7));
  }

  /// The calendar month holding [day].
  factory ReportPeriod.month(DateTime day) {
    return ReportPeriod._(
      ReportKind.month,
      DateTime(day.year, day.month),
      DateTime(day.year, day.month + 1),
    );
  }

  factory ReportPeriod.of(ReportKind kind, DateTime day) =>
      kind == ReportKind.week
      ? ReportPeriod.week(day)
      : ReportPeriod.month(day);

  final ReportKind kind;
  final DateTime start;
  final DateTime end;

  /// Monday at midnight of [day]'s week.
  static DateTime weekStart(DateTime day) =>
      MoodStats.addDays(MoodStats.dayOf(day), 1 - day.weekday);

  DateTime get lastDay => MoodStats.addDays(end, -1);

  ReportPeriod get previous =>
      ReportPeriod.of(kind, MoodStats.addDays(start, -1));

  ReportPeriod get next => ReportPeriod.of(kind, end);

  /// Every day in the period, in order.
  List<DateTime> get days {
    final List<DateTime> list = <DateTime>[];
    for (DateTime d = start; d.isBefore(end); d = MoodStats.addDays(d, 1)) {
      list.add(d);
    }
    return list;
  }

  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(end);

  /// Whether [now] falls in this period (so ">" is disabled).
  bool isCurrent(DateTime now) => contains(now);

  /// "week" or "month", for wording such as "than last week".
  String get unit => kind == ReportKind.week ? 'week' : 'month';

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

  static String monthName(DateTime d) => _months[d.month - 1];

  /// "5 – 11 October", "28 September – 4 October", or "September 2026".
  String get label {
    if (kind == ReportKind.month) {
      return '${monthName(start)} ${start.year}';
    }
    final DateTime last = lastDay;
    if (last.month == start.month) {
      return '${start.day} – ${last.day} ${monthName(last)}';
    }
    return '${start.day} ${monthName(start)} – ${last.day} '
        '${monthName(last)}';
  }

  String get key => '${kind.name}-${start.toIso8601String()}';

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod && other.kind == kind && other.start == start;

  @override
  int get hashCode => Object.hash(kind, start);
}
