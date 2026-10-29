import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../Models/journal_model.dart';

/// An entry still in the old top-level `journals` collection.
class LegacyJournalDoc {
  const LegacyJournalDoc(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

/// Journal entries at `users/{uid}/journals`. Never logs entry text.
class JournalFirestoreService {
  FirebaseFirestore get _firestore {
    _ensureFirebaseInitialized();
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get _auth {
    _ensureFirebaseInitialized();
    return FirebaseAuth.instance;
  }

  /// The signed-in user's id. Throws when nobody is signed in.
  String currentUid() => _currentUser().uid;

  CollectionReference<Map<String, dynamic>> _journals(String uid) {
    return _firestore.collection('users').doc(uid).collection('journals');
  }

  Future<JournalPage> getPage({Object? after, required int limit}) async {
    Query<Map<String, dynamic>> query = _journals(
      currentUid(),
    ).orderBy('createdAt', descending: true);
    if (after is DocumentSnapshot<Object?>) {
      query = query.startAfterDocument(after);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query
        .limit(limit)
        .get();
    return JournalPage(
      entries: _toModels(snapshot.docs),
      cursor: snapshot.docs.isEmpty ? after : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<JournalModel?> getEntry(String id) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _journals(
      currentUid(),
    ).doc(id).get();
    final Map<String, dynamic>? data = snapshot.data();
    return data == null ? null : JournalModel.fromMap(data, id: snapshot.id);
  }

  /// Entries with [start] <= createdAt < [end], newest first.
  Future<List<JournalModel>> getEntriesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _journals(currentUid())
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('createdAt', isLessThan: Timestamp.fromDate(end))
            .orderBy('createdAt', descending: true)
            .get();
    return _toModels(snapshot.docs);
  }

  /// Saves a new entry and returns it with its id.
  Future<JournalModel> createEntry(JournalModel entry) async {
    final DocumentReference<Map<String, dynamic>> doc = _journals(
      currentUid(),
    ).doc();
    await doc.set(entry.toMap());
    return entry.copyWith(id: doc.id);
  }

  /// Replaces the stored fields of an existing entry.
  Future<void> updateEntry(JournalModel entry) {
    return _journals(currentUid()).doc(entry.id).update(entry.toMap());
  }

  Future<void> deleteEntry(String id) {
    return _journals(currentUid()).doc(id).delete();
  }

  // The move from the old top-level collection.

  Future<bool> isLegacyMigrated(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> user = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    return user.data()?['journalsMigratedAt'] != null;
  }

  Future<List<LegacyJournalDoc>> getLegacyJournals(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('journals')
        .where('userId', isEqualTo: uid)
        .get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              LegacyJournalDoc(doc.id, doc.data()),
        )
        .toList(growable: false);
  }

  /// In one atomic batch: writes each entry (already converted) under the
  /// user with the same id, and deletes the old document. Either all of
  /// them move or none do.
  Future<void> moveLegacyBatch(
    String uid,
    Map<String, Map<String, dynamic>> convertedById,
  ) {
    final WriteBatch batch = _firestore.batch();
    for (final MapEntry<String, Map<String, dynamic>> entry
        in convertedById.entries) {
      batch.set(_journals(uid).doc(entry.key), entry.value);
      batch.delete(_firestore.collection('journals').doc(entry.key));
    }
    return batch.commit();
  }

  Future<void> markLegacyMigrated(String uid) {
    return _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'journalsMigratedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<JournalModel> _toModels(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              JournalModel.fromMap(doc.data(), id: doc.id),
        )
        .toList(growable: false);
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
