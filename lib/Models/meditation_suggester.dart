import 'meditation_models.dart';
import 'mood_catalog.dart';
import 'mood_model.dart';

/// The practice shown in "Suggested for you", and why.
class MeditationSuggestion {
  const MeditationSuggestion({required this.session, required this.reason});

  final MeditationSession session;

  /// Second line of the card, e.g. "You logged Stressed today".
  final String reason;
}

/// Picks the practice for the "Suggested for you" card. The first rule that
/// matches wins:
///
/// 1. Latest mood today is in the hard group with Strong intensity:
///    the self-compassion break.
/// 2. Latest mood today is in the hard group: 5-4-3-2-1 senses.
/// 3. Latest mood today is Tired or Restless: the 3-step pause.
/// 4. It is between 21:00 and 05:00: the sleep wind-down.
/// 5. Otherwise the guided practice finished least often.
///
/// A rule is skipped if the practice it names is not in the content.
class MeditationSuggester {
  const MeditationSuggester._();

  static const String selfCompassionId = 'self_compassion_break';
  static const String sensesId = 'senses_54321';
  static const String threeStepPauseId = 'three_step_pause';
  static const String sleepWindDownId = 'sleep_wind_down';

  static const String windingDownReason = 'Winding down';
  static const String somethingNewReason = 'Something new';

  /// Whether [now] is between 21:00 and 05:00.
  static bool isNight(DateTime now) => now.hour >= 21 || now.hour < 5;

  /// [sessions] is every practice; breathing practices are never suggested.
  /// [completedCounts] is how often each was finished, by session id.
  /// [latestMoodToday] is the newest mood entry of today, if any.
  static MeditationSuggestion? suggest({
    required List<MeditationSession> sessions,
    required DateTime now,
    Map<String, int> completedCounts = const <String, int>{},
    MoodModel? latestMoodToday,
  }) {
    final List<MeditationSession> guided = sessions
        .where((MeditationSession session) => !session.isBreathing)
        .toList(growable: false);

    MeditationSession? byId(String id) {
      for (final MeditationSession session in guided) {
        if (session.id == id) {
          return session;
        }
      }
      return null;
    }

    final List<_Rule> rules = <_Rule>[];
    final MoodModel? mood = latestMoodToday;
    if (mood != null) {
      final String reason = 'You logged ${mood.mood} today';
      if (mood.group == MoodGroup.hard) {
        if (mood.intensity == MoodCatalog.strong) {
          rules.add(_Rule(selfCompassionId, reason));
        }
        rules.add(_Rule(sensesId, reason));
      }
      if (mood.mood == 'Tired' || mood.mood == 'Restless') {
        rules.add(_Rule(threeStepPauseId, reason));
      }
    }
    if (isNight(now)) {
      rules.add(const _Rule(sleepWindDownId, windingDownReason));
    }

    for (final _Rule rule in rules) {
      final MeditationSession? session = byId(rule.sessionId);
      if (session != null) {
        return MeditationSuggestion(session: session, reason: rule.reason);
      }
    }

    // Rule 5: the practice finished least often. Ties keep the file order.
    MeditationSession? leastDone;
    int leastCount = 0;
    for (final MeditationSession session in guided) {
      final int count = completedCounts[session.id] ?? 0;
      if (leastDone == null || count < leastCount) {
        leastDone = session;
        leastCount = count;
      }
    }
    if (leastDone == null) {
      return null;
    }
    return MeditationSuggestion(session: leastDone, reason: somethingNewReason);
  }
}

class _Rule {
  const _Rule(this.sessionId, this.reason);

  final String sessionId;
  final String reason;
}
