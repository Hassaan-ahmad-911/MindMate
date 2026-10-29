import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/journal_repository.dart';
import 'package:mindmate/Data/repositories/meditation_repository.dart';
import 'package:mindmate/Data/repositories/mood_repository.dart';
import 'package:mindmate/Models/mood_catalog.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/journal/journal_args.dart';
import 'package:mindmate/ui/journal/journal_choose_view.dart';
import 'package:mindmate/ui/journal/journal_choose_viewmodel.dart';
import 'package:mindmate/ui/journal/journal_entry_view.dart';
import 'package:mindmate/ui/journal/journal_entry_viewmodel.dart';
import 'package:mindmate/ui/journal/journal_insights_view.dart';
import 'package:mindmate/ui/journal/journal_insights_viewmodel.dart';
import 'package:mindmate/ui/journal/journal_let_go_view.dart';
import 'package:mindmate/ui/journal/journal_saved_view.dart';
import 'package:mindmate/ui/journal/journal_saved_viewmodel.dart';
import 'package:mindmate/ui/journal/journal_view.dart';
import 'package:mindmate/ui/journal/journal_viewmodel.dart';
import 'package:mindmate/ui/journal/journal_write_view.dart';
import 'package:mindmate/ui/journal/journal_write_viewmodel.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';

import 'journal_fakes.dart';
import 'meditation_fakes.dart';

/// The real journal screens and routes (as in `app_pages.dart`), wired to
/// fakes instead of Firestore, with a fixed clock.
class JournalTestApp {
  JournalTestApp({
    FakeJournalService? service,
    FakeDraftStore? drafts,
    DateTime Function()? clock,
    MoodModel? todayMood,
  }) : service = service ?? FakeJournalService(),
       drafts = drafts ?? FakeDraftStore(),
       clock = clock ?? (() => DateTime(2026, 10, 8, 21, 40)),
       moods = FakeMoodService()..todayMood = todayMood;

  final FakeJournalService service;
  final FakeDraftStore drafts;
  final DateTime Function() clock;
  final FakeMoodService moods;

  /// Stand-ins for routes outside the journal.
  static const List<String> placeholders = <String>[
    AppRoutes.support,
    AppRoutes.breathingBubble,
    AppRoutes.meditationDetails,
    AppRoutes.moodLog,
  ];

  static MoodModel tiredModerate() {
    return MoodModel(
      id: 'mood-1',
      mood: 'Tired',
      valence: MoodCatalog.valenceFor('Tired'),
      intensity: MoodCatalog.moderate,
      note: '',
      date: DateTime(2026, 10, 8, 20),
    );
  }

  Widget build({String initialRoute = AppRoutes.journal}) {
    final JournalRepository repo = buildJournalRepository(
      service,
      drafts: drafts,
    );
    final MoodRepository moodRepo = MoodRepository(moods);
    final MeditationRepository meditation = buildRepository(FakeLogService());

    Get.put<JournalRepository>(repo);
    Get.lazyPut<JournalViewModel>(
      () => JournalViewModel(repo, clock: clock),
      fenix: true,
    );

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
          name: AppRoutes.journal,
          page: () => const JournalView(showBack: true),
        ),
        GetPage(
          name: AppRoutes.journalNew,
          page: () => const JournalChooseView(),
          binding: BindingsBuilder(() {
            final Object? args = Get.arguments;
            Get.put<JournalChooseViewModel>(
              JournalChooseViewModel(
                repo,
                args: args is JournalWriteArgs ? args : null,
                clock: clock,
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.journalWrite,
          page: () => const JournalWriteView(),
          binding: BindingsBuilder(() {
            if (Get.isRegistered<JournalWriteViewModel>()) {
              Get.delete<JournalWriteViewModel>(force: true);
            }
            final Object? args = Get.arguments;
            Get.put<JournalWriteViewModel>(
              JournalWriteViewModel(
                repo,
                moods: moodRepo,
                args: args is JournalWriteArgs ? args : null,
                clock: clock,
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.journalLetGo,
          page: () => const JournalLetGoView(),
        ),
        GetPage(
          name: AppRoutes.journalSaved,
          page: () => const JournalSavedView(),
          binding: BindingsBuilder(() {
            Get.put<JournalSavedViewModel>(
              JournalSavedViewModel(
                repo,
                Get.arguments as JournalSavedArgs,
                meditation: meditation,
                clock: clock,
              ),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.journalEntry,
          page: () => const JournalEntryView(),
          binding: BindingsBuilder(() {
            Get.put<JournalEntryViewModel>(
              JournalEntryViewModel(repo, source: Get.arguments, clock: clock),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.journalInsights,
          page: () => const JournalInsightsView(),
          binding: BindingsBuilder(() {
            Get.put<JournalInsightsViewModel>(
              JournalInsightsViewModel(repo, clock: clock),
            );
          }),
        ),
      ],
    );
  }
}
