import 'package:cloud_firestore/cloud_firestore.dart';

/// The three "Take a break" activities.
enum BreakActivity {
  breathingBubble('breathing_bubble'),
  calmMatch('calm_match'),
  gratitudeGarden('gratitude_garden');

  const BreakActivity(this.id);

  /// What is stored in Firestore.
  final String id;

  static BreakActivity? fromId(Object? id) {
    for (final BreakActivity activity in BreakActivity.values) {
      if (activity.id == id) {
        return activity;
      }
    }
    return null;
  }
}

/// One short break: `users/{uid}/breaks/{id}`. It records that a break
/// happened and for how long. It never holds turns, scores or anything typed.
class BreakLogEntry {
  const BreakLogEntry({
    required this.id,
    required this.activity,
    required this.startedAt,
    required this.seconds,
    required this.completed,
  });

  final String id;
  final BreakActivity activity;
  final DateTime startedAt;
  final int seconds;

  /// True when a round or game was finished (or today's flower planted).
  final bool completed;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'activity': activity.id,
      'startedAt': Timestamp.fromDate(startedAt),
      'seconds': seconds,
      'completed': completed,
    };
  }

  /// Null when the document is not a break this app understands.
  static BreakLogEntry? fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final BreakActivity? activity = BreakActivity.fromId(map['activity']);
    final Object? started = map['startedAt'];
    final Object? seconds = map['seconds'];
    if (activity == null || started is! Timestamp) {
      return null;
    }
    return BreakLogEntry(
      id: id,
      activity: activity,
      startedAt: started.toDate(),
      seconds: seconds is num ? seconds.round() : 0,
      completed: map['completed'] == true,
    );
  }
}

/// Counting breaks for the hub footer.
class BreakStats {
  const BreakStats._();

  /// "This week" is the last seven days up to [now].
  static DateTime weekStart(DateTime now) =>
      now.subtract(const Duration(days: 7));

  /// How many of [startedAt] fall inside the last seven days.
  static int countThisWeek(Iterable<DateTime> startedAt, DateTime now) {
    final DateTime start = weekStart(now);
    int count = 0;
    for (final DateTime time in startedAt) {
      if (!time.isBefore(start)) {
        count += 1;
      }
    }
    return count;
  }

  /// "4 breaks taken this week" (or the first-break wording).
  static String footerLine(int count) {
    if (count <= 0) {
      return 'A few minutes for yourself counts.';
    }
    final String breaks = count == 1 ? 'break' : 'breaks';
    return '$breaks taken this week. A few minutes for yourself counts.';
  }
}
