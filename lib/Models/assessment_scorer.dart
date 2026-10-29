import 'assessment_definition.dart';

/// The score of one completed questionnaire.
class AssessmentScore {
  const AssessmentScore({
    required this.total,
    required this.rawTotal,
    required this.bandId,
    required this.areas,
    required this.areaBands,
    required this.item9Positive,
  });

  /// PHQ-9, GAD-7 and PSS-10: the sum. WHO-5: raw x 4 (0 to 100).
  /// Workplace: the overall percentage. Null for the CBI, which has no total.
  final double? total;

  /// WHO-5 only: the raw sum, 0 to 25.
  final int? rawTotal;

  /// The range of [total]. Null for the CBI.
  final String? bandId;

  /// CBI and workplace: area id -> 0 to 100.
  final Map<String, double>? areas;

  /// Area id -> range id.
  final Map<String, String>? areaBands;

  /// PHQ-9 question 9 was answered above "Not at all".
  final bool item9Positive;

  /// The area with the highest score (CBI), or null without areas.
  String? get highestArea {
    final Map<String, double>? a = areas;
    if (a == null || a.isEmpty) {
      return null;
    }
    return a.entries
        .reduce(
          (MapEntry<String, double> x, MapEntry<String, double> y) =>
              y.value > x.value ? y : x,
        )
        .key;
  }
}

/// Scores a questionnaire from its raw answers. Pure Dart, no I/O.
///
/// - `sum`: add the values (after reversing marked items: PSS-10 4, 5, 7, 8).
/// - `sumTimes4`: WHO-5. raw = sum (0-25), total = raw x 4 (0-100).
/// - `areaMean`: CBI. Each area is the mean of its items (item 13 reversed).
///   There is no total, and the areas are never averaged together.
/// - `areaPercent`: workplace. For each area and for all items together:
///   (sum - n x min) / (n x (max - min)) x 100, after reversing, so every
///   area can range from 0% to 100%.
class AssessmentScorer {
  const AssessmentScorer._();

  static AssessmentScore score(AssessmentDefinition def, List<int> answers) {
    if (answers.length != def.items.length) {
      throw ArgumentError(
        '${def.id} needs ${def.items.length} answers, got ${answers.length}.',
      );
    }

    final List<int> scored = <int>[
      for (int i = 0; i < answers.length; i += 1)
        def.items[i].scored(answers[i]),
    ];
    bool item9 = false;
    for (int i = 0; i < answers.length; i += 1) {
      if (def.items[i].safety && answers[i] > def.items[i].minValue) {
        item9 = true;
      }
    }

    switch (def.method) {
      case ScoringMethod.sum:
        final double total = _sum(scored).toDouble();
        return AssessmentScore(
          total: total,
          rawTotal: null,
          bandId: bandFor(def.bands, total)?.id,
          areas: null,
          areaBands: null,
          item9Positive: item9,
        );
      case ScoringMethod.sumTimes4:
        final int raw = _sum(scored);
        final double total = raw * 4.0;
        return AssessmentScore(
          total: total,
          rawTotal: raw,
          bandId: bandFor(def.bands, total)?.id,
          areas: null,
          areaBands: null,
          item9Positive: item9,
        );
      case ScoringMethod.areaMean:
        final Map<String, double> areas = <String, double>{
          for (final AssessmentArea area in def.areas)
            area.id: _mean(_valuesIn(def, scored, area.id)),
        };
        return AssessmentScore(
          total: null,
          rawTotal: null,
          bandId: null,
          areas: areas,
          areaBands: _bandsFor(def, areas),
          item9Positive: item9,
        );
      case ScoringMethod.areaPercent:
        final Map<String, double> areas = <String, double>{
          for (final AssessmentArea area in def.areas)
            area.id: _percent(def, scored, area.id),
        };
        final double total = _percent(def, scored, null);
        return AssessmentScore(
          total: total,
          rawTotal: null,
          bandId: bandFor(def.bands, total)?.id,
          areas: areas,
          areaBands: _bandsFor(def, areas),
          item9Positive: item9,
        );
    }
  }

  /// The range holding [value]: the band with min <= value <= max, or, for
  /// a value between two bands (e.g. 49.995), the last band starting at or
  /// below it.
  static AssessmentBand? bandFor(List<AssessmentBand> bands, num value) {
    for (final AssessmentBand band in bands) {
      if (band.contains(value)) {
        return band;
      }
    }
    AssessmentBand? found;
    for (final AssessmentBand band in bands) {
      if (band.min <= value) {
        found = band;
      }
    }
    return found;
  }

  /// The first next step whose condition matches, or null.
  static String? nextStep(AssessmentDefinition def, AssessmentScore score) {
    for (final NextStep step in def.nextSteps) {
      if (step.when.matches(score.total, score.areas)) {
        return step.text;
      }
    }
    return null;
  }

  /// The practice id to suggest, or null.
  static String? practiceId(AssessmentDefinition def, AssessmentScore score) {
    final PracticeRule? rule = def.practice;
    if (rule == null || !rule.when.matches(score.total, score.areas)) {
      return null;
    }
    return rule.practiceId;
  }

  static Map<String, String> _bandsFor(
    AssessmentDefinition def,
    Map<String, double> areas,
  ) {
    return <String, String>{
      for (final MapEntry<String, double> e in areas.entries)
        if (bandFor(def.bands, e.value) != null)
          e.key: bandFor(def.bands, e.value)!.id,
    };
  }

  static List<int> _valuesIn(
    AssessmentDefinition def,
    List<int> scored,
    String area,
  ) {
    return <int>[
      for (int i = 0; i < scored.length; i += 1)
        if (def.items[i].area == area) scored[i],
    ];
  }

  /// [area] null means all items.
  static double _percent(
    AssessmentDefinition def,
    List<int> scored,
    String? area,
  ) {
    int sum = 0;
    int low = 0;
    int high = 0;
    for (int i = 0; i < scored.length; i += 1) {
      final AssessmentItem item = def.items[i];
      if (area != null && item.area != area) {
        continue;
      }
      sum += scored[i];
      low += item.minValue;
      high += item.maxValue;
    }
    if (high == low) {
      return 0;
    }
    return (sum - low) / (high - low) * 100;
  }

  static int _sum(List<int> values) =>
      values.fold<int>(0, (int a, int b) => a + b);

  static double _mean(List<int> values) =>
      values.isEmpty ? 0 : _sum(values) / values.length;
}
