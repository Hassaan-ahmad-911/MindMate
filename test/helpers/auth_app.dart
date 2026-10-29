import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/auth_repository.dart';
import 'package:mindmate/Data/repositories/profile_repository.dart';
import 'package:mindmate/services/auth_service.dart';
import 'package:mindmate/services/email_code_service.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/auth/email_code_view.dart';
import 'package:mindmate/ui/auth/email_code_viewmodel.dart';
import 'package:mindmate/ui/auth/pending_signup.dart';
import 'package:mindmate/ui/auth/forgot_password_view.dart';
import 'package:mindmate/ui/auth/forgot_password_viewmodel.dart';
import 'package:mindmate/ui/auth/login_view.dart';
import 'package:mindmate/ui/auth/login_viewmodel.dart';
import 'package:mindmate/ui/auth/signup_view.dart';
import 'package:mindmate/ui/auth/signup_viewmodel.dart';
import 'package:mindmate/ui/settings/settings_view.dart';
import 'package:mindmate/ui/settings/settings_viewmodel.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';

import 'profile_fakes.dart';

class FakeUser implements User {
  FakeUser({this.uid = 'uid-1', this.email = 'ayesha@example.com'});

  @override
  final String uid;

  @override
  final String? email;

  @override
  String? get displayName => null;

