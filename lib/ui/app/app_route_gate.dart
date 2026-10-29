import 'app_routes.dart';

/// What the gate needs to know about the person on this phone.
class GateState {
  const GateState({
    required this.signedIn,
    this.needsEmailConfirmation = false,
    this.hasOrg = true,
    this.hasProfile = true,
  });

  final bool signedIn;

  /// An email-and-password account whose email is not confirmed yet. Always
  /// false for Google accounts (Google confirms the email).
  final bool needsEmailConfirmation;

  /// Joined a hospital (`orgId` is set; only the server sets it).
  final bool hasOrg;
  final bool hasProfile;
}

/// Where the app goes, on every app open and after every sign-in. The
/// checks run in this order and the first one that fails decides:
///
/// 1. Signed in, else Welcome.
/// 2. Email confirmed (email accounts only), else Confirm your email.
/// 3. Joined a hospital, else Join your hospital.
/// 4. Profile exists, else the profile setup.
/// 5. Home.
class AppRouteGate {
  const AppRouteGate._();

  static String route(GateState state) {
    if (!state.signedIn) {
      return AppRoutes.welcome;
    }
    if (state.needsEmailConfirmation) {
      return AppRoutes.confirmEmail;
    }
    if (!state.hasOrg) {
      return AppRoutes.joinHospital;
    }
    if (!state.hasProfile) {
      return AppRoutes.createProfile;
    }
    return AppRoutes.home;
  }
}
