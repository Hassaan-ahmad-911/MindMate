import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/assessment_repository.dart';
import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/assessment_rules.dart';
import '../app/app_routes.dart';

/// A point on the "Over time" chart.
class HistoryPoint {
  const HistoryPoint({
    required this.value,
    required this.date,
    this.firstCheckIn = false,
  });

  final double value;
  final DateTime date;

  /// WHO-5 from the first check-in at sign-up.
  final bool firstCheckIn;
}

/// "Over time": every completed result of one questionnaire.
class AssessmentHistoryViewModel extends GetxController {
  AssessmentHistoryViewModel(
    this._repository, {
    String? initialId,
    DateTime Function()? clock,
  }) : _initialId = initialId,
       _clock = clock ?? DateTime.now;

  final AssessmentRepository _repository;
  final String? _initialId;
  final DateTime Function() _clock;

  /// Up to this many results are drawn.
  static const int chartLimit = 12;

  final Rxn<AssessmentContent> content = Rxn<AssessmentContent>();
  final RxString selectedId = 'phq9'.obs;

  /// Newest first.
  final RxList<AssessmentResult> results = <AssessmentResult>[].obs;
  final Rxn<InitialWho5> firstCheckIn = Rxn<InitialWho5>();
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;

  int _request = 0;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  AssessmentDefinition? get def => content.value?.byId(selectedId.value);

  DateTime get now => _clock();

  Future<void> load() async {
    hasError.value = false;
    try {
      final AssessmentContent loaded = await _repository.loadContent();
      content.value = loaded;
      final String? wanted = _initialId;
      if (wanted != null && loaded.byId(wanted) != null) {
        selectedId.value = wanted;
      }
    } catch (_) {
      hasError.value = true;
      isLoading.value = false;
      return;
    }
    await _loadSelected();
  }

  void select(String id) {
    if (id == selectedId.value) {
      return;
    }
    selectedId.value = id;
    unawaited(_loadSelected());
  }

  Future<void> _loadSelected() async {
    final int request = ++_request;
    final String id = selectedId.value;
    isLoading.value = true;
    hasError.value = false;
    results.clear();
    firstCheckIn.value = null;
    try {
      final List<AssessmentResult> found = await _repository.getHistory(id);
      InitialWho5? first;
      // Newer setups also save the first check-in's WHO-5 as a result; only
      // older accounts need it read from the check-in itself.
      if (id == 'who5' && !found.any((AssessmentResult r) => r.fromSetup)) {
        try {
          first = await _repository.getInitialWho5();
        } catch (_) {
          first = null;
        }
      }
      if (request != _request || isClosed) {
        return;
      }
      results.assignAll(found);
      firstCheckIn.value = first;
    } catch (_) {
      if (request == _request) {
        hasError.value = true;
      }
    } finally {
      if (request == _request && !isClosed) {
        isLoading.value = false;
      }
    }
  }

  /// The last [chartLimit] results, oldest first, after the first check-in
  /// for WHO-5.
  List<HistoryPoint> get chartPoints {
    final List<HistoryPoint> points = <HistoryPoint>[
      for (final AssessmentResult r
          in results.take(chartLimit).toList().reversed)
        if (r.headline != null)
          HistoryPoint(
            value: r.headline!,
            date: r.completedAt,
            firstCheckIn: r.fromSetup,
          ),
    ];
    final InitialWho5? first = firstCheckIn.value;
    if (first != null) {
      points.insert(
        0,
        HistoryPoint(
          value: first.score,
          date: first.completedAt,
          firstCheckIn: true,
        ),
      );
    }
    return points;
  }

  /// CBI: one line per area, oldest first.
  Map<String, List<double>> get areaSeries {
    final List<AssessmentResult> recent = results
        .take(chartLimit)
        .toList()
        .reversed
        .toList();
    final Map<String, List<double>> series = <String, List<double>>{};
    for (final AssessmentArea area in def?.areas ?? const <AssessmentArea>[]) {
      series[area.id] = <double>[
        for (final AssessmentResult r in recent) r.areas?[area.id] ?? 0,
      ];
    }
    return series;
  }

  List<DateTime> get areaDates => results
      .take(chartLimit)
      .toList()
      .reversed
      .map((AssessmentResult r) => r.completedAt)
      .toList();

  /// The change from the result before [index] (in [results]), or null for
  /// the oldest.
  int? changeAt(int index) {
    if (index + 1 >= results.length) {
      return null;
    }
    return AssessmentMath.change(results[index], results[index + 1]);
  }

  String? get footer {
    final AssessmentDefinition? d = def;
    if (d == null || results.isEmpty) {
      return null;
    }
    return AssessmentMath.nextSuggestedLine(
      d,
      results.first.completedAt,
      _clock(),
    );
  }

  void openResult(AssessmentResult result) {
    Get.toNamed<void>(
      '${AppRoutes.assessments}/${result.assessmentId}',
      arguments: result,
    );
  }

  Future<void> start() async {
    await Get.toNamed<void>('${AppRoutes.assessments}/${selectedId.value}');
    if (!isClosed) {
      await _loadSelected();
    }
  }

  void back() => Get.back<void>();
}
