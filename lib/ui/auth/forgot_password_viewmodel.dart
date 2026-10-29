import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Data/repositories/auth_repository.dart';
import '../../Models/auth_validation.dart';
import '../app/app_routes.dart';
import '../shared/app_feedback.dart';
import 'auth_errors.dart';

class ForgotPasswordViewModel extends GetxController {
  ForgotPasswordViewModel(
    this._authRepository, {
    String initialEmail = '',
    this.resendDelay = const Duration(seconds: 30),
  }) : emailController = TextEditingController(text: initialEmail);

  /// The same words whether or not the email has an account, so nobody can use
  /// this screen to find out who is registered.
  static const String confirmation =
      'If an account exists for that email, a reset link is on its way.';

  final AuthRepository _authRepository;

  /// How long before "Send again" works.
  final Duration resendDelay;

  final TextEditingController emailController;
  final FocusNode emailFocus = FocusNode();

  final RxBool isLoading = false.obs;
  final RxnString emailError = RxnString();

  /// A link has been asked for: the screen shows the confirmation.
  final RxBool sent = false.obs;

  /// Seconds until "Send again" works. 0 when it already does.
  final RxInt secondsUntilResend = 0.obs;

  Timer? _ticker;
  bool _emailTouched = false;

  bool get canSendAgain => sent.value && secondsUntilResend.value == 0;

  @override
  void onInit() {
    super.onInit();
    emailFocus.addListener(() {
      if (!emailFocus.hasFocus) {
        _emailTouched = true;
        _checkEmail();
      }
    });
  }

  void onEmailChanged(String _) {
    if (_emailTouched) {
      _checkEmail();
    }
  }

  void _checkEmail() {
    emailError.value = AuthValidation.emailError(emailController.text);
  }

  /// "Send reset link" and, after that, "Send again".
  Future<void> send() async {
    if (isLoading.value || (sent.value && !canSendAgain)) {
      return;
    }
    _emailTouched = true;
    _checkEmail();
    if (emailError.value != null) {
      return;
    }

    isLoading.value = true;
    try {
      await _authRepository.forgotPassword(email: emailController.text.trim());
      _showConfirmation();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        // Looks the same as a sent link.
        _showConfirmation();
      } else if (error.code == 'invalid-email') {
        emailError.value = AuthErrors.messageFor(error);
      } else {
        final String? message = AuthErrors.messageFor(error);
        if (message != null) {
          showMindMateSnackBar('Could not send the link', message);
        }
      }
    } catch (_) {
      showMindMateSnackBar('Could not send the link', AuthErrors.generic);
    } finally {
      isLoading.value = false;
    }
  }

  void _showConfirmation() {
    FocusManager.instance.primaryFocus?.unfocus();
    sent.value = true;
    _startCountdown();
  }

  void _startCountdown() {
    _ticker?.cancel();
    secondsUntilResend.value = resendDelay.inSeconds;
    if (secondsUntilResend.value == 0) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final int left = secondsUntilResend.value - 1;
      secondsUntilResend.value = left < 0 ? 0 : left;
      if (left <= 0) {
        timer.cancel();
      }
    });
  }

  void back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back<void>();
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  void onClose() {
    _ticker?.cancel();
    emailController.dispose();
    emailFocus.dispose();
    super.onClose();
  }
}
