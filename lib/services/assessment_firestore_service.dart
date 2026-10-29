import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../Models/assessment_result.dart';

/// Completed check-ins at `users/{uid}/assessments`. Answers and scores are
/// never logged.
class AssessmentFirestoreService {
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

  DocumentReference<Map<String, dynamic>> _user() =>
      _firestore.collection('users').doc(currentUid());

  CollectionReference<Map<String, dynamic>> _results() =>
      _user().collection('assessments');

  Future<AssessmentResult> saveResult(AssessmentResult result) async {
    final DocumentReference<Map<String, dynamic>> doc = _results().doc();
    await doc.set(result.toMap());
    return result.copyWith(id: doc.id);
  }

  /// The newest results across all questionnaires.
  Future<List<AssessmentResult>> getRecent({required int limit}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _results()
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .get();
    return _toResults(snapshot);
  }

  /// Every result of one questionnaire, newest first. Sorted on the phone
  /// so the query needs no composite index.
  Future<List<AssessmentResult>> getHistory(String assessmentId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _results()
        .where('assessmentId', isEqualTo: assessmentId)
        .get();
    final List<AssessmentResult> results = _toResults(snapshot)
      ..sort(
        (AssessmentResult a, AssessmentResult b) =>
            b.completedAt.compareTo(a.completedAt),
      );
    return results;
  }

  /// Results with [start] <= completedAt < [end], newest first.
  Future<List<AssessmentResult>> getBetween(
    DateTime start,
    DateTime end,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _results()
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('completedAt', descending: true)
        .get();
    return _toResults(snapshot);
  }

  /// The WHO-5 score and date of the first check-in from profile setup.
  Future<InitialWho5?> getInitialWho5() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _user()
        .collection('checkins')
        .where('type', isEqualTo: 'initial')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final Map<String, dynamic> data = snapshot.docs.first.data();
    final Object? score = data['who5Score'];
    final Object? at = data['completedAt'];
    if (score is! num || at is! Timestamp) {
      return null;
    }
    return InitialWho5(score: score.toDouble(), completedAt: at.toDate());
  }

  List<AssessmentResult> _toResults(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              AssessmentResult.fromMap(d.data(), id: d.id),
        )
        .toList();
  }

  void _ensureFirebaseInitialized() {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase has not been initialized for this platform.');
    }
  }
}
