import 'assessment_definition.dart';
import 'assessment_result.dart';

/// How a range is coloured: never red, never a warning. Best uses the gold
/// blend, heavy ranges the blue blend with white text, the rest light blue.
enum RangeTone { best, middle, heavy }

/// Rules for stepping through a questionnaire.
class AssessmentFlowRules {
  const AssessmentFlowRules._();

  /// The support screen shows after a safety item (PHQ-9 question 9) is
  /// answered above its lowest value, once per attempt.
  static bool shouldShowSafety(
    AssessmentItem item,
    int? answer,
    bool alreadyShownThisAttempt,
  ) {
    return item.safety &&
        answer != null &&
        answer > item.minValue &&
        !alreadyShownThisAttempt;
  }

  /// PHQ-9's difficulty question shows only if some answer is above 0.
  static bool showsExtra(AssessmentDefinition def, List<int?> answers) {
    final ExtraItem? extra = def.extraItem;
    if (extra == null) {
      return false;
    }
    return answers.any((int? a) => a != null && a > extra.showIfAnyAbove);
  }
}

/// The card at the top of the hub.
class AssessmentSuggestion {
  const AssessmentSuggestion({required this.def, this.lastTaken});

  final AssessmentDefinition def;

  /// Null when it has never been taken.
  final DateTime? lastTaken;

  bool get neverTaken => lastTaken == null;

  /// 1. The first in [order] never completed. 2. Otherwise the most overdue
  /// (last completed + retakeDays is in the past). 3. Otherwise null.
  static AssessmentSuggestion? pick({
    required List<AssessmentDefinition> all,
    required List<String> order,
    required Map<String, AssessmentResult> latest,
    required DateTime now,
  }) {
    final List<AssessmentDefinition> ordered = <AssessmentDefinition>[
      for (final String id in order)
        ...all.where((AssessmentDefinition d) => d.id == id),
      ...all.where((AssessmentDefinition d) => !order.contains(d.id)),
    ];
    for (final AssessmentDefinition def in ordered) {
      if (!latest.containsKey(def.id)) {
        return AssessmentSuggestion(def: def);
      }
    }
    AssessmentSuggestion? best;
    Duration mostOverdue = Duration.zero;
    for (final AssessmentDefinition def in ordered) {
      final DateTime last = latest[def.id]!.completedAt;
      final Duration overdue = now.difference(
        last.add(Duration(days: def.retakeDays)),
      );
      if (overdue > mostOverdue) {
        mostOverdue = overdue;
        best = AssessmentSuggestion(def: def, lastTaken: last);
      }
    }
    return best;
  }
}

/// Small calculations shown on the result and history screens.
class AssessmentMath {
  const AssessmentMath._();

  static RangeTone toneFor(AssessmentDefinition def, String? bandId) {
    if (bandId == null) {
      return RangeTone.middle;
    }
    if (bandId == def.bestBand.id) {
      return RangeTone.best;
    }
    if (def.heavyBands.contains(bandId)) {
      return RangeTone.heavy;
    }
    return RangeTone.middle;
  }

  /// The change in the headline number since [previous], rounded; null
  /// without a previous result or a headline. For the CBI this is the
  /// highest area.
  static int? change(AssessmentResult current, AssessmentResult? previous) {
    final double? now = current.headline;
    final double? before = previous?.headline;
    if (now == null || before == null) {
      return null;
    }
    return now.round() - before.round();
  }

  /// When the next check-in is suggested.
  static DateTime nextDue(AssessmentDefinition def, DateTime lastCompleted) =>
      lastCompleted.add(Duration(days: def.retakeDays));

  /// "11", "62%" for the workplace, "68" for a CBI area.
  static String formatScore(AssessmentDefinition def, double value) {
    final String n = value.round().toString();
    return def.method == ScoringMethod.areaPercent ? '$n%' : n;
  }

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

  /// "24 Sep".
  static String shortDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  /// "Today, 8 Oct", or "24 Sep".
  static String listDate(DateTime date, DateTime now) {
    final bool today =
        date.year == now.year && date.month == now.month && date.day == now.day;
    return today ? 'Today, ${shortDate(date)}' : shortDate(date);
  }

  /// "3 since 24 Sep" (the arrow is drawn separately), or "No change since
  /// 24 Sep".
  static String changeLabel(int change, DateTime previousDate) {
    if (change == 0) {
      return 'No change since ${shortDate(previousDate)}';
    }
    return '${change.abs()} since ${shortDate(previousDate)}';
  }

  /// "Next suggested: in 14 days, around 22 Oct" or "Good time for another
  /// look".
  static String nextSuggestedLine(
    AssessmentDefinition def,
    DateTime lastCompleted,
    DateTime now,
  ) {
    final DateTime due = nextDue(def, lastCompleted);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime dueDay = DateTime(due.year, due.month, due.day);
    final int days = dueDay.difference(today).inDays;
    if (days <= 0) {
      return 'Good time for another look';
    }
    final String inDays = days == 1 ? 'in 1 day' : 'in $days days';
    return 'Next suggested: $inDays, around ${shortDate(due)}';
  }
}
