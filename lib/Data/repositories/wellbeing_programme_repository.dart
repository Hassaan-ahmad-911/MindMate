import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/hospital_programme.dart';
import '../../Models/programme_schedule.dart';
import '../../services/programme_firestore_service.dart';
import '../../services/programme_local_store.dart';
import '../../services/wellbeing_programme_service.dart';
import 'assessment_repository.dart';

/// The hospital wellbeing programme: joining, the schedule's inputs, asking
/// the server to evaluate, and the alert records.
class WellbeingProgrammeRepository {
  WellbeingProgrammeRepository(
    this._server,
    this._firestore,
    this._local, {
    AssessmentRepository? assessments,
  }) : _assessments = assessments;

  final WellbeingProgrammeService _server;
  final ProgrammeFirestoreService _firestore;
  final ProgrammeLocalStore _local;
  final AssessmentRepository? _assessments;

  String currentUid() => _firestore.currentUid();

  Future<JoinedHospital> join(String code) => _server.join(code);

  Future<EvaluateOutcome> evaluate() => _server.evaluate();

  Future<HospitalMembership?> getMembership() => _firestore.getMembership();

  /// Every alert record, newest first.
  Future<List<WellbeingAlert>> getAlerts() => _firestore.getAlerts();

  /// The required schedule from the check-in content file.
  Future<ProgrammeConfig?> getConfig() async {
    final AssessmentRepository? assessments = _assessments;
    if (assessments == null) {
      return null;
    }
    final AssessmentContent content = await assessments.loadContent();
    return content.programme;
  }

  /// Scale names by id ("PHQ-4"), for "Your hospital".
  Future<Map<String, String>> getScales() async {
    final AssessmentRepository? assessments = _assessments;
    if (assessments == null) {
      return const <String, String>{};
    }
    final AssessmentContent content = await assessments.loadContent();
    return <String, String>{
      for (final AssessmentDefinition a in content.assessments) a.id: a.scale,
    };
  }

  /// How many questions each check-in has, by id.
  Future<Map<String, int>> getQuestionCounts() async {
    final AssessmentRepository? assessments = _assessments;
    if (assessments == null) {
      return const <String, int>{};
    }
    final AssessmentContent content = await assessments.loadContent();
    return <String, int>{
      for (final AssessmentDefinition a in content.assessments)
        a.id: a.items.length,
    };
  }

  /// The newest `completedAt` of each check-in.
  Future<Map<String, DateTime>> getLastDone() async {
    final AssessmentRepository? assessments = _assessments;
    if (assessments == null) {
      return const <String, DateTime>{};
    }
    final Map<String, AssessmentResult> latest = await assessments
        .getLatestById();
    return <String, DateTime>{
      for (final MapEntry<String, AssessmentResult> e in latest.entries)
        e.key: e.value.completedAt,
    };
  }

  Future<Set<String>> seenAlertIds() => _local.seenAlertIds(currentUid());

  Future<void> markAlertSeen(String alertId) =>
      _local.markAlertSeen(currentUid(), alertId);

  Future<String?> lastEvaluatedDay() => _local.lastEvaluatedDay(currentUid());

  Future<void> setLastEvaluatedDay(String day) =>
      _local.setLastEvaluatedDay(currentUid(), day);
}
