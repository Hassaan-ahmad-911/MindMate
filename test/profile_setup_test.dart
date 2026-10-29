import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/profile_repository.dart';
import 'package:mindmate/Models/profile_validation.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/app/post_auth_routing.dart';
import 'package:mindmate/viewmodels/profile_viewmodel.dart';

import 'helpers/profile_fakes.dart';

void main() {
  group('Name', () {
    test('is required', () {
      expect(ProfileValidation.nameError(''), isNotNull);
      expect(ProfileValidation.nameError('   '), isNotNull);
      expect(ProfileValidation.nameError(null), isNotNull);
      expect(ProfileValidation.nameError('Ayesha Khan'), isNull);
      expect(ProfileValidation.nameError(' Al '), isNull);
    });

    test('is 2 to 40 characters', () {
      expect(ProfileValidation.nameError('A'), 'Use 2 to 40 characters.');
      expect(ProfileValidation.nameError('A' * 40), isNull);
      expect(ProfileValidation.nameError('A' * 41), 'Use 2 to 40 characters.');
    });
  });

  group('Age', () {
    test('is optional', () {
      expect(ProfileValidation.ageError(''), isNull);
      expect(ProfileValidation.ageError('   '), isNull);
      expect(ProfileValidation.ageError(null), isNull);
      expect(ProfileValidation.parseAge(''), isNull);
    });

    test('must be from 18 to 80', () {
      expect(ProfileValidation.ageError('17'), isNotNull);
      expect(ProfileValidation.ageError('18'), isNull);
      expect(ProfileValidation.ageError('29'), isNull);
      expect(ProfileValidation.ageError('80'), isNull);
      expect(ProfileValidation.ageError('81'), isNotNull);
      expect(ProfileValidation.ageError('0'), isNotNull);
      expect(ProfileValidation.ageError('-5'), isNotNull);
    });

    test('must be a whole number', () {
      expect(ProfileValidation.ageError('abc'), isNotNull);
      expect(ProfileValidation.ageError('29.5'), isNotNull);
      expect(ProfileValidation.ageError(' 29 '), isNull);
      expect(ProfileValidation.parseAge(' 29 '), 29);
      expect(ProfileValidation.parseAge('x'), isNull);
    });

    test('says which ages are allowed', () {
      expect(ProfileValidation.ageError('99'), contains('18'));
      expect(ProfileValidation.ageError('99'), contains('80'));
    });
  });

  group('Continue on About you', () {
    test('needs a name, and an age that is blank or valid', () {
      expect(ProfileValidation.isValid(name: '', age: ''), isFalse);
      expect(ProfileValidation.isValid(name: 'Ayesha', age: ''), isTrue);
      expect(ProfileValidation.isValid(name: 'Ayesha', age: '29'), isTrue);
      expect(ProfileValidation.isValid(name: 'Ayesha', age: '12'), isFalse);
      expect(ProfileValidation.isValid(name: '', age: '29'), isFalse);
    });
  });

  group('Profile', () {
    test('keeps old profiles working, with the new fields empty', () {
      final UserProfile old = UserProfile.fromMap('abc', <String, dynamic>{
        'uid': 'abc',
        'name': 'Sana',
        'email': 'sana@example.com',
        'imageUrl': '',
        'bio': 'Night nurse',
        'age': 34,
        'gender': 'Female',
      });
      expect(old.name, 'Sana');
      expect(old.age, 34);
      expect(old.role, isEmpty);
      expect(old.shiftPattern, isEmpty);
      expect(old.goals, isEmpty);
      expect(
        old.checkInStatus,
        isEmpty,
        reason: 'an existing user has no pending check-in',
      );
    });

    test('reads and writes the new fields', () {
      final UserProfile profile = UserProfile.fromMap('abc', <String, dynamic>{
        'name': 'Ayesha Khan',
        'role': 'Nurse',
        'shiftPattern': 'rotating',
        'yearsInHealthcare': '2_to_5',
        'department': 'Emergency',
        'reminderPreference': 'after_shift',
        'goals': <String>['Sleep better', 'Manage stress'],
        'checkInStatus': 'pending',
      });
      expect(profile.role, 'Nurse');
      expect(profile.shiftPattern, 'rotating');
      expect(profile.yearsInHealthcare, '2_to_5');
      expect(profile.department, 'Emergency');
      expect(profile.reminderPreference, 'after_shift');
      expect(profile.goals, <String>['Sleep better', 'Manage stress']);
      expect(profile.checkInStatus, 'pending');

      final Map<String, dynamic> map = profile.toMap();
      expect(map['role'], 'Nurse');
      expect(map['shiftPattern'], 'rotating');
      expect(map['goals'], <String>['Sleep better', 'Manage stress']);
      expect(map['checkInStatus'], 'pending');
    });

    test('ignores goals that are not text', () {
      final UserProfile profile = UserProfile.fromMap('abc', <String, dynamic>{
        'goals': <Object?>['Sleep better', 3, null, ''],
      });
      expect(profile.goals, <String>['Sleep better']);
    });

    test('has a first name', () {
      UserProfile named(String name) => UserProfile(
        uid: 'u',
        name: name,
        email: '',
        imageUrl: '',
        bio: '',
        age: null,
        gender: '',
      );
      expect(named('Ayesha Khan').firstName, 'Ayesha');
      expect(named('  Ayesha   Khan ').firstName, 'Ayesha');
      expect(named('Sana').firstName, 'Sana');
      expect(named('').firstName, '');
    });
  });

  group('After signing in', () {
    test('a user who has a profile goes straight to Home', () {
      expect(PostAuthRouting.routeFor(hasProfile: true), AppRoutes.home);
    });

    test('a user with no profile starts the setup', () {
      expect(
        PostAuthRouting.routeFor(hasProfile: false),
        AppRoutes.createProfile,
      );
    });
  });

  group('Profile setup', () {
    late FakeProfileService service;
    late ProfileViewModel vm;

    ProfileViewModel open({FakeProfileService? with_}) {
      service = with_ ?? FakeProfileService();
      return vm = Get.put<ProfileViewModel>(
        ProfileViewModel(ProfileRepository(service), isSetup: true),
      );
    }

    setUp(() {
      Get.testMode = true;
    });

    tearDown(() {
      Get.reset();
    });

    test('starts from the name and photo of the sign-in', () {
      open(
        with_: FakeProfileService(
          signedIn: const UserProfile(
            uid: 'u',
            name: 'Ayesha Khan',
            email: 'a@example.com',
            imageUrl: 'https://example.com/a.jpg',
            bio: '',
            age: null,
            gender: '',
          ),
        ),
      );
      expect(vm.nameController.text, 'Ayesha Khan');
      expect(vm.profile.value?.imageUrl, 'https://example.com/a.jpg');
      expect(vm.canContinueFromAbout, isTrue);
    });

    test('starts empty when the sign-in has no name', () {
      open();
      expect(vm.nameController.text, isEmpty);
      expect(vm.canContinueFromAbout, isFalse);
    });

    test('Continue on About you waits for a name and a good age', () {
      open();
      expect(vm.canContinueFromAbout, isFalse);

      vm.nameController.text = 'Ayesha';
      expect(vm.canContinueFromAbout, isTrue);

      vm.ageController.text = '17';
      expect(vm.canContinueFromAbout, isFalse);
      expect(vm.ageError, isNotNull);

      vm.ageController.text = '29';
      expect(vm.canContinueFromAbout, isTrue);
      expect(vm.ageError, isNull);

      vm.nameController.text = '   ';
      expect(vm.canContinueFromAbout, isFalse);
    });

    test('gender is optional, and can be chosen again to clear it', () {
      open();
      vm.toggleSetupGender('Female');
      expect(vm.selectedGender.value, 'Female');
      vm.toggleSetupGender('Male');
      expect(vm.selectedGender.value, 'Male');
      vm.toggleSetupGender('Male');
      expect(vm.selectedGender.value, isNull);
    });

    test('Continue on Your work needs a role and shifts', () {
      open();
      expect(vm.canContinueFromWork, isFalse);
      vm.selectRole('Nurse');
      expect(vm.canContinueFromWork, isFalse);
      vm.selectShift('rotating');
      expect(vm.canContinueFromWork, isTrue);
    });

    test('saves the whole profile at the end of Your work', () async {
      open();
      vm.nameController.text = '  Ayesha Khan ';
      vm.ageController.text = '29';
      vm.toggleSetupGender('Female');
      vm.selectRole('Nurse');
      vm.selectShift('rotating');
      vm.selectYears('2_to_5');
      vm.departmentController.text = ' Emergency ';

      await vm.finishSetup();

      expect(service.created, hasLength(1));
      final UserProfile saved = service.created.single;
      expect(saved.name, 'Ayesha Khan');
      expect(saved.age, 29);
      expect(saved.gender, 'Female');
      expect(saved.role, 'Nurse');
      expect(saved.shiftPattern, 'rotating');
      expect(saved.yearsInHealthcare, '2_to_5');
      expect(saved.department, 'Emergency');
      expect(saved.email, 'ayesha@example.com');
      expect(vm.isSaving.value, isFalse);
    });

    test('leaves optional things empty when they are skipped', () async {
      open();
      vm.nameController.text = 'Ayesha';
      vm.selectRole('Doctor');
      vm.selectShift('day');

      await vm.finishSetup();

      final UserProfile saved = service.created.single;
      expect(saved.age, isNull);
      expect(saved.gender, isEmpty);
      expect(saved.yearsInHealthcare, isEmpty);
      expect(saved.department, isEmpty);
    });

    test('does not save until everything required is filled in', () async {
      open();
      vm.nameController.text = 'Ayesha';
      vm.selectRole('Doctor');
      await vm.finishSetup();
      expect(service.created, isEmpty);

      vm.selectShift('night');
      vm.ageController.text = '5';
      await vm.finishSetup();
      expect(service.created, isEmpty, reason: 'the age is not valid');
    });

    test('stays on the screen if saving fails', () async {
      open(with_: FakeProfileService()..failWith = StateError('no'));
      vm.nameController.text = 'Ayesha';
      vm.selectRole('Doctor');
      vm.selectShift('day');

      await vm.finishSetup();

      expect(vm.isSaving.value, isFalse, reason: 'the button works again');
      expect(service.created, isEmpty);
    });

    testWidgets('carries on when the save is slow, as when offline', (
      WidgetTester tester,
    ) async {
      open(with_: FakeProfileService()..neverFinishes = true);
      vm.nameController.text = 'Ayesha';
      vm.selectRole('Doctor');
      vm.selectShift('day');

      final Future<void> saving = vm.finishSetup();
      await tester.pump();
      expect(vm.isSaving.value, isTrue);

      await tester.pump(const Duration(seconds: 13));
      await saving;
      expect(vm.isSaving.value, isFalse);
    });

    test('a second save keeps one profile', () async {
      open();
      vm.nameController.text = 'Ayesha';
      vm.selectRole('Doctor');
      vm.selectShift('day');
      await vm.finishSetup();

      vm.selectRole('Nurse');
      await vm.finishSetup();
      expect(service.created.map((UserProfile p) => p.role), <String>[
        'Doctor',
        'Nurse',
      ]);
      expect(service.profile?.role, 'Nurse');
    });
  });

  group('Editing a profile', () {
    setUp(() {
      Get.testMode = true;
    });

    tearDown(() {
      Get.reset();
    });

    test('is not set up from the sign-in', () async {
      final FakeProfileService service = FakeProfileService(
        profile: const UserProfile(
          uid: 'uid-1',
          name: 'Sana',
          email: 'sana@example.com',
          imageUrl: '',
          bio: '',
          age: 40,
          gender: 'Female',
          role: 'Doctor',
        ),
      );
      final ProfileViewModel vm = Get.put<ProfileViewModel>(
        ProfileViewModel(ProfileRepository(service)),
      );
      await pumpEventQueue();

      expect(vm.isSetup, isFalse);
      expect(vm.nameController.text, 'Sana');
      expect(vm.ageController.text, '40');
      expect(vm.profile.value?.role, 'Doctor');
    });
  });
}
