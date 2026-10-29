import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindmate/Models/email_code_rules.dart';
import 'package:mindmate/services/auth_service.dart';
import 'package:mindmate/services/email_code_service.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/app/post_auth_routing.dart';
import 'package:mindmate/ui/auth/email_code_viewmodel.dart';
import 'package:mindmate/ui/shared/gradient_button.dart';

import 'helpers/auth_app.dart';
import 'helpers/profile_fakes.dart';

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
  String route = AppRoutes.signup,
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

/// Fills Create account and taps the button: the code screen opens.
Future<void> startSignup(WidgetTester tester) async {
  Future<void> type(int index, String text) async {
    await tester.tap(find.byType(TextField).at(index));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(index), text);
    await tester.pump();
  }

  await type(0, 'ayesha@example.com');
  await type(1, 'abcd1234');
  await type(2, 'abcd1234');
  await tester.tap(find.textContaining('I understand MindMate'));
  await tester.pump();
  await tester.tap(find.text('Create account').last);
  await go(tester, 900);
}

Future<void> enterCode(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await go(tester, 900);
}

GradientButton mainButton(WidgetTester tester) =>
    tester.widget<GradientButton>(find.byType(GradientButton));

// A signed-in account with chosen providers, for the routing rule.
class _Provider implements UserInfo {
  _Provider(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Account implements User {
  _Account({required this.providers, required this.emailVerified});

  final List<String> providers;
  int reloads = 0;

  @override
  final bool emailVerified;

  @override
  List<UserInfo> get providerData =>
      providers.map((String p) => _Provider(p)).toList();

  @override
  Future<void> reload() async => reloads += 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AccountAuthService extends AuthService {
  _AccountAuthService(this.user);

  final User? user;

  @override
  User? get currentUser => user;
}

void main() {
  group('messages', () {
    String? msg(String code, {int? attemptsLeft, int? retryAfter}) =>
        EmailCodeMessages.forError(
          EmailCodeException(
            code,
            attemptsLeft: attemptsLeft,
            retryAfter: retryAfter,
          ),
        );

    test('every server error has its words', () {
      expect(msg('invalid_email'), 'Please enter a valid email.');
      expect(
        msg('email_in_use'),
        'This email already has an account. Log in instead.',
      );
      expect(msg('weak_password'), 'Use at least 8 characters.');
      expect(msg('invalid_code_format'), 'Enter all 6 digits.');
      expect(
        msg('wrong_code', attemptsLeft: 3),
        "That code isn't right. 3 tries left.",
      );
      expect(
        msg('wrong_code', attemptsLeft: 1),
        "That code isn't right. 1 try left.",
      );
      expect(msg('code_expired'), 'This code has expired. Send a new one.');
      expect(msg('too_many_attempts'), 'Too many tries. Send a new code.');
      expect(msg('no_code'), 'Please send a new code.');
      expect(msg('wait_before_resend', retryAfter: 40), isNull);
      expect(
        msg('too_many_codes', retryAfter: 1500),
        "You've asked for a lot of codes. Try again in 25 minutes.",
      );
      expect(
        msg('too_many_codes', retryAfter: 30),
        "You've asked for a lot of codes. Try again in 1 minute.",
      );
      expect(
        msg('too_many_requests'),
        'Too many tries from this network. Please wait a few minutes.',
      );
      expect(msg('unauthorized'), 'Please log in again.');
      expect(msg('not_configured'), 'Sign-up is not set up yet.');
    });

    test('server errors, timeouts and no internet read the same', () {
      const String unreachable =
          "We couldn't reach MindMate. Check your connection and try again.";
      expect(msg('server_error'), unreachable);
      expect(msg('network'), unreachable);
      expect(msg('something_new'), unreachable);
    });

    test('a spent code needs a new one', () {
      expect(EmailCodeMessages.needsNewCode('code_expired'), isTrue);
      expect(EmailCodeMessages.needsNewCode('too_many_attempts'), isTrue);
      expect(EmailCodeMessages.needsNewCode('wrong_code'), isFalse);
    });
  });

  group('resend countdown', () {
    final DateTime t0 = DateTime(2026, 10, 25, 12);

    test('counts down from the server value and rounds up', () {
      final ResendCountdown countdown = ResendCountdown()..start(60, t0);
      expect(countdown.remaining(t0), 60);
      expect(
        countdown.remaining(t0.add(const Duration(milliseconds: 18500))),
        42,
      );
      expect(countdown.canResend(t0.add(const Duration(seconds: 59))), isFalse);
      expect(countdown.remaining(t0.add(const Duration(seconds: 60))), 0);
      expect(countdown.canResend(t0.add(const Duration(seconds: 61))), isTrue);
    });

    test('retryAfter restarts it', () {
      final ResendCountdown countdown = ResendCountdown()..start(60, t0);
      final DateTime later = t0.add(const Duration(seconds: 70));
      expect(countdown.canResend(later), isTrue);
      countdown.start(25, later);
      expect(countdown.remaining(later), 25);
    });

    test('nothing started means a code can be asked for', () {
      expect(ResendCountdown().canResend(t0), isTrue);
    });

    test('formats as m:ss', () {
      expect(ResendCountdown.format(42), '0:42');
      expect(ResendCountdown.format(75), '1:15');
      expect(ResendCountdown.format(0), '0:00');
    });
  });

  group('code input', () {
    test('keeps digits only, at most six', () {
      expect(CodeInput.sanitize('12a3'), '123');
      expect(CodeInput.sanitize('123 456'), '123456');
      expect(CodeInput.sanitize('Your code: 123456.'), '123456');
      expect(CodeInput.sanitize('1234567890'), '123456');
      expect(CodeInput.sanitize('abc'), '');
    });

    test('the formatter cleans a paste and keeps the cursor at the end', () {
      const CodeInputFormatter formatter = CodeInputFormatter();
      final TextEditingValue value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '98-76-54'),
      );
      expect(value.text, '987654');
      expect(value.selection.baseOffset, 6);
    });

    test('backspace just removes the last digit', () {
      const CodeInputFormatter formatter = CodeInputFormatter();
      final TextEditingValue value = formatter.formatEditUpdate(
        const TextEditingValue(text: '1234'),
        const TextEditingValue(text: '123'),
      );
      expect(value.text, '123');
    });

    test('is read out as one field', () {
      expect(CodeInput.semanticsLabel(4), '6-digit code, 4 of 6 entered');
    });
  });

  group('server address', () {
    test('empty means not set up', () {
      expect(EmailCodeConfig.usable(''), isNull);
      expect(EmailCodeConfig.usable('   '), isNull);
    });

    test('plain http only in debug builds', () {
      expect(
        EmailCodeConfig.usable('http://10.0.2.2:8080', release: false),
        'http://10.0.2.2:8080',
      );
      expect(
        EmailCodeConfig.usable('http://10.0.2.2:8080', release: true),
        isNull,
      );
      expect(
        EmailCodeConfig.usable('https://otp.example.com/', release: true),
        'https://otp.example.com',
      );
    });
  });

  group('EmailCodeService', () {
    test('posts JSON and reads the answer', () async {
      late http.Request seen;
      final EmailCodeService service = EmailCodeService(
        baseUrl: 'https://otp.example.com',
        client: MockClient((http.Request request) async {
          seen = request;
          return http.Response('{"expiresIn": 600, "resendIn": 60}', 200);
        }),
      );

      final CodeSent sent = await service.sendSignupCode('a@b.co');

      expect(
        seen.url.toString(),
        'https://otp.example.com/v1/signup/send-code',
      );
      expect(seen.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(seen.body), <String, dynamic>{'email': 'a@b.co'});
      expect(sent.resendIn, 60);
      expect(sent.expiresIn, 600);
    });

    test('sends the ID token for an existing account', () async {
      late http.Request seen;
      final EmailCodeService service = EmailCodeService(
        baseUrl: 'https://otp.example.com',
        client: MockClient((http.Request request) async {
          seen = request;
          return http.Response('{"alreadyVerified": true}', 200);
        }),
      );

      final CodeSent sent = await service.sendExistingCode('tok');

      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(sent.alreadyVerified, isTrue);
    });

    test('turns error answers into codes with their details', () async {
      EmailCodeService answering(int status, String body) => EmailCodeService(
        baseUrl: 'https://otp.example.com',
        client: MockClient((_) async => http.Response(body, status)),
      );

      await expectLater(
        answering(
          400,
          '{"error": "wrong_code", "attemptsLeft": 3}',
        ).verifySignup(email: 'a@b.co', code: '000000', password: 'abcd1234'),
        throwsA(
          isA<EmailCodeException>()
              .having((EmailCodeException e) => e.code, 'code', 'wrong_code')
              .having((EmailCodeException e) => e.attemptsLeft, 'left', 3),
        ),
      );
      await expectLater(
        answering(
          429,
          '{"error": "wait_before_resend", "retryAfter": 41}',
        ).sendSignupCode('a@b.co'),
        throwsA(
          isA<EmailCodeException>().having(
            (EmailCodeException e) => e.retryAfter,
            'retryAfter',
            41,
          ),
        ),
      );
      await expectLater(
        answering(502, '<html>Bad gateway</html>').sendSignupCode('a@b.co'),
        throwsA(
          isA<EmailCodeException>().having(
            (EmailCodeException e) => e.code,
            'code',
            'server_error',
          ),
        ),
      );
    });

    test('no connection is reported as network', () async {
      final EmailCodeService service = EmailCodeService(
        baseUrl: 'https://otp.example.com',
        client: MockClient((_) async => throw const SocketException('off')),
      );
      await expectLater(
        service.sendSignupCode('a@b.co'),
        throwsA(
          isA<EmailCodeException>().having(
            (EmailCodeException e) => e.code,
            'code',
            EmailCodeException.network,
          ),
        ),
      );
    });

    test('without an address nothing is sent', () async {
      int calls = 0;
      final EmailCodeService service = EmailCodeService(
        baseUrl: '',
        client: MockClient((_) async {
          calls += 1;
          return http.Response('{}', 200);
        }),
      );
      expect(service.isConfigured, isFalse);
      await expectLater(
        service.sendSignupCode('a@b.co'),
        throwsA(
          isA<EmailCodeException>().having(
            (EmailCodeException e) => e.code,
            'code',
            EmailCodeException.notConfigured,
          ),
        ),
      );
      expect(calls, 0);
    });
  });

  test('no account is ever created in the app', () {
    final List<File> dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(dartFiles, isNotEmpty);
    for (final File file in dartFiles) {
      expect(
        file.readAsStringSync().contains('createUserWithEmailAndPassword'),
        isFalse,
        reason: '${file.path} creates an account directly',
      );
    }
  });

  group('who must confirm their email', () {
    test('an email account that is not confirmed', () async {
      final _Account user = _Account(
        providers: <String>['password'],
        emailVerified: false,
      );
      expect(await _AccountAuthService(user).needsEmailConfirmation(), isTrue);
      expect(user.reloads, 1);
    });

    test('not a confirmed email account', () async {
      final _Account user = _Account(
        providers: <String>['password'],
        emailVerified: true,
      );
      expect(await _AccountAuthService(user).needsEmailConfirmation(), isFalse);
    });

    test('never a Google account', () async {
      for (final List<String> providers in <List<String>>[
        <String>['google.com'],
        <String>['google.com', 'password'],
      ]) {
        final _Account user = _Account(
          providers: providers,
          emailVerified: false,
        );
        expect(
          await _AccountAuthService(user).needsEmailConfirmation(),
          isFalse,
        );
      }
    });

    test('nobody signed in', () async {
      expect(await _AccountAuthService(null).needsEmailConfirmation(), isFalse);
    });

    test('the routing rule puts confirmation first', () {
      expect(
        PostAuthRouting.routeFor(
          hasProfile: true,
          needsEmailConfirmation: true,
        ),
        AppRoutes.confirmEmail,
      );
      expect(PostAuthRouting.routeFor(hasProfile: true), AppRoutes.home);
      expect(
        PostAuthRouting.routeFor(hasProfile: false),
        AppRoutes.createProfile,
      );
    });
  });

  group('Check your email', () {
    setUp(() => Get.testMode = true);
    tearDown(Get.reset);

    testWidgets('wrong code, then the right one, creates the account', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(tester);
      await startSignup(tester);

      expect(Get.currentRoute, AppRoutes.verifyEmailCode);
      expect(app.pending.password, 'abcd1234');
      expect(mainButton(tester).onPressed, isNull);

      // The sixth digit submits by itself.
      await enterCode(tester, '111111');
      expect(app.emailCodes.count('verify'), 1);
      expect(find.text("That code isn't right. 4 tries left."), findsOneWidget);
      expect(find.text('Send a new code'), findsWidgets);
      expect(Get.currentRoute, AppRoutes.verifyEmailCode);
      expect(app.auth.count('login'), 0);

      await enterCode(tester, '123456');

      expect(app.emailCodes.count('verify'), 2);
      expect(app.emailCodes.lastPassword, 'abcd1234');
      expect(app.auth.count('login'), 1);
      expect(app.auth.count('consent'), 1);
      expect(Get.currentRoute, AppRoutes.createProfile);
      expect(Get.key.currentState?.canPop(), isFalse);
      // The password is gone from memory.
      expect(app.pending.password, isNull);
      expect(app.pending.isReady, isFalse);
    });

    testWidgets('a pasted code with spaces and letters fills all six', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(tester);
      await startSignup(tester);

      await enterCode(tester, '12a');
      expect(Get.find<EmailCodeViewModel>().code.value, '12');
      expect(app.emailCodes.count('verify'), 0);

      await enterCode(tester, 'Code: 123 456');
      expect(app.emailCodes.count('verify'), 1);
      expect(Get.currentRoute, AppRoutes.createProfile);
    });

    testWidgets('an expired code keeps the button off until a new one', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(tester);
      await startSignup(tester);
      app.emailCodes.verifyError = const EmailCodeException('code_expired');

      await enterCode(tester, '123456');
      expect(
        find.text('This code has expired. Send a new one.'),
        findsOneWidget,
      );

      // Typing again does not submit a spent code.
      await enterCode(tester, '123456');
      expect(app.emailCodes.count('verify'), 1);
      expect(mainButton(tester).onPressed, isNull);

      await tester.tap(find.text('Send a new code').first);
      await go(tester);
      expect(app.emailCodes.count('send'), 2);
      expect(find.text('This code has expired. Send a new one.'), findsNothing);

      await enterCode(tester, '123456');
      expect(app.emailCodes.count('verify'), 2);
      expect(Get.currentRoute, AppRoutes.createProfile);
    });