  @override
  String? get photoURL => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCredential implements UserCredential {
  FakeCredential([User? user]) : user = user ?? FakeUser();

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An account service that records what it was asked and fails on demand. No
/// Firebase, no Google.
class FakeAuthService extends AuthService {
  final List<String> calls = <String>[];

  /// Thrown by the next call of that kind.
  Object? loginError;
  Object? googleError;
  Object? resetError;
  Object? googleSignOutError;
  Object? firebaseSignOutError;

  /// Google sign-in was cancelled by the person.
  bool googleCancelled = false;

  /// What [hasAcceptedDisclaimer] says.
  bool disclaimerAccepted = false;

  /// If set, [login] waits for it (a request that is still running).
  Completer<void>? loginGate;

  int count(String call) => calls.where((String c) => c == call).length;

  @override
  Future<UserCredential> login(String email, String password) async {
    calls.add('login');
    await loginGate?.future;
    final Object? error = loginError;
    if (error != null) {
      throw error;
    }
    return FakeCredential();
  }

  /// What [needsEmailConfirmation] says (an email account never confirmed).
  bool needsConfirmation = false;

  /// Whether someone is signed in when the app starts (Splash).
  bool signedInAtStart = false;

  /// Thrown by [waitForAuthState] when set.
  Object? authStateError;

  @override
  Future<User?> waitForAuthState() async {
    final Object? error = authStateError;
    if (error != null) {
      throw error;
    }
    return signedInAtStart ? FakeUser() : null;
  }

  @override
  Future<bool> needsEmailConfirmation() async => needsConfirmation;

  @override
  Future<String> idToken() async => 'id-token';

  @override
  Future<void> refreshAfterEmailConfirmed() async {
    calls.add('refresh');
    needsConfirmation = false;
  }

  @override
  Future<UserCredential?> signInWithGoogle() async {
    calls.add('google');
    final Object? error = googleError;
    if (error != null) {
      throw error;
    }
    return googleCancelled ? null : FakeCredential();
  }

  @override
  Future<void> forgotPassword(String email) async {
    calls.add('reset');
    final Object? error = resetError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<bool> hasAcceptedDisclaimer() async => disclaimerAccepted;

  @override
  Future<void> recordDisclaimerAccepted() async {
    calls.add('consent');
    disclaimerAccepted = true;
  }

  @override
  Future<void> signOutFromGoogle() async {
    calls.add('signOutGoogle');
    final Object? error = googleSignOutError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> signOutFromFirebase() async {
    calls.add('signOutFirebase');
    final Object? error = firebaseSignOutError;
    if (error != null) {
      throw error;
    }
  }

  @override
  User? get currentUser => FakeUser();

  /// Signed in with Google only (no password to change).
  bool googleOnly = false;

  @override
  bool get isGoogleOnly => googleOnly;
}

/// The email-code server, scripted. Records every call (never the password
/// or code values in a log: they are only kept for the assertions).
class FakeEmailCodeService extends EmailCodeService {
  FakeEmailCodeService() : super(baseUrl: '');

  final List<String> calls = <String>[];

  /// The code the "server" accepts.
  String rightCode = '123456';
  int attemptsLeft = 5;

  /// Seconds before a resend; 0 keeps tests free of running timers.
  int resendIn = 0;

  /// Thrown by the next send / verify, then cleared.
  EmailCodeException? sendError;
  EmailCodeException? verifyError;

  /// The existing account's email is confirmed already.
  bool alreadyVerified = false;

  String? lastPassword;

  int count(String call) => calls.where((String c) => c == call).length;

  @override
  bool get isConfigured => true;

  CodeSent _sent() {
    final EmailCodeException? error = sendError;
    sendError = null;
    if (error != null) {
      throw error;
    }
    return CodeSent(resendIn: resendIn);
  }

  void _check(String code) {
    final EmailCodeException? error = verifyError;
    verifyError = null;
    if (error != null) {
      throw error;
    }
    if (code != rightCode) {
      attemptsLeft -= 1;
      throw EmailCodeException('wrong_code', attemptsLeft: attemptsLeft);
    }
  }

  @override
  Future<CodeSent> sendSignupCode(String email) async {
    calls.add('send');
    return _sent();
  }

  @override
  Future<String> verifySignup({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    calls.add('verify');
    _check(code);
    lastPassword = password;
    return 'new-uid';
  }

  @override
  Future<CodeSent> sendExistingCode(String idToken) async {
    calls.add('sendExisting');
    if (alreadyVerified) {
      return const CodeSent(alreadyVerified: true);
    }
    return _sent();
  }

  @override
  Future<void> verifyExisting(String idToken, String code) async {
    calls.add('verifyExisting');
    _check(code);
  }
}

/// The real account screens and routes (as in `app_pages.dart`), wired to
/// fakes. The next screens are plain placeholders.
class AuthTestApp {
  AuthTestApp({
    FakeAuthService? auth,
    FakeProfileService? profiles,
    FakeEmailCodeService? emailCodes,
  }) : auth = auth ?? FakeAuthService(),
       profiles = profiles ?? FakeProfileService(),
       emailCodes = emailCodes ?? FakeEmailCodeService();

  final FakeAuthService auth;
  final FakeProfileService profiles;
  final FakeEmailCodeService emailCodes;
  final PendingSignup pending = PendingSignup();

  /// The code screen's clock (for the resend countdown).
  DateTime Function()? clock;

  late final AuthRepository authRepository = AuthRepository(
    auth,
    emailCodes: emailCodes,
  );
  late final ProfileRepository profileRepository = ProfileRepository(profiles);

  Widget build({String initialRoute = AppRoutes.login}) {
    Widget placeholder(String text) =>
        Scaffold(body: Center(child: Text(text)));

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      initialRoute: initialRoute,
      getPages: <GetPage<dynamic>>[
        GetPage(name: AppRoutes.welcome, page: () => placeholder('WELCOME')),
        GetPage(
          name: AppRoutes.login,
          page: () => const LoginView(),
          binding: BindingsBuilder(() {
            Get.put<LoginViewModel>(
              LoginViewModel(authRepository, profileRepository),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.signup,
          page: () => const SignupView(),
          binding: BindingsBuilder(() {
            Get.put<SignupViewModel>(
              SignupViewModel(
                authRepository,
                profileRepository,
                pending: pending,
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.verifyEmailCode,
          page: () => const EmailCodeView(),
          binding: BindingsBuilder(() {
            Get.put<EmailCodeViewModel>(
              EmailCodeViewModel(
                authRepository,
                profileRepository,
                mode: EmailCodeMode.newAccount,
                pending: pending,
                clock: clock,
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.confirmEmail,
          page: () => const EmailCodeView(),
          binding: BindingsBuilder(() {
            Get.put<EmailCodeViewModel>(
              EmailCodeViewModel(
                authRepository,
                profileRepository,
                mode: EmailCodeMode.existing,
                pending: pending,
                clock: clock,
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.forgotPassword,
          page: () => const ForgotPasswordView(),
          binding: BindingsBuilder(() {
            final Object? arguments = Get.arguments;
            final Object? email = arguments is Map ? arguments['email'] : null;
            Get.put<ForgotPasswordViewModel>(
              ForgotPasswordViewModel(
                authRepository,
                initialEmail: email is String ? email : '',
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.settings,
          page: () => const SettingsView(),
          binding: BindingsBuilder(() {
            Get.put<SettingsViewModel>(
              SettingsViewModel(
                authRepository,
                cleanupDelay: const Duration(milliseconds: 100),
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.createProfile,
          page: () => placeholder('PROFILE SETUP'),
        ),
        GetPage(name: AppRoutes.home, page: () => placeholder('HOME')),
      ],
    );
  }
}
