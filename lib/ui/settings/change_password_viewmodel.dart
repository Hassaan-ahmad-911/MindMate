import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Data/repositories/auth_repository.dart';
import '../shared/app_feedback.dart';

class ChangePasswordViewModel extends GetxController {
  ChangePasswordViewModel(this._authRepository);

  final AuthRepository _authRepository;

  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final RxBool obscureCurrentPassword = true.obs;
  final RxBool obscureNewPassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;
  final RxBool isLoading = false.obs;

  final RxString currentPasswordError = ''.obs;
  final RxString newPasswordError = ''.obs;
  final RxString confirmPasswordError = ''.obs;

  void toggleCurrentPasswordVisibility() {
    obscureCurrentPassword.value = !obscureCurrentPassword.value;
  }

  void toggleNewPasswordVisibility() {
    obscureNewPassword.value = !obscureNewPassword.value;
  }

  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword.value = !obscureConfirmPassword.value;
  }

  void clearCurrentPasswordError() => currentPasswordError.value = '';

  void clearNewPasswordError() => newPasswordError.value = '';

  void clearConfirmPasswordError() => confirmPasswordError.value = '';

  Future<void> updatePassword() async {
    if (isLoading.value) {
      return;
    }

    final bool valid = _validateInputs();
    if (!valid) {
      return;
    }

    isLoading.value = true;
    try {
      await _authRepository.changePassword(
        currentPassword: currentPasswordController.text.trim(),
        newPassword: newPasswordController.text.trim(),
      );

      _clearFields();
      showMindMateSnackBar(
        'Password updated',
        'Your password has been changed successfully.',
      );
      Get.back();
    } on FirebaseAuthException catch (error) {
      showMindMateSnackBar('Update failed', _messageFor(error));
    } catch (error) {
      showMindMateSnackBar('Update failed', _messageFor(error));
    } finally {
      isLoading.value = false;
    }
  }

  bool _validateInputs() {
    currentPasswordError.value = '';
    newPasswordError.value = '';
    confirmPasswordError.value = '';

    final String currentPassword = currentPasswordController.text.trim();
    final String newPassword = newPasswordController.text.trim();
    final String confirmPassword = confirmPasswordController.text.trim();

    bool isValid = true;

    if (currentPassword.isEmpty) {
      currentPasswordError.value = 'Current password is required';
      isValid = false;
    }

    if (newPassword.isEmpty) {
      newPasswordError.value = 'New password is required';
      isValid = false;
    } else if (newPassword.length < 6) {
      newPasswordError.value = 'Password must be at least 6 characters';
      isValid = false;
    }

    if (confirmPassword.isEmpty) {
      confirmPasswordError.value = 'Please confirm your new password';
      isValid = false;
    } else if (confirmPassword != newPassword) {
      confirmPasswordError.value = 'Passwords do not match';
      isValid = false;
    }

    if (!isValid &&
        confirmPassword.isNotEmpty &&
        newPassword.isNotEmpty &&
        confirmPassword != newPassword) {
      showMindMateSnackBar(
        'Passwords do not match',
        'Please re-enter the confirmation password.',
      );
    }

    return isValid;
  }

  void _clearFields() {
    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
    currentPasswordError.value = '';
    newPasswordError.value = '';
    confirmPasswordError.value = '';
  }

  String _messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-mismatch':
        case 'requires-recent-login':
          return 'Wrong current password. Please try again.';
        case 'weak-password':
          return 'The new password is too weak.';
        case 'network-request-failed':
          return 'Network error. Please check your connection and try again.';
        case 'no-current-user':
          return 'Please sign in again to continue.';
        case 'missing-email':
          return 'This account does not support password changes.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return error.message ?? 'Please try again.';
      }
    }

    if (error.toString().toLowerCase().contains('network')) {
      return 'Network error. Please check your connection and try again.';
    }

    return 'Please try again.';
  }

  @override
  void onClose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
