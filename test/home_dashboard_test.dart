import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/home_dashboard.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/Models/support_contacts.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/home/widgets/animated_name.dart';

import 'helpers/home_fakes.dart';

DateTime at(int hour, [int minute = 0]) => DateTime(2026, 10, 8, hour, minute);

/// A mood [daysAgo] days before [now], at noon.
MoodModel moodDaysAgo(DateTime now, int daysAgo, String mood) {
  return moodAt(DateTime(now.year, now.month, now.day - daysAgo, 12), mood);
}

void main() {
  group('The time of day', () {
    test('morning is 05:00 to 11:59', () {
      expect(DayPart.of(at(5)), DayPart.morning);
      expect(DayPart.of(at(11, 59)), DayPart.morning);
    });

    test('afternoon is 12:00 to 16:59', () {
      expect(DayPart.of(at(12)), DayPart.afternoon);
      expect(DayPart.of(at(16, 59)), DayPart.afternoon);
    });

    test('evening is 17:00 to 04:59, midnight included', () {
      expect(DayPart.of(at(17)), DayPart.evening);
      expect(DayPart.of(at(23, 59)), DayPart.evening);
      expect(DayPart.of(at(0)), DayPart.evening);
      expect(DayPart.of(at(4, 59)), DayPart.evening);
    });

    test('the greeting follows it', () {
      expect(DayPart.of(at(8)).greeting, 'Good morning,');
      expect(DayPart.of(at(13)).greeting, 'Good afternoon,');
      expect(DayPart.of(at(19)).greeting, 'Good evening,');
      expect(DayPart.of(at(2)).greeting, 'Good evening,');
    });

    test('the suggestion heading is for tonight from 18:00', () {
      expect(HomeText.suggestionHeading(at(17, 59)), 'Suggested for you');
      expect(HomeText.suggestionHeading(at(18)), 'Suggested for tonight');
      expect(HomeText.suggestionHeading(at(2)), 'Suggested for you');
      expect(HomeText.suggestionHeading(at(9)), 'Suggested for you');
    });
  });

  group('Initials', () {
    test('first and last word of the name', () {
      expect(HomeText.initials('Ayesha Khan'), 'AK');
      expect(HomeText.initials('  ayesha   bint  khan '), 'AK');
    });

    test('one letter for one word, U for nothing', () {
      expect(HomeText.initials('Ayesha'), 'A');
      expect(HomeText.initials(''), 'U');
      expect(HomeText.initials(null), 'U');
      expect(HomeText.initials('   '), 'U');
    });
  });

  group('The mood card', () {
    test('asks how you feel today when nothing is logged', () {
      final MoodCardContent card = MoodCardContent.of(
        moodToday: null,
        reminderPreference: '',
        now: at(10),
      );

      expect(card.title, 'How are you feeling today?');
      expect(card.buttonLabel, 'Log mood');
      expect(card.loggedToday, isFalse);
    });

    test('asks about the shift for an after-shift reminder, after 14:00', () {
      MoodCardContent card(int hour, String preference) => MoodCardContent.of(
        moodToday: null,
        reminderPreference: preference,
        now: at(hour),
      );

      expect(
        card(14, 'after_shift').title,
        'How are you feeling after your shift?',
      );
      expect(
        card(20, 'after_shift').title,
        'How are you feeling after your shift?',
      );
      expect(card(13, 'after_shift').title, 'How are you feeling today?');
      expect(card(15, 'before_shift').title, 'How are you feeling today?');
      expect(card(15, 'evening').title, 'How are you feeling today?');
      expect(card(15, 'none').title, 'How are you feeling today?');
    });

    test('says what you felt once a mood is logged, with Log again', () {
      final MoodCardContent card = MoodCardContent.of(
        moodToday: 'Tired',
        reminderPreference: 'after_shift',
        now: at(20),
      );

      expect(card.title, 'Today you felt tired.');
      expect(card.buttonLabel, 'Log again');
      expect(card.loggedToday, isTrue);
    });
  });

  group('The week so far', () {
    final DateTime now = at(15);

    test('no data with no entries or only one day', () {
      expect(WeekMood.of(<MoodModel>[], now), WeekWord.noData);
      expect(
        WeekMood.of(<MoodModel>[moodDaysAgo(now, 0, 'Happy')], now),
        WeekWord.noData,
      );
    });

    test('several entries on one day are still one day', () {
      final List<MoodModel> entries = <MoodModel>[
        moodAt(DateTime(2026, 10, 8, 8), 'Happy'),
        moodAt(DateTime(2026, 10, 8, 14), 'Happy'),
        moodAt(DateTime(2026, 10, 8, 18), 'Calm'),
      ];

      expect(WeekMood.of(entries, now), WeekWord.noData);
    });

    test('two logged days are enough', () {
      final List<MoodModel> entries = <MoodModel>[
        moodDaysAgo(now, 0, 'Happy'),
        moodDaysAgo(now, 1, 'Happy'),
      ];

      expect(WeekMood.of(entries, now), WeekWord.good);
    });

    test('Good is an average above 0.5', () {
      final List<MoodModel> entries = <MoodModel>[
        moodDaysAgo(now, 0, 'Calm'),
        moodDaysAgo(now, 1, 'Happy'),
        moodDaysAgo(now, 2, 'Okay'),
      ];

      // (1 + 2 + 0) / 3 = 1.0
      expect(WeekMood.of(entries, now), WeekWord.good);
    });

    test('exactly 0.5 is Mixed', () {
      final List<MoodModel> entries = <MoodModel>[
        moodDaysAgo(now, 0, 'Calm'),
        moodDaysAgo(now, 1, 'Okay'),
      ];

      // (1 + 0) / 2 = 0.5
      expect(WeekMood.of(entries, now), WeekWord.mixed);
    });

    test('exactly -0.5 is Mixed', () {
      final List<MoodModel> entries = <MoodModel>[
        moodDaysAgo(now, 0, 'Stressed'),
        moodDaysAgo(now, 1, 'Okay'),
      ];

      // (-1 + 0) / 2 = -0.5
      expect(WeekMood.of(entries, now), WeekWord.mixed);
    });

    test('Hard is an average below -0.5', () {
      final List<MoodModel> entries = <MoodModel>[
        moodDaysAgo(now, 0, 'Sad'),
        moodDaysAgo(now, 1, 'Stressed'),
        moodDaysAgo(now, 2, 'Okay'),
      ];

      // (-2 - 1 + 0) / 3 = -1.0
      expect(WeekMood.of(entries, now), WeekWord.hard);
    });

    test('good and hard days balance out to Mixed', () {
      final List<MoodModel> entries = <MoodModel>[
        moodDaysAgo(now, 0, 'Happy'),
        moodDaysAgo(now, 1, 'Sad'),
      ];

      expect(WeekMood.of(entries, now), WeekWord.mixed);
    });

    test('a day with several entries counts once, as its average', () {
      final List<MoodModel> entries = <MoodModel>[
        moodAt(DateTime(2026, 10, 8, 8), 'Sad'),
        moodAt(DateTime(2026, 10, 8, 9), 'Sad'),
        moodAt(DateTime(2026, 10, 8, 10), 'Sad'),
        moodAt(DateTime(2026, 10, 8, 11), 'Happy'),
        moodDaysAgo(now, 1, 'Happy'),
      ];

      // Today: (-2 - 2 - 2 + 2) / 4 = -1. Yesterday: 2. Mean 0.5 -> Mixed.
      expect(WeekMood.of(entries, now), WeekWord.mixed);
    });

    test('only the last 7 days count', () {
      final List<MoodModel> entries = <MoodModel>[
        moodDaysAgo(now, 0, 'Happy'),
        moodDaysAgo(now, 1, 'Happy'),
        moodDaysAgo(now, 7, 'Sad'),
        moodDaysAgo(now, 20, 'Sad'),
      ];

      expect(WeekMood.of(entries, now), WeekWord.good);
    });

    test('six days back is the oldest day of the week', () {
      final List<MoodModel> entries = <MoodModel>[
        moodDaysAgo(now, 6, 'Happy'),
        moodDaysAgo(now, 0, 'Happy'),
      ];

      expect(WeekMood.of(entries, now), WeekWord.good);
      expect(
        WeekMood.of(<MoodModel>[moodDaysAgo(now, 7, 'Happy'), entries[1]], now),
        WeekWord.noData,
      );
    });

    test('the labels', () {
      expect(WeekWord.good.label, 'Good');
      expect(WeekWord.mixed.label, 'Mixed');
      expect(WeekWord.hard.label, 'Hard');
      expect(WeekWord.noData.label, 'No data');
    });
  });

  group('The speech bubble', () {
    String? pick({
      int streak = 0,
      bool? moodLoggedToday = false,
      DayPart dayPart = DayPart.afternoon,
      bool firstOpenToday = false,
    }) {
      return HomeBubble.pick(
        streak: streak,
        moodLoggedToday: moodLoggedToday,
        dayPart: dayPart,
        firstOpenToday: firstOpenToday,
      );
    }

    test('a streak that grew today says how long', () {
      expect(pick(streak: 5, moodLoggedToday: true), '5 days in a row');
      expect(pick(streak: 2, moodLoggedToday: true), '2 days in a row');
    });

    test('a streak of one is not announced', () {
      expect(pick(streak: 1, moodLoggedToday: true), isNull);
    });

    test('a streak that did not grow today is not announced', () {
      expect(pick(streak: 5, moodLoggedToday: false), isNull);
    });

    test('evening with no mood today offers a minute', () {
      expect(
        pick(dayPart: DayPart.evening, moodLoggedToday: false),
        'Long shift? Take a minute',
      );
    });

    test('evening with a mood logged is quiet', () {
      expect(pick(dayPart: DayPart.evening, moodLoggedToday: true), isNull);
    });

    test('morning and afternoon never say Long shift', () {
      expect(pick(dayPart: DayPart.morning), isNull);
      expect(pick(dayPart: DayPart.afternoon), isNull);
    });

    test('the first open of the day says good to see you', () {
      expect(pick(firstOpenToday: true), 'Good to see you');
    });

    test('rules apply in order: streak, then evening, then first open', () {
      expect(
        pick(
          streak: 3,
          moodLoggedToday: true,
          dayPart: DayPart.evening,
          firstOpenToday: true,
        ),
        '3 days in a row',
      );
      expect(
        pick(
          dayPart: DayPart.evening,
          moodLoggedToday: false,
          firstOpenToday: true,
        ),
        'Long shift? Take a minute',
      );
    });

    test('when the mood is not known, nothing untrue is said', () {
      expect(pick(dayPart: DayPart.evening, moodLoggedToday: null), isNull);
      expect(
        pick(
          dayPart: DayPart.evening,
          moodLoggedToday: null,
          firstOpenToday: true,
        ),
        'Good to see you',
      );
    });

    test('otherwise there is no bubble', () {
      expect(pick(), isNull);
    });
  });

  group('Once per launch', () {
    setUp(HomeIntro.reset);
    tearDown(HomeIntro.reset);

    test('the intro is claimed once', () {
      expect(HomeIntro.claim(), isTrue);
      expect(HomeIntro.claim(), isFalse);
      expect(HomeIntro.claim(), isFalse);
    });

    test('a new launch can claim again', () {
      HomeIntro.claim();
      HomeIntro.reset();
      expect(HomeIntro.claim(), isTrue);
    });
  });

  group('The name animation', () {
    int start(int index, int count) => AnimatedName.startMillis(
      index: index,
      count: count,
      letterGap: const Duration(milliseconds: 250),
      fade: const Duration(milliseconds: 250),
      maxTotal: const Duration(milliseconds: 1200),
    );

    test('letters come 0.25 seconds apart for a short name', () {
      expect(start(0, 4), 0);
      expect(start(1, 4), 250);
      expect(start(3, 4), 750);
    });

    test(
      'a longer name is squeezed so the last letter ends at 1.2 seconds',
      () {
        // 6 letters: the last one starts at 950 and fades for 250.
        expect(start(0, 6), 0);
        expect(start(5, 6), 950);
        expect(start(1, 6), 190);
      },
    );

    test('a long name still ends within 1.2 seconds', () {
      for (final int count in <int>[8, 12, 20, 40]) {
        final int last = start(count - 1, count);
        expect(last + 250, lessThanOrEqualTo(1200), reason: '$count letters');
      }
    });

    test('one letter starts at once', () {
      expect(start(0, 1), 0);
    });
  });

  group('Explore tiles', () {
    List<ExploreTile> tiles({
      Set<String>? built,
      bool? moodLoggedToday,
      int? practiceCount,
    }) {
      return ExploreTiles.build(
        routeExists: (String route) => built == null || built.contains(route),
        routes: const <ExploreId, String>{
          ExploreId.mood: AppRoutes.moodTracking,
          ExploreId.journal: AppRoutes.journal,
          ExploreId.meditation: AppRoutes.meditation,
          ExploreId.aiChat: AppRoutes.aiChat,
          ExploreId.checkIns: AppRoutes.assessments,
          ExploreId.reports: AppRoutes.reports,
          ExploreId.takeABreak: AppRoutes.games,
          ExploreId.emotionCheck: AppRoutes.emotionCheck,
        },
        moodLoggedToday: moodLoggedToday,
        practiceCount: practiceCount,
      );
    }

    ExploreTile byId(List<ExploreTile> list, ExploreId id) =>
        list.firstWhere((ExploreTile t) => t.id == id);

    test('there are eight, in grid order', () {
      expect(tiles().map((ExploreTile t) => t.title), <String>[
        'Mood',
        'Journal',
        'Meditation',
        'AI chat',
        'Check-ins',
        'Reports',
        'Take a break',
        'Emotion check',
      ]);
    });

    test('with every module built they all say their own line', () {
      final List<ExploreTile> list = tiles(
        moodLoggedToday: true,
        practiceCount: 12,
      );

      expect(list.every((ExploreTile t) => t.isLive), isTrue);
      expect(byId(list, ExploreId.mood).line, 'Logged today');
      expect(byId(list, ExploreId.journal).line, 'Write it out');
      expect(byId(list, ExploreId.meditation).line, '12 guided practices');
      expect(byId(list, ExploreId.aiChat).line, 'Talk it through');
      expect(byId(list, ExploreId.checkIns).line, '6 self-assessments');
      expect(byId(list, ExploreId.reports).line, 'Your week and month');
      expect(byId(list, ExploreId.takeABreak).line, '3 calm activities');
      expect(byId(list, ExploreId.emotionCheck).line, 'With your camera');
    });

    test('the mood line follows what was logged', () {
      expect(
        byId(tiles(moodLoggedToday: false), ExploreId.mood).line,
        'Not logged yet',
      );
      expect(
        byId(tiles(moodLoggedToday: true), ExploreId.mood).line,
        'Logged today',
      );
      expect(byId(tiles(), ExploreId.mood).line, isNot('Not logged yet'));
    });

    test('a missing module is Coming soon and not tappable', () {
      final List<ExploreTile> list = tiles(
        built: <String>{
          AppRoutes.moodTracking,
          AppRoutes.journal,
          AppRoutes.meditation,
          AppRoutes.aiChat,
          AppRoutes.assessments,
          AppRoutes.games,
        },
        practiceCount: 12,
      );

      final ExploreTile reports = byId(list, ExploreId.reports);
      final ExploreTile emotion = byId(list, ExploreId.emotionCheck);
      expect(reports.isLive, isFalse);
      expect(reports.line, 'Coming soon');
      expect(emotion.isLive, isFalse);
      expect(emotion.line, 'Coming soon');
      expect(byId(list, ExploreId.journal).isLive, isTrue);
      expect(byId(list, ExploreId.meditation).line, '12 guided practices');
    });

    test('a route with no screen is Coming soon, whatever the tile says', () {
      final List<ExploreTile> list = tiles(built: <String>{});

      expect(list.every((ExploreTile t) => !t.isLive), isTrue);
      expect(
        list.every((ExploreTile t) => t.line == ExploreTiles.comingSoon),
        isTrue,
      );
    });

    test('a tile with no route at all is Coming soon', () {
      final List<ExploreTile> list = ExploreTiles.build(
        routeExists: (String route) => true,
        routes: const <ExploreId, String>{},
      );

      expect(list.every((ExploreTile t) => !t.isLive), isTrue);
    });
  });

  group('The support page', () {
    test('says MindMate is not an emergency service', () {
      expect(
        SupportContacts.notEmergencyLine,
        'MindMate is not an emergency service.',
      );
    });

    test('has a placeholder list to fill in', () {
      expect(SupportContacts.all, isNotEmpty);
      expect(
        SupportContacts.all.every(
          (SupportContact c) =>
              c.howToReach == SupportContacts.placeholderNumber,
        ),
        isTrue,
      );
    });
  });
}
