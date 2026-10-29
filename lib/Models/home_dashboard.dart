import 'check_in_questions.dart';
import 'mood_model.dart';
import 'mood_stats.dart';

/// Which part of the day it is, by the phone's local time. It picks the
/// greeting and the look of the mood card.
enum DayPart {
  /// 05:00 to 11:59.
  morning('Good morning,'),

  /// 12:00 to 16:59.
  afternoon('Good afternoon,'),

  /// 17:00 to 04:59.
  evening('Good evening,');

  const DayPart(this.greeting);

  /// The line above the name.
  final String greeting;

  static DayPart of(DateTime now) {
    final int hour = now.hour;
    if (hour >= 5 && hour < 12) {
      return DayPart.morning;
    }
    if (hour >= 12 && hour < 17) {
      return DayPart.afternoon;
    }
    return DayPart.evening;
  }
}

/// The words in the header of the dashboard.
class HomeText {
  const HomeText._();

  /// "Suggested for tonight" from 18:00, otherwise "Suggested for you".
  static String suggestionHeading(DateTime now) {
    return now.hour >= 18 ? 'Suggested for tonight' : 'Suggested for you';
  }

  /// Two letters for the photo circle: the first letters of the first and
  /// last words of the name. One letter for a single word, "U" for none.
  static String initials(String? name) {
    final List<String> words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return 'U';
    }
    final String first = _firstLetter(words.first);
    if (words.length == 1) {
      return first;
    }
    return '$first${_firstLetter(words.last)}';
  }

  static String _firstLetter(String word) =>
      String.fromCharCode(word.runes.first).toUpperCase();
}

/// What the big card at the top says and offers.
class MoodCardContent {
  const MoodCardContent({
    required this.title,
    required this.buttonLabel,
    required this.loggedToday,
  });

  final String title;
  final String buttonLabel;
  final bool loggedToday;

  /// After 14:00, someone who asked for an after-shift reminder is asked how
  /// they feel after their shift.
  static const int afterShiftHour = 14;

  /// [moodToday] is the name of the latest mood logged today, or null if
  /// there is none.
  static MoodCardContent of({
    required String? moodToday,
    required String reminderPreference,
    required DateTime now,
  }) {
    if (moodToday != null && moodToday.trim().isNotEmpty) {
      return MoodCardContent(
        title: 'Today you felt ${moodToday.trim().toLowerCase()}.',
        buttonLabel: 'Log again',
        loggedToday: true,
      );
    }

    final bool afterShift =
        reminderPreference == CheckInReminder.afterShift &&
        now.hour >= afterShiftHour;
    return MoodCardContent(
      title: afterShift
          ? 'How are you feeling after your shift?'
          : 'How are you feeling today?',
      buttonLabel: 'Log mood',
      loggedToday: false,
    );
  }
}

/// The word in the third stat tile.
enum WeekWord {
  good('Good'),
  mixed('Mixed'),
  hard('Hard'),
  noData('No data');

  const WeekWord(this.label);

  final String label;
}

class WeekMood {
  const WeekMood._();

  /// The fewest logged days that make a word.
  static const int minDays = 2;

  /// The week so far: the last 7 days, today included. The average of the
  /// day scores is "Good" above 0.5, "Hard" below -0.5 and "Mixed" between.
  /// With fewer than [minDays] logged days there is no word.
  static WeekWord of(Iterable<MoodModel> entries, DateTime now) {
    final DateTime start = MoodStats.addDays(MoodStats.dayOf(now), -6);
    final DateTime end = MoodStats.addDays(MoodStats.dayOf(now), 1);
    final Map<DateTime, double> scores = MoodStats.dayScores(
      entries.where(
        (MoodModel entry) =>
            !entry.date.isBefore(start) && entry.date.isBefore(end),
      ),
    );
    if (scores.length < minDays) {
      return WeekWord.noData;
    }

    final double average =
        scores.values.reduce((double a, double b) => a + b) / scores.length;
    if (average > 0.5) {
      return WeekWord.good;
    }
    if (average < -0.5) {
      return WeekWord.hard;
    }
    return WeekWord.mixed;
  }
}

