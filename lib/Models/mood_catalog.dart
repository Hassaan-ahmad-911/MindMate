/// The one source of truth for moods, their scores, factors and strengths.
library;

enum MoodGroup { good, between, hard }

extension MoodGroupLabels on MoodGroup {
  /// Section title on the "Pick a mood" screen.
  String get sectionTitle {
    switch (this) {
      case MoodGroup.good:
        return 'Feeling good';
      case MoodGroup.between:
        return 'In between';
      case MoodGroup.hard:
        return 'Having a hard time';
    }
  }

  /// Short name used in legends and filters.
  String get shortLabel {
    switch (this) {
      case MoodGroup.good:
        return 'Good';
      case MoodGroup.between:
        return 'In between';
      case MoodGroup.hard:
        return 'Hard';
    }
  }
}

class MoodDefinition {
  const MoodDefinition(this.name, this.group, this.valence);

  final String name;
  final MoodGroup group;

  /// Mood score from -2 (hardest) to +2 (best).
  final int valence;
}

class MoodCatalog {
  const MoodCatalog._();

  /// All moods, in display order within each group.
  static const List<MoodDefinition> moods = <MoodDefinition>[
    MoodDefinition('Happy', MoodGroup.good, 2),
    MoodDefinition('Calm', MoodGroup.good, 1),
    MoodDefinition('Grateful', MoodGroup.good, 2),
    MoodDefinition('Motivated', MoodGroup.good, 1),
    MoodDefinition('Hopeful', MoodGroup.good, 1),
    MoodDefinition('Proud', MoodGroup.good, 2),
    MoodDefinition('Okay', MoodGroup.between, 0),
    MoodDefinition('Tired', MoodGroup.between, 0),
    MoodDefinition('Restless', MoodGroup.between, 0),
    MoodDefinition('Stressed', MoodGroup.hard, -1),
    MoodDefinition('Anxious', MoodGroup.hard, -1),
    MoodDefinition('Sad', MoodGroup.hard, -2),
    MoodDefinition('Angry', MoodGroup.hard, -2),
    MoodDefinition('Overwhelmed', MoodGroup.hard, -2),
    MoodDefinition('Lonely', MoodGroup.hard, -1),
  ];

  /// What's affecting the mood. Multi-select, optional.
  static const List<String> factors = <String>[
    'Workload',
    'Night shift',
    'Patients',
    'Team',
    'Sleep',
    'Family',
    'Health',
    'Exercise',
    'Rest day',
    'Something else',
  ];

  static const String mild = 'Mild';
  static const String moderate = 'Moderate';
  static const String strong = 'Strong';
  static const List<String> intensities = <String>[mild, moderate, strong];

  static const int noteMaxLength = 500;

  /// Old entries used "Neutral", which is now "Okay".
  static const Map<String, String> _legacyNames = <String, String>{
    'neutral': 'Okay',
  };

  static List<MoodDefinition> inGroup(MoodGroup group) {
    return moods
        .where((MoodDefinition mood) => mood.group == group)
        .toList(growable: false);
  }

  /// The mood called [name], ignoring case and mapping old names.
  static MoodDefinition? find(String name) {
    final String key = name.trim().toLowerCase();
    final String lookup = (_legacyNames[key] ?? key).toLowerCase();
    for (final MoodDefinition mood in moods) {
      if (mood.name.toLowerCase() == lookup) {
        return mood;
      }
    }
    return null;
  }

  /// The display name for a stored mood. Unknown names are kept as they are.
  static String normalizeName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Okay';
    }
    return find(trimmed)?.name ?? trimmed;
  }

  /// The score for a stored mood. Unknown moods count as 0.
  static int valenceFor(String name) => find(name)?.valence ?? 0;

  static MoodGroup groupForValence(int valence) {
    if (valence > 0) {
      return MoodGroup.good;
    }
    if (valence < 0) {
      return MoodGroup.hard;
    }
    return MoodGroup.between;
  }

  /// Reads a stored strength. Old entries used "Severe" (now "Strong") or a
  /// number from 1 to 3.
  static String normalizeIntensity(Object? value) {
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'mild':
          return mild;
        case 'moderate':
          return moderate;
        case 'strong':
        case 'severe':
          return strong;
      }
    }
    if (value is num) {
      final int level = value.round();
      if (level <= 1) {
        return mild;
      }
      return level == 2 ? moderate : strong;
    }
    return moderate;
  }
}
