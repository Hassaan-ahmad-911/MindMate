import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../Models/gratitude_entry.dart';

/// Reads and writes `users/{uid}/gratitude/{yyyy-MM-dd}`.
class GratitudeService {
  /// More flowers than anyone will plant in a year.
  static const int maxEntries = 400;

  FirebaseFirestore get _firestore {
    _ensureFirebaseInitialized();
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get _auth {
    _ensureFirebaseInitialized();
    return FirebaseAuth.instance;
  }

  CollectionReference<Map<String, dynamic>> _entries() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user is available.',
      );
    }
    return _firestore.collection('users').doc(user.uid).collection('gratitude');
  }

  /// The newest entries, newest first (the date is the document id).
  Future<List<GratitudeEntry>> getEntries() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _entries()
        .orderBy(FieldPath.documentId, descending: true)
        .limit(maxEntries)
        .get();

    final List<GratitudeEntry> entries = <GratitudeEntry>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final GratitudeEntry? entry = GratitudeEntry.fromMap(
        doc.data(),
        id: doc.id,
      );
      if (entry != null) {
        entries.add(entry);
      }
    }
    return entries;
  }

  /// Plants a new flower: the document id is the date, so there is only ever
  /// one for a day.
  Future<void> create(GratitudeEntry entry) {
    return _entries().doc(entry.dateKey).set(entry.toMap());
  }

  /// Changes the words of an existing flower, keeping when it was planted.
  Future<void> updateText(GratitudeEntry entry) {
    return _entries().doc(entry.dateKey).set(<String, dynamic>{
      'text': entry.text,
      'updatedAt': Timestamp.fromDate(entry.updatedAt),
    }, SetOptions(merge: true));
  }

  Future<void> delete(String dateKey) {
    return _entries().doc(dateKey).delete();
  }

  void _ensureFirebaseInitialized() {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase has not been initialized for this platform.');
    }
  }
}
