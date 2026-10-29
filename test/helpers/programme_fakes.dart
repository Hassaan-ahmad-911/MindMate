import 'dart:io';

import 'package:mindmate/Data/repositories/wellbeing_programme_repository.dart';
import 'package:mindmate/Models/assessment_definition.dart';
import 'package:mindmate/Models/hospital_programme.dart';
import 'package:mindmate/Models/programme_schedule.dart';
import 'package:mindmate/services/email_code_service.dart';
import 'package:mindmate/services/programme_firestore_service.dart';
import 'package:mindmate/services/programme_local_store.dart';
import 'package:mindmate/services/wellbeing_programme_service.dart';

/// The content file, read from disk.
AssessmentContent fileContent() => AssessmentContent.fromJson(
  File('assets/assessments/assessments_content.json').readAsStringSync(),
);

/// The programme schedule from the content file.
ProgrammeConfig fileProgramme() => fileContent().programme!;

HospitalMembership cityGeneral({DateTime? joinedAt}) => HospitalMembership(
  orgId: 'org-1',
  joinedAt: joinedAt ?? DateTime(2026, 10, 1, 9),
  name: 'City General Hospital',
  officerName: 'Dr. Sana Malik',
  officerRole: 'Staff wellbeing, Occupational Health',
);

/// The programme's data in memory: no server, no Firestore, no phone
/// storage. Records every call to the server.
class FakeProgrammeRepository extends WellbeingProgrammeRepository {
  FakeProgrammeRepository({this.membership})
    : super(
        WellbeingProgrammeService(
          EmailCodeService(baseUrl: 'https://server.invalid'),
          idToken: () async => 'token',
        ),
        ProgrammeFirestoreService(),
        ProgrammeLocalStore(),
      );

  HospitalMembership? membership;
  ProgrammeConfig? config = fileProgramme();
  Map<String, DateTime> lastDone = <String, DateTime>{};
  Map<String, int> questionCounts = <String, int>{
    'phq4': 4,
    'who5': 5,
    'phq9': 9,
    'gad7': 7,
    'cbi': 19,
    'pss10': 10,
  };
  List<WellbeingAlert> alerts = <WellbeingAlert>[];
  final Set<String> seen = <String>{};
  String? evaluatedDay;

  int evaluateCalls = 0;
  EvaluateOutcome outcome = const EvaluateOutcome(status: 'ok');

  /// The next this many evaluations fail.
  int failEvaluations = 0;

  final List<String> joinCodes = <String>[];
  JoinedHospital joinResult = const JoinedHospital(
    orgId: 'org-1',
    name: 'City General Hospital',
    officerName: 'Dr. Sana Malik',
  );

  /// If set, joining fails with it.
  Object? joinError;

  @override
  String currentUid() => 'uid-1';

  @override
  Future<JoinedHospital> join(String code) async {
    joinCodes.add(code);
    final Object? error = joinError;
    if (error != null) {
      throw error;
    }
    return joinResult;
  }

  @override
  Future<EvaluateOutcome> evaluate() async {
    evaluateCalls += 1;
    if (failEvaluations > 0) {
      failEvaluations -= 1;
      throw const EmailCodeException(EmailCodeException.network);
    }
    return outcome;
  }

  @override
  Future<HospitalMembership?> getMembership() async => membership;

  @override
  Future<List<WellbeingAlert>> getAlerts() async => alerts;

  @override
  Future<ProgrammeConfig?> getConfig() async => config;

  @override
  Future<Map<String, String>> getScales() async => <String, String>{
    for (final AssessmentDefinition a in fileContent().assessments)
      a.id: a.scale,
  };

  @override
  Future<Map<String, int>> getQuestionCounts() async => questionCounts;

  @override
  Future<Map<String, DateTime>> getLastDone() async => lastDone;

  @override
  Future<Set<String>> seenAlertIds() async => Set<String>.of(seen);

  @override
  Future<void> markAlertSeen(String alertId) async => seen.add(alertId);

  @override
  Future<String?> lastEvaluatedDay() async => evaluatedDay;

  @override
  Future<void> setLastEvaluatedDay(String day) async => evaluatedDay = day;
}