/// The small speech bubble over the robot.
class HomeBubble {
  const HomeBubble._();

  static const String longShift = 'Long shift? Take a minute';
  static const String welcome = 'Good to see you';

  /// The first line that applies, or null for no bubble:
  ///
  /// 1. The mood streak grew today: "{n} days in a row".
  /// 2. Evening, and no mood logged today: "Long shift? Take a minute".
  /// 3. The first open of the day: "Good to see you".
  ///
  /// [moodLoggedToday] is null while it is not known, which skips rule 2
  /// rather than saying something untrue.
  static String? pick({
    required int streak,
    required bool? moodLoggedToday,
    required DayPart dayPart,
    required bool firstOpenToday,
  }) {
    // A streak of 2 or more that includes today means yesterday was logged
    // too, so today is the day it grew.
    if (moodLoggedToday == true && streak >= 2) {
      return '$streak days in a row';
    }
    if (dayPart == DayPart.evening && moodLoggedToday == false) {
      return longShift;
    }
    if (firstOpenToday) {
      return welcome;
    }
    return null;
  }
}

/// Which animations to play. They run once per app launch.
class HomeIntro {
  HomeIntro._();

  static bool _claimed = false;

  /// True the first time it is asked in an app launch, false after that.
  static bool claim() {
    if (_claimed) {
      return false;
    }
    _claimed = true;
    return true;
  }

  /// For tests.
  static void reset() => _claimed = false;
}

/// One tile of the Explore grid.
class ExploreTile {
  const ExploreTile({
    required this.id,
    required this.title,
    required this.line,
    required this.route,
    required this.isLive,
  });

  final ExploreId id;
  final String title;

  /// The second line: a fact, or "Coming soon".
  final String line;
  final String route;

  /// False when the module behind it is not built: the tile is shown faded and
  /// does nothing.
  final bool isLive;
}

enum ExploreId {
  mood,
  journal,
  meditation,
  aiChat,
  checkIns,
  reports,
  takeABreak,
  emotionCheck,
}

class ExploreTiles {
  const ExploreTiles._();

  static const String comingSoon = 'Coming soon';

  /// The tiles in grid order. [routeExists] says whether a screen is
  /// registered for a route; a tile whose route has none is "Coming soon".
  /// [moodLoggedToday] and [practiceCount] are null while unknown.
  static List<ExploreTile> build({
    required bool Function(String route) routeExists,
    required Map<ExploreId, String> routes,
    bool? moodLoggedToday,
    int? practiceCount,
  }) {
    ExploreTile tile(ExploreId id, String title, String line) {
      final String route = routes[id] ?? '';
      final bool live = route.isNotEmpty && routeExists(route);
      return ExploreTile(
        id: id,
        title: title,
        line: live ? line : comingSoon,
        route: route,
        isLive: live,
      );
    }

    return <ExploreTile>[
      tile(
        ExploreId.mood,
        'Mood',
        moodLoggedToday == null
            ? 'Track how you feel'
            : moodLoggedToday
            ? 'Logged today'
            : 'Not logged yet',
      ),
      tile(ExploreId.journal, 'Journal', 'Write it out'),
      tile(
        ExploreId.meditation,
        'Meditation',
        practiceCount == null
            ? 'Guided practices'
            : '$practiceCount guided practices',
      ),
      tile(ExploreId.aiChat, 'AI chat', 'Talk it through'),
      tile(ExploreId.checkIns, 'Check-ins', '6 self-assessments'),
      tile(ExploreId.reports, 'Reports', 'Your week and month'),
      tile(ExploreId.takeABreak, 'Take a break', '3 calm activities'),
      tile(ExploreId.emotionCheck, 'Emotion check', 'With your camera'),
    ];
  }
}
