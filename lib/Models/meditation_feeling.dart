/// The five-point "How do you feel?" scale used before and after a practice.
class MeditationFeeling {
  const MeditationFeeling._();

  static const int lowest = 1;
  static const int highest = 5;

  /// Labels for the values 1 to 5.
  static const List<String> labels = <String>[
    'Very low',
    'Low',
    'Okay',
    'Good',
    'Very good',
  ];

  /// The label for [value] (1 to 5), or null for anything else.
  static String? labelFor(int? value) {
    if (value == null || value < lowest || value > highest) {
      return null;
    }
    return labels[value - 1];
  }

  /// Reads a stored value; anything outside 1 to 5 becomes null.
  static int? parse(Object? raw) {
    if (raw is! num) {
      return null;
    }
    final int value = raw.round();
    return value < lowest || value > highest ? null : value;
  }
}
