import 'check_in_questions.dart';

/// What MindMate suggests the user focuses on first.
enum CheckInFocus { sleepAndSwitchOff, easingStress, energy, dailyHabit }

extension CheckInFocusText on CheckInFocus {
  String get title {
    switch (this) {
      case CheckInFocus.sleepAndSwitchOff:
        return 'Sleep and switching off after shifts';
      case CheckInFocus.easingStress:
        return 'Easing work stress';
      case CheckInFocus.energy:
        return 'Getting your energy back';
      case CheckInFocus.dailyHabit:
        return 'Building a daily check-in habit';
    }
  }
}

/// The "All set" screen's content, worked out from the check-in answers.
class CheckInPlan {
  const CheckInPlan({
    required this.focus,
    required this.practiceIds,
    required this.showSupportLine,
  });

  final CheckInFocus focus;

  /// Ids of the two practices to suggest (see the meditation content file).
  final List<String> practiceIds;

  /// Whether to add the gentle line about talking to someone.
  final bool showSupportLine;
}

class CheckInPlanner {
  const CheckInPlanner._();

  /// A standardised WHO-5 score at or below this adds the gentle line.
  static const int supportLineThreshold = 28;

  static const String supportLine =
      'It sounds like things have been heavy lately. If it stays this way, '
      'talking to someone you trust or a professional can help.';

  /// The first rule that matches wins:
  /// 1. sleep quality 0 or 1, or the goal "Sleep better";
  /// 2. work stress 3 or 4, or the goal "Manage stress";
  /// 3. the goal "Feel less drained";
  /// 4. otherwise, a daily check-in habit.
  static CheckInFocus focusFor({
    List<String> goals = const <String>[],
    int? sleepQuality,
    int? workStress,
  }) {
    if ((sleepQuality != null && sleepQuality <= 1) ||
        goals.contains(CheckInGoals.sleepBetter)) {
      return CheckInFocus.sleepAndSwitchOff;
    }
    if ((workStress != null && workStress >= 3) ||
        goals.contains(CheckInGoals.manageStress)) {
      return CheckInFocus.easingStress;
    }
    if (goals.contains(CheckInGoals.feelLessDrained)) {
      return CheckInFocus.energy;
    }
    return CheckInFocus.dailyHabit;
  }

  static List<String> practicesFor(CheckInFocus focus) {
    switch (focus) {
      case CheckInFocus.sleepAndSwitchOff:
        return const <String>['sleep_wind_down', 'leaving_work'];
      case CheckInFocus.easingStress:
        return const <String>['three_step_pause', 'senses_54321'];
      case CheckInFocus.energy:
        return const <String>['kindness_for_carers', 'release_the_tension'];
      case CheckInFocus.dailyHabit:
        return const <String>['three_step_pause', 'calm_place'];
    }
  }

  /// Whether the standardised WHO-5 score [who5Score] (0 to 100, or null if it
  /// could not be worked out) adds the gentle line.
  static bool showsSupportLine(int? who5Score) =>
      who5Score != null && who5Score <= supportLineThreshold;

  static CheckInPlan plan({
    List<String> goals = const <String>[],
    int? sleepQuality,
    int? workStress,
    int? who5Score,
  }) {
    final CheckInFocus focus = focusFor(
      goals: goals,
      sleepQuality: sleepQuality,
      workStress: workStress,
    );
    return CheckInPlan(
      focus: focus,
      practiceIds: practicesFor(focus),
      showSupportLine: showsSupportLine(who5Score),
    );
  }

  /// The plan when the user chose "Do this later": the daily habit focus, and
  /// no support line, since nothing was answered.
  static CheckInPlan skippedPlan() => plan();

  /// The line under "Daily mood check-in" on the All set screen. The times are
  /// where a reminder would go; reminders are not built yet, so only the
  /// choice is stored.
  static String reminderLine(String? preference) {
    switch (preference) {
      case CheckInReminder.beforeShift:
        return 'Reminder before your shift, 7:00 am';
      case CheckInReminder.afterShift:
        return 'Reminder after your shift, 8:00 pm';
      case CheckInReminder.evening:
        return 'Reminder in the evening, 9:00 pm';
      case CheckInReminder.none:
        return 'No reminder set';
      default:
        return 'A quick look at how you feel each day';
    }
  }
}
