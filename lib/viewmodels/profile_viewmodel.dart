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

/// The profile screens: editing a profile from Settings, and the two-step
/// setup (About you, Your work) that follows sign-up. [isSetup] is true for the
/// setup, where nothing is loaded and the sign-in fills in the name and photo.
class ProfileViewModel extends GetxController {
  ProfileViewModel(this._repository, {this.isSetup = false});

  final ProfileRepository _repository;
  final bool isSetup;

  final Rxn<UserProfile> profile = Rxn<UserProfile>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final RxnString selectedGender = RxnString();
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isEditMode = true.obs;
  final Rxn<File> selectedImageFile = Rxn<File>();

  // Setup (About you, Your work).
  final RxString nameText = ''.obs;
  final RxString ageText = ''.obs;
  final RxnString selectedRole = RxnString();
  final RxnString selectedShift = RxnString();
  final RxnString selectedYears = RxnString();
  final TextEditingController departmentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool _fromSettings = false;
  bool _initialEditMode = true;

  static const List<String> genderOptions = <String>[
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];

  @override
  void onInit() {
    super.onInit();
    _readArguments();
    if (isSetup) {
      nameController.addListener(() => nameText.value = nameController.text);
      ageController.addListener(() => ageText.value = ageController.text);
      _prefillFromSignIn();
    } else {
      unawaited(fetchProfile());
    }
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

  void _readArguments() {
    final Object? arguments = Get.arguments;
    if (arguments is Map) {
      final Object? origin = arguments['origin'];
      _fromSettings = origin == 'settings';

      final Object? editMode =
          arguments['initialEditMode'] ?? arguments['editMode'];
      if (editMode is bool) {
        _initialEditMode = editMode;
      }
    }

    isEditMode.value = _initialEditMode;
  }

  Future<void> fetchProfile() async {
    isLoading.value = true;
    try {
      final UserProfile loadedProfile = await _repository
          .getCurrentUserProfile();
      profile.value = loadedProfile;
      _populateFields(loadedProfile);
    } on Object catch (error) {
      showMindMateSnackBar('Profile load failed', _messageFor(error));
    } finally {
      isLoading.value = false;
    }
  }

  void toggleEditMode() {
    if (isEditMode.value) {
      cancelEdit();
      return;
    }

    isEditMode.value = true;
  }

  void cancelEdit() {
    final UserProfile? currentProfile = profile.value;
    if (currentProfile != null) {
      _populateFields(currentProfile);
    }
    selectedImageFile.value = null;

    if (_fromSettings || currentProfile?.createdAt != null) {
      isEditMode.value = false;
    } else {
      isEditMode.value = true;
    }
  }

  void selectGender(String? value) {
    if (value == null || value.trim().isEmpty) {
      selectedGender.value = null;
      return;
    }

    selectedGender.value = value.trim();
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

  Future<void> updateProfile() async {
    if (isSaving.value) {
      return;
    }

    final String trimmedName = nameController.text.trim();
    final String trimmedBio = bioController.text.trim();
    final String? gender = selectedGender.value;

    final String? nameError = ProfileValidation.nameError(trimmedName);
    if (nameError != null) {
      showMindMateSnackBar('Name required', nameError);
      return;
    }

    if (gender == null || gender.isEmpty) {
      showMindMateSnackBar('Gender required', 'Please select a gender.');
      return;
    }

    final String? ageError = ProfileValidation.ageError(ageController.text);
    if (ageError != null) {
      showMindMateSnackBar('Invalid age', ageError);
      return;
    }
    final int? age = ProfileValidation.parseAge(ageController.text);

    final UserProfile currentProfile =
        profile.value ??
        UserProfile(
          uid: '',
          name: '',
          email: '',
          imageUrl: '',
          bio: '',
          age: null,
          gender: '',
        );

    final UserProfile draftProfile = UserProfile(
      uid: currentProfile.uid,
      name: trimmedName,
      email: currentProfile.email,
      imageUrl: currentProfile.imageUrl,
      bio: trimmedBio,
      age: age,
      gender: gender,
      createdAt: currentProfile.createdAt,
      updatedAt: DateTime.now(),
    );

    isSaving.value = true;
    try {
      final UserProfile savedProfile = await _repository.updateUserProfile(
        draftProfile,
        imageFile: selectedImageFile.value,
      );

      profile.value = savedProfile;
      _populateFields(savedProfile);
      selectedImageFile.value = null;
      isEditMode.value = false;

      showMindMateSnackBar(
        'Profile updated',
        'Your profile was saved successfully.',
      );

      if (_fromSettings) {
        Get.back(result: true);
      } else {
        Get.offAllNamed(AppRoutes.home);
      }
    } on FirebaseException catch (error) {
      showMindMateSnackBar('Profile update failed', _messageFor(error));
    } catch (error) {
      showMindMateSnackBar('Profile update failed', _messageFor(error));
    } finally {
      isSaving.value = false;
    }
  }

  String _messageFor(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to update this profile.';
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

  void _populateFields(UserProfile userProfile) {
    nameController.text = userProfile.name;
    bioController.text = userProfile.bio;
    ageController.text = userProfile.age?.toString() ?? '';
    selectedGender.value = userProfile.gender.trim().isNotEmpty
        ? userProfile.gender.trim()
        : null;
  }

  @override
  void onClose() {
    nameController.dispose();
    bioController.dispose();
    ageController.dispose();
    departmentController.dispose();
    selectedImageFile.value = null;
    super.onClose();
  }
}
