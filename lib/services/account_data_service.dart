import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Reads and deletes everything the app stores for one user. Used by the
/// data export and by account deletion. Every delete is safe to repeat.
abstract class AccountDataBackend {
  /// Everything stored under `users/{uid}`.
  static const List<String> subcollections = <String>[
    'moods',
    'journals',
    'journal_drafts',
    'meditation_sessions',
    'breaks',
    'gratitude',
    'checkins',
    'assessments',
  ];

  String currentUid();

  Future<Map<String, dynamic>?> readUserDocument(String uid);

  /// Documents of one subcollection, each with its `id`.
  Future<List<Map<String, dynamic>>> readSubcollection(String uid, String name);

  /// The user's documents still in the old top-level `journals` collection.
  Future<List<Map<String, dynamic>>> readLegacyJournals(String uid);

  /// Deletes a subcollection in batches of up to 400. Returns how many.
  Future<int> deleteSubcollection(String uid, String name);

  Future<int> deleteLegacyJournals(String uid);

  /// Ignores "not found".
  Future<void> deleteProfilePhoto(String uid);

  Future<void> deleteUserDocument(String uid);
}

class FirebaseAccountDataService implements AccountDataBackend {
  static const int batchSize = 400;

  FirebaseFirestore get _firestore {
    _ensureFirebaseInitialized();
    return FirebaseFirestore.instance;
  }

  @override
  String currentUid() {
    _ensureFirebaseInitialized();
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user is available.',
      );
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Future<Map<String, dynamic>?> readUserDocument(String uid) async =>
      (await _user(uid).get()).data();

  @override
  Future<List<Map<String, dynamic>>> readSubcollection(
    String uid,
    String name,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> s = await _user(
      uid,
    ).collection(name).get();
    return s.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) => <String, dynamic>{
            'id': d.id,
            ...d.data(),
          },
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> readLegacyJournals(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> s = await _firestore
        .collection('journals')
        .where('userId', isEqualTo: uid)
        .get();
    return s.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) => <String, dynamic>{
            'id': d.id,
            ...d.data(),
          },
        )
        .toList();
  }

  Future<int> _deleteQuery(Query<Map<String, dynamic>> query) async {
    int deleted = 0;
    while (true) {
      final QuerySnapshot<Map<String, dynamic>> page = await query
          .limit(batchSize)
          .get();
      if (page.docs.isEmpty) {
        return deleted;
      }
      final WriteBatch batch = _firestore.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in page.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      deleted += page.docs.length;
    }
  }

  @override
  Future<int> deleteSubcollection(String uid, String name) =>
      _deleteQuery(_user(uid).collection(name));

  @override
  Future<int> deleteLegacyJournals(String uid) => _deleteQuery(
    _firestore.collection('journals').where('userId', isEqualTo: uid),
  );

  @override
  Future<void> deleteProfilePhoto(String uid) async {
    _ensureFirebaseInitialized();
    try {
      await FirebaseStorage.instance
          .ref()
          .child('profile_images/$uid.jpg')
          .delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  @override
  Future<void> deleteUserDocument(String uid) => _user(uid).delete();

  void _ensureFirebaseInitialized() {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase has not been initialized for this platform.');
    }
  }
}
