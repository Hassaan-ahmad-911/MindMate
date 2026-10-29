import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../Data/repositories/profile_repository.dart';
import '../../Models/profile_validation.dart';
import '../../Models/user_profile.dart';
import '../shared/app_feedback.dart';

/// Edit profile. Uses the profile setup's rules (ProfileValidation and
/// ProfileOptions) and saves only these fields.
class EditProfileViewModel extends GetxController {
  EditProfileViewModel(this._profiles, {ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ProfileRepository _profiles;
  final ImagePicker _picker;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();

  final Rxn<UserProfile> original = Rxn<UserProfile>();
  final RxString gender = ''.obs;
  final RxString role = ''.obs;
  final RxString shift = ''.obs;
  final Rxn<File> newPhoto = Rxn<File>();
  final RxBool removePhoto = false.obs;
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxBool isSaving = false.obs;

  /// Bumped on every edit, so the button and the "Discard?" check update.
  final RxInt _edits = 0.obs;

  @override
  void onInit() {
    super.onInit();
    for (final TextEditingController c in <TextEditingController>[
      nameController,
      ageController,
      departmentController,
    ]) {
      c.addListener(() => _edits.value += 1);
    }
    unawaited(load());
  }

  Future<void> load() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final UserProfile p = await _profiles.getCurrentUserProfile();
      original.value = p;
      nameController.text = p.name;
      ageController.text = p.age?.toString() ?? '';
      departmentController.text = p.department;
      gender.value = p.gender;
      role.value = p.role;
      shift.value = p.shiftPattern;
      newPhoto.value = null;
      removePhoto.value = false;
    } catch (_) {
      hasError.value = true;
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
    }
  }

  String? get nameError => ProfileValidation.nameError(nameController.text);

  String? get ageError => ProfileValidation.ageError(ageController.text);

  bool get hasPhoto =>
      newPhoto.value != null ||
      (!removePhoto.value && (original.value?.hasImage ?? false));

  /// Something differs from what was loaded.
  bool get hasChanges {
    _edits.value;
    final UserProfile? p = original.value;
    if (p == null) {
      return false;
    }
    return nameController.text.trim() != p.name.trim() ||
        ageController.text.trim() != (p.age?.toString() ?? '') ||
        departmentController.text.trim() != p.department.trim() ||
        gender.value != p.gender ||
        role.value != p.role ||
        shift.value != p.shiftPattern ||
        newPhoto.value != null ||
        removePhoto.value;
  }

  bool get canSave =>
      hasChanges && nameError == null && ageError == null && !isSaving.value;

  void setGender(String v) {
    gender.value = v;
    _edits.value += 1;
  }

  void setRole(String v) {
    role.value = v;
    _edits.value += 1;
  }

  void setShift(String v) {
    shift.value = v;
    _edits.value += 1;
  }

  Future<void> pickPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        newPhoto.value = File(picked.path);
        removePhoto.value = false;
        _edits.value += 1;
      }
    } catch (_) {
      showMindMateSnackBar(
        'Could not open the photo',
        'Check that MindMate may use the camera or photos.',
      );
    }
  }

  void clearPhoto() {
    newPhoto.value = null;
    removePhoto.value = true;
    _edits.value += 1;
  }

  /// True when saved.
  Future<bool> save() async {
    if (!canSave) {
      return false;
    }
    isSaving.value = true;
    try {
      final UserProfile saved = await _profiles.updateEditableFields(
        name: nameController.text,
        age: ProfileValidation.parseAge(ageController.text),
        gender: gender.value,
        role: role.value,
        shiftPattern: shift.value,
        department: departmentController.text,
        imageFile: newPhoto.value,
        removePhoto: removePhoto.value,
      );
      original.value = saved;
      newPhoto.value = null;
      removePhoto.value = false;
      _edits.value += 1;
      showSavedToast();
      return true;
    } catch (_) {
      showMindMateSnackBar('Not saved', 'Check your connection and try again.');
      return false;
    } finally {
      if (!isClosed) {
        isSaving.value = false;
      }
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    ageController.dispose();
    departmentController.dispose();
    super.onClose();
  }
}
