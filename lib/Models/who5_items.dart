/// The five WHO-5 Well-Being items, in one place. The WHO-5 assessment and the
/// first check-in both read their wording from here.
class Who5 {
  const Who5._();

  static const List<String> items = <String>[
    'I have felt cheerful and in good spirits.',
    'I have felt calm and relaxed.',
    'I have felt active and vigorous.',
    'I woke up feeling fresh and rested.',
    'My daily life has been filled with things that interest me.',
  ];

  /// Each answer is scored 0 (at no time) to 5 (all of the time).
  static const int highestAnswer = 5;

  /// The raw score, 0 to 25. Null unless every item is answered: a missing
  /// answer is never guessed.
  static int? rawScore(List<int?> answers) {
    if (answers.length != items.length) {
      return null;
    }
    int total = 0;
    for (final int? answer in answers) {
      if (answer == null || answer < 0 || answer > highestAnswer) {
        return null;
      }
      total += answer;
    }
    return total;
  }

  /// The standardised score, 0 to 100 (`raw * 4`). Null unless every item is
  /// answered.
  static int? standardizedScore(List<int?> answers) {
    final int? raw = rawScore(answers);
    return raw == null ? null : raw * 4;
  }
}
