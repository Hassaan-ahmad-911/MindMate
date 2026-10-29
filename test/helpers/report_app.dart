import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/assessment_repository.dart';
import 'package:mindmate/Data/repositories/break_repository.dart';
import 'package:mindmate/Data/repositories/meditation_repository.dart';
import 'package:mindmate/Data/repositories/mood_repository.dart';
import 'package:mindmate/Data/repositories/profile_repository.dart';
import 'package:mindmate/Data/repositories/report_repository.dart';
import 'package:mindmate/Models/break_log.dart';
import 'package:mindmate/Models/meditation_log_entry.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/services/assessment_content_service.dart';
import 'package:mindmate/services/report_pdf_service.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/reports/checkins_writing_view.dart';
import 'package:mindmate/ui/reports/checkins_writing_viewmodel.dart';
import 'package:mindmate/ui/reports/reports_view.dart';
import 'package:mindmate/ui/reports/reports_viewmodel.dart';
import 'package:mindmate/ui/reports/share_summary_view.dart';
import 'package:mindmate/ui/reports/share_summary_viewmodel.dart';
import 'package:mindmate/ui/reports/what_helped_view.dart';
import 'package:mindmate/ui/reports/what_helped_viewmodel.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';

import 'assessment_app.dart';
import 'games_fakes.dart';
import 'home_fakes.dart';
import 'journal_fakes.dart';
import 'meditation_fakes.dart';
import 'profile_fakes.dart';

/// Practices kept in memory, answering date-range queries.
class RangeLogService extends FakeLogService {
  bool failRange = false;

  @override
  Future<List<MeditationLogEntry>> getSessionsBetween(
    DateTime start,
    DateTime end,
  ) async {
    if (failRange) {
      throw StateError('offline');
    }
    return history
        .where(
          (MeditationLogEntry e) =>
              !e.startedAt.isBefore(start) && e.startedAt.isBefore(end),
        )
        .toList();
  }
}

/// Breaks kept in memory, answering date-range queries.
class RangeBreakService extends FakeBreakService {
  @override
  Future<List<BreakLogEntry>> getBreaksBetween(
    DateTime start,
    DateTime end,
  ) async {
    return stored
        .where(
          (BreakLogEntry b) =>
              !b.startedAt.isBefore(start) && b.startedAt.isBefore(end),
        )
        .toList();
  }
}

Future<ReportPdfFonts> fileFonts() => ReportPdfFonts.load(
  loader: (String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync()),
);

/// The real report screens and routes, wired to in-memory fakes, with a
/// fixed clock (Thursday 8 October 2026, 21:00).
class ReportTestApp {
  ReportTestApp({DateTime Function()? clock})
    : clock = clock ?? (() => DateTime(2026, 10, 8, 21));

  final DateTime Function() clock;
  final FakeMoodHistoryService moods = FakeMoodHistoryService();
  final RangeLogService practice = RangeLogService();
  final RangeBreakService breaks = RangeBreakService();
  final FakeJournalService journal = FakeJournalService();
  final FakeAssessmentService checkIns = FakeAssessmentService();
  final FakeProfileService profile = FakeProfileService(
    profile: const UserProfile(
      uid: 'uid-1',
      name: 'Ayesha Khan',
      email: 'a@example.com',
      imageUrl: '',
      bio: '',
      age: null,
      gender: '',
      role: 'Nurse',
    ),
  );

  /// What the share sheet was given.
  final List<String> sharedFiles = <String>[];
  final List<Uint8List> sharedBytes = <Uint8List>[];

  late final ReportRepository repository = ReportRepository(
    moods: MoodRepository(moods),
    meditation: MeditationRepository(fileContentService(), practice),
    breaks: BreakRepository(breaks),
    journal: buildJournalRepository(journal),
    assessments: AssessmentRepository(
      checkIns,
      AssessmentContentService(loader: () async => assessmentContentText()),
    ),
    profile: ProfileRepository(profile),
  );

  static const List<String> placeholders = <String>[
    AppRoutes.moodHistory,
    AppRoutes.moodLog,
    AppRoutes.assessmentHistory,
  ];

  Widget build({String initialRoute = AppRoutes.reports}) {
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
            page: () => Scaffold(
              body: Center(child: Text('PAGE $route ${Get.arguments ?? ''}')),
            ),
          ),
        GetPage(
          name: AppRoutes.reports,
          page: () => const ReportsView(),
          binding: BindingsBuilder(() {
            Get.put<ReportsViewModel>(
              ReportsViewModel(repository, clock: clock),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.reportsHelped,
          page: () => const WhatHelpedView(),
          binding: BindingsBuilder(() {
            final Object? a = Get.arguments;
            Get.put<WhatHelpedViewModel>(
              WhatHelpedViewModel(
                repository,
                lastDay: a is DateTime ? a : clock(),
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.reportsCheckIns,
          page: () => const CheckInsWritingView(),
          binding: BindingsBuilder(() {
            final Object? a = Get.arguments;
            Get.put<CheckInsWritingViewModel>(
              CheckInsWritingViewModel(
                repository,
                lastDay: a is DateTime ? a : clock(),
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.reportsShare,
          page: () => const ShareSummaryView(),
          binding: BindingsBuilder(() {
            Get.put<ShareSummaryViewModel>(
              ShareSummaryViewModel(
                repository,
                clock: clock,
                loadFonts: fileFonts,
                share: (Uint8List bytes, String name) async {
                  sharedBytes.add(bytes);
                  sharedFiles.add(name);
                  return true;
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}
