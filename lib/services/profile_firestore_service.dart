import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../Models/check_in_result.dart';
import '../Models/profile_options.dart';
import '../Models/user_profile.dart';

class ProfileFirestoreService {
  FirebaseFirestore get _firestore {
    _ensureFirebaseInitialized();
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get _auth {
    _ensureFirebaseInitialized();
    return FirebaseAuth.instance;
  }

  FirebaseStorage get _storage {
    _ensureFirebaseInitialized();
    return FirebaseStorage.instance;
  }

  Future<UserProfile> getCurrentUserProfile() async {
    final User user = _currentUser();
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!snapshot.exists || !UserProfile.isStoredProfile(snapshot.data())) {
      return UserProfile(
        uid: user.uid,
        name: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'User',
        email: user.email ?? '',
        imageUrl: user.photoURL ?? '',
        bio: '',
        age: null,
        gender: '',
      );
    }

    return UserProfile.fromMap(
      snapshot.id,
      snapshot.data() ?? <String, dynamic>{},
    );
  }

  /// Whether the signed-in user has a profile. A profile exists from the end
  /// of the "Your work" setup step onwards.
  Future<bool> profileExists() async {
    final User user = _currentUser();
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    return snapshot.exists && UserProfile.isStoredProfile(snapshot.data());
  }

  /// One read for the start-up checks: whether the user has a profile and
  /// whether they joined a hospital (`orgId`, set only by the server).
  Future<({bool hasProfile, bool hasOrg})> setupState() async {
    final User user = _currentUser();
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final Map<String, dynamic>? data = snapshot.data();
    final Object? orgId = data?['orgId'];
    return (
      hasProfile: snapshot.exists && UserProfile.isStoredProfile(data),
      hasOrg: orgId is String && orgId.isNotEmpty,
    );
  }

  /// What the sign-in itself knows about the user (for example the name and
  /// photo of a Google account), to fill in the first setup screen. The name
  /// is empty if there is none.
  UserProfile signedInUserDefaults() {
    final User user = _currentUser();
    return UserProfile(
      uid: user.uid,
      name: user.displayName?.trim() ?? '',
      email: user.email ?? '',
      imageUrl: user.photoURL ?? '',
      bio: '',
      age: null,
      gender: '',
    );
  }

  /// Saves the profile at the end of the setup. It can be called again (for
  /// example after going back a step): fields the setup does not own, and the
  /// check-in state, are kept.
  Future<void> createProfile(UserProfile profile, {File? imageFile}) async {
    final User user = _currentUser();
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('users')
        .doc(user.uid);

    DocumentSnapshot<Map<String, dynamic>>? existing;
    try {
      existing = await docRef.get();
    } catch (_) {
      existing = null;
    }
    final Map<String, dynamic> existingData =
        existing?.data() ?? <String, dynamic>{};

    String imageUrl = profile.imageUrl.trim();
    if (imageFile != null) {
      imageUrl = await uploadProfileImage(user.uid, imageFile);
    }

    await docRef.set(<String, dynamic>{
      'uid': user.uid,
      'name': profile.name.trim(),
      'email': profile.email.trim(),
      'imageUrl': imageUrl,
      'age': profile.age,
      'gender': profile.gender.trim(),
      'role': profile.role,
      'shiftPattern': profile.shiftPattern,
      'yearsInHealthcare': profile.yearsInHealthcare,
      'department': profile.department.trim(),
      if (existingData['bio'] == null) 'bio': '',
      if (existingData['checkInStatus'] == null)
        'checkInStatus': ProfileOptions.checkInPending,
      if (existingData['createdAt'] != null)
        'createdAt': existingData['createdAt']
      else
        'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// `pending`, `completed` or `dismissed`.
  Future<void> updateCheckInStatus(String status) {
    final User user = _currentUser();
    return _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'checkInStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Saves the check-in answers at `users/{uid}/checkins/{id}` and, in the
  /// same write, the goals, the reminder choice and `completed` on the
  /// profile.
  Future<void> saveCheckIn(CheckInResult result) {
    final User user = _currentUser();
    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(user.uid);

    final WriteBatch batch = _firestore.batch();
    batch.set(userRef.collection('checkins').doc(), <String, dynamic>{
      ...result.toMap(),
      'completedAt': FieldValue.serverTimestamp(),
    });
    batch.set(userRef, <String, dynamic>{
      'goals': result.goals,
      if (result.reminderPreference != null)
        'reminderPreference': result.reminderPreference,
      'checkInStatus': ProfileOptions.checkInCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return batch.commit();
  }

  Future<UserProfile> updateUserProfile(
    UserProfile profile, {
    File? imageFile,
  }) async {
    final User user = _currentUser();
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('users')
        .doc(user.uid);

    final DocumentSnapshot<Map<String, dynamic>> existingSnapshot = await docRef
        .get();
    final Map<String, dynamic> existingData =
        existingSnapshot.data() ?? <String, dynamic>{};

    String imageUrl = profile.imageUrl.trim();
    if (imageFile != null) {
      imageUrl = await uploadProfileImage(user.uid, imageFile);
    }

    final Map<String, dynamic> data = <String, dynamic>{
      'uid': user.uid,
      'name': profile.name.trim(),
      'email': profile.email.trim(),
      'imageUrl': imageUrl,
      'bio': profile.bio.trim(),
      'age': profile.age,
      'gender': profile.gender.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (existingData['createdAt'] != null)
        'createdAt': existingData['createdAt']
      else
        'createdAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data, SetOptions(merge: true));

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();
    return UserProfile.fromMap(
      snapshot.id,
      snapshot.data() ?? <String, dynamic>{},
    );
  }

  /// Edit profile: updates only the fields it shows (one `update`, so the
  /// rest of the document stays). A new [imageFile] is uploaded to the same
  /// place as at setup; [removePhoto] clears the photo.
  Future<UserProfile> updateEditableFields({
    required String name,
    required int? age,
    required String gender,
    required String role,
    required String shiftPattern,
    required String department,
    File? imageFile,
    bool removePhoto = false,
  }) async {
    final User user = _currentUser();
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('users')
        .doc(user.uid);
    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await uploadProfileImage(user.uid, imageFile);
    } else if (removePhoto) {
      imageUrl = '';
      try {
        await _storage.ref().child('profile_images/${user.uid}.jpg').delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') {
          rethrow;
        }
      }
    }
    await docRef.update(<String, dynamic>{
      'name': name.trim(),
      'age': age,
      'gender': gender.trim(),
      'role': role,
      'shiftPattern': shiftPattern,
      'department': department.trim(),
      'imageUrl': ?imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return getCurrentUserProfile();
  }

  Future<String> uploadProfileImage(String uid, File imageFile) async {
    final Reference reference = _storage.ref().child('profile_images/$uid.jpg');
    final UploadTask task = reference.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final TaskSnapshot snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }

  User _currentUser() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user is available.',
      );
    }

    return user;
  }

  void _ensureFirebaseInitialized() {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase has not been initialized for this platform.');
    }
  }
}