    testWidgets('the resend link waits for the countdown', (
      WidgetTester tester,
    ) async {
      DateTime now = DateTime(2026, 10, 25, 12);
      final AuthTestApp app = AuthTestApp()..clock = () => now;
      app.emailCodes.resendIn = 3;
      await open(tester, app: app);
      await startSignup(tester);

      expect(find.text("Didn't get it? Resend in 0:03"), findsOneWidget);
      for (int i = 0; i < 3; i += 1) {
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text("Didn't get it? Resend in 0:03"), findsNothing);
      expect(find.text('Send a new code'), findsOneWidget);

      // A server that still says wait restarts the countdown.
      app.emailCodes.sendError = const EmailCodeException(
        'wait_before_resend',
        retryAfter: 2,
      );
      await tester.tap(find.text('Send a new code'));
      await tester.pump();
      expect(find.text("Didn't get it? Resend in 0:02"), findsOneWidget);
      for (int i = 0; i < 2; i += 1) {
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
    });

    testWidgets('asking again within a minute says the first code works', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp();
      app.emailCodes.sendError = const EmailCodeException(
        'wait_before_resend',
        retryAfter: 0,
      );
      await open(tester, app: app);
      await startSignup(tester);

      expect(Get.currentRoute, AppRoutes.verifyEmailCode);
      expect(find.text(EmailCodeMessages.codeSentEarlier), findsOneWidget);

      // Typing the earlier code clears the note and still works.
      await enterCode(tester, '123456');
      expect(Get.currentRoute, AppRoutes.createProfile);
    });

