import 'package:get/get.dart';

import '../../Data/repositories/auth_repository.dart';
import '../../Data/repositories/break_repository.dart';
import '../../Data/repositories/gratitude_repository.dart';
import '../../Data/repositories/journal_repository.dart';
import '../../Data/repositories/meditation_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../../Data/repositories/mood_repository.dart';
import '../../Data/repositories/wellbeing_programme_repository.dart';
import '../programme/join_hospital_view.dart';
import '../programme/join_hospital_viewmodel.dart';
import '../programme/wellbeing_alert_view.dart';
import '../programme/wellbeing_programme_controller.dart';
import '../programme/your_hospital_view.dart';
import '../programme/your_hospital_viewmodel.dart';
import '../../services/keep_awake_service.dart';
import '../../services/meditation_audio_service.dart';
import '../../services/meditation_voice_service.dart';
import '../ai_chat/ai_chat_view.dart';
import '../ai_chat/ai_chat_viewmodel.dart';
import '../auth/email_code_view.dart';
import '../auth/email_code_viewmodel.dart';
import '../auth/forgot_password_view.dart';
import '../check_in/check_in_done_view.dart';
import '../check_in/check_in_intro_view.dart';
import '../check_in/check_in_question_view.dart';
import '../check_in/check_in_viewmodel.dart';
import '../profile_setup/profile_about_view.dart';
import '../profile_setup/profile_work_view.dart';
import '../auth/forgot_password_viewmodel.dart';
import '../auth/login_view.dart';
import '../auth/login_viewmodel.dart';
import '../auth/signup_view.dart';
import '../auth/signup_viewmodel.dart';
import '../auth/welcome_view.dart';
import '../auth/welcome_viewmodel.dart';
import '../door_animation/door_animation_screen.dart';
import '../games/breathing_bubble_view.dart';
import '../games/breathing_bubble_viewmodel.dart';
import '../games/calm_match_view.dart';
import '../games/calm_match_viewmodel.dart';
import '../games/games_hub_view.dart';
import '../games/games_hub_viewmodel.dart';
import '../games/gratitude_garden_view.dart';
import '../games/gratitude_garden_viewmodel.dart';
import '../journal/journal_args.dart';
import '../journal/journal_binding.dart';
import '../journal/journal_choose_view.dart';
import '../journal/journal_choose_viewmodel.dart';
import '../journal/journal_entry_view.dart';
import '../journal/journal_entry_viewmodel.dart';
import '../journal/journal_insights_view.dart';
import '../journal/journal_insights_viewmodel.dart';
import '../journal/journal_let_go_view.dart';
import '../journal/journal_saved_view.dart';
import '../journal/journal_saved_viewmodel.dart';
import '../journal/journal_view.dart';
import '../journal/journal_write_view.dart';
import '../journal/journal_write_viewmodel.dart';
import '../../Data/repositories/assessment_repository.dart';
import '../../Models/assessment_result.dart';
import '../../services/share_service.dart';
import '../assessments/assessment_binding.dart';
import '../../Data/repositories/report_repository.dart';
import '../reports/checkins_writing_view.dart';
import '../reports/checkins_writing_viewmodel.dart';
import '../reports/reports_binding.dart';
import '../reports/reports_view.dart';
import '../reports/reports_viewmodel.dart';
import '../reports/share_summary_view.dart';
import '../reports/share_summary_viewmodel.dart';
import '../reports/what_helped_view.dart';
import '../reports/what_helped_viewmodel.dart';
import '../assessments/assessment_flow_view.dart';
import '../assessments/assessment_flow_viewmodel.dart';
import '../assessments/assessment_history_view.dart';
import '../assessments/assessment_history_viewmodel.dart';
import '../assessments/assessments_hub_view.dart';
import '../assessments/assessments_hub_viewmodel.dart';
import '../main_navigation/main_navigation_binding.dart';
import '../main_navigation/main_navigation_view.dart';
import '../support/support_view.dart';
import '../meditation/meditation_check_in_view.dart';
import '../meditation/meditation_complete_view.dart';
import '../meditation/meditation_details_view.dart';
import '../meditation/meditation_player_view.dart';
import '../meditation/meditation_player_viewmodel.dart';
import '../meditation/meditation_view.dart';
import '../meditation/meditation_viewmodel.dart';
import '../../Models/mood_model.dart';
import '../mood_tracking/log_mood_note_view.dart';
import '../mood_tracking/log_mood_pick_view.dart';
import '../mood_tracking/log_mood_strength_view.dart';
import '../mood_tracking/log_mood_viewmodel.dart';
import '../mood_tracking/mood_history_view.dart';
import '../mood_tracking/mood_history_viewmodel.dart';
import '../mood_tracking/mood_insights_view.dart';
import '../mood_tracking/mood_insights_viewmodel.dart';
import '../mood_tracking/mood_saved_view.dart';
import '../mood_tracking/mood_saved_viewmodel.dart';
import '../mood_tracking/mood_tracking_view.dart';
import '../mood_tracking/mood_tracking_viewmodel.dart';
import '../robot/robot_screen.dart';
import '../../Data/repositories/account_repository.dart';
import '../settings/delete_account_view.dart';
import '../settings/delete_account_viewmodel.dart';
import '../settings/edit_profile_view.dart';
import '../settings/edit_profile_viewmodel.dart';
import '../settings/info_page_view.dart';
import '../settings/privacy_view.dart';
import '../settings/reminders_view.dart';
import '../settings/settings_binding.dart';
import '../settings/settings_view.dart';
import '../settings/theme_view.dart';
import '../settings/change_password_screen.dart';
import '../settings/change_password_viewmodel.dart';
import '../splash/splash_view.dart';
import '../splash/splash_viewmodel.dart';

