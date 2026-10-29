import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Data/repositories/auth_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../app/app_routes.dart';
import '../app/post_auth_routing.dart';

class SplashViewModel extends GetxController {
  SplashViewModel(
    this._authRepository,
    this._profileRepository, {
    Future<SharedPreferences> Function()? prefs,
  }) : _prefs = prefs ?? SharedPreferences.getInstance;

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final Future<SharedPreferences> Function() _prefs;

  static const Duration _profileCheckTimeout = Duration(seconds: 8);

  /// Where the old onboarding slides remembered they had been seen. The
  /// slides are gone; the key is removed on every start (a no-op once gone).
  static const String legacyOnboardingKey = 'onboarding_completed';

  String? _destination;
  bool _animationFinished = false;
  bool _hasNavigated = false;

  @override
  void onInit() {
    super.onInit();
    unawaited(forgetOnboardingFlag());
    // Start-up work runs while the animation plays.
    unawaited(resolveRoute().then(_onDestinationResolved));
  }

  /// Called by the view when the splash animation has finished.
  void onAnimationFinished() {
    _animationFinished = true;
    _navigateWhenReady();
  }

  void _onDestinationResolved(String route) {
    _destination = route;
    _navigateWhenReady();
  }

  void _navigateWhenReady() {
    final String? destination = _destination;
    if (_hasNavigated || !_animationFinished || destination == null) {
      return;
    }
    _hasNavigated = true;
    Get.offAllNamed(destination);
  }

  /// Welcome when nobody is signed in (or the check fails); otherwise the
  /// signed-in checks: email confirmed, joined a hospital, then Home or the
  /// profile setup (see `AppRouteGate`).
  @visibleForTesting
  Future<String> resolveRoute() async {
    try {
      final User? user = await _authRepository.waitForAuthState();
      if (user != null) {
        return await _routeForSignedInUser();
      }
      return AppRoutes.welcome;
    } catch (_) {
      return AppRoutes.welcome;
    }
  }

  Future<String> _routeForSignedInUser() async {
    bool needsConfirmation = false;
    try {
      needsConfirmation = await _authRepository
          .needsEmailConfirmation()
          .timeout(_profileCheckTimeout);
    } catch (_) {
      needsConfirmation = false;
    }
    if (needsConfirmation) {
      return PostAuthRouting.routeFor(
        hasProfile: false,
        needsEmailConfirmation: true,
      );
    }

    final ({bool hasProfile, bool hasOrg}) state;
    try {
      state = await _profileRepository.setupState().timeout(
        _profileCheckTimeout,
      );
    } catch (_) {
      // Offline or Firestore unavailable: keep the user signed in and send
      // them Home, rather than through the setup again.
      return AppRoutes.home;
    }

    return PostAuthRouting.routeFor(
      hasProfile: state.hasProfile,
      hasOrg: state.hasOrg,
    );
  }

  /// Removes the old "seen onboarding" flag from this phone.
  @visibleForTesting
  Future<void> forgetOnboardingFlag() async {
    try {
      await (await _prefs()).remove(legacyOnboardingKey);
    } catch (_) {
      // Storage unavailable: nothing reads the key any more anyway.
    }
  }
}
