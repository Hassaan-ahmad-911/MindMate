import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Data/repositories/auth_repository.dart';
import 'package:mindmate/Data/repositories/profile_repository.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/splash/splash_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_app.dart';
import 'helpers/profile_fakes.dart';

const UserProfile _profile = UserProfile(
  uid: 'uid-1',
  name: 'Ayesha',
  email: 'ayesha@example.com',
  imageUrl: '',
  bio: '',
  age: 30,
  gender: 'Female',
);

SplashViewModel splash(FakeAuthService auth, {UserProfile? profile}) {
  return SplashViewModel(
    AuthRepository(auth, emailCodes: FakeEmailCodeService()),
    ProfileRepository(FakeProfileService(profile: profile)),
  );
}

void main() {
  group('Splash routing', () {
    test('nobody signed in goes to Welcome', () async {
      final FakeAuthService auth = FakeAuthService();
      expect(await splash(auth).resolveRoute(), AppRoutes.welcome);
    });

    test('a failed sign-in check also goes to Welcome', () async {
      final FakeAuthService auth = FakeAuthService()
        ..authStateError = StateError('no Firebase');
      expect(await splash(auth).resolveRoute(), AppRoutes.welcome);
    });

    test('signed in without a profile goes to the profile setup', () async {
      final FakeAuthService auth = FakeAuthService()..signedInAtStart = true;
      expect(await splash(auth).resolveRoute(), AppRoutes.createProfile);
    });

    test('signed in with a profile goes Home', () async {
      final FakeAuthService auth = FakeAuthService()..signedInAtStart = true;
      expect(
        await splash(auth, profile: _profile).resolveRoute(),
        AppRoutes.home,
      );
    });

    test('an unconfirmed email goes to Confirm your email first', () async {
      final FakeAuthService auth = FakeAuthService()
        ..signedInAtStart = true
        ..needsConfirmation = true;
      expect(
        await splash(auth, profile: _profile).resolveRoute(),
        AppRoutes.confirmEmail,
      );
    });
  });

  test('the old "seen onboarding" flag is removed from the phone', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SplashViewModel.legacyOnboardingKey: true,
      'other_setting': 'kept',
    });

    await splash(FakeAuthService()).forgetOnboardingFlag();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(SplashViewModel.legacyOnboardingKey), isFalse);
    expect(prefs.getString('other_setting'), 'kept');

    // Safe to run again when the key is already gone.
    await splash(FakeAuthService()).forgetOnboardingFlag();
  });
}
