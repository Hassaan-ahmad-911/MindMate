import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../Data/repositories/auth_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../app/app_routes.dart';
import '../app/post_auth_routing.dart';
import '../app/user_session.dart';

/// Where a Google sign-in leads.
enum GoogleOutcome {
  /// Signed in; [AuthFlow.routeFor] gave the next screen.
  continued,

  /// A new account whose owner did not accept the notice: signed out again.
  declined,
}

/// The steps after a successful sign-in, shared by Log in and Create account:
/// the profile check, the self-support notice for new Google accounts, and the
/// move to the next screen.
class AuthFlow {
  AuthFlow(this._auth, this._profiles);

  final AuthRepository _auth;
  final ProfileRepository _profiles;

  /// "Confirm your email" for an email account that never confirmed it; then
  /// Home for someone with a profile, the profile setup for someone without.
  /// If the profile check itself fails, Home is safer than sending an
  /// existing user back through the setup.
  Future<String> routeAfterSignIn() async {
    bool needsConfirmation = false;
    try {
      needsConfirmation = await _auth.needsEmailConfirmation();
    } catch (_) {
      needsConfirmation = false;
    }
    if (needsConfirmation) {
      return PostAuthRouting.routeFor(
        hasProfile: false,
        needsEmailConfirmation: true,
      );
    }

    bool hasProfile = true;
    try {
      hasProfile = await _profiles.profileExists();
    } catch (_) {
      hasProfile = true;
    }
    return PostAuthRouting.routeFor(hasProfile: hasProfile);
  }

  /// After a Google sign-in. Someone with a profile carries on as before. A
  /// new account must have agreed to the self-support notice: either it was
  /// ticked on Create account ([consentGiven]), was agreed earlier, or
  /// [askConsent] gets a yes. Without it the new account is signed out again.
  Future<({GoogleOutcome outcome, String route})> afterGoogle({
    bool consentGiven = false,
    Future<bool> Function()? askConsent,
  }) async {
    final String route = await routeAfterSignIn();
    if (route == AppRoutes.home) {
      return (outcome: GoogleOutcome.continued, route: route);
    }

    bool accepted = consentGiven;
    if (!accepted) {
      try {
        accepted = await _auth.hasAcceptedDisclaimer();
      } catch (_) {
        accepted = false;
      }
    }
    if (!accepted && askConsent != null) {
      accepted = await askConsent();
    }

    if (!accepted) {
      try {
        await _auth.logout();
      } catch (_) {
        // The person is not taken further either way.
      }
      return (outcome: GoogleOutcome.declined, route: AppRoutes.welcome);
    }

    await recordConsent();
    return (outcome: GoogleOutcome.continued, route: route);
  }

  /// Stores `acceptedDisclaimerAt`. A failure here does not stop the sign-up:
  /// the account exists, and the write is retried by Firestore when it can.
  Future<void> recordConsent() async {
    try {
      await _auth.recordDisclaimerAccepted().timeout(
        const Duration(seconds: 6),
      );
    } catch (error) {
      debugPrint(
        'Could not store the notice agreement (${error.runtimeType}).',
      );
    }
  }

  /// Opens [route] with nothing left of an earlier session, and with no way
  /// back to the account screens.
  void goTo(String route, {Object? arguments}) {
    UserSession.clearControllers();
    Get.offAllNamed(route, arguments: arguments);
  }
}
