import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/profile_repository.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/check_in/check_in_done_view.dart';
import 'package:mindmate/ui/check_in/check_in_intro_view.dart';
import 'package:mindmate/ui/check_in/check_in_question_view.dart';
import 'package:mindmate/ui/check_in/check_in_viewmodel.dart';
import 'package:mindmate/ui/profile_setup/profile_about_view.dart';
import 'package:mindmate/ui/profile_setup/profile_work_view.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';
import 'package:mindmate/viewmodels/profile_viewmodel.dart';

import 'meditation_fakes.dart';
import 'profile_fakes.dart';

/// The real profile setup and check-in screens and routes (as in
/// `app_pages.dart`), wired to fakes instead of Firestore. It starts on
/// "About you", as the app does after sign-up.
class SetupTestApp {
  SetupTestApp({FakeProfileService? profileService})
    : profileService = profileService ?? FakeProfileService();

  final FakeProfileService profileService;

  /// Key of the RepaintBoundary around the app, for screenshots.
  final GlobalKey boundaryKey = GlobalKey();

  Widget build({String initialRoute = AppRoutes.createProfile}) {
    final ProfileRepository profiles = ProfileRepository(profileService);

    return RepaintBoundary(
      key: boundaryKey,
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
        ),
        initialRoute: initialRoute,
        getPages: <GetPage<dynamic>>[
          GetPage(
            name: AppRoutes.createProfile,
            page: () => const ProfileAboutView(),
            binding: BindingsBuilder(() {
              Get.put<ProfileViewModel>(ProfileViewModel(profiles));
            }),
          ),
          GetPage(
            name: AppRoutes.profileWork,
            page: () => const ProfileWorkView(),
          ),
          GetPage(
            name: AppRoutes.checkInIntro,
            page: () => const CheckInIntroView(),
            binding: BindingsBuilder(() {
              if (Get.isRegistered<CheckInViewModel>()) {
                Get.delete<CheckInViewModel>(force: true);
              }
              Get.put<CheckInViewModel>(
                CheckInViewModel(profiles, buildRepository(FakeLogService())),
              );
            }),
          ),
          GetPage(
            name: AppRoutes.checkInQuestion,
            page: () => const CheckInQuestionView(),
          ),
          GetPage(
            name: AppRoutes.checkInDone,
            page: () => const CheckInDoneView(),
          ),
          GetPage(
            name: AppRoutes.home,
            page: () => const Scaffold(body: Center(child: Text('HOME'))),
          ),
          GetPage(
            name: AppRoutes.moodLog,
            page: () => const Scaffold(body: Center(child: Text('MOOD LOG'))),
          ),
          GetPage(
            name: AppRoutes.meditationDetails,
            page: () =>
                const Scaffold(body: Center(child: Text('PRACTICE DETAILS'))),
          ),
        ],
      ),
    );
  }
}