import '../../viewmodels/profile_viewmodel.dart';
import 'app_routes.dart';

class AppPages {
  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: BindingsBuilder(() {
        Get.put<SplashViewModel>(
          SplashViewModel(
            Get.find<AuthRepository>(),
            Get.find<ProfileRepository>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.welcome,
      page: () => const WelcomeView(),
      binding: BindingsBuilder(() {
        Get.put<WelcomeViewModel>(WelcomeViewModel());
      }),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: BindingsBuilder(() {
        Get.put<LoginViewModel>(
          LoginViewModel(
            Get.find<AuthRepository>(),
            Get.find<ProfileRepository>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.signup,
      page: () => const SignupView(),
      binding: BindingsBuilder(() {
        Get.put<SignupViewModel>(
          SignupViewModel(
            Get.find<AuthRepository>(),
            Get.find<ProfileRepository>(),
          ),
        );
      }),
    ),
    // The emailed code. The email and password come from PendingSignup (in
    // memory), never from route arguments.
    GetPage(
      name: AppRoutes.verifyEmailCode,
      page: () => const EmailCodeView(),
      binding: BindingsBuilder(() {
        Get.put<EmailCodeViewModel>(
          EmailCodeViewModel(
            Get.find<AuthRepository>(),
            Get.find<ProfileRepository>(),
            mode: EmailCodeMode.newAccount,
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.confirmEmail,
      page: () => const EmailCodeView(),
      binding: BindingsBuilder(() {
        Get.put<EmailCodeViewModel>(
          EmailCodeViewModel(
            Get.find<AuthRepository>(),
            Get.find<ProfileRepository>(),
            mode: EmailCodeMode.existing,
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordView(),
      binding: BindingsBuilder(() {
        final Object? arguments = Get.arguments;
        final Object? email = arguments is Map ? arguments['email'] : null;
        Get.put<ForgotPasswordViewModel>(
          ForgotPasswordViewModel(
            Get.find<AuthRepository>(),
            initialEmail: email is String ? email : '',
          ),
        );
      }),
    ),
    // The hospital programme: joining (setup step 1 of 3), the alert screen
    // and "Your hospital" in Settings.
    GetPage(
      name: AppRoutes.joinHospital,
      page: () => const JoinHospitalView(),
      binding: BindingsBuilder(() {
        Get.put<JoinHospitalViewModel>(
          JoinHospitalViewModel(
            Get.find<WellbeingProgrammeRepository>(),
            Get.find<ProfileRepository>(),
            Get.find<AuthRepository>(),
            programme: Get.find<WellbeingProgrammeController>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.wellbeingAlert,
      page: () => const WellbeingAlertView(),
    ),
    GetPage(
      name: AppRoutes.settingsHospital,
      page: () => const YourHospitalView(),
      binding: BindingsBuilder(() {
        Get.put<YourHospitalViewModel>(
          YourHospitalViewModel(
            Get.find<WellbeingProgrammeController>(),
            Get.find<WellbeingProgrammeRepository>(),
            Get.find<MoodRepository>(),
          ),
        );
      }),
    ),
    // The profile setup after joining (steps 2 and 3). Both screens share
    // the one ProfileViewModel created here.
    GetPage(
      name: AppRoutes.createProfile,
      page: () => const ProfileAboutView(),
      binding: BindingsBuilder(() {
        Get.put<ProfileViewModel>(
          ProfileViewModel(Get.find<ProfileRepository>()),
        );
      }),
    ),
    GetPage(name: AppRoutes.profileWork, page: () => const ProfileWorkView()),
    // The first check-in. The intro creates the ViewModel; the question and
    // All set screens share it.
    GetPage(
      name: AppRoutes.checkInIntro,
      page: () => const CheckInIntroView(),
      binding: BindingsBuilder(() {
        if (Get.isRegistered<CheckInViewModel>()) {
          Get.delete<CheckInViewModel>(force: true);
        }
        Get.put<CheckInViewModel>(
          CheckInViewModel(
            Get.find<ProfileRepository>(),
            Get.find<MeditationRepository>(),
            assessments: Get.find<AssessmentRepository>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.checkInQuestion,
      page: () => const CheckInQuestionView(),
    ),
    GetPage(name: AppRoutes.checkInDone, page: () => const CheckInDoneView()),
    GetPage(
      name: AppRoutes.aiChat,
      page: () => const AiChatView(),
      binding: BindingsBuilder(() {
        Get.put<AiChatViewModel>(AiChatViewModel());
      }),
    ),
    // Settings. SettingsBinding shares one SettingsViewModel between the tab
    // and these routes.
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsView(showBack: true),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.settingsProfile,
      page: () => const EditProfileView(),
      bindings: <Bindings>[
        SettingsBinding(),
        BindingsBuilder(() {
          Get.put<EditProfileViewModel>(
            EditProfileViewModel(Get.find<ProfileRepository>()),
          );
        }),
      ],
    ),
    GetPage(
      name: AppRoutes.settingsReminders,
      page: () => const RemindersView(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.settingsTheme,
      page: () => const ThemeView(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.settingsPrivacy,
      page: () => const PrivacyView(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.settingsDeleteAccount,
      page: () => const DeleteAccountView(),
      bindings: <Bindings>[
        SettingsBinding(),
        BindingsBuilder(() {
          Get.put<DeleteAccountViewModel>(
            DeleteAccountViewModel(Get.find<AccountRepository>()),
          );
        }),
      ],
    ),
    GetPage(name: AppRoutes.infoPage, page: () => const InfoPageView()),
    GetPage(
      name: AppRoutes.changePassword,
      page: () => const ChangePasswordScreen(),
      binding: BindingsBuilder(() {
        Get.put<ChangePasswordViewModel>(
          ChangePasswordViewModel(Get.find<AuthRepository>()),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.doorAnimation,
      page: () => const DoorAnimationScreen(),
    ),
    GetPage(name: AppRoutes.robot, page: () => const RobotScreen()),
    GetPage(
      name: AppRoutes.meditation,
      page: () => const MeditationView(),
      binding: BindingsBuilder(() {
        Get.put<MeditationViewModel>(
          MeditationViewModel(
            Get.find<MeditationRepository>(),
            Get.find<MoodRepository>(),
          ),
        );
      }),
    ),
    // One practice, from its details to "Well done". The details route creates
    // the ViewModel and the screens after it share it. The route argument is a
    // practice id (or a MeditationSession).
    GetPage(
      name: AppRoutes.meditationDetails,
      page: () => const MeditationDetailsView(),
      binding: BindingsBuilder(() {
        if (Get.isRegistered<MeditationPlayerViewModel>()) {
          Get.delete<MeditationPlayerViewModel>(force: true);
        }
        // The recorded voice, the backup voice and the background sound.
        Get.lazyPut<MeditationAudioService>(
          () => JustAudioMeditationService(
            backupVoice: Get.find<MeditationVoiceService>(),
          ),
          fenix: true,
        );
        Get.put<MeditationPlayerViewModel>(
          MeditationPlayerViewModel(
            repository: Get.find<MeditationRepository>(),
            audio: Get.find<MeditationAudioService>(),
            keepAwake: Get.find<KeepAwakeService>(),
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
    // The journal. JournalBinding registers the shared services and the one
    // JournalViewModel (also used by the Journal tab).
    GetPage(
      name: AppRoutes.journal,
      page: () => const JournalView(showBack: true),
      binding: JournalBinding(),
    ),
    GetPage(
      name: AppRoutes.journalNew,
      page: () => const JournalChooseView(),
      bindings: <Bindings>[
        JournalBinding(),
        BindingsBuilder(() {
          final Object? arguments = Get.arguments;
          Get.put<JournalChooseViewModel>(
            JournalChooseViewModel(
              Get.find<JournalRepository>(),
              args: arguments is JournalWriteArgs ? arguments : null,
            ),
          );
        }),
      ],
    ),
    // Writing and editing. The keep-or-let-go screen shares this ViewModel.
    GetPage(
      name: AppRoutes.journalWrite,
      page: () => const JournalWriteView(),
      bindings: <Bindings>[
        JournalBinding(),
        BindingsBuilder(() {
          if (Get.isRegistered<JournalWriteViewModel>()) {
            Get.delete<JournalWriteViewModel>(force: true);
          }
          final Object? arguments = Get.arguments;
          Get.put<JournalWriteViewModel>(
            JournalWriteViewModel(
              Get.find<JournalRepository>(),
              moods: Get.isRegistered<MoodRepository>()
                  ? Get.find<MoodRepository>()
                  : null,
              args: arguments is JournalWriteArgs ? arguments : null,
            ),
          );
        }),
      ],
    ),
    GetPage(name: AppRoutes.journalLetGo, page: () => const JournalLetGoView()),
    GetPage(
      name: AppRoutes.journalSaved,
      page: () => const JournalSavedView(),
      bindings: <Bindings>[
        JournalBinding(),
        BindingsBuilder(() {
          final Object? arguments = Get.arguments;
          Get.put<JournalSavedViewModel>(
            JournalSavedViewModel(
              Get.find<JournalRepository>(),
              arguments as JournalSavedArgs,
              meditation: Get.isRegistered<MeditationRepository>()
                  ? Get.find<MeditationRepository>()
                  : null,
            ),
          );
        }),
      ],
    ),
    GetPage(
      name: AppRoutes.journalEntry,
      page: () => const JournalEntryView(),
      bindings: <Bindings>[
        JournalBinding(),
        BindingsBuilder(() {
          Get.put<JournalEntryViewModel>(
            JournalEntryViewModel(
              Get.find<JournalRepository>(),
              source: Get.arguments,
            ),
          );
        }),
      ],
    ),
    GetPage(
      name: AppRoutes.journalInsights,
      page: () => const JournalInsightsView(),
      bindings: <Bindings>[
        JournalBinding(),
        BindingsBuilder(() {
          Get.put<JournalInsightsViewModel>(
            JournalInsightsViewModel(Get.find<JournalRepository>()),
          );
        }),
      ],
    ),
    GetPage(
      name: AppRoutes.moodTracking,
      page: () => const MoodTrackingView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<MoodTrackingViewModel>()) {
          Get.put<MoodTrackingViewModel>(
            MoodTrackingViewModel(Get.find<MoodRepository>()),
          );
        }
      }),
    ),
    GetPage(
      name: AppRoutes.moodLog,
      page: () => const LogMoodPickView(),
      binding: BindingsBuilder(() {
        Get.put<LogMoodViewModel>(LogMoodViewModel(Get.find<MoodRepository>()));
      }),
    ),
    // Steps 2 and 3 share the LogMoodViewModel created by step 1.
    GetPage(
      name: AppRoutes.moodLogStrength,
      page: () => const LogMoodStrengthView(),
    ),
    GetPage(name: AppRoutes.moodLogNote, page: () => const LogMoodNoteView()),
    GetPage(
      name: AppRoutes.moodSaved,
      page: () => const MoodSavedView(),
      binding: BindingsBuilder(() {
        final Object? arguments = Get.arguments;
        Get.put<MoodSavedViewModel>(
          MoodSavedViewModel(arguments is MoodModel ? arguments : null),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.moodHistory,
      page: () => const MoodHistoryView(),
      binding: BindingsBuilder(() {
        final Object? arguments = Get.arguments;
        Get.put<MoodHistoryViewModel>(
          MoodHistoryViewModel(
            Get.find<MoodRepository>(),
            initialDay: arguments is DateTime ? arguments : null,
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.moodInsights,
      page: () => const MoodInsightsView(),
      binding: BindingsBuilder(() {
        Get.put<MoodInsightsViewModel>(
          MoodInsightsViewModel(Get.find<MoodRepository>()),
        );
      }),
    ),
    // Check-ins. The history route comes before `/assessments/:id` so that
    // "history" is never read as a questionnaire id.
    GetPage(
      name: AppRoutes.assessments,
      page: () => const AssessmentsHubView(),
      bindings: <Bindings>[
        AssessmentBinding(),
        BindingsBuilder(() {
          Get.put<AssessmentsHubViewModel>(
            AssessmentsHubViewModel(Get.find<AssessmentRepository>()),
          );
        }),
      ],
    ),
    GetPage(
      name: AppRoutes.assessmentHistory,
      page: () => const AssessmentHistoryView(),
      bindings: <Bindings>[
        AssessmentBinding(),
        BindingsBuilder(() {
          final Object? arguments = Get.arguments;
          Get.put<AssessmentHistoryViewModel>(
            AssessmentHistoryViewModel(
              Get.find<AssessmentRepository>(),
              initialId: arguments is String ? arguments : null,
            ),
          );
        }),
      ],
    ),
    // One questionnaire, opened as `/assessments/{id}`. A saved
    // AssessmentResult as the argument shows that result read-only.
    GetPage(
      name: AppRoutes.assessmentFlow,
      page: () => const AssessmentFlowView(),
      bindings: <Bindings>[
        AssessmentBinding(),
        BindingsBuilder(() {
          if (Get.isRegistered<AssessmentFlowViewModel>()) {
            Get.delete<AssessmentFlowViewModel>(force: true);
          }
          final Object? arguments = Get.arguments;
          final AssessmentResult? saved = arguments is AssessmentResult
              ? arguments
              : null;
          Get.put<AssessmentFlowViewModel>(
            AssessmentFlowViewModel(
              Get.find<AssessmentRepository>(),
              assessmentId: Get.parameters['id'] ?? saved?.assessmentId ?? '',
              savedResult: saved,
              meditation: Get.isRegistered<MeditationRepository>()
                  ? Get.find<MeditationRepository>()
                  : null,
              share: Get.find<ShareService>(),
              programme: Get.isRegistered<WellbeingProgrammeController>()
                  ? Get.find<WellbeingProgrammeController>()
                  : null,
            ),
          );
        }),
      ],
    ),
    GetPage(name: AppRoutes.support, page: () => const SupportView()),
    GetPage(
      name: AppRoutes.games,
      page: () => const GamesHubView(),
      binding: BindingsBuilder(() {
        Get.put<GamesHubViewModel>(
          GamesHubViewModel(
            Get.find<BreakRepository>(),
            Get.find<GratitudeRepository>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.breathingBubble,
      page: () => const BreathingBubbleView(),
      binding: BindingsBuilder(() {
        Get.put<BreathingBubbleViewModel>(
          BreathingBubbleViewModel(Get.find<BreakRepository>()),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.calmMatch,
      page: () => const CalmMatchView(),
      binding: BindingsBuilder(() {
        Get.put<CalmMatchViewModel>(
          CalmMatchViewModel(Get.find<BreakRepository>()),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.gratitudeGarden,
      page: () => const GratitudeGardenView(),
      binding: BindingsBuilder(() {
        Get.put<GratitudeGardenViewModel>(
          GratitudeGardenViewModel(
            Get.find<GratitudeRepository>(),
            Get.find<BreakRepository>(),
          ),
        );
      }),
    ),
    // Reports read the other modules; they never write.
    GetPage(
      name: AppRoutes.reports,
      page: () => const ReportsView(),
      bindings: <Bindings>[
        ReportsBinding(),
        BindingsBuilder(() {
          Get.put<ReportsViewModel>(
            ReportsViewModel(Get.find<ReportRepository>()),
          );
        }),
      ],
    ),
    GetPage(
      name: AppRoutes.reportsHelped,
      page: () => const WhatHelpedView(),
      bindings: <Bindings>[
        ReportsBinding(),
        BindingsBuilder(() {
          final Object? arguments = Get.arguments;
          Get.put<WhatHelpedViewModel>(
            WhatHelpedViewModel(
              Get.find<ReportRepository>(),
              lastDay: arguments is DateTime ? arguments : null,
            ),
          );
        }),
      ],
    ),
    GetPage(
      name: AppRoutes.reportsCheckIns,
      page: () => const CheckInsWritingView(),
      bindings: <Bindings>[
        ReportsBinding(),
        BindingsBuilder(() {
          final Object? arguments = Get.arguments;
          Get.put<CheckInsWritingViewModel>(
            CheckInsWritingViewModel(
              Get.find<ReportRepository>(),
              lastDay: arguments is DateTime ? arguments : null,
            ),
          );
        }),
      ],
    ),
    GetPage(
      name: AppRoutes.reportsShare,
      page: () => const ShareSummaryView(),
      bindings: <Bindings>[
        ReportsBinding(),
        BindingsBuilder(() {
          Get.put<ShareSummaryViewModel>(
            ShareSummaryViewModel(Get.find<ReportRepository>()),
          );
        }),
      ],
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const MainNavigationView(),
      binding: MainNavigationBinding(),
    ),
  ];
}
