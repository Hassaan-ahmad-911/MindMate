import 'package:cloud_firestore/cloud_firestore.dart';

import 'meditation_feeling.dart';

/// One practice done by the user: `users/{uid}/meditation_sessions/{id}`.
class MeditationLogEntry {
  const MeditationLogEntry({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.secondsPractised,
    required this.completed,
    this.feelBefore,
    this.feelAfter,
  });

  final String id;

  /// The id from the content file (or a breathing practice's id).
  final String sessionId;

  /// Stored so the history still reads well if the content changes.
  final String title;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Time actually practised, not counting pauses.
  final int secondsPractised;

  /// True only if the last step finished.
  final bool completed;

  /// How the user felt before and after, 1 (very low) to 5 (very good).
  final int? feelBefore;
  final int? feelAfter;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'title': title,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': Timestamp.fromDate(endedAt),
      'secondsPractised': secondsPractised,
      'completed': completed,
      'feelBefore': feelBefore,
      'feelAfter': feelAfter,
    };
  }

  factory MeditationLogEntry.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final DateTime startedAt = _readDate(map['startedAt']) ?? DateTime.now();
    final Object? seconds = map['secondsPractised'];

    return MeditationLogEntry(
      id: id,
      sessionId: map['sessionId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      startedAt: startedAt,
      endedAt: _readDate(map['endedAt']) ?? startedAt,
      secondsPractised: seconds is num ? seconds.round() : 0,
      completed: map['completed'] == true,
      feelBefore: MeditationFeeling.parse(map['feelBefore']),
      feelAfter: MeditationFeeling.parse(map['feelAfter']),
    );
  }

  MeditationLogEntry copyWith({int? feelAfter}) {
    return MeditationLogEntry(
      id: id,
      sessionId: sessionId,
      title: title,
      startedAt: startedAt,
      endedAt: endedAt,
      secondsPractised: secondsPractised,
      completed: completed,
      feelBefore: feelBefore,
      feelAfter: feelAfter ?? this.feelAfter,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
