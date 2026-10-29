import 'package:cloud_firestore/cloud_firestore.dart';

import 'assessment_definition.dart';
import 'assessment_scorer.dart';

/// A completed questionnaire, stored at `users/{uid}/assessments/{id}`.
/// Only completed attempts are ever saved.
class AssessmentResult {
  const AssessmentResult({
    this.id = '',
    required this.assessmentId,
    required this.contentVersion,
    required this.answers,
    this.extraAnswers = const <String, int>{},
    required this.total,
    this.rawTotal,
    required this.bandId,
    this.areas,
    this.areaBands,
    required this.startedAt,
    required this.completedAt,
    this.source,
  });

  /// [source] of the WHO-5 saved from the first check-in in profile setup.
  static const String setupSource = 'setup';

  /// Builds the result of an attempt from its answers.
  factory AssessmentResult.fromAttempt({
    required AssessmentDefinition def,
    required int contentVersion,
    required List<int> answers,
    Map<String, int> extraAnswers = const <String, int>{},
    required DateTime startedAt,
    required DateTime completedAt,
    String? source,
  }) {
    final AssessmentScore score = AssessmentScorer.score(def, answers);
    return AssessmentResult(
      assessmentId: def.id,
      contentVersion: contentVersion,
      answers: List<int>.unmodifiable(answers),
      extraAnswers: Map<String, int>.unmodifiable(extraAnswers),
      total: score.total,
      rawTotal: score.rawTotal,
      bandId: score.bandId,
      areas: score.areas,
      areaBands: score.areaBands,
      startedAt: startedAt,
      completedAt: completedAt,
      source: source,
    );
  }

  final String id;
  final String assessmentId;
  final int contentVersion;

  /// Raw answer values in item order, before reversing.
  final List<int> answers;

  /// Unscored answers, e.g. `{difficulty: 2}` for PHQ-9.
  final Map<String, int> extraAnswers;
  final double? total;
  final int? rawTotal;
  final String? bandId;
  final Map<String, double>? areas;
  final Map<String, String>? areaBands;
  final DateTime startedAt;
  final DateTime completedAt;

  /// Where it was taken, when not in the check-ins module: [setupSource].
  final String? source;

  bool get fromSetup => source == setupSource;

  /// Re-scores the stored answers (for the result screen of a saved result).
  AssessmentScore scoreWith(AssessmentDefinition def) =>
      AssessmentScorer.score(def, answers);

  /// The number shown for this result: the total, or for the CBI the
  /// highest area.
  double? get headline {
    if (total != null) {
      return total;
    }
    final Map<String, double>? a = areas;
    if (a == null || a.isEmpty) {
      return null;
    }
    return a.values.reduce((double x, double y) => x > y ? x : y);
  }

  /// The range of [headline]: the total's, or for the CBI the highest
  /// area's.
  String? get headlineBandId {
    if (bandId != null) {
      return bandId;
    }
    final Map<String, double>? a = areas;
    final Map<String, String>? b = areaBands;
    if (a == null || b == null || a.isEmpty) {
      return null;
    }
    final String top = a.entries
        .reduce(
          (MapEntry<String, double> x, MapEntry<String, double> y) =>
              y.value > x.value ? y : x,
        )
        .key;
    return b[top];
  }

  AssessmentResult copyWith({String? id}) {
    return AssessmentResult(
      id: id ?? this.id,
      assessmentId: assessmentId,
      contentVersion: contentVersion,
      answers: answers,
      extraAnswers: extraAnswers,
      total: total,
      rawTotal: rawTotal,
      bandId: bandId,
      areas: areas,
      areaBands: areaBands,
      startedAt: startedAt,
      completedAt: completedAt,
      source: source,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'assessmentId': assessmentId,
      'contentVersion': contentVersion,
      'answers': answers,
      'extraAnswers': extraAnswers,
      'total': total,
      'rawTotal': rawTotal,
      'bandId': bandId,
      'areas': areas,
      'areaBands': areaBands,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': Timestamp.fromDate(completedAt),
      'source': ?source,
    };
  }

  factory AssessmentResult.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final DateTime completed = _date(map['completedAt']) ?? DateTime.now();
    return AssessmentResult(
      id: id,
      assessmentId: map['assessmentId']?.toString() ?? '',
      contentVersion: (map['contentVersion'] as num? ?? 1).toInt(),
      answers: List<int>.unmodifiable(
        (map['answers'] as List? ?? const <Object>[]).map(
          (Object? v) => (v as num? ?? 0).toInt(),
        ),
      ),
      extraAnswers: Map<String, int>.unmodifiable(<String, int>{
        for (final MapEntry<dynamic, dynamic> e
            in (map['extraAnswers'] as Map? ?? const <String, int>{}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      }),
      total: (map['total'] as num?)?.toDouble(),
      rawTotal: (map['rawTotal'] as num?)?.toInt(),
      bandId: map['bandId'] as String?,
      areas: _doubles(map['areas']),
      areaBands: _strings(map['areaBands']),
      startedAt: _date(map['startedAt']) ?? completed,
      completedAt: completed,
      source: map['source'] as String?,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static Map<String, double>? _doubles(Object? value) {
    if (value is! Map) {
      return null;
    }
    return Map<String, double>.unmodifiable(<String, double>{
      for (final MapEntry<dynamic, dynamic> e in value.entries)
        if (e.value is num) '${e.key}': (e.value as num).toDouble(),
    });
  }

  static Map<String, String>? _strings(Object? value) {
    if (value is! Map) {
      return null;
    }
    return Map<String, String>.unmodifiable(<String, String>{
      for (final MapEntry<dynamic, dynamic> e in value.entries)
        if (e.value is String) '${e.key}': e.value as String,
    });
  }
}

/// What the Reports module gets: no answers.
class AssessmentSummary {
  const AssessmentSummary({
    required this.assessmentId,
    required this.total,
    required this.bandId,
    required this.areas,
    required this.completedAt,
    this.areaBands,
    this.headline,
    this.headlineBandId,
    this.item9Positive = false,
  });

  factory AssessmentSummary.fromResult(
    AssessmentResult r, {
    bool item9Positive = false,
  }) {
    return AssessmentSummary(
      assessmentId: r.assessmentId,
      total: r.total,
      bandId: r.bandId,
      areas: r.areas,
      areaBands: r.areaBands,
      headline: r.headline,
      headlineBandId: r.headlineBandId,
      completedAt: r.completedAt,
      item9Positive: item9Positive,
    );
  }

  final String assessmentId;
  final double? total;
  final String? bandId;
  final Map<String, double>? areas;
  final Map<String, String>? areaBands;

  /// The total, or for the CBI the highest area (see AssessmentResult).
  final double? headline;
  final String? headlineBandId;
  final DateTime completedAt;

  /// PHQ-9 question 9 was answered above "Not at all". Only the shared PDF
  /// shows this, when the user chooses to share it.
  final bool item9Positive;
}

/// The newest result of one questionnaire and the one before it.
class AssessmentLatest {
  const AssessmentLatest({required this.latest, this.previous});

  final AssessmentSummary latest;
  final AssessmentSummary? previous;
}

/// The WHO-5 part of the first check-in.
class InitialWho5 {
  const InitialWho5({required this.score, required this.completedAt});

  /// 0 to 100.
  final double score;
  final DateTime completedAt;
}
