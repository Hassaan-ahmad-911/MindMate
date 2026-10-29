import 'package:get/get.dart';

import '../../Data/repositories/account_repository.dart';
import '../../Data/repositories/auth_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../../Data/repositories/settings_repository.dart';
import '../../services/account_data_service.dart';
import '../../services/theme_controller.dart';
import '../programme/wellbeing_programme_controller.dart';
import 'settings_viewmodel.dart';

/// The Settings tab and every settings route share one [SettingsViewModel],
/// created the first time it is needed.
class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountDataBackend>(
      () => FirebaseAccountDataService(),
      fenix: true,
    );
    Get.lazyPut<AccountRepository>(
      () => AccountRepository(
        data: Get.find<AccountDataBackend>(),
        auth: Get.find<AuthRepository>(),
        settings: Get.find<SettingsRepository>(),
      ),
      fenix: true,
    );
    Get.lazyPut<SettingsViewModel>(
      () => SettingsViewModel(
        Get.find<AuthRepository>(),
        settings: _find<SettingsRepository>(),
        profiles: _find<ProfileRepository>(),
        account: Get.find<AccountRepository>(),
        theme: _find<ThemeController>(),
        programme: _find<WellbeingProgrammeController>(),
      ),
      fenix: true,
    );
  }

  static T? _find<T>() => Get.isRegistered<T>() ? Get.find<T>() : null;
}
