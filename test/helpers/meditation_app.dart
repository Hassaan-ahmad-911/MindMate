import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/meditation_repository.dart';
import 'package:mindmate/Data/repositories/mood_repository.dart';
import 'package:mindmate/Data/repositories/settings_repository.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/meditation/meditation_check_in_view.dart';
import 'package:mindmate/ui/meditation/meditation_complete_view.dart';
import 'package:mindmate/ui/meditation/meditation_details_view.dart';
import 'package:mindmate/ui/meditation/meditation_player_view.dart';
import 'package:mindmate/ui/meditation/meditation_player_viewmodel.dart';
import 'package:mindmate/ui/meditation/meditation_view.dart';
import 'package:mindmate/ui/meditation/meditation_viewmodel.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';

import 'meditation_fakes.dart';
import 'settings_fakes.dart';

/// The real meditation screens and routes (as in `app_pages.dart`), wired to
/// fakes instead of Firestore, the phone's voice and the wake lock.
class MeditationTestApp {
  MeditationTestApp({
    FakeAudioService? voice,
    FakeKeepAwake? keepAwake,
    FakeLogService? logService,
    FakeMoodService? moodService,
    DateTime Function()? clock,
  }) : clock = clock ?? daytime,
       voice = voice ?? FakeAudioService(),
       keepAwake = keepAwake ?? FakeKeepAwake(),
       logService = logService ?? FakeLogService(),
       moodService = moodService ?? FakeMoodService();

  final FakeAudioService voice;
  final FakeKeepAwake keepAwake;
  final FakeLogService logService;
  final FakeMoodService moodService;

  /// The library's clock. The suggested practice depends on the time of day,
  /// so by default the library always sees the same afternoon (today's date).
  final DateTime Function() clock;

  static DateTime daytime() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 14, 30);
  }

  /// Where the background sound choice is saved (the user's settings).
  final FakeSettingsService settingsService = FakeSettingsService(uid: 'guest');
  late final MeditationRepository repository = buildRepository(
    logService,
    settings: SettingsRepository(settingsService),
  );

  /// Key of the RepaintBoundary around the app, for screenshots.
  final GlobalKey boundaryKey = GlobalKey();

  /// A page for the route "beneath" the library, so leaving a practice has
  /// somewhere to land.
  static const String homePlaceholder = '/home-placeholder';

  Widget build() {
    return RepaintBoundary(
      key: boundaryKey,
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
        ),
        initialRoute: homePlaceholder,
        getPages: <GetPage<dynamic>>[
          GetPage(
            name: homePlaceholder,
            page: () => const Scaffold(body: Center(child: Text('HOME'))),
          ),
          GetPage(
            name: AppRoutes.meditation,
            page: () => const MeditationView(),
            binding: BindingsBuilder(() {
              Get.put<MeditationViewModel>(
                MeditationViewModel(
                  repository,
                  MoodRepository(moodService),
                  clock: clock,
                ),
              );
            }),
          ),
          GetPage(
            name: AppRoutes.meditationDetails,
            page: () => const MeditationDetailsView(),
            binding: BindingsBuilder(() {
              if (Get.isRegistered<MeditationPlayerViewModel>()) {
                Get.delete<MeditationPlayerViewModel>(force: true);
              }
              Get.put<MeditationPlayerViewModel>(
                MeditationPlayerViewModel(
                  repository: repository,
                  audio: voice,
                  keepAwake: keepAwake,
                  source: Get.arguments,
                ),
              );
            }),
          ),
          GetPage(
            name: AppRoutes.meditationCheckIn,
            page: () => const MeditationCheckInView(),
          ),
          GetPage(
            name: AppRoutes.meditationPlayer,
            page: () => const MeditationPlayerView(),
          ),
          GetPage(
            name: AppRoutes.meditationComplete,
            page: () => const MeditationCompleteView(),
          ),
          GetPage(
            name: AppRoutes.moodLog,
            page: () => const Scaffold(body: Center(child: Text('MOOD LOG'))),
          ),
        ],
      ),
    );
  }
}
