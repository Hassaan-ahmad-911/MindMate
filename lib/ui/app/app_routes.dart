class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  /// "Check your email": the code that creates a new account.
  static const String verifyEmailCode = '/verify-email-code';

  /// "Confirm your email": the same screen for an existing account whose
  /// email was never confirmed.
  static const String confirmEmail = '/confirm-email';
  static const String createProfile = '/create-profile';

  /// "Join your hospital": the code that links the account to a hospital.
  static const String joinHospital = '/join-hospital';

  /// "Someone will reach out": shown once per wellbeing alert.
  static const String wellbeingAlert = '/wellbeing-alert';
  static const String settingsHospital = '/settings/hospital';

  /// "Gentle reminders": asks for notification permission (once).
  static const String remindersPermission = '/reminders/permission';

  /// "Today", from the Home bell.
  static const String today = '/today';
  static const String profileWork = '/profile-setup/work';
  static const String checkInIntro = '/check-in';
  static const String checkInQuestion = '/check-in/question';
  static const String checkInDone = '/check-in/done';
  static const String changePassword = '/change-password';
  static const String mainNavigation = '/main-navigation';
  static const String aiChat = '/ai-chat';
  static const String settings = '/settings';
  static const String settingsProfile = '/settings/profile';
  static const String settingsReminders = '/settings/reminders';
  static const String settingsTheme = '/settings/theme';
  static const String settingsPrivacy = '/settings/privacy';
  static const String settingsDeleteAccount = '/settings/delete-account';

  /// A simple page for help items that are not built yet ("Coming soon").
  static const String infoPage = '/info';
  static const String doorAnimation = '/door-animation';
  static const String robot = '/robot';
  static const String meditation = '/meditation';
  static const String meditationDetails = '/meditation-details';
  static const String meditationCheckIn = '/meditation-check-in';
  static const String meditationPlayer = '/meditation-player';
  static const String meditationComplete = '/meditation-complete';
  static const String journal = '/journal';
  static const String journalNew = '/journal/new';
  static const String journalWrite = '/journal/write';
  static const String journalLetGo = '/journal/let-go';
  static const String journalSaved = '/journal/saved';
  static const String journalEntry = '/journal/entry';
  static const String journalInsights = '/journal/insights';
  static const String home = '/home';
  static const String moodTracking = '/mood-tracking';
  static const String moodLog = '/mood/log';
  static const String moodLogStrength = '/mood/log/strength';
  static const String moodLogNote = '/mood/log/note';
  static const String moodSaved = '/mood/saved';
  static const String moodHistory = '/mood/history';
  static const String moodInsights = '/mood/insights';
  static const String assessments = '/assessments';
  static const String assessmentHistory = '/assessments/history';

  /// One questionnaire: open `/assessments/{id}`, e.g. `/assessments/phq9`.
  static const String assessmentFlow = '/assessments/:id';
  static const String games = '/games';
  static const String reports = '/reports';
  static const String reportsHelped = '/reports/helped';
  static const String reportsCheckIns = '/reports/checkins';
  static const String reportsShare = '/reports/share';
  static const String emotionCheck = '/emotion-check';
  static const String support = '/support';
  static const String breathingBubble = '/games/breathing-bubble';
  static const String calmMatch = '/games/calm-match';
  static const String gratitudeGarden = '/games/gratitude-garden';
}
