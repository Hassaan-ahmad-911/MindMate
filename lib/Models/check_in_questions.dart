import 'who5_items.dart';

enum CheckInQuestionKind { goals, who5, workStress, sleepQuality, reminder }

/// One answer card. [value] is what is kept: a number for the scored
/// questions, the label for the goals, and a key for the reminder.
class CheckInOption {
  const CheckInOption(this.label, this.value);

  final String label;
  final Object value;
}

class CheckInQuestion {
  const CheckInQuestion({
    required this.kind,
    required this.title,
    required this.options,
    this.eyebrow,
    this.multiSelect = false,
    this.who5Index,
  });

  final CheckInQuestionKind kind;
  final String title;

  /// Small line above the title, e.g. "Over the last two weeks".
  final String? eyebrow;
  final List<CheckInOption> options;
  final bool multiSelect;

  /// For a WHO-5 question: which of the five items it is (0 to 4).
  final int? who5Index;
}

/// The goals offered by the first question, as stored.
class CheckInGoals {
  const CheckInGoals._();

  static const String manageStress = 'Manage stress';
  static const String sleepBetter = 'Sleep better';
  static const String switchOff = 'Switch off after work';
  static const String feelLessDrained = 'Feel less drained';
  static const String justCurious = 'Just curious';

  static const List<String> all = <String>[
    manageStress,
    sleepBetter,
    switchOff,
    feelLessDrained,
    justCurious,
  ];
}

/// The reminder choices of the last question, as stored.
class CheckInReminder {
  const CheckInReminder._();

  static const String beforeShift = 'before_shift';
  static const String afterShift = 'after_shift';
  static const String evening = 'evening';
  static const String none = 'none';
}

/// The nine questions of the first check-in.
class CheckInQuestions {
  const CheckInQuestions._();

  static const int count = 9;

  static const String who5Eyebrow = 'Over the last two weeks';

  static const List<CheckInOption> _who5Answers = <CheckInOption>[
    CheckInOption('All of the time', 5),
    CheckInOption('Most of the time', 4),
    CheckInOption('More than half the time', 3),
    CheckInOption('Less than half the time', 2),
    CheckInOption('Some of the time', 1),
    CheckInOption('At no time', 0),
  ];

  static final List<CheckInQuestion> all = List<CheckInQuestion>.unmodifiable(
    <CheckInQuestion>[
      CheckInQuestion(
        kind: CheckInQuestionKind.goals,
        title: 'What brings you here?',
        multiSelect: true,
        options: CheckInGoals.all
            .map((String goal) => CheckInOption(goal, goal))
            .toList(growable: false),
      ),
      // The five WHO-5 items, worded exactly as in the WHO-5 assessment.
      for (int i = 0; i < Who5.items.length; i += 1)
        CheckInQuestion(
          kind: CheckInQuestionKind.who5,
          eyebrow: who5Eyebrow,
          title: Who5.items[i],
          who5Index: i,
          options: _who5Answers,
        ),
      const CheckInQuestion(
        kind: CheckInQuestionKind.workStress,
        title: 'How stressful has work felt lately?',
        options: <CheckInOption>[
          CheckInOption('Not at all', 0),
          CheckInOption('A little', 1),
          CheckInOption('Moderately', 2),
          CheckInOption('Very', 3),
          CheckInOption('Extremely', 4),
        ],
      ),
      const CheckInQuestion(
        kind: CheckInQuestionKind.sleepQuality,
        title: 'How well have you been sleeping?',
        options: <CheckInOption>[
          CheckInOption('Very poorly', 0),
          CheckInOption('Poorly', 1),
          CheckInOption('Okay', 2),
          CheckInOption('Well', 3),
          CheckInOption('Very well', 4),
        ],
      ),
      const CheckInQuestion(
        kind: CheckInQuestionKind.reminder,
        title: 'When would you like a daily reminder?',
        options: <CheckInOption>[
          CheckInOption('Before my shift', CheckInReminder.beforeShift),
          CheckInOption('After my shift', CheckInReminder.afterShift),
          CheckInOption('In the evening', CheckInReminder.evening),
          CheckInOption('No reminders', CheckInReminder.none),
        ],
      ),
    ],
  );
}
