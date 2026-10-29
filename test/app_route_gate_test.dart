import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Data/repositories/auth_repository.dart';
import 'package:mindmate/Data/repositories/profile_repository.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/ui/app/app_route_gate.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/app/post_auth_routing.dart';
import 'package:mindmate/ui/auth/auth_flow.dart';
import 'package:mindmate/ui/splash/splash_viewmodel.dart';

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

String gate({
  bool signedIn = true,
  bool needsEmailConfirmation = false,
  bool hasOrg = true,
  bool hasProfile = true,
}) => AppRouteGate.route(
  GateState(
    signedIn: signedIn,
    needsEmailConfirmation: needsEmailConfirmation,
    hasOrg: hasOrg,
    hasProfile: hasProfile,
  ),
);

void main() {
  group('AppRouteGate, in order', () {
    test('1. not signed in: Welcome, whatever else is true', () {
      expect(
        gate(signedIn: false, hasOrg: false, hasProfile: false),
        AppRoutes.welcome,
      );
    });

    test('2. email not confirmed: Confirm your email, before the hospital', () {
      expect(
        gate(needsEmailConfirmation: true, hasOrg: false, hasProfile: false),
        AppRoutes.confirmEmail,
      );
    });

    test('3. not in a hospital: Join your hospital, before the profile', () {
      expect(gate(hasOrg: false, hasProfile: false), AppRoutes.joinHospital);
      // An existing user with a profile still joins once.
      expect(gate(hasOrg: false), AppRoutes.joinHospital);
    });

    test('4. no profile: the profile setup', () {
      expect(gate(hasProfile: false), AppRoutes.createProfile);
    });

    test('5. everything in place: Home', () {
      expect(gate(), AppRoutes.home);
    });

    test('a Google account never needs the email code', () {
      // Google accounts arrive with needsEmailConfirmation false.
      expect(gate(hasOrg: false, hasProfile: false), AppRoutes.joinHospital);
      expect(gate(hasProfile: false), AppRoutes.createProfile);
    });

    test('PostAuthRouting follows the gate', () {
      expect(
        PostAuthRouting.routeFor(hasProfile: true, hasOrg: false),
        AppRoutes.joinHospital,
      );
      expect(
        PostAuthRouting.routeFor(hasProfile: false),
        AppRoutes.createProfile,
      );
    });
  });

  group('App start', () {
    SplashViewModel splash(FakeAuthService auth, FakeProfileService profiles) {
      return SplashViewModel(
        AuthRepository(auth, emailCodes: FakeEmailCodeService()),
        ProfileRepository(profiles),
      );
    }

    test('signed in, not in a hospital: Join your hospital', () async {
      final FakeAuthService auth = FakeAuthService()..signedInAtStart = true;
      final FakeProfileService profiles = FakeProfileService(profile: _profile)
        ..hasOrg = false;
      expect(
        await splash(auth, profiles).resolveRoute(),
        AppRoutes.joinHospital,
      );
    });

    test('an unconfirmed email is asked for before the hospital', () async {
      final FakeAuthService auth = FakeAuthService()
        ..signedInAtStart = true
        ..needsConfirmation = true;
      final FakeProfileService profiles = FakeProfileService()..hasOrg = false;
      expect(
        await splash(auth, profiles).resolveRoute(),
        AppRoutes.confirmEmail,
      );
    });

    test('joined but no profile yet: the profile setup', () async {
      final FakeAuthService auth = FakeAuthService()..signedInAtStart = true;
      expect(
        await splash(auth, FakeProfileService()).resolveRoute(),
        AppRoutes.createProfile,
      );
    });
  });

  group('After a Google sign-in', () {
    AuthFlow flow(FakeProfileService profiles) => AuthFlow(
      AuthRepository(FakeAuthService(), emailCodes: FakeEmailCodeService()),
      ProfileRepository(profiles),
    );

    test(
      'an existing user without a hospital goes to Join, not asked again',
      () async {
        bool asked = false;
        final FakeProfileService profiles = FakeProfileService(
          profile: _profile,
        )..hasOrg = false;

        final ({GoogleOutcome outcome, String route}) result = await flow(
          profiles,
        ).afterGoogle(askConsent: () async => asked = true);

        expect(result.outcome, GoogleOutcome.continued);
        expect(result.route, AppRoutes.joinHospital);
        expect(asked, isFalse);
      },
    );

    test('a new Google account must agree, then joins a hospital', () async {
      final FakeProfileService profiles = FakeProfileService()..hasOrg = false;

      final ({GoogleOutcome outcome, String route}) result = await flow(
        profiles,
      ).afterGoogle(consentGiven: true);

      expect(result.outcome, GoogleOutcome.continued);
      expect(result.route, AppRoutes.joinHospital);
    });
  });
}
