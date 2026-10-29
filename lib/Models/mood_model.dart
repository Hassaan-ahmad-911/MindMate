import 'package:cloud_firestore/cloud_firestore.dart';

import 'mood_catalog.dart';

class MoodModel {
  const MoodModel({
    this.id = '',
    required this.mood,
    required this.valence,
    required this.intensity,
    this.factors = const <String>[],
    required this.note,
    required this.date,
  });

  /// Builds a new entry for [mood], taking its score from the catalog.
  factory MoodModel.create({
    required MoodDefinition mood,
    required String intensity,
    required List<String> factors,
    required String note,
  }) {
    return MoodModel(
      mood: mood.name,
      valence: mood.valence,
      intensity: intensity,
      factors: List<String>.unmodifiable(factors),
      note: note,
      date: DateTime.now(),
    );
  }

  /// Firestore document id. Empty until the entry is saved.
  final String id;
  final String mood;

  /// Mood score from -2 to +2. Charts and averages use this, never intensity.
  final int valence;

  /// "Mild", "Moderate" or "Strong".
  final String intensity;
  final List<String> factors;
  final String note;
  final DateTime date;

  MoodGroup get group => MoodCatalog.groupForValence(valence);

  /// e.g. "Mild · Sleep, Family".
  String get detailLabel {
    if (factors.isEmpty) {
      return intensity;
    }
    return '$intensity · ${factors.join(', ')}';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'mood': mood,
      'valence': valence,
      'intensity': intensity,
      'factors': factors,
      'note': note,
    };
  }

  factory MoodModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final String mood = MoodCatalog.normalizeName(
      map['mood']?.toString() ?? '',
    );
    final Object? storedValence = map['valence'];

    return MoodModel(
      id: id,
      mood: mood,
      valence: storedValence is num
          ? storedValence.round().clamp(-2, 2)
          : MoodCatalog.valenceFor(mood),
      intensity: MoodCatalog.normalizeIntensity(map['intensity']),
      factors: _readFactors(map['factors']),
      note: map['note']?.toString() ?? '',
      date: _readDate(map),
    );
  }

  MoodModel copyWith({String? id, String? note, DateTime? date}) {
    return MoodModel(
      id: id ?? this.id,
      mood: mood,
      valence: valence,
      intensity: intensity,
      factors: factors,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }

  static List<String> _readFactors(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(
      value
          .map((Object? item) => item?.toString() ?? '')
          .where((String item) => item.trim().isNotEmpty),
    );
  }

  static DateTime _readDate(Map<String, dynamic> map) {
    final dynamic dateValue = map['createdAt'] ?? map['date'];
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    }
    if (dateValue is DateTime) {
      return dateValue;
    }
    if (dateValue is String) {
      final DateTime? parsed = DateTime.tryParse(dateValue);
      if (parsed != null) {
        return parsed;
      }
    }
    return DateTime.now();
  }
}
