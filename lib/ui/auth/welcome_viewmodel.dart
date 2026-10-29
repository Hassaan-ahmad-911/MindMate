import 'package:get/get.dart';

import '../app/app_routes.dart';

class WelcomeViewModel extends GetxController {
  void goToLogin() {
    Get.toNamed(AppRoutes.login);
  }

  void goToSignup() {
    Get.toNamed(AppRoutes.signup);
  }
}
