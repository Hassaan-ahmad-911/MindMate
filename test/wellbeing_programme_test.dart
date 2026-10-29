import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/assessment_repository.dart';
import 'package:mindmate/Data/repositories/auth_repository.dart';
import 'package:mindmate/Data/repositories/journal_repository.dart';
import 'package:mindmate/Data/repositories/mood_repository.dart';
import 'package:mindmate/Data/repositories/profile_repository.dart';
import 'package:mindmate/Models/assessment_definition.dart';
import 'package:mindmate/Models/assessment_result.dart';
import 'package:mindmate/Models/assessment_scorer.dart';
import 'package:mindmate/Models/check_in_questions.dart';
import 'package:mindmate/Models/hospital_programme.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/services/assessment_content_service.dart';
import 'package:mindmate/services/email_code_service.dart';
import 'package:mindmate/services/mood_firestore_service.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/check_in/check_in_viewmodel.dart';
import 'package:mindmate/ui/programme/join_hospital_viewmodel.dart';
import 'package:mindmate/ui/programme/wellbeing_programme_controller.dart';

import 'helpers/assessment_app.dart';
import 'helpers/auth_app.dart';
import 'helpers/home_fakes.dart';
import 'helpers/journal_fakes.dart';
import 'helpers/meditation_fakes.dart';
import 'helpers/profile_fakes.dart';
import 'helpers/programme_fakes.dart';

const UserProfile _profile = UserProfile(
  uid: 'uid-1',
  name: 'Ayesha Khan',
  email: 'ayesha@example.com',
  imageUrl: '',
  bio: '',
  age: 30,
  gender: 'Female',
);

/// Saves moods in memory.
class _SavingMoodService extends MoodFirestoreService {
  final List<MoodModel> saved = <MoodModel>[];

  @override
  Future<MoodModel> saveMood(MoodModel mood) async {
    saved.add(mood);
    return mood;
  }
}

AssessmentRepository _assessments(
  FakeAssessmentService service, {
  void Function()? onSaved,
}) => AssessmentRepository(
  service,
  AssessmentContentService(loader: () async => assessmentContentText()),
  onSaved: onSaved,
);

WellbeingAlert _alert(String id, DateTime sentAt, {bool urgent = false}) =>
    WellbeingAlert(
      id: id,
      sentAt: sentAt,
      urgent: urgent,
      officerName: 'Dr. Sana Malik',
    );

