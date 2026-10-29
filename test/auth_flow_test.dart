import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/auth_repository.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/services/auth_service.dart';
import 'package:mindmate/services/email_code_service.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/app/user_session.dart';
import 'package:mindmate/ui/auth/forgot_password_viewmodel.dart';
import 'package:mindmate/ui/auth/login_viewmodel.dart';
import 'package:mindmate/ui/auth/signup_viewmodel.dart';
import 'package:mindmate/ui/games/games_hub_viewmodel.dart';
import 'package:mindmate/ui/settings/settings_viewmodel.dart';
import 'package:mindmate/ui/shared/gradient_button.dart';
import 'package:mindmate/viewmodels/home_viewmodel.dart';

import 'helpers/auth_app.dart';
import 'helpers/games_fakes.dart';
import 'helpers/home_fakes.dart';
import 'helpers/profile_fakes.dart';

/// The text in these tests is wider than the real font, which can overflow a
/// row. Overflow is not what these tests are about, so it is left out.
void ignoreOverflowErrors() {
  final FlutterExceptionHandler? original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (!details.exceptionAsString().contains('overflowed')) {
      original?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<void> go(WidgetTester tester, [int milliseconds = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
}

Future<AuthTestApp> open(
  WidgetTester tester, {
  String route = AppRoutes.login,
  AuthTestApp? app,
}) async {
  tester.view.physicalSize = const Size(1170, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ignoreOverflowErrors();

  final AuthTestApp testApp = app ?? AuthTestApp();
  await tester.pumpWidget(testApp.build(initialRoute: route));
  await go(tester);
  return testApp;
}

Finder field(int index) => find.byType(TextField).at(index);

Future<void> type(WidgetTester tester, int index, String text) async {
  await tester.tap(field(index));
  await tester.pump();
  await tester.enterText(field(index), text);
  await tester.pump();
}

/// The gradient button with this label.
GradientButton button(WidgetTester tester, String label) {
  return tester.widget<GradientButton>(
    find.widgetWithText(GradientButton, label),
  );
}

FirebaseAuthException authError(String code) =>
    FirebaseAuthException(code: code, message: 'ayesha@example.com $code');

UserProfile someProfile() => const UserProfile(
  uid: 'uid-1',
  name: 'Ayesha',
  email: 'ayesha@example.com',
  imageUrl: '',
  bio: '',
  age: 30,
  gender: 'Female',
);

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('Log in', () {
    testWidgets('shows the heading, both fields, Google and the sign-up link', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        find.text('Log in to pick up where you left off.'),
        findsOneWidget,
      );
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
      expect(find.text('or'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('New here?'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets('the password can be shown and hidden', (
      WidgetTester tester,
    ) async {
      await open(tester);
      bool obscured() => tester.widget<TextField>(field(1)).obscureText;
      expect(obscured(), isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(obscured(), isFalse);

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(obscured(), isTrue);
    });

    testWidgets('tapping Log in with nothing typed explains what is missing', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(tester);

      await tester.tap(find.text('Log in'));
      await go(tester);

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(app.auth.count('login'), 0);
    });

    testWidgets('a bad email is flagged when the field is left, and clears', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await type(tester, 0, 'ayesha');
      expect(
        find.text('That email does not look right. Check it and try again.'),
        findsNothing,
      );
      await tester.tap(field(1));
      await tester.pump();
      expect(
        find.text('That email does not look right. Check it and try again.'),
        findsOneWidget,
      );

      await tester.enterText(field(0), 'ayesha@example.com');
      await tester.pump();
      expect(
        find.text('That email does not look right. Check it and try again.'),
        findsNothing,
      );
    });

    testWidgets('with a profile, logging in goes Home with no way back', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp(
        profiles: FakeProfileService(profile: someProfile()),
      );
      await open(tester, app: app);

      await type(tester, 0, 'ayesha@example.com');
      await type(tester, 1, 'secret1');
      await tester.tap(find.text('Log in'));
      await go(tester, 900);

      expect(app.auth.count('login'), 1);
      expect(Get.currentRoute, AppRoutes.home);
      expect(find.text('HOME'), findsOneWidget);
      expect(Get.key.currentState?.canPop(), isFalse);
    });

    testWidgets('without a profile, logging in goes to the profile setup', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp();
      await open(tester, app: app);

      await type(tester, 0, 'ayesha@example.com');
      await type(tester, 1, 'secret1');
      await tester.tap(find.text('Log in'));
      await go(tester, 900);

      expect(Get.currentRoute, AppRoutes.createProfile);
    });

    testWidgets('a wrong password keeps the screen and the typed email', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp();
      app.auth.loginError = authError('wrong-password');
      await open(tester, app: app);

      await type(tester, 0, 'ayesha@example.com');
      await type(tester, 1, 'wrong');
      await tester.tap(find.text('Log in'));
      await go(tester);

      expect(Get.currentRoute, AppRoutes.login);
      expect(find.text('ayesha@example.com'), findsOneWidget);
      final LoginViewModel vm = Get.find<LoginViewModel>();
      expect(vm.isLoading, isFalse);
      expect(tester.widget<TextField>(field(0)).enabled, isTrue);
    });

    testWidgets(
      'while logging in the inputs are off and nothing is sent twice',
      (WidgetTester tester) async {
        final AuthTestApp app = AuthTestApp(
          profiles: FakeProfileService(profile: someProfile()),
        );
        app.auth.loginGate = Completer<void>();
        await open(tester, app: app);
        await type(tester, 0, 'ayesha@example.com');
        await type(tester, 1, 'secret1');

        await tester.tap(find.text('Log in'));
        await tester.pump();

        expect(tester.widget<TextField>(field(0)).enabled, isFalse);
        expect(tester.widget<TextField>(field(1)).enabled, isFalse);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // The spinner has taken the place of the label.
        expect(
          tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
          isNull,
        );

        // A second attempt (the keyboard's "done", say) does nothing.
        await Get.find<LoginViewModel>().submit();
        expect(app.auth.count('login'), 1);

        app.auth.loginGate!.complete();
        await go(tester, 900);
        expect(app.auth.count('login'), 1);
        expect(Get.currentRoute, AppRoutes.home);
      },
    );

    testWidgets('Forgot password opens Reset password with the typed email', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await type(tester, 0, 'ayesha@example.com');

      await tester.tap(find.text('Forgot password?'));
      await go(tester);

      expect(Get.currentRoute, AppRoutes.forgotPassword);
      expect(find.text('Reset password'), findsWidgets);
      expect(
        tester.widget<TextField>(field(0)).controller?.text,
        'ayesha@example.com',
      );
    });

    testWidgets('Create an account opens Create account', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.tap(find.text('Create an account'));
      await go(tester);

      expect(Get.currentRoute, AppRoutes.signup);
      expect(find.text('It takes less than a minute.'), findsOneWidget);
    });

    group('with Google', () {
      testWidgets('cancelling shows nothing and stays put', (
        WidgetTester tester,
      ) async {
        final AuthTestApp app = AuthTestApp();
        app.auth.googleCancelled = true;
        await open(tester, app: app);

        await tester.tap(find.text('Continue with Google'));
        await go(tester);

        expect(Get.currentRoute, AppRoutes.login);
        expect(app.auth.count('consent'), 0);
        expect(Get.find<LoginViewModel>().isLoading, isFalse);
      });

      testWidgets('an existing account goes Home without being asked again', (
        WidgetTester tester,
      ) async {
        final AuthTestApp app = AuthTestApp(
          profiles: FakeProfileService(profile: someProfile()),
        );
        await open(tester, app: app);

        await tester.tap(find.text('Continue with Google'));
        await go(tester, 900);

        expect(Get.currentRoute, AppRoutes.home);
        expect(find.text('One thing before you start'), findsNothing);
        expect(app.auth.count('consent'), 0);
      });

      testWidgets('a new account must agree to the notice, then sets up', (
        WidgetTester tester,
      ) async {
        final AuthTestApp app = AuthTestApp();
        await open(tester, app: app);

        await tester.tap(find.text('Continue with Google'));
        await go(tester);
        expect(find.text('One thing before you start'), findsOneWidget);
        expect(button(tester, 'Continue').onPressed, isNull);

        await tester.tap(
          find.textContaining('I understand MindMate is a self-support'),
        );
        await tester.pump();
        expect(button(tester, 'Continue').onPressed, isNotNull);
        await tester.tap(find.text('Continue'));
        await go(tester, 900);

        expect(app.auth.count('consent'), 1);
        expect(Get.currentRoute, AppRoutes.createProfile);
      });

      testWidgets('declining the notice signs the new account out again', (
        WidgetTester tester,
      ) async {
        final AuthTestApp app = AuthTestApp();
        await open(tester, app: app);

        await tester.tap(find.text('Continue with Google'));
        await go(tester);
        await tester.tap(find.text('Cancel'));
        await go(tester);

        expect(app.auth.count('consent'), 0);
        expect(app.auth.count('signOutGoogle'), 1);
        expect(app.auth.count('signOutFirebase'), 1);
        expect(Get.currentRoute, AppRoutes.login);
      });

      testWidgets('someone who agreed earlier is not asked again', (
        WidgetTester tester,
      ) async {
        final AuthTestApp app = AuthTestApp();
        app.auth.disclaimerAccepted = true;
        await open(tester, app: app);

        await tester.tap(find.text('Continue with Google'));
        await go(tester, 900);

        expect(find.text('One thing before you start'), findsNothing);
        expect(Get.currentRoute, AppRoutes.createProfile);
      });
    });
  });

  group('Create account', () {
    testWidgets('shows the fields, the notice and Google', (
      WidgetTester tester,
    ) async {
      await open(tester, route: AppRoutes.signup);

      expect(find.text('Create account'), findsWidgets);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text('Type it again'), findsOneWidget);
      expect(
        find.text(
          'I understand MindMate is a self-support tool and not a substitute '
          'for professional care.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Already have an account?'), findsOneWidget);
    });

    testWidgets('Create account waits for the notice to be ticked', (
      WidgetTester tester,
    ) async {
      await open(tester, route: AppRoutes.signup);
      expect(button(tester, 'Create account').onPressed, isNull);

      await tester.tap(find.textContaining('I understand MindMate'));
      await tester.pump();
      expect(button(tester, 'Create account').onPressed, isNotNull);

      await tester.tap(find.textContaining('I understand MindMate'));
      await tester.pump();
      expect(button(tester, 'Create account').onPressed, isNull);
    });

    testWidgets('the strength bar follows the password', (
      WidgetTester tester,
    ) async {
      await open(tester, route: AppRoutes.signup);
      final SignupViewModel vm = Get.find<SignupViewModel>();

      await type(tester, 1, 'abc');
      expect(vm.strength.level, 1);
      expect(find.text('Too short. 8 or more characters'), findsOneWidget);

      await tester.enterText(field(1), 'abcdefgh');
      await tester.pump();
      expect(find.text('Okay. 8 or more characters'), findsOneWidget);

      await tester.enterText(field(1), 'abcd1234');
      await tester.pump();
      expect(find.text('Good. 8 or more characters'), findsOneWidget);

      await tester.enterText(field(1), 'abcd123!');
      await tester.pump();
      expect(find.text('Strong'), findsOneWidget);
      expect(vm.strength.level, 4);
    });

    testWidgets(
      'problems are explained under the fields, and nothing is sent',
      (WidgetTester tester) async {
        final AuthTestApp app = await open(tester, route: AppRoutes.signup);

        await type(tester, 0, 'nope');
        await type(tester, 1, 'short');
        await type(tester, 2, 'different');
        await tester.tap(find.textContaining('I understand MindMate'));
        await tester.pump();
        await tester.tap(find.text('Create account').last);
        await go(tester);

        expect(
          find.text('That email does not look right. Check it and try again.'),
          findsOneWidget,
        );
        expect(find.text('Use at least 8 characters.'), findsOneWidget);
        expect(find.text('The two passwords do not match.'), findsOneWidget);
        expect(app.emailCodes.count('send'), 0);
      },
    );

    testWidgets('the confirmation is checked again when the password changes', (
      WidgetTester tester,
    ) async {
      await open(tester, route: AppRoutes.signup);

      await type(tester, 1, 'abcd1234');
      await type(tester, 2, 'abcd1234');
      await tester.tap(field(0));
      await tester.pump();
      expect(find.text('The two passwords do not match.'), findsNothing);

      await tester.enterText(field(1), 'abcd12345');
      await tester.pump();
      expect(find.text('The two passwords do not match.'), findsOneWidget);
    });

    testWidgets('Create account emails a code and opens Check your email', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(tester, route: AppRoutes.signup);

      await type(tester, 0, 'ayesha@example.com');
      await type(tester, 1, 'abcd1234');
      await type(tester, 2, 'abcd1234');
      await tester.tap(find.textContaining('I understand MindMate'));
      await tester.pump();
      await tester.tap(find.text('Create account').last);
      await go(tester, 900);

      // Nothing is created yet: only a code was asked for.
      expect(app.emailCodes.count('send'), 1);
      expect(app.emailCodes.count('verify'), 0);
      expect(app.auth.count('login'), 0);
      expect(app.auth.count('consent'), 0);
      expect(Get.currentRoute, AppRoutes.verifyEmailCode);
      expect(find.text('Check your email'), findsOneWidget);
      expect(
        find.textContaining('ayesha@example.com', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('an email that is already registered keeps the screen', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp();
      app.emailCodes.sendError = const EmailCodeException('email_in_use');
      await open(tester, route: AppRoutes.signup, app: app);

      await type(tester, 0, 'ayesha@example.com');
      await type(tester, 1, 'abcd1234');
      await type(tester, 2, 'abcd1234');
      await tester.tap(find.textContaining('I understand MindMate'));
      await tester.pump();
      await tester.tap(find.text('Create account').last);
      await go(tester);

      expect(Get.currentRoute, AppRoutes.signup);
      expect(
        find.text('This email already has an account. Log in instead.'),
        findsOneWidget,
      );
      expect(app.auth.count('consent'), 0);
      expect(Get.find<SignupViewModel>().isLoading, isFalse);

      // The "Log in" link under the email (the last one is the page link).
      await tester.tap(find.text('Log in').first);
      await go(tester);
      expect(Get.currentRoute, AppRoutes.login);
    });

    testWidgets('Google with the notice already ticked records it', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(tester, route: AppRoutes.signup);

      await tester.tap(find.textContaining('I understand MindMate'));
      await tester.pump();
      await tester.tap(find.text('Continue with Google'));
      await go(tester, 900);

      expect(find.text('One thing before you start'), findsNothing);
      expect(app.auth.count('consent'), 1);
      expect(Get.currentRoute, AppRoutes.createProfile);
    });

    testWidgets('Google without the notice ticked asks for it first', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(tester, route: AppRoutes.signup);

      await tester.tap(find.text('Continue with Google'));
      await go(tester);

      expect(find.text('One thing before you start'), findsOneWidget);
      expect(app.auth.count('consent'), 0);
    });

    testWidgets('Log in switches to the Log in screen', (
      WidgetTester tester,
    ) async {
      await open(tester, route: AppRoutes.signup);

      await tester.tap(find.text('Log in'));
      await go(tester);

      expect(Get.currentRoute, AppRoutes.login);
    });
  });

  group('Reset password', () {
    testWidgets('shows the explanation, the field and the spam note', (
      WidgetTester tester,
    ) async {
      await open(tester, route: AppRoutes.forgotPassword);

      expect(find.text('Reset password'), findsOneWidget);
      expect(
        find.text(
          'Enter your email and we will send you a link to choose a new '
          'password.',
        ),
        findsOneWidget,
      );
      expect(find.text('Send reset link'), findsOneWidget);
      expect(
        find.text(
          'The email can take a few minutes. Check your spam folder too.',
        ),
        findsOneWidget,
      );
      expect(find.text('Remembered it?'), findsOneWidget);
      expect(find.text('Back to log in'), findsOneWidget);
    });

    testWidgets('an empty or bad email is not sent', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(
        tester,
        route: AppRoutes.forgotPassword,
      );

      await tester.tap(find.text('Send reset link'));
      await go(tester);
      expect(find.text('Enter your email address.'), findsOneWidget);

      await type(tester, 0, 'nope');
      await tester.tap(find.text('Send reset link'));
      await go(tester);
      expect(app.auth.count('reset'), 0);
    });

    testWidgets('after sending, the same confirmation is shown', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(
        tester,
        route: AppRoutes.forgotPassword,
      );

      await type(tester, 0, 'ayesha@example.com');
      await tester.tap(find.text('Send reset link'));
      await go(tester);

      expect(app.auth.count('reset'), 1);
      expect(find.text(ForgotPasswordViewModel.confirmation), findsOneWidget);
      expect(find.text('Back to log in'), findsOneWidget);
      expect(find.text('Send reset link'), findsNothing);
    });

    testWidgets('an email with no account gets exactly the same answer', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp();
      app.auth.resetError = authError('user-not-found');
      await open(tester, route: AppRoutes.forgotPassword, app: app);

      await type(tester, 0, 'nobody@example.com');
      await tester.tap(find.text('Send reset link'));
      await go(tester);

      expect(find.text(ForgotPasswordViewModel.confirmation), findsOneWidget);
    });

    testWidgets('a failure to send is not shown as sent', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp();
      app.auth.resetError = authError('network-request-failed');
      await open(tester, route: AppRoutes.forgotPassword, app: app);

      await type(tester, 0, 'ayesha@example.com');
      await tester.tap(find.text('Send reset link'));
      await go(tester);

      expect(find.text(ForgotPasswordViewModel.confirmation), findsNothing);
      expect(find.text('Send reset link'), findsOneWidget);
      expect(find.text('ayesha@example.com'), findsOneWidget);
    });

    testWidgets('Send again works after 30 seconds, not before', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(
        tester,
        route: AppRoutes.forgotPassword,
      );
      await type(tester, 0, 'ayesha@example.com');
      await tester.tap(find.text('Send reset link'));
      await go(tester);
      final ForgotPasswordViewModel vm = Get.find<ForgotPasswordViewModel>();

      expect(vm.canSendAgain, isFalse);
      expect(find.text('Send again in 30s'), findsOneWidget);
      await vm.send();
      expect(app.auth.count('reset'), 1);

      await tester.pump(const Duration(seconds: 29));
      expect(vm.canSendAgain, isFalse);
      expect(find.text('Send again in 1s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(vm.canSendAgain, isTrue);
      expect(find.text('Send again'), findsOneWidget);

      await tester.tap(find.text('Send again'));
      await go(tester);
      expect(app.auth.count('reset'), 2);
      expect(vm.canSendAgain, isFalse);
    });
  });

  group('Logout', () {
    late FakeAuthService auth;

    Future<AuthTestApp> openSettings(WidgetTester tester) async {
      auth = FakeAuthService();
      final AuthTestApp app = AuthTestApp(auth: auth);
      await open(tester, route: AppRoutes.settings, app: app);
      return app;
    }

    /// The Sign out row sits near the bottom of Settings.
    Future<void> tapSignOutRow(WidgetTester tester) async {
      final Finder row = find.text('Sign out').first;
      await tester.ensureVisible(row);
      await go(tester);
      await tester.tap(row);
    }

    /// Logs out through the ViewModel and lets the delayed clean-up run.
    Future<void> logoutAndSettle(WidgetTester tester) async {
      final Future<void> done = Get.find<SettingsViewModel>().logout();
      await tester.pump(const Duration(seconds: 1));
      await done;
    }

    /// Some of what a signed-in session leaves behind.
    void putUserControllers(AuthTestApp app) {
      Get.put<HomeViewModel>(
        buildHome(
          auth: app.authRepository,
          profileRepository: app.profileRepository,
        ),
      );
      Get.put<GamesHubViewModel>(
        GamesHubViewModel(
          breakRepository(FakeBreakService()),
          gratitudeRepository(FakeGratitudeService()),
        ),
      );
    }

    testWidgets('asks first, and Cancel does nothing', (
      WidgetTester tester,
    ) async {
      await openSettings(tester);

      await tapSignOutRow(tester);
      await go(tester);
      expect(find.text('Sign out of MindMate?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await go(tester);

      expect(auth.calls, isEmpty);
      expect(Get.currentRoute, AppRoutes.settings);
    });

    testWidgets('signs out of both, goes to Welcome with no way back', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await openSettings(tester);
      putUserControllers(app);
      expect(Get.isRegistered<HomeViewModel>(), isTrue);

      await tapSignOutRow(tester);
      await go(tester);
      await tester.tap(find.text('Sign out').last);
      await go(tester, 400);

      expect(auth.count('signOutGoogle'), 1);
      expect(auth.count('signOutFirebase'), 1);
      expect(Get.currentRoute, AppRoutes.welcome);
      expect(find.text('WELCOME'), findsOneWidget);
      expect(Get.key.currentState?.canPop(), isFalse);

      await tester.pump(const Duration(milliseconds: 300));
      expect(Get.isRegistered<HomeViewModel>(), isFalse);
      expect(Get.isRegistered<GamesHubViewModel>(), isFalse);
      expect(Get.isRegistered<SettingsViewModel>(), isFalse);
    });

    testWidgets('Google first, then Firebase', (WidgetTester tester) async {
      await openSettings(tester);

      await logoutAndSettle(tester);

      expect(
        auth.calls.where((String c) => c.startsWith('signOut')).toList(),
        <String>['signOutGoogle', 'signOutFirebase'],
      );
    });

    testWidgets('a Google problem does not stop the Firebase sign-out', (
      WidgetTester tester,
    ) async {
      await openSettings(tester);
      auth.googleSignOutError = StateError('boom');

      await logoutAndSettle(tester);

      expect(auth.count('signOutFirebase'), 1);
      expect(Get.currentRoute, AppRoutes.welcome);
    });

    testWidgets(
      'if signing out fails the screen stays and nothing is removed',
      (WidgetTester tester) async {
        final AuthTestApp app = await openSettings(tester);
        putUserControllers(app);
        auth.firebaseSignOutError = StateError('offline');

        await tapSignOutRow(tester);
        await go(tester);
        await tester.tap(find.text('Sign out').last);
        await go(tester, 1000);

        expect(Get.currentRoute, AppRoutes.settings);
        expect(Get.isRegistered<HomeViewModel>(), isTrue);
        expect(Get.isRegistered<GamesHubViewModel>(), isTrue);
        expect(Get.find<SettingsViewModel>().isLoggingOut.value, isFalse);

        // It can be tried again.
        auth.firebaseSignOutError = null;
        await logoutAndSettle(tester);
        expect(Get.currentRoute, AppRoutes.welcome);
      },
    );

    testWidgets('a second tap while signing out does nothing', (
      WidgetTester tester,
    ) async {
      await openSettings(tester);
      final SettingsViewModel vm = Get.find<SettingsViewModel>();

      final Future<void> first = vm.logout();
      final Future<void> second = vm.logout();
      await tester.pump(const Duration(seconds: 1));
      await Future.wait(<Future<void>>[first, second]);

      expect(auth.count('signOutFirebase'), 1);
    });
  });

  group('The account service', () {
    test('logout asks Google and then Firebase to sign out', () async {
      final List<String> calls = <String>[];
      final _RecordingAuthService service = _RecordingAuthService(calls);

      await service.logout();

      expect(calls, <String>['google', 'firebase']);
    });

    test('logout still signs out of Firebase when Google fails', () async {
      final List<String> calls = <String>[];
      final _RecordingAuthService service = _RecordingAuthService(
        calls,
        failGoogle: true,
      );

      await service.logout();

      expect(calls, <String>['google', 'firebase']);
    });

    test('logout reports a Firebase failure', () async {
      final List<String> calls = <String>[];
      final _RecordingAuthService service = _RecordingAuthService(
        calls,
        failFirebase: true,
      );

      await expectLater(service.logout(), throwsStateError);
    });

    test('the repository\'s logout reaches both sign-outs', () async {
      final List<String> calls = <String>[];
      final AuthRepository repository = AuthRepository(
        _RecordingAuthService(calls),
      );

      await repository.logout();

      expect(calls, <String>['google', 'firebase']);
    });
  });

  group('User session', () {
    test('removes every user-specific controller and nothing else', () {
      final AuthTestApp app = AuthTestApp();
      Get.put<HomeViewModel>(buildHome(auth: app.authRepository));
      Get.put<GamesHubViewModel>(
        GamesHubViewModel(
          breakRepository(FakeBreakService()),
          gratitudeRepository(FakeGratitudeService()),
        ),
      );
      Get.put<AuthRepository>(app.authRepository);

      UserSession.clearControllers();

      expect(Get.isRegistered<HomeViewModel>(), isFalse);
      expect(Get.isRegistered<GamesHubViewModel>(), isFalse);
      expect(Get.isRegistered<AuthRepository>(), isTrue);
    });

    test('is safe when nothing is registered, and when repeated', () {
      UserSession.clearControllers();
      UserSession.clearControllers();
    });
  });
}

class _RecordingAuthService extends AuthService {
  _RecordingAuthService(
    this.calls, {
    this.failGoogle = false,
    this.failFirebase = false,
  });

  final List<String> calls;
  final bool failGoogle;
  final bool failFirebase;

  @override
  Future<void> signOutFromGoogle() async {
    calls.add('google');
    if (failGoogle) {
      throw StateError('google');
    }
  }

  @override
  Future<void> signOutFromFirebase() async {
    calls.add('firebase');
    if (failFirebase) {
      throw StateError('firebase');
    }
  }
}
