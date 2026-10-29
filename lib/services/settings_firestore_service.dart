import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// `settings` on `users/{uid}`. Single fields are written with `update`, so
/// the rest of the document is never overwritten.
class SettingsFirestoreService {
  FirebaseFirestore get _firestore {
    _ensureFirebaseInitialized();
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get _auth {
    _ensureFirebaseInitialized();
    return FirebaseAuth.instance;
  }

  String currentUid() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user is available.',
      );
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _doc() =>
      _firestore.collection('users').doc(currentUid());

  /// The whole user document, or null if there is none yet.
  Future<Map<String, dynamic>?> readUserDocument() async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _doc().get();
    return snapshot.data();
  }

  /// Writes the whole `settings` map (first load only).
  Future<void> createSettings(Map<String, dynamic> settings) {
    return _doc().set(<String, dynamic>{
      'settings': settings,
    }, SetOptions(merge: true));
  }

  /// Writes one field, e.g. `reminders.mood.time`.
  Future<void> updateField(String path, Object? value) {
    return _doc().update(<String, dynamic>{'settings.$path': value});
  }

  void _ensureFirebaseInitialized() {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase has not been initialized for this platform.');
    }
  }
}
