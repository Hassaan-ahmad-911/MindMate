import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../Models/meditation_log_entry.dart';

/// Reads and writes `users/{uid}/meditation_sessions/{id}`.
class MeditationLogService {
  FirebaseFirestore get _firestore {
    _ensureFirebaseInitialized();
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get _auth {
    _ensureFirebaseInitialized();
    return FirebaseAuth.instance;
  }

  CollectionReference<Map<String, dynamic>> _sessions() {
    final User user = _currentUser();
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('meditation_sessions');
  }

  /// A new document id, made on the phone so the entry can be written (and
  /// updated) without waiting for the server.
  String newId() => _sessions().doc().id;

  Future<void> saveSession(MeditationLogEntry entry) {
    return _sessions().doc(entry.id).set(entry.toMap());
  }

  Future<void> updateFeelAfter(String id, int feelAfter) {
    return _sessions().doc(id).update(<String, dynamic>{
      'feelAfter': feelAfter,
    });
  }

  /// Practices that ended on or after [start], newest first.
  Future<List<MeditationLogEntry>> getSessionsSince(DateTime start) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _sessions()
        .where('endedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('endedAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              MeditationLogEntry.fromMap(doc.data(), id: doc.id),
        )
        .toList(growable: false);
  }

  /// Practices that started with [start] <= startedAt < [end], newest first.
  Future<List<MeditationLogEntry>> getSessionsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _sessions()
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startedAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('startedAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              MeditationLogEntry.fromMap(doc.data(), id: doc.id),
        )
        .toList(growable: false);
  }

  /// The signed-in user's id, or null.
  String? currentUidOrNull() {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
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
