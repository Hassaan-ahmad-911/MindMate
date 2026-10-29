import 'dart:async';
import 'dart:io';

import 'package:mindmate/Models/check_in_result.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/services/profile_firestore_service.dart';

/// Keeps the profile in memory instead of Firestore.
class FakeProfileService extends ProfileFirestoreService {
  FakeProfileService({UserProfile? signedIn, this.profile})
    : signedIn =
          signedIn ??
          const UserProfile(
            uid: 'uid-1',
            name: '',
            email: 'ayesha@example.com',
            imageUrl: '',
            bio: '',
            age: null,
            gender: '',
          );

  /// What the sign-in knows (for example a Google name and photo).
  final UserProfile signedIn;

  /// The saved profile, or null if the user has none.
  UserProfile? profile;

  final List<UserProfile> created = <UserProfile>[];
  final List<CheckInResult> checkIns = <CheckInResult>[];
  final List<String> statusUpdates = <String>[];

  /// If set, the next save fails with it.
  Object? failWith;

  /// If true, saving a profile never finishes (like being offline).
  bool neverFinishes = false;

  /// Whether the user joined a hospital. True by default, so tests about
  /// other screens are not sent to "Join your hospital".
  bool hasOrg = true;

  @override
  Future<bool> profileExists() async => profile != null;

  @override
  Future<({bool hasProfile, bool hasOrg})> setupState() async =>
      (hasProfile: profile != null, hasOrg: hasOrg);

  @override
  UserProfile signedInUserDefaults() => signedIn;

  @override
  Future<UserProfile> getCurrentUserProfile() async => profile ?? signedIn;

  @override
  Future<void> createProfile(UserProfile profile, {File? imageFile}) {
    if (neverFinishes) {
      return Completer<void>().future;
    }
    final Object? failure = failWith;
    if (failure != null) {
      return Future<void>.error(failure);
    }
    created.add(profile);
    this.profile = profile;
    return Future<void>.value();
  }

  @override
  Future<void> updateCheckInStatus(String status) {
    final Object? failure = failWith;
    if (failure != null) {
      return Future<void>.error(failure);
    }
    statusUpdates.add(status);
    return Future<void>.value();
  }

  @override
  Future<void> saveCheckIn(CheckInResult result) {
    final Object? failure = failWith;
    if (failure != null) {
      return Future<void>.error(failure);
    }
    checkIns.add(result);
    return Future<void>.value();
  }
}
