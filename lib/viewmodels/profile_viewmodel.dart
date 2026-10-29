import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../Data/repositories/profile_repository.dart';
import '../Models/profile_validation.dart';
import '../Models/user_profile.dart';
import '../ui/app/app_routes.dart';
import '../ui/shared/app_feedback.dart';

/// The two-step profile setup (About you, Your work) that follows sign-up.
/// Nothing is loaded: the sign-in fills in the name and photo. Editing a
/// profile later happens on Edit profile (`EditProfileViewModel`).
class ProfileViewModel extends GetxController {
  ProfileViewModel(this._repository);

  final ProfileRepository _repository;

  final Rxn<UserProfile> profile = Rxn<UserProfile>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final RxnString selectedGender = RxnString();
  final RxBool isSaving = false.obs;
  final Rxn<File> selectedImageFile = Rxn<File>();

  // Setup (About you, Your work).
  final RxString nameText = ''.obs;
  final RxString ageText = ''.obs;
  final RxnString selectedRole = RxnString();
  final RxnString selectedShift = RxnString();
  final RxnString selectedYears = RxnString();
  final TextEditingController departmentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    nameController.addListener(() => nameText.value = nameController.text);
    ageController.addListener(() => ageText.value = ageController.text);
    _prefillFromSignIn();
  }

  /// A new Google account already has a name and a photo: start from those.
  void _prefillFromSignIn() {
    try {
      final UserProfile defaults = _repository.signedInUserDefaults();
      profile.value = defaults;
      nameController.text = defaults.name;
    } on Object {
      // Nothing to fill in: the user types their name.
    }
  }

  // ---------------------------------------------------------------------------
  // Setup.
  // ---------------------------------------------------------------------------

  /// "Continue" on About you needs a name, and an age that is blank or valid.
  bool get canContinueFromAbout =>
      ProfileValidation.isValid(name: nameText.value, age: ageText.value);

  /// Shown under the age field, or null.
  String? get ageError => ProfileValidation.ageError(ageText.value);

  /// "Continue" on Your work needs a role and the usual shifts.
  bool get canContinueFromWork =>
      selectedRole.value != null && selectedShift.value != null;

  /// Picks a gender chip; tapping the chosen one again clears it (optional).
  void toggleSetupGender(String value) {
    selectedGender.value = selectedGender.value == value ? null : value;
  }

  void selectRole(String role) => selectedRole.value = role;

  void selectShift(String key) => selectedShift.value = key;

  void selectYears(String key) => selectedYears.value = key;

  void continueFromAbout() {
    if (!canContinueFromAbout) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Get.toNamed(AppRoutes.profileWork);
  }

  /// "Continue" on Your work: saves the profile. From here on the user counts
  /// as having a profile, even if they close the app.
  Future<void> finishSetup() async {
    if (isSaving.value || !canContinueFromWork || !canContinueFromAbout) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    final UserProfile base =
        profile.value ?? _repository.signedInUserDefaults();
    final UserProfile draft = UserProfile(
      uid: base.uid,
      name: nameController.text.trim(),
      email: base.email,
      imageUrl: base.imageUrl,
      bio: '',
      age: ProfileValidation.parseAge(ageController.text),
      gender: selectedGender.value ?? '',
      role: selectedRole.value ?? '',
      shiftPattern: selectedShift.value ?? '',
      yearsInHealthcare: selectedYears.value ?? '',
      department: departmentController.text.trim(),
    );

    isSaving.value = true;
    try {
      // Without a connection a write only finishes once the phone is back
      // online, so wait a while and then carry on: it is saved on the phone.
      await _repository
          .createProfile(draft, imageFile: selectedImageFile.value)
          .timeout(
            Duration(seconds: selectedImageFile.value == null ? 12 : 40),
          );
    } on TimeoutException {
      // Saved on the phone; it syncs later.
    } on Object catch (error) {
      showMindMateSnackBar('Could not save your profile', _messageFor(error));
      return;
    } finally {
      isSaving.value = false;
    }

    Get.toNamed(AppRoutes.checkInIntro);
  }

  Future<void> pickImage() async {
    final XFile? pickedImage = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedImage == null) {
      return;
    }

    selectedImageFile.value = File(pickedImage.path);
  }

  String _messageFor(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to save this profile.';
        case 'unauthenticated':
        case 'no-current-user':
          return 'Please sign in again to continue.';
        case 'unavailable':
          return 'Firebase is temporarily unavailable. Please try again.';
        default:
          return error.message ?? 'Please try again.';
      }
    }

    if (error.toString().contains('no-current-user')) {
      return 'Please sign in again to continue.';
    }

    return 'Please try again.';
  }

  @override
  void onClose() {
    nameController.dispose();
    ageController.dispose();
    departmentController.dispose();
    selectedImageFile.value = null;
    super.onClose();
  }
}
