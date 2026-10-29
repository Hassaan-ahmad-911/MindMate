import 'dart:io';

import '../../Models/check_in_result.dart';
import '../../Models/user_profile.dart';
import '../../services/profile_firestore_service.dart';

class ProfileRepository {
  ProfileRepository(this._service);

  final ProfileFirestoreService _service;

  Future<UserProfile> getCurrentUserProfile() {
    return _service.getCurrentUserProfile();
  }

  Future<UserProfile> updateUserProfile(
    UserProfile profile, {
    File? imageFile,
  }) {
    return _service.updateUserProfile(profile, imageFile: imageFile);
  }

  Future<UserProfile> updateEditableFields({
    required String name,
    required int? age,
    required String gender,
    required String role,
    required String shiftPattern,
    required String department,
    File? imageFile,
    bool removePhoto = false,
  }) {
    return _service.updateEditableFields(
      name: name,
      age: age,
      gender: gender,
      role: role,
      shiftPattern: shiftPattern,
      department: department,
      imageFile: imageFile,
      removePhoto: removePhoto,
    );
  }

  Future<bool> profileExists() {
    return _service.profileExists();
  }

  UserProfile signedInUserDefaults() {
    return _service.signedInUserDefaults();
  }

  Future<void> createProfile(UserProfile profile, {File? imageFile}) {
    return _service.createProfile(profile, imageFile: imageFile);
  }

  Future<void> updateCheckInStatus(String status) {
    return _service.updateCheckInStatus(status);
  }

  Future<void> saveCheckIn(CheckInResult result) {
    return _service.saveCheckIn(result);
  }
}