    testWidgets('Change email goes back with the fields kept', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = await open(tester);
      await startSignup(tester);

      await tester.tap(find.text('Change email'));
      await go(tester, 900);

      expect(Get.currentRoute, AppRoutes.signup);
      expect(find.text('ayesha@example.com'), findsOneWidget);
      expect(app.pending.password, isNull);
    });

    testWidgets('without a server address, Create account says so', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp();
      app.emailCodes.sendError = const EmailCodeException(
        EmailCodeException.notConfigured,
      );
      await open(tester, app: app);
      await startSignup(tester);

      expect(Get.currentRoute, AppRoutes.signup);
      expect(find.text('Sign-up is not set up yet.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Confirm your email (older accounts)', () {
    setUp(() => Get.testMode = true);
    tearDown(Get.reset);

    testWidgets('logging in to an unconfirmed account asks for a code', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp(
        profiles: FakeProfileService(profile: null),
      );
      app.auth.needsConfirmation = true;
      await open(tester, route: AppRoutes.login, app: app);

      await tester.enterText(
        find.byType(TextField).at(0),
        'ayesha@example.com',
      );
      await tester.enterText(find.byType(TextField).at(1), 'secret1');
      await tester.tap(find.text('Log in'));
      await go(tester, 900);

      expect(Get.currentRoute, AppRoutes.confirmEmail);
      expect(find.text('Confirm your email'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Change email'), findsNothing);
      // The code goes out as soon as the screen opens.
      expect(app.emailCodes.count('sendExisting'), 1);

      await enterCode(tester, '123456');
      expect(app.emailCodes.count('verifyExisting'), 1);
      expect(app.auth.count('refresh'), 1);
      expect(Get.currentRoute, AppRoutes.createProfile);
    });

    testWidgets('a Google account is never asked', (WidgetTester tester) async {
      final AuthTestApp app = AuthTestApp();
      app.auth.disclaimerAccepted = true;
      await open(tester, route: AppRoutes.login, app: app);

      await tester.tap(find.text('Continue with Google'));
      await go(tester, 900);

      // FakeAuthService.needsConfirmation is false, as the real service
      // answers for Google accounts (see "who must confirm their email").
      expect(Get.currentRoute, AppRoutes.createProfile);
      expect(app.emailCodes.count('sendExisting'), 0);
    });

    testWidgets('already confirmed elsewhere: carries on', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp();
      app.auth.needsConfirmation = true;
      app.emailCodes.alreadyVerified = true;
      await open(tester, route: AppRoutes.confirmEmail, app: app);
      await go(tester, 900);

      expect(app.auth.count('refresh'), 1);
      expect(Get.currentRoute, AppRoutes.createProfile);
    });

    testWidgets('Not you? Sign out leaves for Welcome', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp();
      app.auth.needsConfirmation = true;
      await open(tester, route: AppRoutes.confirmEmail, app: app);

      await tester.tap(find.text('Sign out'));
      await go(tester, 900);

      expect(app.auth.count('signOutFirebase'), 1);
      expect(Get.currentRoute, AppRoutes.welcome);
    });

    testWidgets('a rejected token signs out and goes to Log in', (
      WidgetTester tester,
    ) async {
      final AuthTestApp app = AuthTestApp();
      app.auth.needsConfirmation = true;
      app.emailCodes.sendError = const EmailCodeException('unauthorized');
      await open(tester, route: AppRoutes.confirmEmail, app: app);
      await go(tester, 900);

      expect(app.auth.count('signOutFirebase'), 1);
      expect(Get.currentRoute, AppRoutes.login);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
