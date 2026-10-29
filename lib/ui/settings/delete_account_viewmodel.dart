import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../Data/repositories/account_repository.dart';
import '../../services/account_deletion_service.dart';
import '../app/app_routes.dart';
import '../app/user_session.dart';
import '../shared/app_feedback.dart';

/// Deleting the account: confirm identity, then delete everything in order.
class DeleteAccountViewModel extends GetxController {
  DeleteAccountViewModel(this._account, {void Function()? goToWelcome})
    : _goToWelcome = goToWelcome ?? _openWelcome;

  final AccountRepository _account;
  final void Function() _goToWelcome;

  final TextEditingController password = TextEditingController();
  final RxString passwordText = ''.obs;
  final RxBool googleConfirmed = false.obs;
  final RxBool isDeleting = false.obs;
  final RxBool isExporting = false.obs;
  final RxnString error = RxnString();

  static const String wrongPassword = 'That password is not right.';
  static const String failed =
      'We could not finish deleting your account. Please try again.';

  @override
  void onInit() {
    super.onInit();
    password.addListener(() => passwordText.value = password.text);
  }

  bool get isGoogleOnly => _account.isGoogleOnly;

  /// The button is on once re-authentication input is present.
  bool get canDelete =>
      !isDeleting.value &&
      (isGoogleOnly ? googleConfirmed.value : passwordText.value.isNotEmpty);

  Future<void> confirmWithGoogle() async {
    error.value = null;
    try {
      googleConfirmed.value = await _account.reauthenticateWithGoogle();
    } catch (_) {
      googleConfirmed.value = false;
      error.value = 'Google could not confirm it is you. Please try again.';
    }
  }

  Future<void> downloadMyData() async {
    if (isExporting.value) {
      return;
    }
    isExporting.value = true;
    try {
      await _account.downloadMyData();
    } catch (_) {
      showMindMateSnackBar(
        'Could not make the file',
        'Check your connection and try again.',
      );
    } finally {
      if (!isClosed) {
        isExporting.value = false;
      }
    }
  }

  Future<void> deleteAccount() async {
    if (!canDelete) {
      return;
    }
    error.value = null;
    isDeleting.value = true;
    if (!isGoogleOnly) {
      try {
        await _account.reauthenticateWithPassword(password.text);
      } on FirebaseAuthException {
        isDeleting.value = false;
        error.value = wrongPassword;
        return;
      } catch (_) {
        isDeleting.value = false;
        error.value = failed;
        return;
      }
    }
    try {
      await _account.deleteAccount();
    } on AccountDeletionException {
      if (!isClosed) {
        isDeleting.value = false;
        error.value = failed;
      }
      return;
    }
    _goToWelcome();
    showMindMateSnackBar(
      'Your account has been deleted.',
      'Thank you for using MindMate. Take care.',
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    UserSession.clearControllers();
  }

  static void _openWelcome() => Get.offAllNamed(AppRoutes.welcome);

  @override
  void onClose() {
    password.dispose();
    super.onClose();
  }
}
