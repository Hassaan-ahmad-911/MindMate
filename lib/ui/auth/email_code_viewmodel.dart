import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../Data/repositories/auth_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../../Models/email_code_rules.dart';
import '../../services/email_code_service.dart';
import '../app/app_routes.dart';
import '../shared/app_feedback.dart';
import 'auth_flow.dart';
import 'pending_signup.dart';

/// Which job the code screen is doing.
enum EmailCodeMode {
  /// "Check your email": the code creates the new account.
  newAccount,

  /// "Confirm your email": an existing account confirms its address.
  existing,
}

enum EmailCodeStatus { idle, sending, submitting }

/// "Check your email" and "Confirm your email": six boxes for the emailed
/// code, the resend countdown, and what happens when the code is right.
///
/// Neither the code nor the password is ever logged.
class EmailCodeViewModel extends GetxController {
  EmailCodeViewModel(
    this._auth,
    ProfileRepository profiles, {
    required this.mode,
    PendingSignup? pending,
    AuthFlow? flow,
    DateTime Function()? clock,
  }) : _pending = pending ?? PendingSignup.shared(),
       _flow = flow ?? AuthFlow(_auth, profiles),
       _now = clock ?? DateTime.now;

  final AuthRepository _auth;
  final PendingSignup _pending;
  final AuthFlow _flow;
  final DateTime Function() _now;
  final EmailCodeMode mode;

  final TextEditingController codeController = TextEditingController();
  final FocusNode codeFocus = FocusNode();

  /// The digits typed so far (0 to 6).
  final RxString code = ''.obs;
  final Rx<EmailCodeStatus> status = EmailCodeStatus.idle.obs;

  /// The line under the boxes, or null.
  final RxnString message = RxnString();

  /// The last code was turned down: the boxes keep showing it, with navy
  /// borders, until the person types again.
  final RxString rejectedCode = ''.obs;

  /// The current code is spent (expired, too many tries, none on file):
  /// the button stays off until a new one is sent.
  final RxBool needsNewCode = false.obs;

  /// The white "Send a new code" pill under the message.
  final RxBool showNewCodePill = false.obs;

  /// Seconds before another code can be asked for.
  final RxInt resendSeconds = 0.obs;

  /// "The code works for 10 minutes."
  final RxInt expiresMinutes = 10.obs;

  final ResendCountdown _countdown = ResendCountdown();
  Timer? _ticker;

  /// The sign-up this screen belongs to (see [PendingSignup.clear]).
  late final int _session;

  bool get isNewAccount => mode == EmailCodeMode.newAccount;

  String get email =>
      isNewAccount ? _pending.email : (_auth.currentUser?.email?.trim() ?? '');

  String get title => isNewAccount ? 'Check your email' : 'Confirm your email';

  String get buttonLabel => isNewAccount ? 'Create account' : 'Confirm email';

  bool get isBusy => status.value != EmailCodeStatus.idle;

  bool get isRejected => rejectedCode.value.isNotEmpty;

  /// What the six boxes show.
  String get shownCode => isRejected ? rejectedCode.value : code.value;

  bool get canSubmit =>
      code.value.length == CodeInput.length &&
      !isBusy &&
      !needsNewCode.value &&
      !isRejected;

  @override
  void onInit() {
    super.onInit();
    _session = _pending.session;
    if (isNewAccount) {
      expiresMinutes.value = (_pending.expiresIn / 60).ceil();
      _startCountdown(_pending.resendIn);
      if (_pending.codeSentEarlier) {
        message.value = EmailCodeMessages.codeSentEarlier;
      }
    }
  }

  @override
  void onReady() {
    super.onReady();
    if (!isNewAccount) {
      // An existing account gets its code as soon as the screen opens.
      unawaited(resend());
    }
  }

  /// Called by the hidden field on every change.
  void onCodeChanged(String value) {
    final String clean = CodeInput.sanitize(value);
    if (message.value == EmailCodeMessages.codeSentEarlier) {
      message.value = null;
    }
    if (isRejected) {
      // Typing again starts a fresh code.
      rejectedCode.value = '';
      if (!needsNewCode.value) {
        message.value = null;
        showNewCodePill.value = false;
      }
    }
    code.value = clean;
    if (clean.length == CodeInput.length && canSubmit) {
      unawaited(submit());
    }
  }

  /// "Create account" / "Confirm email", and the sixth digit.
  Future<void> submit() async {
    if (!canSubmit) {
      return;
    }
    final String typed = code.value;
    status.value = EmailCodeStatus.submitting;
    message.value = null;
    try {
      if (isNewAccount) {
        await _finishNewAccount(typed);
      } else {
        await _auth.confirmEmail(typed);
        await _continueAfterConfirmed();
      }
    } on EmailCodeException catch (error) {
      await _onCodeError(error, typed);
    } catch (_) {
      message.value = EmailCodeMessages.unreachable;
    } finally {
      if (!isClosed) {
        status.value = EmailCodeStatus.idle;
      }
    }
  }

