import 'package:get/get.dart';

import '../../services/meditation_audio_service.dart';

import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/main_navigation_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../ai_chat/ai_chat_viewmodel.dart';
import '../assessments/assessment_flow_viewmodel.dart';
import '../assessments/assessment_history_viewmodel.dart';
import '../assessments/assessments_hub_viewmodel.dart';
import '../check_in/check_in_viewmodel.dart';
import '../games/breathing_bubble_viewmodel.dart';
import '../games/calm_match_viewmodel.dart';
import '../games/games_hub_viewmodel.dart';
import '../games/gratitude_garden_viewmodel.dart';
import '../journal/journal_choose_viewmodel.dart';
import '../journal/journal_entry_viewmodel.dart';
import '../journal/journal_insights_viewmodel.dart';
import '../journal/journal_saved_viewmodel.dart';
import '../journal/journal_viewmodel.dart';
import '../journal/journal_write_viewmodel.dart';
import '../meditation/meditation_player_viewmodel.dart';
import '../meditation/meditation_viewmodel.dart';
import '../mood_tracking/log_mood_viewmodel.dart';
import '../mood_tracking/mood_history_viewmodel.dart';
import '../mood_tracking/mood_insights_viewmodel.dart';
import '../mood_tracking/mood_saved_viewmodel.dart';
import '../mood_tracking/mood_tracking_viewmodel.dart';
import '../programme/join_hospital_viewmodel.dart';
import '../programme/wellbeing_programme_controller.dart';
import '../programme/your_hospital_viewmodel.dart';
import '../reports/checkins_writing_viewmodel.dart';
import '../reports/reports_viewmodel.dart';
import '../reports/share_summary_viewmodel.dart';
import '../reports/what_helped_viewmodel.dart';
import '../settings/change_password_viewmodel.dart';
import '../settings/delete_account_viewmodel.dart';
import '../settings/edit_profile_viewmodel.dart';
import '../settings/settings_viewmodel.dart';

/// Everything that holds one person's data in memory, so the next person to
/// sign in on this phone never sees it.
///
/// The repositories and services keep nothing of their own (they read the
/// signed-in user each time), so what has to go is the ViewModels: profile,
/// mood, journal, chat, meditation, check-in and the break activities.
class UserSession {
  const UserSession._();

  /// Removes every user-specific ViewModel that is currently registered.
  /// Safe to call at any time, and more than once.
  static void clearControllers() {
    for (final void Function() remove in _removers) {
      remove();
    }
    // The hospital programme lives as long as the app; forget the user.
    if (Get.isRegistered<WellbeingProgrammeController>()) {
      Get.find<WellbeingProgrammeController>().reset();
    }
    // Stop any meditation voice or background sound still playing.
    if (Get.isRegistered<MeditationAudioService>() &&
        !Get.isPrepared<MeditationAudioService>()) {
      Get.find<MeditationAudioService>().dispose();
    }
  }

  static void _remove<T extends GetxController>() {
    if (Get.isRegistered<T>()) {
      Get.delete<T>(force: true);
    }
  }

  static final List<void Function()> _removers = <void Function()>[
    _remove<HomeViewModel>,
    _remove<MainNavigationViewModel>,
    _remove<ProfileViewModel>,
    _remove<CheckInViewModel>,
    _remove<MoodTrackingViewModel>,
    _remove<LogMoodViewModel>,
    _remove<MoodHistoryViewModel>,
    _remove<MoodInsightsViewModel>,
    _remove<MoodSavedViewModel>,
    _remove<JournalViewModel>,
    _remove<JournalChooseViewModel>,
    _remove<JournalWriteViewModel>,
    _remove<JournalSavedViewModel>,
    _remove<JournalEntryViewModel>,
    _remove<JournalInsightsViewModel>,
    _remove<AiChatViewModel>,
    _remove<AssessmentsHubViewModel>,
    _remove<AssessmentFlowViewModel>,
    _remove<AssessmentHistoryViewModel>,
    _remove<MeditationViewModel>,
    _remove<MeditationPlayerViewModel>,
    _remove<GamesHubViewModel>,
    _remove<BreathingBubbleViewModel>,
    _remove<CalmMatchViewModel>,
    _remove<GratitudeGardenViewModel>,
    _remove<ReportsViewModel>,
    _remove<WhatHelpedViewModel>,
    _remove<CheckInsWritingViewModel>,
    _remove<ShareSummaryViewModel>,
    _remove<ChangePasswordViewModel>,
    _remove<SettingsViewModel>,
    _remove<EditProfileViewModel>,
    _remove<DeleteAccountViewModel>,
    _remove<JoinHospitalViewModel>,
    _remove<YourHospitalViewModel>,
  ];
}
