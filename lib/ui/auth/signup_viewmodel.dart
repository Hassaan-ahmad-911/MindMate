import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Data/repositories/auth_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../../Models/auth_validation.dart';
import '../../Models/email_code_rules.dart';
import '../../services/email_code_service.dart';
import '../app/app_routes.dart';
import '../shared/app_feedback.dart';
import 'auth_errors.dart';
import 'auth_flow.dart';
import 'login_viewmodel.dart' show AuthRequest;
import 'pending_signup.dart';

class SignupViewModel extends GetxController {
  SignupViewModel(
    this._authRepository,
    ProfileRepository profileRepository, {
    AuthFlow? flow,
    PendingSignup? pending,
  }) : _flow = flow ?? AuthFlow(_authRepository, profileRepository),
       _pending = pending ?? PendingSignup.shared();

  final AuthRepository _authRepository;
  final AuthFlow _flow;
  final PendingSignup _pending;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  final FocusNode confirmFocus = FocusNode();

  final RxBool obscurePassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;
  final Rx<AuthRequest> request = AuthRequest.none.obs;

  /// "I understand MindMate is a self-support tool..."
  final RxBool acceptedDisclaimer = false.obs;

  final RxnString emailError = RxnString();
  final RxnString passwordError = RxnString();
  final RxnString confirmError = RxnString();

  /// The email already has an account: a "Log in" link shows under it.
  final RxBool emailInUse = false.obs;

  /// The password as typed, for the strength bar.
  final RxString passwordText = ''.obs;

  /// Asks a brand-new Google account to agree to the notice when the box above
  /// was not ticked. The screen sets this.
  Future<bool> Function()? askGoogleConsent;

  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _confirmTouched = false;

  bool get isLoading => request.value != AuthRequest.none;

  /// "Create account" works only once the notice is ticked, and not while
  /// something is running.
  bool get canSubmit => acceptedDisclaimer.value && !isLoading;

  PasswordStrength get strength => PasswordStrength.of(passwordText.value);

  @override
  void onInit() {
    super.onInit();
    emailFocus.addListener(() {
      if (!emailFocus.hasFocus) {
        _emailTouched = true;
        _checkEmail();
      }
    });
    passwordFocus.addListener(() {
      if (!passwordFocus.hasFocus) {
        _passwordTouched = true;
        _checkPassword();
      }
    });
    confirmFocus.addListener(() {
      if (!confirmFocus.hasFocus) {
        _confirmTouched = true;
        _checkConfirm();
      }
    });
  }

  void onEmailChanged(String _) {
    if (emailInUse.value) {
      emailInUse.value = false;
      emailError.value = null;
    }
    if (_emailTouched) {
      _checkEmail();
    }
  }

  void onPasswordChanged(String value) {
    passwordText.value = value;
    if (_passwordTouched) {
      _checkPassword();
    }
    if (_confirmTouched) {
      _checkConfirm();
    }
  }

  void onConfirmChanged(String _) {
    if (_confirmTouched) {
      _checkConfirm();
    }
  }

  void _checkEmail() {
    emailError.value = AuthValidation.emailError(emailController.text);
  }

  void _checkPassword() {
    passwordError.value = AuthValidation.newPasswordError(
      passwordController.text,
    );
  }

  void _checkConfirm() {
    confirmError.value = AuthValidation.confirmPasswordError(
      passwordController.text,
      confirmPasswordController.text,
    );
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword.value = !obscureConfirmPassword.value;
  }

  void setDisclaimer(bool value) {
    acceptedDisclaimer.value = value;
  }

  /// "Create account" (and "done" on the keyboard).
  Future<void> submit() async {
    if (isLoading || !acceptedDisclaimer.value) {
      return;
    }
    _emailTouched = true;
    _passwordTouched = true;
    _confirmTouched = true;
    _checkEmail();
    _checkPassword();
    _checkConfirm();
    if (emailError.value != null ||
        passwordError.value != null ||
        confirmError.value != null) {
      return;
    }

    // Nothing is created here: the server emails a code, and the account is
    // made on "Check your email" once the code is right.
    request.value = AuthRequest.email;
    final String email = emailController.text.trim();
    try {
      final CodeSent sent = await _authRepository.sendSignupCode(email);
      _openCodeScreen(email, sent.resendIn, sent.expiresIn);
    } on EmailCodeException catch (error) {
      switch (error.code) {
        case 'invalid_email':
          emailError.value = EmailCodeMessages.invalidEmail;
        case 'email_in_use':
          emailError.value = EmailCodeMessages.emailInUse;
          emailInUse.value = true;
        case 'weak_password':
          passwordError.value = EmailCodeMessages.weakPassword;
        case 'wait_before_resend':
          // A code was sent to this email moments ago and still works.
          _openCodeScreen(
            email,
            error.retryAfter ?? 60,
            600,
            codeSentEarlier: true,
          );
        default:
          showMindMateSnackBar(
            'Could not send the code',
            EmailCodeMessages.forError(error) ?? EmailCodeMessages.unreachable,
          );
      }
    } catch (_) {
      showMindMateSnackBar(
        'Could not send the code',
        EmailCodeMessages.unreachable,
      );
    } finally {
      request.value = AuthRequest.none;
    }
  }

  /// "Check your email". The password goes in memory only; the fields here
  /// stay filled for when the person comes back.
  void _openCodeScreen(
    String email,
    int resendIn,
    int expiresIn, {
    bool codeSentEarlier = false,
  }) {
    _pending.start(
      email: email,
      password: passwordController.text,
      resendIn: resendIn,
      expiresIn: expiresIn,
      codeSentEarlier: codeSentEarlier,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    Get.toNamed<void>(AppRoutes.verifyEmailCode);
  }

  Future<void> signUpWithGoogle() async {
    if (isLoading) {
      return;
    }

    request.value = AuthRequest.google;
    try {
      final credential = await _authRepository.signInWithGoogle();
      if (credential == null) {
        return;
      }

      final result = await _flow.afterGoogle(
        consentGiven: acceptedDisclaimer.value,
        askConsent: askGoogleConsent,
      );
      if (result.outcome == GoogleOutcome.declined) {
        showMindMateSnackBar(
          'Before you continue',
          'Please agree to the notice to create your account.',
        );
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      _flow.goTo(result.route);
    } catch (error) {
      final String? message = AuthErrors.messageFor(error);
      if (message != null) {
        showMindMateSnackBar('Google sign-in did not work', message);
      }
    } finally {
      request.value = AuthRequest.none;
    }
  }

  void back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back<void>();
    } else {
      Get.offAllNamed(AppRoutes.welcome);
    }
  }

  void goToLogin() {
    if (Get.currentRoute == AppRoutes.login) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Get.offNamed(AppRoutes.login);
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    confirmFocus.dispose();
    super.onClose();
  }
}
