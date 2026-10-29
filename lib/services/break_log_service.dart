import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../Models/break_log.dart';

/// Reads and writes `users/{uid}/breaks/{id}`.
class BreakLogService {
  FirebaseFirestore get _firestore {
    _ensureFirebaseInitialized();
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get _auth {
    _ensureFirebaseInitialized();
    return FirebaseAuth.instance;
  }

  CollectionReference<Map<String, dynamic>> _breaks() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user is available.',
      );
    }
    return _firestore.collection('users').doc(user.uid).collection('breaks');
  }

  /// A new document id, made on the phone.
  String newId() => _breaks().doc().id;

  Future<void> saveBreak(BreakLogEntry entry) {
    return _breaks().doc(entry.id).set(entry.toMap());
  }

  /// Breaks that started on or after [start].
  Future<List<BreakLogEntry>> getBreaksSince(DateTime start) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _breaks()
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();

    final List<BreakLogEntry> entries = <BreakLogEntry>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final BreakLogEntry? entry = BreakLogEntry.fromMap(
        doc.data(),
        id: doc.id,
      );
      if (entry != null) {
        entries.add(entry);
      }
    }
    return entries;
  }

  /// Breaks with [start] <= startedAt < [end].
  Future<List<BreakLogEntry>> getBreaksBetween(
    DateTime start,
    DateTime end,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _breaks()
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startedAt', isLessThan: Timestamp.fromDate(end))
        .get();

    final List<BreakLogEntry> entries = <BreakLogEntry>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final BreakLogEntry? entry = BreakLogEntry.fromMap(
        doc.data(),
        id: doc.id,
      );
      if (entry != null) {
        entries.add(entry);
      }
    }
    return entries;
  }

  void _ensureFirebaseInitialized() {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase has not been initialized for this platform.');
    }
  }
}