  Future<void> _finishNewAccount(String typed) async {
    final String email = _pending.email;
    final String? password = _pending.password;
    if (!_pending.isReady || password == null) {
      // The details are gone (the app was restarted): start again.
      Get.offAllNamed<void>(AppRoutes.signup);
      return;
    }

    final String uid = await _auth.verifySignupCode(
      email: email,
      code: typed,
      password: password,
      name: _pending.name,
    );

    // The account exists now, with its email confirmed.
    try {
      await _auth.login(email: email, password: password);
    } catch (_) {
      _pending.clear();
      showMindMateSnackBar(
        'Your account is ready',
        'Please log in with your email and new password.',
      );
      _flow.goTo(AppRoutes.login);
      return;
    }
    _pending.clear();

    // Not waited for, as before: Firestore keeps the write until it can send.
    unawaited(_flow.recordConsent());

    FocusManager.instance.primaryFocus?.unfocus();
    TextInput.finishAutofillContext();
    _flow.goTo(
      AppRoutes.createProfile,
      arguments: <String, String>{'uid': uid, 'email': email},
    );
  }

  /// After the email is confirmed: the usual next screen.
  Future<void> _continueAfterConfirmed() async {
    final String route = await _flow.routeAfterSignIn();
    if (route == AppRoutes.confirmEmail) {
      // The account did not refresh (offline): stay and say so.
      message.value = EmailCodeMessages.unreachable;
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _flow.goTo(route);
  }

  Future<void> _onCodeError(EmailCodeException error, String typed) async {
    if (error.code == 'unauthorized') {
      await _signOutTo(AppRoutes.login, note: EmailCodeMessages.logInAgain);
      return;
    }
    message.value = EmailCodeMessages.forError(error);
    final bool spent = EmailCodeMessages.needsNewCode(error.code);
    needsNewCode.value = spent;
    if (error.code == 'wrong_code' || spent) {
      rejectedCode.value = typed;
      showNewCodePill.value = true;
      code.value = '';
      codeController.clear();
      codeFocus.requestFocus();
    }
  }

  /// "Send a new code" (also sends the first one for an existing account).
  Future<void> resend() async {
    if (isBusy || resendSeconds.value > 0) {
      return;
    }
    status.value = EmailCodeStatus.sending;
    try {
      final CodeSent sent = isNewAccount
          ? await _auth.sendSignupCode(_pending.email)
          : await _auth.sendConfirmEmailCode();
      if (sent.alreadyVerified) {
        await _auth.refreshAfterEmailConfirmed();
        await _continueAfterConfirmed();
        return;
      }
      expiresMinutes.value = (sent.expiresIn / 60).ceil();
      _startCountdown(sent.resendIn);
      _clearCode();
      codeFocus.requestFocus();
    } on EmailCodeException catch (error) {
      if (error.code == 'wait_before_resend') {
        _startCountdown(error.retryAfter ?? 60);
        message.value = EmailCodeMessages.codeSentEarlier;
      } else if (error.code == 'unauthorized') {
        await _signOutTo(AppRoutes.login, note: EmailCodeMessages.logInAgain);
      } else {
        message.value = EmailCodeMessages.forError(error);
      }
    } catch (_) {
      message.value = EmailCodeMessages.unreachable;
    } finally {
      if (!isClosed) {
        status.value = EmailCodeStatus.idle;
      }
    }
  }

  void _clearCode() {
    code.value = '';
    rejectedCode.value = '';
    message.value = null;
    needsNewCode.value = false;
    showNewCodePill.value = false;
    codeController.clear();
  }

  void _startCountdown(int seconds) {
    _ticker?.cancel();
    _countdown.start(seconds, _now());
    resendSeconds.value = _countdown.remaining(_now());
    if (resendSeconds.value == 0) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      resendSeconds.value = _countdown.remaining(_now());
      if (resendSeconds.value == 0) {
        timer.cancel();
      }
    });
  }

  /// Back and "Change email": to Create account, fields still filled.
  void back() {
    FocusManager.instance.primaryFocus?.unfocus();
    _pending.clear(session: _session);
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back<void>();
    } else {
      Get.offAllNamed<void>(AppRoutes.signup);
    }
  }

  /// "Not you? Sign out" (existing accounts).
  Future<void> signOut() => _signOutTo(AppRoutes.welcome);

  Future<void> _signOutTo(String route, {String? note}) async {
    try {
      await _auth.logout();
    } catch (_) {
      // Leave the screen either way.
    }
    _pending.clear();
    if (note != null) {
      showMindMateSnackBar('Signed out', note);
    }
    _flow.goTo(route);
  }

  @override
  void onClose() {
    _ticker?.cancel();
    if (isNewAccount) {
      _pending.clear(session: _session);
    }
    codeController.dispose();
    codeFocus.dispose();
    super.onClose();
  }
}
