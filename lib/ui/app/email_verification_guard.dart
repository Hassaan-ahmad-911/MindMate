import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../Data/repositories/auth_repository.dart';
import 'app_routes.dart';
import 'post_auth_routing.dart';
import 'user_session.dart';

/// When the app comes back to the front, an email account whose email is
/// not confirmed is sent to "Confirm your email" (app start and Log in check
/// this themselves).
class EmailVerificationGuard extends GetxService with WidgetsBindingObserver {
  EmailVerificationGuard(this._auth);

  final AuthRepository _auth;
  bool _checking = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(check());
    }
  }

  Future<void> check() async {
    if (_checking ||
        _auth.currentUser == null ||
        PostAuthRouting.openRoutes.contains(Get.currentRoute)) {
      return;
    }
    _checking = true;
    try {
      if (await _auth.needsEmailConfirmation()) {
        UserSession.clearControllers();
        Get.offAllNamed<void>(AppRoutes.confirmEmail);
      }
    } catch (_) {
      // Offline or signed out meanwhile: check again next time.
    } finally {
      _checking = false;
    }
  }
}
