import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Turns a sign-in or sign-up failure into words for the person using the
/// app. Only the error's kind (its code) is read, never its message, which can
/// hold an email address.
class AuthErrors {
  const AuthErrors._();

  /// One message for a wrong email and a wrong password, so the screen never
  /// says which of the two was wrong.
  static const String wrongCredentials =
      'That email and password do not match. Please check them and try again.';

  static const String noInternet =
      'No internet connection. Check it and try again.';

  static const String tooManyAttempts =
      'Too many attempts. Please wait a few minutes and try again.';

  static const String generic = 'Something went wrong. Please try again.';

  static const Set<String> _wrongCredentialCodes = <String>{
    'wrong-password',
    'user-not-found',
    'invalid-credential',
    'invalid-login-credentials',
    'INVALID_LOGIN_CREDENTIALS',
  };

  static const Set<String> _cancelledCodes = <String>{
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-storage-unsupported',
    'canceled',
    'cancelled',
    'user-cancelled',
  };

  /// What to show for [error]. Null means show nothing (the person cancelled).
  static String? messageFor(Object error) {
    if (error is FirebaseAuthException) {
      return _forCode(error.code);
    }
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          return null;
        default:
          return 'Google sign-in did not work. Please try again.';
      }
    }
    return generic;
  }

  static String? _forCode(String code) {
    if (_cancelledCodes.contains(code)) {
      return null;
    }
    if (_wrongCredentialCodes.contains(code)) {
      return wrongCredentials;
    }
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists for that email. Try logging in '
            'instead.';
      case 'invalid-email':
        return 'That email does not look right. Check it and try again.';
      case 'weak-password':
        return 'Choose a stronger password, with at least 8 characters.';
      case 'too-many-requests':
        return tooManyAttempts;
      case 'network-request-failed':
        return noInternet;
      case 'user-disabled':
        return 'This account is not available.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with another way of signing in.';
      case 'operation-not-allowed':
        return 'This way of signing in is not available right now.';
      default:
        return generic;
    }
  }
}