void main() {
  final AssessmentContent content = fileContent();

  group('PHQ-4 (3-day check)', () {
    final AssessmentDefinition phq4 = content.byId('phq4')!;

    test('four questions in two parts, scored as a sum out of 12', () {
      expect(phq4.items.map((AssessmentItem i) => i.part).toList(), <String?>[
        'gad2',
        'gad2',
        'phq2',
        'phq2',
      ]);
      expect(phq4.checkTitle, '3-day check');
      expect(phq4.aboutMinutes, 'about 1 minute');
      expect(phq4.icon, 'clipboard');

      final AssessmentScore score = AssessmentScorer.score(phq4, <int>[
        1,
        2,
        3,
        3,
      ]);
      expect(score.total, 9);
      expect(score.bandId, 'severe');
      expect(AssessmentScorer.score(phq4, <int>[0, 1, 1, 0]).bandId, 'normal');
      expect(AssessmentScorer.score(phq4, <int>[1, 1, 1, 1]).bandId, 'mild');
      expect(
        AssessmentScorer.score(phq4, <int>[2, 2, 1, 1]).bandId,
        'moderate',
      );
    });

    List<String> followUps(List<int> answers) => phq4
        .followUpsFor(answers)
        .map((FollowUpRule r) => r.assessmentId)
        .toList();

    test('PHQ-2 part of 3 or more suggests PHQ-9', () {
      expect(followUps(<int>[0, 1, 1, 2]), <String>['phq9']);
    });

    test('GAD-2 part of 3 or more suggests GAD-7', () {
      expect(followUps(<int>[2, 1, 1, 1]), <String>['gad7']);
    });

    test('both parts: both cards', () {
      expect(followUps(<int>[3, 0, 0, 3]), <String>['phq9', 'gad7']);
    });

    test('neither part: no card', () {
      expect(followUps(<int>[1, 1, 1, 1]), isEmpty);
      expect(followUps(<int>[0, 2, 2, 0]), isEmpty);
    });

    test('the follow-up text comes from the content file', () {
      expect(
        phq4.followUpsFor(<int>[0, 0, 3, 0]).single.text,
        'Your answers suggest taking the full low mood check now. '
        'It has 9 questions.',
      );
    });
  });

  group('Join your hospital', () {
    test('the code: capitals, digits and dashes, at least 4', () {
      expect(JoinRules.normalise(' cgh-2026 '), 'CGH-2026');
      expect(JoinRules.normalise('cgh_2026!'), 'CGH2026');
      expect(JoinRules.isValidCode('cgh-2026'), isTrue);
      expect(JoinRules.isValidCode('AB1'), isFalse);
      expect(JoinRules.isValidCode(''), isFalse);
      expect(JoinRules.isValidCode('ABCD'), isTrue);
    });

    test('error codes map to the agreed messages', () {
      expect(
        JoinRules.message('unknown_code'),
        "We couldn't find that code. Check it with your hospital.",
      );
      expect(
        JoinRules.message('consent_required'),
        'Please tick the box to continue.',
      );
      expect(JoinRules.message('email_not_verified'), isNull);
      expect(
        JoinRules.message('network'),
        'No internet connection. Check it and try again.',
      );
    });

    group('the screen', () {
      late FakeProgrammeRepository repo;
      late WellbeingProgrammeController programme;
      late List<String> routes;

      JoinHospitalViewModel open({UserProfile? profile}) {
        repo = FakeProgrammeRepository();
        programme = WellbeingProgrammeController(repo);
        routes = <String>[];
        return Get.put<JoinHospitalViewModel>(
          JoinHospitalViewModel(
            repo,
            ProfileRepository(FakeProfileService(profile: profile)),
            AuthRepository(
              FakeAuthService(),
              emailCodes: FakeEmailCodeService(),
            ),
            programme: programme,
            cardDuration: Duration.zero,
            navigate: routes.add,
          ),
        );
      }

      setUp(() => Get.testMode = true);
      tearDown(Get.reset);

      test('needs a code and the tick before joining', () async {
        final JoinHospitalViewModel vm = open();
        expect(vm.canJoin, isFalse);

        vm.codeController.text = 'cgh-2026';
        expect(vm.code.value, 'CGH-2026');
        expect(vm.codeLooksRight, isTrue);
        expect(vm.canJoin, isFalse, reason: 'the box is not ticked');

        vm.setAgreed(true);
        expect(vm.canJoin, isTrue);

        vm.codeController.text = 'AB';
        expect(vm.canJoin, isFalse);
        await vm.join();
        expect(repo.joinCodes, isEmpty);
      });

      test('a new user joins, then goes on to About you', () async {
        final JoinHospitalViewModel vm = open()..setAgreed(true);
        vm.codeController.text = 'CGH-2026';

        await vm.join();

        expect(repo.joinCodes, <String>['CGH-2026']);
        expect(vm.joined.value?.name, 'City General Hospital');
        expect(programme.membership.value?.officerName, 'Dr. Sana Malik');
        expect(routes, <String>[AppRoutes.createProfile]);
      });

      test('an existing user goes Home after joining', () async {
        final JoinHospitalViewModel vm = open(profile: _profile)
          ..setAgreed(true);
        vm.codeController.text = 'CGH-2026';

        await vm.join();

        expect(routes, <String>[AppRoutes.home]);
      });

      test('an unknown code shows its message and stays', () async {
        final JoinHospitalViewModel vm = open()..setAgreed(true);
        repo.joinError = const EmailCodeException('unknown_code');
        vm.codeController.text = 'XYZ-0000';

        await vm.join();

        expect(
          vm.error.value,
          "We couldn't find that code. Check it with your hospital.",
        );
        expect(vm.joined.value, isNull);
        expect(routes, isEmpty);

        vm.codeController.text = 'XYZ-0001';
        expect(vm.error.value, isNull, reason: 'typing clears it');
      });

      test('an unconfirmed email goes to the email code screen', () async {
        final JoinHospitalViewModel vm = open()..setAgreed(true);
        repo.joinError = const EmailCodeException('email_not_verified');
        vm.codeController.text = 'CGH-2026';

        await vm.join();

        expect(routes, <String>[AppRoutes.confirmEmail]);
        expect(vm.error.value, isNull);
      });

      test('no connection: the usual message', () async {
        final JoinHospitalViewModel vm = open()..setAgreed(true);
        repo.joinError = const EmailCodeException(EmailCodeException.network);
        vm.codeController.text = 'CGH-2026';

        await vm.join();

        expect(
          vm.error.value,
          'No internet connection. Check it and try again.',
        );
      });
    });
  });

  group('Asking the server to evaluate', () {
    test('after a mood is saved', () async {
      int calls = 0;
      final MoodRepository moods = MoodRepository(
        _SavingMoodService(),
        onSaved: () => calls += 1,
      );
      await moods.saveMood(moodAt(DateTime(2026, 10, 20, 8), 'Calm'));
      expect(calls, 1);
    });

    test('after a check-in result is saved', () async {
      int calls = 0;
      final AssessmentRepository repo = _assessments(
        FakeAssessmentService(),
        onSaved: () => calls += 1,
      );
      final AssessmentDefinition phq4 = content.byId('phq4')!;
      await repo.saveResult(
        AssessmentResult.fromAttempt(
          def: phq4,
          contentVersion: 2,
          answers: <int>[0, 0, 0, 0],
          startedAt: DateTime(2026, 10, 1),
          completedAt: DateTime(2026, 10, 1),
        ),
      );
      expect(calls, 1);
    });

    test('not when saving a check-in fails', () async {
      int calls = 0;
      final FakeAssessmentService service = FakeAssessmentService()
        ..failSaving = true;
      final AssessmentRepository repo = _assessments(
        service,
        onSaved: () => calls += 1,
      );
      await expectLater(
        repo.saveResult(
          AssessmentResult.fromAttempt(
            def: content.byId('phq4')!,
            contentVersion: 2,
            answers: <int>[0, 0, 0, 0],
            startedAt: DateTime(2026, 10, 1),
            completedAt: DateTime(2026, 10, 1),
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(calls, 0);
    });

    test('after a journal entry is saved or edited', () async {
      int calls = 0;
      final JournalRepository journal = JournalRepository(
        FakeJournalService(),
        fileJournalContentService(),
        FakeDraftStore(),
        onSaved: () => calls += 1,
      );
      final saved = await journal.createEntry(journalEntry(id: ''));
      expect(calls, 1);
      await journal.updateEntry(saved);
      expect(calls, 2);
    });

    group('the first check-in', () {
      setUp(() => Get.testMode = true);
      tearDown(Get.reset);

      CheckInViewModel open(FakeAssessmentService service, List<int> saves) {
        return Get.put<CheckInViewModel>(
          CheckInViewModel(
            ProfileRepository(FakeProfileService(profile: _profile)),
            buildRepository(FakeLogService()),
            assessments: _assessments(service, onSaved: () => saves.add(1)),
            clock: () => DateTime(2026, 10, 1, 9, 30),
          ),
        );
      }

      void answerWho5(CheckInViewModel vm, List<String?> labels) {
        vm.skip(); // goals
        for (final String? label in labels) {
          if (label == null) {
            vm.skip();
          } else {
            vm.select(
              vm.question.options.firstWhere(
                (CheckInOption o) => o.label == label,
              ),
            );
            vm.next();
          }
        }
        vm.skip();
        vm.skip();
        vm.skip();
      }

      test(
        'all five WHO-5 answers: also saved as a Wellbeing result',
        () async {
          final FakeAssessmentService service = FakeAssessmentService();
          final List<int> saves = <int>[];
          final CheckInViewModel vm = open(service, saves);

          answerWho5(vm, <String>[
            'Less than half the time', // 2
            'Some of the time', // 1
            'Some of the time', // 1
            'Less than half the time', // 2
            'Some of the time', // 1 -> raw 7, score 28
          ]);
          await pumpEventQueue();

          final AssessmentResult who5 = service.stored.single;
          expect(who5.assessmentId, 'who5');
          expect(who5.answers, <int>[2, 1, 1, 2, 1]);
          expect(who5.total, 28);
          expect(who5.fromSetup, isTrue);
          expect(who5.completedAt, DateTime(2026, 10, 1, 9, 30));
          expect(saves, hasLength(1), reason: 'the server is asked once');
        },
      );

      test('a skipped WHO-5 answer: no Wellbeing result', () async {
        final FakeAssessmentService service = FakeAssessmentService();
        final List<int> saves = <int>[];
        final CheckInViewModel vm = open(service, saves);

        answerWho5(vm, <String?>[
          'Some of the time',
          null,
          'Some of the time',
          'Some of the time',
          'Some of the time',
        ]);
        await pumpEventQueue();

        expect(service.stored, isEmpty);
        expect(saves, isEmpty);
      });
    });

    group('the programme', () {
      late FakeProgrammeRepository repo;
      late List<WellbeingAlert> shown;

      WellbeingProgrammeController controller({
        HospitalMembership? membership,
        DateTime? now,
      }) {
        repo = FakeProgrammeRepository(membership: membership);
        shown = <WellbeingAlert>[];
        return WellbeingProgrammeController(
          repo,
          clock: () => now ?? DateTime(2026, 10, 20, 10),
          retryDelay: const Duration(milliseconds: 20),
          showAlert: shown.add,
          canShowAlert: () => true,
        );
      }

      test('asks once per save for someone in a hospital', () async {
        final WellbeingProgrammeController c = controller(
          membership: cityGeneral(),
        );
        c.dataSaved();
        await pumpEventQueue();
        expect(repo.evaluateCalls, 1);
      });

      test('never asks for someone not in a hospital', () async {
        final WellbeingProgrammeController c = controller();
        c.dataSaved();
        await c.homeOpened();
        await pumpEventQueue();
        expect(repo.evaluateCalls, 0);
      });

      test('a failed call is tried once more, later', () async {
        final WellbeingProgrammeController c = controller(
          membership: cityGeneral(),
        );
        repo.failEvaluations = 5;
        c.dataSaved();
        await pumpEventQueue();
        expect(repo.evaluateCalls, 1);

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(repo.evaluateCalls, 2, reason: 'one retry only');
        expect(shown, isEmpty, reason: 'no error is ever shown');
      });

      test('once a day when Home opens', () async {
        final WellbeingProgrammeController c = controller(
          membership: cityGeneral(),
        );
        await c.homeOpened();
        await c.homeOpened();
        expect(repo.evaluateCalls, 1);
        expect(repo.evaluatedDay, '2026-10-20');
      });

      test('alert_sent shows "Someone will reach out" once', () async {
        final WellbeingProgrammeController c = controller(
          membership: cityGeneral(),
        );
        repo.outcome = const EvaluateOutcome(
          status: EvaluateOutcome.alertSent,
          officerName: 'Dr. Sana Malik',
        );
        repo.alerts = <WellbeingAlert>[
          _alert('a2', DateTime(2026, 10, 20, 9)),
          _alert('a1', DateTime(2026, 10, 18)),
        ];

        c.dataSaved();
        await pumpEventQueue();
        expect(shown.map((WellbeingAlert a) => a.id), <String>['a2']);
        expect(repo.seen, <String>{'a1', 'a2'});

        // Shown on this phone: never again, also not on the next open.
        await c.showPendingAlert();
        await c.homeOpened();
        expect(shown, hasLength(1));
      });

      test(
        'an alert sent while the app was closed shows on the next open',
        () async {
          final WellbeingProgrammeController c = controller(
            membership: cityGeneral(),
          );
          repo.evaluatedDay = '2026-10-20';
          repo.alerts = <WellbeingAlert>[
            _alert('u1', DateTime(2026, 10, 19, 22), urgent: true),
          ];

          await c.homeOpened();

          expect(shown.single.urgent, isTrue);
        },
      );

      test('alerts older than two weeks are history, not new', () async {
        final WellbeingProgrammeController c = controller(
          membership: cityGeneral(),
        );
        repo.alerts = <WellbeingAlert>[_alert('old', DateTime(2026, 9, 1))];
        await c.showPendingAlert();
        expect(shown, isEmpty);
      });

      test('not shown over the sign-in and setup screens', () async {
        repo = FakeProgrammeRepository(membership: cityGeneral());
        shown = <WellbeingAlert>[];
        bool canShow = false;
        final WellbeingProgrammeController c = WellbeingProgrammeController(
          repo,
          clock: () => DateTime(2026, 10, 20, 10),
          showAlert: shown.add,
          canShowAlert: () => canShow,
        );
        repo.alerts = <WellbeingAlert>[_alert('a1', DateTime(2026, 10, 20))];

        await c.showPendingAlert();
        expect(shown, isEmpty);
        expect(repo.seen, isEmpty, reason: 'kept for later');

        canShow = true;
        await c.showPendingAlert();
        expect(shown, hasLength(1));
      });

      test('signing out forgets the hospital', () async {
        final WellbeingProgrammeController c = controller(
          membership: cityGeneral(),
        );
        await c.loadMembership();
        expect(c.inProgramme, isTrue);
        c.reset();
        expect(c.inProgramme, isFalse);
      });
    });
  });

  test('the evaluate answer is read without guessing', () {
    final EvaluateOutcome urgent = EvaluateOutcome.fromJson(<String, dynamic>{
      'status': 'alert_sent',
      'kind': 'urgent',
      'officerName': 'Dr. Sana Malik',
    });
    expect(urgent.sent, isTrue);
    expect(urgent.urgent, isTrue);
    expect(
      EvaluateOutcome.fromJson(<String, dynamic>{'status': 'watching'}).sent,
      isFalse,
    );
    expect(cityGeneral().officerInitials, 'SM');
  });
}
