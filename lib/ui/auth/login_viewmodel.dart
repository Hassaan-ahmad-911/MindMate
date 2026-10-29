import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../Data/repositories/auth_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../../Models/auth_validation.dart';
import '../app/app_routes.dart';
import '../shared/app_feedback.dart';
import 'auth_errors.dart';
import 'auth_flow.dart';

/// What is running, so only the pressed button shows the spinner.
enum AuthRequest { none, email, google }

class LoginViewModel extends GetxController {
  LoginViewModel(
    this._authRepository,
    ProfileRepository profileRepository, {
    AuthFlow? flow,
  }) : _flow = flow ?? AuthFlow(_authRepository, profileRepository);

  final AuthRepository _authRepository;
  final AuthFlow _flow;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  final RxBool obscurePassword = true.obs;
  final Rx<AuthRequest> request = AuthRequest.none.obs;

  /// The message under each field, once the person has left it or tried to
  /// log in.
  final RxnString emailError = RxnString();
  final RxnString passwordError = RxnString();

  /// Asks a brand-new Google account to agree to the self-support notice.
  /// The screen sets this; it answers true when they agree.
  Future<bool> Function()? askGoogleConsent;

  bool _emailTouched = false;
  bool _passwordTouched = false;

  /// While anything is running the inputs are off and nothing can be pressed
  /// twice.
  bool get isLoading => request.value != AuthRequest.none;

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
  }

  void onEmailChanged(String _) {
    if (_emailTouched) {
      _checkEmail();
    }
  }

  void onPasswordChanged(String _) {
    if (_passwordTouched) {
      _checkPassword();
    }
  }

  void _checkEmail() {
    emailError.value = AuthValidation.emailError(emailController.text);
  }

  void _checkPassword() {
    passwordError.value = AuthValidation.loginPasswordError(
      passwordController.text,
    );
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  /// "Log in" (and "done" on the keyboard).
  Future<void> submit() async {
    if (isLoading) {
      return;
    }
    _emailTouched = true;
    _passwordTouched = true;
    _checkEmail();
    _checkPassword();
    if (emailError.value != null || passwordError.value != null) {
      return;
    }

    request.value = AuthRequest.email;
    try {
      await _authRepository.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      final String route = await _flow.routeAfterSignIn();
      FocusManager.instance.primaryFocus?.unfocus();
      TextInput.finishAutofillContext();
      _flow.goTo(route);
    } catch (error) {
      final String? message = AuthErrors.messageFor(error);
      if (message != null) {
        showMindMateSnackBar('Could not log in', message);
      }
    } finally {
      request.value = AuthRequest.none;
    }
  }

  Future<void> loginWithGoogle() async {
    if (isLoading) {
      return;
    }

    request.value = AuthRequest.google;
    try {
      final credential = await _authRepository.signInWithGoogle();
      if (credential == null) {
        // Cancelled: nothing to say.
        return;
      }

      final result = await _flow.afterGoogle(askConsent: askGoogleConsent);
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

  void goToSignup() {
    if (Get.currentRoute == AppRoutes.signup) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Get.offNamed(AppRoutes.signup);
  }

  /// Opens Reset password with whatever was typed as the email.
  void goToForgotPassword() {
    FocusManager.instance.primaryFocus?.unfocus();
    Get.toNamed(
      AppRoutes.forgotPassword,
      arguments: <String, String>{'email': emailController.text.trim()},
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.onClose();
  }
}
