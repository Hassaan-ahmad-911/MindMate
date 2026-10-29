import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/assessment_repository.dart';
import 'package:mindmate/Data/repositories/meditation_repository.dart';
import 'package:mindmate/Models/assessment_result.dart';
import 'package:mindmate/services/assessment_content_service.dart';
import 'package:mindmate/services/assessment_firestore_service.dart';
import 'package:mindmate/services/share_service.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/assessments/assessment_flow_view.dart';
import 'package:mindmate/ui/assessments/assessment_flow_viewmodel.dart';
import 'package:mindmate/ui/assessments/assessment_history_view.dart';
import 'package:mindmate/ui/assessments/assessment_history_viewmodel.dart';
import 'package:mindmate/ui/assessments/assessments_hub_view.dart';
import 'package:mindmate/ui/assessments/assessments_hub_viewmodel.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';

import 'meditation_fakes.dart';

/// Keeps results in memory instead of Firestore.
class FakeAssessmentService extends AssessmentFirestoreService {
  final List<AssessmentResult> stored = <AssessmentResult>[];
  InitialWho5? initialWho5;
  bool failSaving = false;
  bool failLoading = false;
  int _next = 0;

  @override
  String currentUid() => 'user-1';

  @override
  Future<AssessmentResult> saveResult(AssessmentResult result) async {
    if (failSaving) {
      throw StateError('offline');
    }
    final AssessmentResult saved = result.copyWith(id: 'r${++_next}');
    stored.add(saved);
    return saved;
  }

  List<AssessmentResult> _newestFirst(Iterable<AssessmentResult> list) =>
      list.toList()..sort(
        (AssessmentResult a, AssessmentResult b) =>
            b.completedAt.compareTo(a.completedAt),
      );

  @override
  Future<List<AssessmentResult>> getRecent({required int limit}) async {
    if (failLoading) {
      throw StateError('offline');
    }
    return _newestFirst(stored).take(limit).toList();
  }

  @override
  Future<List<AssessmentResult>> getHistory(String assessmentId) async {
    if (failLoading) {
      throw StateError('offline');
    }
    return _newestFirst(
      stored.where((AssessmentResult r) => r.assessmentId == assessmentId),
    );
  }

  @override
  Future<List<AssessmentResult>> getBetween(
    DateTime start,
    DateTime end,
  ) async {
    return _newestFirst(
      stored.where(
        (AssessmentResult r) =>
            !r.completedAt.isBefore(start) && r.completedAt.isBefore(end),
      ),
    );
  }

  @override
  Future<InitialWho5?> getInitialWho5() async => initialWho5;
}

/// A share sheet that only records what it was asked to share.
class FakeShare extends ShareService {
  final List<String> shared = <String>[];

  @override
  Future<bool> shareText(String text) async {
    shared.add(text);
    return true;
  }
}

String assessmentContentText() =>
    File('assets/assessments/assessments_content.json').readAsStringSync();

/// The real check-in screens and routes (as in `app_pages.dart`), wired to
/// fakes, with a fixed clock.
class AssessmentTestApp {
  AssessmentTestApp({
    FakeAssessmentService? service,
    DateTime Function()? clock,
  }) : service = service ?? FakeAssessmentService(),
       clock = clock ?? (() => DateTime(2026, 10, 8, 9));

  final FakeAssessmentService service;
  final DateTime Function() clock;
  final FakeShare share = FakeShare();
  late final AssessmentRepository repository = AssessmentRepository(
    service,
    AssessmentContentService(loader: () async => assessmentContentText()),
  );

  static const List<String> placeholders = <String>[
    AppRoutes.support,
    AppRoutes.meditationDetails,
  ];

  Widget build({String initialRoute = AppRoutes.assessments}) {
    final MeditationRepository meditation = buildRepository(FakeLogService());
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      initialRoute: initialRoute,
      getPages: <GetPage<dynamic>>[
        for (final String route in placeholders)
          GetPage(
            name: route,
            page: () => Scaffold(body: Center(child: Text('PAGE $route'))),
          ),
        GetPage(
          name: AppRoutes.assessments,
          page: () => const AssessmentsHubView(),
          binding: BindingsBuilder(() {
            Get.put<AssessmentsHubViewModel>(
              AssessmentsHubViewModel(repository, clock: clock),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.assessmentHistory,
          page: () => const AssessmentHistoryView(),
          binding: BindingsBuilder(() {
            final Object? args = Get.arguments;
            Get.put<AssessmentHistoryViewModel>(
              AssessmentHistoryViewModel(
                repository,
                initialId: args is String ? args : null,
                clock: clock,
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.assessmentFlow,
          page: () => const AssessmentFlowView(),
          binding: BindingsBuilder(() {
            if (Get.isRegistered<AssessmentFlowViewModel>()) {
              Get.delete<AssessmentFlowViewModel>(force: true);
            }
            final Object? args = Get.arguments;
            final AssessmentResult? saved = args is AssessmentResult
                ? args
                : null;
            Get.put<AssessmentFlowViewModel>(
              AssessmentFlowViewModel(
                repository,
                assessmentId: Get.parameters['id'] ?? saved?.assessmentId ?? '',
                savedResult: saved,
                meditation: meditation,
                share: share,
                clock: clock,
              ),
            );
          }),
        ),
      ],
    );
  }
}
