import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../Models/mood_model.dart';

class MoodFirestoreService {
  FirebaseFirestore get _firestore {
    _ensureFirebaseInitialized();
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get _auth {
    _ensureFirebaseInitialized();
    return FirebaseAuth.instance;
  }

  CollectionReference<Map<String, dynamic>> _moods() {
    final User user = _currentUser();
    return _firestore.collection('users').doc(user.uid).collection('moods');
  }

  /// Saves a new entry and returns it with its document id.
  Future<MoodModel> saveMood(MoodModel mood) async {
    final DocumentReference<Map<String, dynamic>> docRef = await _moods().add(
      <String, dynamic>{
        ...mood.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    return mood.copyWith(id: docRef.id);
  }

  Future<List<MoodModel>> getMoodHistory() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _moods()
        .orderBy('createdAt')
        .get();
    return _toModels(snapshot);
  }

  Future<List<MoodModel>> getRecentMoods() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _moods()
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    return _toModels(snapshot);
  }

  /// Entries from the last 7 days, oldest first.
  Future<List<MoodModel>> getWeeklyMoods() async {
    final DateTime now = DateTime.now();
    final DateTime weekStart = DateTime(now.year, now.month, now.day - 6);
    final List<MoodModel> moods = await getMoodsBetween(
      weekStart,
      DateTime(now.year, now.month, now.day + 1),
    );
    return moods.reversed.toList(growable: false);
  }

  /// Entries with [start] <= createdAt < [end], newest first.
  Future<List<MoodModel>> getMoodsBetween(DateTime start, DateTime end) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _moods()
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();
    return _toModels(snapshot);
  }

  /// One page of entries, newest first, older than [before] when given.
  Future<List<MoodModel>> getMoodPage({
    DateTime? before,
    required int limit,
  }) async {
    Query<Map<String, dynamic>> query = _moods().orderBy(
      'createdAt',
      descending: true,
    );
    if (before != null) {
      query = query.startAfter(<Object>[Timestamp.fromDate(before)]);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query
        .limit(limit)
        .get();
    return _toModels(snapshot);
  }

  Future<void> updateMoodNote(String moodId, String note) {
    return _moods().doc(moodId).update(<String, dynamic>{'note': note});
  }

  Future<void> deleteMood(String moodId) {
    return _moods().doc(moodId).delete();
  }

  List<MoodModel> _toModels(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              MoodModel.fromMap(doc.data(), id: doc.id),
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
