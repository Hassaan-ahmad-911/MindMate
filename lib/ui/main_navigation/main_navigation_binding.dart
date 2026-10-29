import 'package:get/get.dart';

import '../../Data/repositories/auth_repository.dart';
import '../../Data/repositories/home_repository.dart';
import '../../Data/repositories/meditation_repository.dart';
import '../../Data/repositories/mood_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/main_navigation_viewmodel.dart';
import '../ai_chat/ai_chat_viewmodel.dart';
import '../journal/journal_binding.dart';
import '../mood_tracking/mood_tracking_viewmodel.dart';
import '../settings/settings_binding.dart';

/// Everything the five tabs need. The repositories are already registered by
/// the initial binding; this adds the tabs' ViewModels.
class MainNavigationBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<MainNavigationViewModel>(
      MainNavigationViewModel(
        // Coming back to the Home tab brings its numbers up to date.
        onHomeSelected: () {
          if (Get.isRegistered<HomeViewModel>()) {
            Get.find<HomeViewModel>().refreshQuiet();
          }
        },
      ),
    );
    Get.put<HomeViewModel>(
      HomeViewModel(
        Get.find<AuthRepository>(),
        Get.find<MoodRepository>(),
        Get.find<ProfileRepository>(),
        Get.find<MeditationRepository>(),
        Get.find<HomeRepository>(),
      ),
    );
    Get.put<MoodTrackingViewModel>(
      MoodTrackingViewModel(Get.find<MoodRepository>()),
    );
    Get.put<AiChatViewModel>(AiChatViewModel());
    // Shared with the pushed Journal screen; created when the tab is built.
    JournalBinding().dependencies();
    SettingsBinding().dependencies();
  }
}
