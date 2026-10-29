import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/profile_repository.dart';
import 'package:mindmate/Models/check_in_planner.dart';
import 'package:mindmate/Models/check_in_questions.dart';
import 'package:mindmate/Models/check_in_result.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/Models/who5_items.dart';
import 'package:mindmate/ui/check_in/check_in_viewmodel.dart';

import 'helpers/meditation_fakes.dart';
import 'helpers/profile_fakes.dart';

void main() {
  group('WHO-5 scoring', () {
    test('adds up five answers, 0 to 25, and multiplies by 4', () {
      expect(Who5.rawScore(<int?>[5, 5, 5, 5, 5]), 25);
      expect(Who5.rawScore(<int?>[0, 0, 0, 0, 0]), 0);
      expect(Who5.rawScore(<int?>[3, 4, 2, 5, 1]), 15);
      expect(Who5.standardizedScore(<int?>[5, 5, 5, 5, 5]), 100);
      expect(Who5.standardizedScore(<int?>[0, 0, 0, 0, 0]), 0);
      expect(Who5.standardizedScore(<int?>[3, 4, 2, 5, 1]), 60);
    });

    test('has no score if any item was skipped', () {
      expect(Who5.rawScore(<int?>[5, 5, null, 5, 5]), isNull);
      expect(Who5.standardizedScore(<int?>[5, 5, null, 5, 5]), isNull);
      expect(Who5.rawScore(<int?>[null, null, null, null, null]), isNull);
    });

    test('has no score for a wrong number of items or a wrong answer', () {
      expect(Who5.rawScore(<int?>[5, 5, 5, 5]), isNull);
      expect(Who5.rawScore(<int?>[5, 5, 5, 5, 5, 5]), isNull);
      expect(Who5.rawScore(<int?>[6, 0, 0, 0, 0]), isNull);
      expect(Who5.rawScore(<int?>[-1, 0, 0, 0, 0]), isNull);
    });

    test('has the five items worded as in the WHO-5', () {
      expect(Who5.items, hasLength(5));
      expect(Who5.items.first, 'I have felt cheerful and in good spirits.');
      expect(Who5.items[1], 'I have felt calm and relaxed.');
    });
  });

  group('The nine questions', () {
    final List<CheckInQuestion> all = CheckInQuestions.all;

    test('are nine, in the agreed order', () {
      expect(all, hasLength(9));
      expect(all[0].kind, CheckInQuestionKind.goals);
      expect(
        all.sublist(1, 6).every((q) => q.kind == CheckInQuestionKind.who5),
        isTrue,
      );
      expect(all[6].kind, CheckInQuestionKind.workStress);
      expect(all[7].kind, CheckInQuestionKind.sleepQuality);
      expect(all[8].kind, CheckInQuestionKind.reminder);
    });

    test('start with what brings the user here, to pick any of five', () {
      expect(all[0].title, 'What brings you here?');
      expect(all[0].multiSelect, isTrue);
      expect(all[0].options.map((o) => o.label).toList(), <String>[
        'Manage stress',
        'Sleep better',
        'Switch off after work',
        'Feel less drained',
        'Just curious',
      ]);
      expect(all.skip(1).every((q) => !q.multiSelect), isTrue);
    });

    test('use the WHO-5 wording exactly, under one heading', () {
      for (int i = 0; i < 5; i += 1) {
        expect(all[1 + i].title, Who5.items[i]);
        expect(all[1 + i].eyebrow, 'Over the last two weeks');
        expect(all[1 + i].who5Index, i);
      }
    });

    test('score the WHO-5 answers 5 down to 0', () {
      final List<CheckInOption> options = all[1].options;
      expect(options.map((o) => o.label).toList(), <String>[
        'All of the time',
        'Most of the time',
        'More than half the time',
        'Less than half the time',
        'Some of the time',
        'At no time',
      ]);
      expect(options.map((o) => o.value).toList(), <Object>[5, 4, 3, 2, 1, 0]);
    });

    test('score stress and sleep from 0 to 4', () {
      expect(all[6].options.map((o) => o.label).toList(), <String>[
        'Not at all',
        'A little',
        'Moderately',
        'Very',
        'Extremely',
      ]);
      expect(all[6].options.map((o) => o.value).toList(), <Object>[
        0,
        1,
        2,
        3,
        4,
      ]);
      expect(all[7].options.map((o) => o.label).toList(), <String>[
        'Very poorly',
        'Poorly',
        'Okay',
        'Well',
        'Very well',
      ]);
      expect(all[7].options.map((o) => o.value).toList(), <Object>[
        0,
        1,
        2,
        3,
        4,
      ]);
    });

    test('store the reminder choice as a key', () {
      expect(all[8].options.map((o) => o.value).toList(), <Object>[
        'before_shift',
        'after_shift',
        'evening',
        'none',
      ]);
    });
  });

  group('The result', () {
    List<Object?> answers({
      Object? goals = const <String>['Manage stress'],
      List<Object?> who5 = const <Object?>[4, 3, 3, 2, 5],
      Object? stress = 3,
      Object? sleep = 2,
      Object? reminder = 'after_shift',
    }) {
      return <Object?>[goals, ...who5, stress, sleep, reminder];
    }

    test('works out the WHO-5 score when all five were answered', () {
      final CheckInResult result = CheckInResult.fromAnswers(answers());
      expect(result.who5Answers, <int?>[4, 3, 3, 2, 5]);
      expect(result.who5Raw, 17);
      expect(result.who5Score, 68);
      expect(result.workStress, 3);
      expect(result.sleepQuality, 2);
      expect(result.reminderPreference, 'after_shift');
      expect(result.goals, <String>['Manage stress']);
    });

    test('stores a skipped question as null, and never guesses', () {
      final CheckInResult result = CheckInResult.fromAnswers(
        answers(
          goals: null,
          who5: <Object?>[4, null, 3, 2, 5],
          stress: null,
          sleep: null,
          reminder: null,
        ),
      );
      expect(result.goals, isEmpty);
      expect(result.who5Answers, <int?>[4, null, 3, 2, 5]);
      expect(result.who5Raw, isNull);
      expect(result.who5Score, isNull);
      expect(result.workStress, isNull);
      expect(result.sleepQuality, isNull);
      expect(result.reminderPreference, isNull);
    });

    test('is saved in the agreed shape', () {
      final Map<String, dynamic> map = CheckInResult.fromAnswers(
        answers(),
      ).toMap();
      expect(map['type'], 'initial');
      expect(map['goals'], <String>['Manage stress']);
      expect(map['who5Answers'], <int?>[4, 3, 3, 2, 5]);
      expect(map['who5Raw'], 17);
      expect(map['who5Score'], 68);
      expect(map['workStress'], 3);
      expect(map['sleepQuality'], 2);
    });

    test('leaves the WHO-5 numbers out when an item was skipped', () {
      final Map<String, dynamic> map = CheckInResult.fromAnswers(
        answers(who5: <Object?>[4, 3, null, 2, 5], stress: null),
      ).toMap();
      expect(map.containsKey('who5Raw'), isFalse);
      expect(map.containsKey('who5Score'), isFalse);
      expect(map['who5Answers'], <int?>[4, 3, null, 2, 5]);
      expect(map.containsKey('workStress'), isTrue);
      expect(map['workStress'], isNull);
    });
  });

  group('Your focus', () {
    CheckInFocus focus({
      List<String> goals = const <String>[],
      int? sleep,
      int? stress,
    }) => CheckInPlanner.focusFor(
      goals: goals,
      sleepQuality: sleep,
      workStress: stress,
    );

    test('1: poor sleep, or the goal to sleep better', () {
      expect(focus(sleep: 0), CheckInFocus.sleepAndSwitchOff);
      expect(focus(sleep: 1), CheckInFocus.sleepAndSwitchOff);
      expect(
        focus(goals: <String>['Sleep better']),
        CheckInFocus.sleepAndSwitchOff,
      );
      expect(
        CheckInFocus.sleepAndSwitchOff.title,
        'Sleep and switching off after shifts',
      );
    });

    test('2: high work stress, or the goal to manage stress', () {
      expect(focus(stress: 3), CheckInFocus.easingStress);
      expect(focus(stress: 4), CheckInFocus.easingStress);
      expect(
        focus(goals: <String>['Manage stress']),
        CheckInFocus.easingStress,
      );
      expect(CheckInFocus.easingStress.title, 'Easing work stress');
    });

    test('3: the goal to feel less drained', () {
      expect(focus(goals: <String>['Feel less drained']), CheckInFocus.energy);
      expect(CheckInFocus.energy.title, 'Getting your energy back');
    });

    test('4: otherwise a daily habit', () {
      expect(focus(), CheckInFocus.dailyHabit);
      expect(
        focus(goals: <String>['Just curious', 'Switch off after work']),
        CheckInFocus.dailyHabit,
      );
      expect(focus(sleep: 2, stress: 2), CheckInFocus.dailyHabit);
      expect(focus(sleep: 4, stress: 0), CheckInFocus.dailyHabit);
      expect(CheckInFocus.dailyHabit.title, 'Building a daily check-in habit');
    });

    test('the first rule that matches wins', () {
      expect(
        focus(sleep: 1, stress: 4, goals: <String>['Manage stress']),
        CheckInFocus.sleepAndSwitchOff,
      );
      expect(
        focus(stress: 3, goals: <String>['Feel less drained']),
        CheckInFocus.easingStress,
      );
      expect(
        focus(goals: <String>['Manage stress', 'Sleep better']),
        CheckInFocus.sleepAndSwitchOff,
      );
      expect(
        focus(
          sleep: 3,
          stress: 2,
          goals: <String>['Feel less drained', 'Just curious'],
        ),
        CheckInFocus.energy,
      );
    });

    test('a skipped sleep or stress question does not count either way', () {
      expect(focus(sleep: null, stress: null), CheckInFocus.dailyHabit);
      expect(
        focus(sleep: null, goals: <String>['Manage stress']),
        CheckInFocus.easingStress,
      );
    });

    test('each focus suggests its two practices', () {
      expect(
        CheckInPlanner.practicesFor(CheckInFocus.sleepAndSwitchOff),
        <String>['sleep_wind_down', 'leaving_work'],
      );
      expect(CheckInPlanner.practicesFor(CheckInFocus.easingStress), <String>[
        'three_step_pause',
        'senses_54321',
      ]);
      expect(CheckInPlanner.practicesFor(CheckInFocus.energy), <String>[
        'kindness_for_carers',
        'release_the_tension',
      ]);
      expect(CheckInPlanner.practicesFor(CheckInFocus.dailyHabit), <String>[
        'three_step_pause',
        'calm_place',
      ]);
    });

    test('the plan puts the focus and its practices together', () {
      final CheckInPlan plan = CheckInPlanner.plan(
        goals: <String>['Manage stress'],
        sleepQuality: 3,
      );
      expect(plan.focus, CheckInFocus.easingStress);
      expect(plan.practiceIds, <String>['three_step_pause', 'senses_54321']);
    });

    test('"Do this later" gives the habit focus and no support line', () {
      final CheckInPlan plan = CheckInPlanner.skippedPlan();
      expect(plan.focus, CheckInFocus.dailyHabit);
      expect(plan.showSupportLine, isFalse);
      expect(plan.practiceIds, <String>['three_step_pause', 'calm_place']);
    });
  });

  group('The gentle line about talking to someone', () {
    test('shows at a WHO-5 score of 28 or below', () {
      expect(CheckInPlanner.showsSupportLine(0), isTrue);
      expect(CheckInPlanner.showsSupportLine(12), isTrue);
      expect(CheckInPlanner.showsSupportLine(28), isTrue);
    });

    test('is hidden above 28', () {
      expect(CheckInPlanner.showsSupportLine(29), isFalse);
      expect(CheckInPlanner.showsSupportLine(32), isFalse);
      expect(CheckInPlanner.showsSupportLine(100), isFalse);
    });

    test('is hidden when there is no score', () {
      expect(CheckInPlanner.showsSupportLine(null), isFalse);
    });

    test('uses the agreed wording, with no labels', () {
      expect(
        CheckInPlanner.supportLine,
        'It sounds like things have been heavy lately. If it stays this way, '
        'talking to someone you trust or a professional can help.',
      );
      expect(
        CheckInPlanner.supportLine.toLowerCase(),
        isNot(contains('depress')),
      );
      expect(
        CheckInPlanner.supportLine.toLowerCase(),
        isNot(contains('score')),
      );
    });

    test('follows the WHO-5 answers of the check-in', () {
      CheckInPlan planFor(List<Object?> who5) {
        final CheckInResult result = CheckInResult.fromAnswers(<Object?>[
          const <String>[],
          ...who5,
          null,
          null,
          null,
        ]);
        return CheckInPlanner.plan(who5Score: result.who5Score);
      }

      // 7 / 25 -> 28: shown.
      expect(planFor(<Object?>[2, 1, 1, 2, 1]).showSupportLine, isTrue);
      // 8 / 25 -> 32: hidden.
      expect(planFor(<Object?>[2, 2, 1, 2, 1]).showSupportLine, isFalse);
      // One item skipped: no score, so no line.
      expect(planFor(<Object?>[0, 0, null, 0, 0]).showSupportLine, isFalse);
    });
  });

  group('Daily mood check-in line', () {
    test('names the reminder the user chose', () {
      expect(
        CheckInPlanner.reminderLine('after_shift'),
        'Reminder after your shift, 8:00 pm',
      );
      expect(
        CheckInPlanner.reminderLine('before_shift'),
        startsWith('Reminder before your shift'),
      );
      expect(
        CheckInPlanner.reminderLine('evening'),
        startsWith('Reminder in the evening'),
      );
    });

    test('has no time for "No reminders" or a skipped question', () {
      expect(CheckInPlanner.reminderLine('none'), 'No reminder set');
      expect(CheckInPlanner.reminderLine(null), isNot(contains(':')));
      expect(CheckInPlanner.reminderLine('none'), isNot(contains(':')));
    });
  });

  group('The check-in flow', () {
    late FakeProfileService service;
    late CheckInViewModel vm;

    CheckInViewModel open() {
      service = FakeProfileService(
        profile: const UserProfile(
          uid: 'uid-1',
          name: 'Ayesha Khan',
          email: 'a@example.com',
          imageUrl: '',
          bio: '',
          age: 29,
          gender: 'Female',
        ),
      );
      return vm = Get.put<CheckInViewModel>(
        CheckInViewModel(
          ProfileRepository(service),
          buildRepository(FakeLogService()),
        ),
      );
    }

    CheckInOption option(String label) =>
        vm.question.options.firstWhere((CheckInOption o) => o.label == label);

    setUp(() {
      Get.testMode = true;
    });

    tearDown(() {
      Get.reset();
    });

    test('knows the first name for the welcome', () async {
      open();
      await pumpEventQueue();
      expect(vm.firstName.value, 'Ayesha');
    });

    test('needs an answer before Next', () {
      open();
      expect(vm.hasAnswer, isFalse);
      vm.next();
      expect(vm.index.value, 0, reason: 'Next does nothing without an answer');

      vm.select(option('Sleep better'));
      expect(vm.hasAnswer, isTrue);
      vm.next();
      expect(vm.index.value, 1);
    });

    test('lets the goals be picked and unpicked', () {
      open();
      vm.select(option('Manage stress'));
      vm.select(option('Sleep better'));
      expect(vm.isSelected(option('Manage stress')), isTrue);
      expect(vm.isSelected(option('Sleep better')), isTrue);

      vm.select(option('Manage stress'));
      expect(vm.isSelected(option('Manage stress')), isFalse);
      expect(vm.isSelected(option('Sleep better')), isTrue);

      vm.select(option('Sleep better'));
      expect(vm.hasAnswer, isFalse, reason: 'nothing is picked now');
    });

    test('lets one answer be chosen, and changed', () {
      open();
      vm.skip();
      vm.select(option('Most of the time'));
      expect(vm.isSelected(option('Most of the time')), isTrue);
      vm.select(option('At no time'));
      expect(vm.isSelected(option('Most of the time')), isFalse);
      expect(vm.isSelected(option('At no time')), isTrue);
    });

    test('Back keeps the answer of the question before', () {
      open();
      vm.select(option('Manage stress'));
      vm.next();
      vm.select(option('Some of the time'));
      vm.next();
      expect(vm.index.value, 2);

      vm.back();
      expect(vm.index.value, 1);
      expect(vm.isSelected(option('Some of the time')), isTrue);

      vm.back();
      expect(vm.index.value, 0);
      expect(vm.isSelected(option('Manage stress')), isTrue);
    });

    test('Skip leaves the question empty and goes on', () {
      open();
      vm.select(option('Manage stress'));
      vm.skip();
      expect(vm.index.value, 1);
      vm.skip();
      expect(vm.index.value, 2);
      expect(vm.answers[0], isNull, reason: 'the skipped goals are cleared');
      expect(vm.answers[1], isNull);
    });

    test('Skip clears an answer that was already chosen', () {
      open();
      vm.skip();
      vm.select(option('Most of the time'));
      vm.skip();
      vm.back();
      expect(vm.hasAnswer, isFalse);
    });

    test('finishing saves the answers and marks the check-in done', () async {
      open();
      // 1: goals
      vm.select(option('Manage stress'));
      vm.next();
      // 2 to 6: WHO-5, 4 3 3 2 5
      for (final String label in <String>[
        'Most of the time',
        'More than half the time',
        'More than half the time',
        'Less than half the time',
        'All of the time',
      ]) {
        vm.select(option(label));
        vm.next();
      }
      // 7: stress, 8: sleep, 9: reminder
      vm.select(option('Very'));
      vm.next();
      vm.skip();
      vm.select(option('After my shift'));
      expect(vm.isLastQuestion, isTrue);
      vm.next();
      await pumpEventQueue();

      expect(service.checkIns, hasLength(1));
      final CheckInResult saved = service.checkIns.single;
      expect(saved.goals, <String>['Manage stress']);
      expect(saved.who5Answers, <int?>[4, 3, 3, 2, 5]);
      expect(saved.who5Score, 68);
      expect(saved.workStress, 3);
      expect(saved.sleepQuality, isNull, reason: 'it was skipped');
      expect(saved.reminderPreference, 'after_shift');

      expect(vm.answeredCheckIn.value, isTrue);
      expect(vm.plan.value?.focus, CheckInFocus.easingStress);
      expect(vm.plan.value?.showSupportLine, isFalse);
    });

    test('suggests three starting points, with the reminder', () async {
      open();
      vm.select(option('Sleep better'));
      vm.next();
      for (int i = 0; i < 5; i += 1) {
        vm.skip();
      }
      vm.skip();
      vm.skip();
      vm.select(option('After my shift'));
      vm.next();
      await pumpEventQueue();

      expect(vm.plan.value?.focus, CheckInFocus.sleepAndSwitchOff);
      expect(
        vm.startingPoints.map((StartingPoint p) => p.title).toList(),
        <String>[
          'Daily mood check-in',
          'Sleep wind-down',
          'Leaving work at work',
        ],
      );
      expect(
        vm.startingPoints.first.subtitle,
        'Reminder after your shift, 8:00 pm',
      );
      expect(vm.startingPoints[1].session?.id, 'sleep_wind_down');
    });

    test('hides the reminder time for "No reminders"', () async {
      open();
      for (int i = 0; i < 8; i += 1) {
        vm.skip();
      }
      vm.select(option('No reminders'));
      vm.next();
      await pumpEventQueue();

      expect(vm.startingPoints.first.subtitle, 'No reminder set');
    });

    test('adds the gentle line when the WHO-5 answers are low', () async {
      open();
      vm.skip(); // goals
      for (final String label in <String>[
        'Less than half the time', // 2
        'Some of the time', // 1
        'Some of the time', // 1
        'Less than half the time', // 2
        'Some of the time', // 1 -> raw 7, score 28
      ]) {
        vm.select(option(label));
        vm.next();
      }
      vm.skip();
      vm.skip();
      vm.skip();
      await pumpEventQueue();

      expect(service.checkIns.single.who5Score, 28);
      expect(vm.plan.value?.showSupportLine, isTrue);
    });

    test('skipping every question saves an empty check-in', () async {
      open();
      for (int i = 0; i < 9; i += 1) {
        vm.skip();
      }
      await pumpEventQueue();

      final CheckInResult saved = service.checkIns.single;
      expect(saved.goals, isEmpty);
      expect(saved.who5Answers, <int?>[null, null, null, null, null]);
      expect(saved.who5Score, isNull);
      expect(saved.workStress, isNull);
      expect(saved.sleepQuality, isNull);
      expect(saved.reminderPreference, isNull);
      expect(vm.plan.value?.focus, CheckInFocus.dailyHabit);
      expect(vm.plan.value?.showSupportLine, isFalse);
    });

    test(
      '"Do this later" saves nothing and suggests the habit focus',
      () async {
        open();
        await vm.doLater();

        expect(service.checkIns, isEmpty);
        expect(service.statusUpdates, isEmpty, reason: 'it stays pending');
        expect(vm.answeredCheckIn.value, isFalse);
        expect(vm.plan.value?.focus, CheckInFocus.dailyHabit);
        expect(
          vm.startingPoints.map((StartingPoint p) => p.title).toList(),
          <String>['Daily mood check-in', 'The 3-step pause', 'A calm place'],
        );
      },
    );

    test('still shows All set if the answers cannot be saved', () async {
      open();
      service.failWith = StateError('offline');
      for (int i = 0; i < 9; i += 1) {
        vm.skip();
      }
      await pumpEventQueue();

      expect(service.checkIns, isEmpty);
      expect(vm.plan.value, isNotNull);
    });

    test('does not finish twice', () async {
      open();
      for (int i = 0; i < 9; i += 1) {
        vm.skip();
      }
      await vm.finish();
      await pumpEventQueue();
      expect(service.checkIns, hasLength(1));
    });
  });
}
