import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../services/assessment_content_service.dart';
import '../../services/assessment_firestore_service.dart';

/// The check-in content file and the user's completed check-ins.
class AssessmentRepository {
  AssessmentRepository(
    this._service,
    this._contentService, {
    void Function()? onSaved,
  }) : _onSaved = onSaved;

  /// Called after a result is saved (the hospital programme's evaluation).
  final void Function()? _onSaved;

  /// The hub reads this many of the newest results and keeps the latest of
  /// each questionnaire.
  static const int recentLimit = 60;

  final AssessmentFirestoreService _service;
  final AssessmentContentService _contentService;

  /// Users who answered PHQ-9 question 9 above "Not at all" during this app
  /// session. Kept in memory only, never stored or sent.
  final Set<String> _item9ThisSession = <String>{};

  Future<AssessmentContent> loadContent() => _contentService.load();

  AssessmentContent? get content => _contentService.content;

  Future<AssessmentResult> saveResult(AssessmentResult result) async {
    final AssessmentResult saved = await _service.saveResult(result);
    _onSaved?.call();
    return saved;
  }

  /// The latest result of each questionnaire, by id.
  Future<Map<String, AssessmentResult>> getLatestById() async {
    final List<AssessmentResult> recent = await _service.getRecent(
      limit: recentLimit,
    );
    final Map<String, AssessmentResult> latest = <String, AssessmentResult>{};
    for (final AssessmentResult r in recent) {
      final AssessmentResult? known = latest[r.assessmentId];
      if (known == null || r.completedAt.isAfter(known.completedAt)) {
        latest[r.assessmentId] = r;
      }
    }
    return latest;
  }

  /// Every result of one questionnaire, newest first.
  Future<List<AssessmentResult>> getHistory(String assessmentId) =>
      _service.getHistory(assessmentId);

  /// For the Reports module: no answers.
  Future<List<AssessmentSummary>> getResultsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final List<AssessmentResult> results = await _service.getBetween(
      start,
      end,
    );
    final AssessmentContent content = await loadContent();
    return results
        .map((AssessmentResult r) => _summary(r, content))
        .toList(growable: false);
  }

  /// For each questionnaire completed with [start] <= completedAt < [end]:
  /// its newest result in that time and the result before it (which may be
  /// older than [start]). Newest first. No answers.
  Future<List<AssessmentLatest>> getLatestBetween(
    DateTime start,
    DateTime end,
  ) async {
    final List<AssessmentResult> inRange = await _service.getBetween(
      start,
      end,
    );
    final AssessmentContent content = await loadContent();
    final Map<String, AssessmentResult> newest = <String, AssessmentResult>{};
    for (final AssessmentResult r in inRange) {
      final AssessmentResult? known = newest[r.assessmentId];
      if (known == null || r.completedAt.isAfter(known.completedAt)) {
        newest[r.assessmentId] = r;
      }
    }
    final List<AssessmentLatest> rows = await Future.wait(
      newest.values.map((AssessmentResult latest) async {
        final List<AssessmentResult> history = await _service.getHistory(
          latest.assessmentId,
        );
        AssessmentResult? previous;
        for (final AssessmentResult r in history) {
          if (r.completedAt.isBefore(latest.completedAt) &&
              (previous == null ||
                  r.completedAt.isAfter(previous.completedAt))) {
            previous = r;
          }
        }
        return AssessmentLatest(
          latest: _summary(latest, content),
          previous: previous == null ? null : _summary(previous, content),
        );
      }),
    );
    rows.sort(
      (AssessmentLatest a, AssessmentLatest b) =>
          b.latest.completedAt.compareTo(a.latest.completedAt),
    );
    return rows;
  }

  AssessmentSummary _summary(AssessmentResult r, AssessmentContent content) {
    bool item9 = false;
    final AssessmentDefinition? def = content.byId(r.assessmentId);
    if (def != null && r.answers.length == def.items.length) {
      item9 = r.scoreWith(def).item9Positive;
    }
    return AssessmentSummary.fromResult(r, item9Positive: item9);
  }

  Future<InitialWho5?> getInitialWho5() => _service.getInitialWho5();

  // The hub banner for this session.

  void markItem9Positive() {
    try {
      _item9ThisSession.add(_service.currentUid());
    } catch (_) {
      // Not signed in: nothing to remember.
    }
  }

  bool get item9PositiveThisSession {
    try {
      return _item9ThisSession.contains(_service.currentUid());
    } catch (_) {
      return false;
    }
  }
}
