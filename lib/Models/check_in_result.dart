import 'check_in_questions.dart';
import 'who5_items.dart';

/// What the user answered in the first check-in. A skipped question is null
/// (or an empty list for the goals); nothing is ever filled in for them.
class CheckInResult {
  const CheckInResult({
    this.goals = const <String>[],
    this.who5Answers = const <int?>[null, null, null, null, null],
    this.workStress,
    this.sleepQuality,
    this.reminderPreference,
  });

  /// Builds the result from one answer per question, in question order
  /// (see [CheckInQuestions.all]). For the goals question the answer is a
  /// `List<String>`; for the others it is the option's value.
  factory CheckInResult.fromAnswers(List<Object?> answers) {
    assert(answers.length == CheckInQuestions.count);

    final Object? goals = answers[0];
    final List<int?> who5 = List<int?>.generate(Who5.items.length, (int i) {
      final Object? answer = answers[1 + i];
      return answer is int ? answer : null;
    }, growable: false);
    final Object? stress = answers[6];
    final Object? sleep = answers[7];
    final Object? reminder = answers[8];

    return CheckInResult(
      goals: goals is List
          ? List<String>.unmodifiable(goals.whereType<String>())
          : const <String>[],
      who5Answers: who5,
      workStress: stress is int ? stress : null,
      sleepQuality: sleep is int ? sleep : null,
      reminderPreference: reminder is String ? reminder : null,
    );
  }

  final List<String> goals;

  /// The five WHO-5 answers, 0 to 5 each, null where skipped.
  final List<int?> who5Answers;

  /// 0 (not at all stressful) to 4 (extremely), or null.
  final int? workStress;

  /// 0 (very poorly) to 4 (very well), or null.
  final int? sleepQuality;

  /// `before_shift`, `after_shift`, `evening` or `none`, or null if skipped.
  final String? reminderPreference;

  /// 0 to 25, only if all five WHO-5 items were answered.
  int? get who5Raw => Who5.rawScore(who5Answers);

  /// 0 to 100 (`who5Raw * 4`), only if all five WHO-5 items were answered.
  int? get who5Score => Who5.standardizedScore(who5Answers);

  /// The document saved at `users/{uid}/checkins/{id}`. The service adds
  /// `completedAt`.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': 'initial',
      'goals': goals,
      'who5Answers': who5Answers,
      if (who5Raw != null) 'who5Raw': who5Raw,
      if (who5Score != null) 'who5Score': who5Score,
      'workStress': workStress,
      'sleepQuality': sleepQuality,
    };
  }
}
