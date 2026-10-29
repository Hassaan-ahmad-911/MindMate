import 'package:get/get.dart';

import '../Data/repositories/auth_repository.dart';
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
      MoodRepository(Get.find<MoodFirestoreService>()),
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
