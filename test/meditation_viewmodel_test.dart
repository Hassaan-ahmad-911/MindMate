import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/meditation_repository.dart';
import 'package:mindmate/Data/repositories/mood_repository.dart';
import 'package:mindmate/Models/meditation_log_entry.dart';
import 'package:mindmate/Models/meditation_models.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/services/meditation_content_service.dart';
import 'package:mindmate/ui/meditation/meditation_viewmodel.dart';

import 'helpers/meditation_fakes.dart';

void main() {
  // A Wednesday afternoon.
  final DateTime afternoon = DateTime(2026, 10, 7, 14, 30);

  late FakeLogService logService;
  late FakeMoodService moodService;

  MoodModel mood(String name, {String intensity = 'Moderate'}) {
    return MoodModel(
      mood: name,
      valence: name == 'Stressed' ? -1 : 0,
      intensity: intensity,
      note: '',
      date: afternoon,
    );
  }

  Future<MeditationViewModel> open({
    DateTime? now,
    MeditationRepository? repository,
  }) async {
    final MeditationViewModel vm = Get.put<MeditationViewModel>(
      MeditationViewModel(
        repository ?? buildRepository(logService),
        MoodRepository(moodService),
        clock: () => now ?? afternoon,
      ),
    );
    await pumpEventQueue();
    return vm;
  }

  setUp(() {
    Get.testMode = true;
    logService = FakeLogService();
    moodService = FakeMoodService();
  });

  tearDown(() {
    Get.reset();
  });

  group('Loading', () {
    test('lists the guided practices, then the breathing ones', () async {
      final MeditationViewModel vm = await open();

      expect(vm.isLoading.value, isFalse);
      expect(vm.hasLoadError.value, isFalse);
      expect(vm.sessions, hasLength(22));
      expect(vm.sessions.first.id, 'arriving');
      expect(vm.sessions[11].id, 'full_body_scan');
      expect(vm.sessions[12].isBreathing, isTrue);
      expect(vm.sessions.last.isBreathing, isTrue);
    });

    test('has a filter for every group, then Breathing', () async {
      final MeditationViewModel vm = await open();

      expect(
        vm.groups.map((MeditationGroup group) => group.title).toList(),
        <String>[
          'Before a shift',
          'Between patients',
          'When overwhelmed',
          'After a hard moment',
          'After a shift',
          'Before sleep',
          'Any time',
          'Breathing',
        ],
      );
    });

    test('shows an error, then loads when tried again', () async {
      int attempts = 0;
      final MeditationRepository repository = MeditationRepository(
        MeditationContentService(
          loader: () async {
            attempts += 1;
            if (attempts == 1) {
              throw StateError('could not read the file');
            }
            return fileContentLoader();
          },
        ),
        logService,
      );

      final MeditationViewModel vm = await open(repository: repository);
      expect(vm.hasLoadError.value, isTrue);
      expect(vm.isLoading.value, isFalse);
      expect(vm.sessions, isEmpty);

      await vm.load();
      expect(vm.hasLoadError.value, isFalse);
      expect(vm.sessions, hasLength(22));
    });
  });

  group('Filters', () {
    test('show the practices of one group', () async {
      final MeditationViewModel vm = await open();

      vm.selectGroup('on_shift');
      expect(
        vm.visibleSessions.map((MeditationSession s) => s.id).toList(),
        <String>['three_step_pause', 'mindful_hand_washing'],
      );

      vm.selectGroup(MeditationGroup.breathingId);
      expect(vm.visibleSessions, hasLength(10));
      expect(
        vm.visibleSessions.every((MeditationSession s) => s.isBreathing),
        isTrue,
      );

      vm.selectGroup(null);
      expect(vm.visibleSessions, hasLength(22));
    });

    test('look up the title of a practice\'s group', () async {
      final MeditationViewModel vm = await open();

      expect(vm.groupTitleFor(vm.sessions[1]), 'Between patients');
      expect(vm.groupTitleFor(vm.sessions.last), 'Breathing');
    });
  });

  group('This week', () {
    test('shows minutes, practices and the streak', () async {
      DateTime at(int daysAgo, int hour) =>
          DateTime(2026, 10, 7 - daysAgo, hour);
      logService.history = <MeditationLogEntry>[
        logEntry(at(0, 8), seconds: 300),
        logEntry(at(1, 9), seconds: 300),
        logEntry(at(2, 21), seconds: 300),
        logEntry(at(4, 7), seconds: 300),
        logEntry(at(4, 18), seconds: 240),
        logEntry(at(9, 18), seconds: 600), // too long ago
      ];

      final MeditationViewModel vm = await open();

      expect(vm.statsLoaded.value, isTrue);
      expect(vm.minutesThisWeek, 24);
      expect(vm.sessionsThisWeek, 5);
      expect(vm.streak, 3);
    });

    test('are not shown as 0 when the history cannot be loaded', () async {
      logService.failLoading = true;
      final MeditationViewModel vm = await open();

      expect(vm.statsLoaded.value, isFalse);
      expect(vm.suggestion.value, isNotNull, reason: 'it still has a rule');
    });

    test('are updated when a practice is saved', () async {
      final MeditationViewModel vm = await open();
      expect(vm.sessionsThisWeek, 0);

      final MeditationLogEntry entry = logEntry(afternoon, seconds: 125);
      vm.recordLog(entry);
      expect(vm.sessionsThisWeek, 1);
      expect(vm.minutesThisWeek, 2);
      expect(vm.streak, 1);

      // The same practice with how the user felt: replaced, not added twice.
      vm.recordLog(entry.copyWith(feelAfter: 4));
      expect(vm.sessionsThisWeek, 1);
      expect(vm.logs.single.feelAfter, 4);
    });
  });

  group('Suggested for you', () {
    test('uses the latest mood of today', () async {
      moodService.todayMood = mood('Stressed', intensity: 'Strong');
      final MeditationViewModel vm = await open();

      expect(vm.suggestion.value?.session.id, 'self_compassion_break');
      expect(vm.suggestion.value?.reason, 'You logged Stressed today');
    });

    test('goes by the time of day when there is no mood', () async {
      final MeditationViewModel night = await open(
        now: DateTime(2026, 10, 7, 22, 15),
      );
      expect(night.suggestion.value?.session.id, 'sleep_wind_down');
      expect(night.suggestion.value?.reason, 'Winding down');
    });

    test('falls back to the practice finished least often', () async {
      logService.history = <MeditationLogEntry>[
        logEntry(DateTime(2026, 10, 6, 9), sessionId: 'arriving'),
      ];
      final MeditationViewModel vm = await open();

      expect(vm.suggestion.value?.session.id, 'three_step_pause');
      expect(vm.suggestion.value?.reason, 'Something new');
    });

    test('still works when today\'s mood cannot be loaded', () async {
      moodService.failLoading = true;
      final MeditationViewModel vm = await open();

      expect(vm.suggestion.value, isNotNull);
      expect(vm.suggestion.value?.reason, 'Something new');
    });

    test('changes when a practice is finished', () async {
      final MeditationViewModel vm = await open();
      expect(vm.suggestion.value?.session.id, 'arriving');

      vm.recordLog(logEntry(afternoon, sessionId: 'arriving'));
      expect(vm.suggestion.value?.session.id, 'three_step_pause');
    });
  });
}
