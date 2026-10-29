import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../Models/hospital_programme.dart';

/// Reads the hospital programme's data. The app never writes any of it:
/// `orgId`, `orgJoinedAt`, the hospital and the alert records are written by
/// the server only (see `firestore.rules`).
class ProgrammeFirestoreService {
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

  /// The user's hospital, or null when they have not joined one. The
  /// officer's email is in the hospital document but is never read out.
  Future<HospitalMembership?> getMembership() async {
    final Map<String, dynamic>? user = (await _user().get()).data();
    final Object? orgId = user?['orgId'];
    if (orgId is! String || orgId.isEmpty) {
      return null;
    }
    final Object? joined = user?['orgJoinedAt'];
    final DateTime joinedAt = joined is Timestamp
        ? joined.toDate()
        : DateTime.now();

    Map<String, dynamic> org = <String, dynamic>{};
    try {
      org =
          (await _firestore.collection('organizations').doc(orgId).get())
              .data() ??
          <String, dynamic>{};
    } on FirebaseException {
      // Not readable (rules not deployed yet): the schedule still works.
    }
    final Object? officer = org['wellbeingOfficer'];
    String text(Object? value) => value is String ? value : '';
    return HospitalMembership(
      orgId: orgId,
      joinedAt: joinedAt,
      name: text(org['name']),
      officerName: officer is Map ? text(officer['name']) : '',
      officerRole: officer is Map ? text(officer['role']) : '',
    );
  }

  /// Every alert record, newest first.
  Future<List<WellbeingAlert>> getAlerts() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _user()
        .collection('wellbeing_alerts')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .get();
    return <WellbeingAlert>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snapshot.docs)
        if (d.data()['sentAt'] is Timestamp)
          WellbeingAlert(
            id: d.id,
            sentAt: (d.data()['sentAt'] as Timestamp).toDate(),
            urgent: d.data()['kind'] == 'urgent',
            officerName: d.data()['officerName'] is String
                ? d.data()['officerName'] as String
                : '',
          ),
    ];
  }

  void _ensureFirebaseInitialized() {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase has not been initialized for this platform.');
    }
  }
}
