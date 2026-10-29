import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/profile_options.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/viewmodels/home_viewmodel.dart';

import 'helpers/home_fakes.dart';
import 'helpers/profile_fakes.dart';

UserProfile _profile(String status) => UserProfile(
  uid: 'uid-1',
  name: 'Ayesha Khan',
  email: 'ayesha@example.com',
  imageUrl: '',
  bio: '',
  age: 30,
  gender: 'Female',
  role: 'Nurse',
  goals: const <String>['Sleep better'],
  checkInStatus: status,
);

/// The view model is built directly (no Firebase): only the profile and the
/// check-in card are under test.
HomeViewModel _home(FakeProfileService service, String status) {
  final HomeViewModel vm = buildHome(fakes: HomeFakes(profiles: service));
  vm.profile.value = _profile(status);
  return vm;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  group('Finish your check-in card', () {
    test('shows only while the check-in is pending', () {
      final FakeProfileService service = FakeProfileService();
      expect(
        _home(service, ProfileOptions.checkInPending).showCheckInCard,
        isTrue,
      );
      expect(
        _home(service, ProfileOptions.checkInCompleted).showCheckInCard,
        isFalse,
      );
      expect(
        _home(service, ProfileOptions.checkInDismissed).showCheckInCard,
        isFalse,
      );
    });

    test('is never shown to people who signed up before the check-in', () {
      final HomeViewModel vm = _home(FakeProfileService(), '');
      expect(vm.showCheckInCard, isFalse);
    });

    test('is not shown when there is no profile', () {
      final HomeViewModel vm = _home(FakeProfileService(), 'pending');
      vm.profile.value = null;
      expect(vm.showCheckInCard, isFalse);
    });

    test('dismissing hides it and saves the dismissed status', () async {
      final FakeProfileService service = FakeProfileService();
      final HomeViewModel vm = _home(service, ProfileOptions.checkInPending);

      await vm.dismissCheckIn();

      expect(vm.showCheckInCard, isFalse);
      expect(vm.profile.value?.checkInStatus, ProfileOptions.checkInDismissed);
      expect(service.statusUpdates, <String>[ProfileOptions.checkInDismissed]);
    });

    test('a failed dismiss brings the card back', () async {
      final FakeProfileService service = FakeProfileService()
        ..failWith = Exception('offline');
      final HomeViewModel vm = _home(service, ProfileOptions.checkInPending);

      await vm.dismissCheckIn();

      expect(vm.showCheckInCard, isTrue);
      expect(vm.profile.value?.checkInStatus, ProfileOptions.checkInPending);
    });

    test('finishing the check-in elsewhere hides it and keeps the rest', () {
      final HomeViewModel vm = _home(
        FakeProfileService(),
        ProfileOptions.checkInPending,
      );

      vm.setCheckInStatus(ProfileOptions.checkInCompleted);

      expect(vm.showCheckInCard, isFalse);
      expect(vm.profile.value?.name, 'Ayesha Khan');
      expect(vm.profile.value?.role, 'Nurse');
      expect(vm.profile.value?.goals, <String>['Sleep better']);
    });
  });
}
