import 'app_route_gate.dart';
import 'app_routes.dart';

/// Where a signed-in user goes first.
class PostAuthRouting {
  const PostAuthRouting._();

  /// An email-and-password account whose email is not confirmed yet goes to
  /// "Confirm your email" first, then someone not in a hospital to "Join your
  /// hospital". Otherwise a user with a profile goes straight to Home, even
  /// if they never finished the first check-in (Home offers to finish it),
  /// and a user without one starts the profile setup. See [AppRouteGate].
  static String routeFor({
    required bool hasProfile,
    bool needsEmailConfirmation = false,
    bool hasOrg = true,
  }) {
    return AppRouteGate.route(
      GateState(
        signedIn: true,
        needsEmailConfirmation: needsEmailConfirmation,
        hasOrg: hasOrg,
        hasProfile: hasProfile,
      ),
    );
  }

  /// Screens a user without a confirmed email may stay on.
  static const Set<String> openRoutes = <String>{
    AppRoutes.splash,
    AppRoutes.welcome,
    AppRoutes.login,
    AppRoutes.signup,
    AppRoutes.forgotPassword,
    AppRoutes.verifyEmailCode,
    AppRoutes.confirmEmail,
  };
}
