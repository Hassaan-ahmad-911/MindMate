import 'package:get/get.dart';

import '../Data/repositories/assessment_repository.dart';
import '../Data/repositories/auth_repository.dart';
import '../Data/repositories/wellbeing_programme_repository.dart';
import '../services/programme_firestore_service.dart';
import '../services/programme_local_store.dart';
import '../services/wellbeing_programme_service.dart';
import '../ui/assessments/assessment_binding.dart';
import '../ui/programme/wellbeing_programme_controller.dart';
import '../Data/repositories/break_repository.dart';
import '../Data/repositories/gratitude_repository.dart';
import '../Data/repositories/home_repository.dart';
import '../Data/repositories/profile_repository.dart';
import '../Data/repositories/settings_repository.dart';
import '../Data/repositories/meditation_repository.dart';
import '../Data/repositories/mood_repository.dart';
import '../services/auth_service.dart';
import '../services/email_code_service.dart';
import '../ui/app/email_verification_guard.dart';
import '../ui/auth/pending_signup.dart';
import '../services/break_log_service.dart';
import '../services/gratitude_service.dart';
import '../services/keep_awake_service.dart';
import '../services/meditation_content_service.dart';
import '../services/meditation_log_service.dart';
import '../services/meditation_voice_service.dart';
import '../services/mood_firestore_service.dart';
import '../services/profile_firestore_service.dart';
import '../services/settings_firestore_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AuthService>(AuthService(), permanent: true);
    Get.put<EmailCodeService>(EmailCodeService(), permanent: true);
    Get.put<AuthRepository>(
      AuthRepository(
        Get.find<AuthService>(),
        emailCodes: Get.find<EmailCodeService>(),
      ),
      permanent: true,
    );
    Get.put<PendingSignup>(PendingSignup(), permanent: true);
    Get.put<EmailVerificationGuard>(
      EmailVerificationGuard(Get.find<AuthRepository>()),
      permanent: true,
    );
    Get.put<ProfileFirestoreService>(
      ProfileFirestoreService(),
      permanent: true,
    );
    Get.put<ProfileRepository>(
      ProfileRepository(Get.find<ProfileFirestoreService>()),
      permanent: true,
    );
    Get.put<HomeRepository>(HomeRepository(), permanent: true);
    Get.put<MoodFirestoreService>(MoodFirestoreService(), permanent: true);
    Get.put<MoodRepository>(
      MoodRepository(
        Get.find<MoodFirestoreService>(),
        onSaved: notifyWellbeingProgramme,
      ),
      permanent: true,
    );
    Get.put<SettingsFirestoreService>(
      SettingsFirestoreService(),
      permanent: true,
    );
    Get.put<SettingsRepository>(
      SettingsRepository(Get.find<SettingsFirestoreService>()),
      permanent: true,
    );
    Get.put<MeditationContentService>(
      MeditationContentService(),
      permanent: true,
    );
    Get.put<MeditationLogService>(MeditationLogService(), permanent: true);
    Get.put<MeditationRepository>(
      MeditationRepository(
        Get.find<MeditationContentService>(),
        Get.find<MeditationLogService>(),
        settings: Get.find<SettingsRepository>(),
      ),
      permanent: true,
    );
    Get.put<BreakLogService>(BreakLogService(), permanent: true);
    Get.put<BreakRepository>(
      BreakRepository(Get.find<BreakLogService>()),
      permanent: true,
    );
    Get.put<GratitudeService>(GratitudeService(), permanent: true);
    Get.put<GratitudeRepository>(
      GratitudeRepository(Get.find<GratitudeService>()),
      permanent: true,
    );
    // The hospital programme: Home, Settings and the save hooks use it, so
    // it lives as long as the app. The check-in services are lazy.
    AssessmentBinding().dependencies();
    Get.put<WellbeingProgrammeRepository>(
      WellbeingProgrammeRepository(
        WellbeingProgrammeService(
          Get.find<EmailCodeService>(),
          idToken: Get.find<AuthService>().idToken,
        ),
        ProgrammeFirestoreService(),
        ProgrammeLocalStore(),
        assessments: Get.find<AssessmentRepository>(),
      ),
      permanent: true,
    );
    Get.put<WellbeingProgrammeController>(
      WellbeingProgrammeController(Get.find<WellbeingProgrammeRepository>()),
      permanent: true,
    );
    // Created the first time a practice needs them.
    Get.lazyPut<MeditationVoiceService>(
      () => FlutterTtsVoiceService(),
      fenix: true,
    );
    Get.lazyPut<KeepAwakeService>(
      () => WakelockKeepAwakeService(),
      fenix: true,
    );
  }
}
