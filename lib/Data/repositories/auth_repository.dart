import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import '../../services/email_code_service.dart';

class AuthRepository {
  AuthRepository(this._authService, {EmailCodeService? emailCodes})
    : _emailCodes = emailCodes ?? EmailCodeService();

  final AuthService _authService;
  final EmailCodeService _emailCodes;

  Future<UserCredential> login({
    required String email,
    required String password,
  }) {
    return _authService.login(email, password);
  }

  /// Emails the 6-digit sign-up code. No account exists yet.
  Future<CodeSent> sendSignupCode(String email) {
    return _emailCodes.sendSignupCode(email);
  }

  /// Checks the code; on success the server creates the account with its
  /// email confirmed and returns its uid. Sign in afterwards with [login].
  Future<String> verifySignupCode({
    required String email,
    required String code,
    required String password,
    String? name,
  }) {
    return _emailCodes.verifySignup(
      email: email,
      code: code,
      password: password,
      name: name,
    );
  }

  /// An email account signed in without a confirmed email.
  Future<bool> needsEmailConfirmation() =>
      _authService.needsEmailConfirmation();

  /// Emails a code to the signed-in account's address.
  Future<CodeSent> sendConfirmEmailCode() async {
    return _emailCodes.sendExistingCode(await _authService.idToken());
  }

  /// Confirms the signed-in account's email, then refreshes the account so
  /// the confirmation reaches Firestore.
  Future<void> confirmEmail(String code) async {
    await _emailCodes.verifyExisting(await _authService.idToken(), code);
    await _authService.refreshAfterEmailConfirmed();
  }

  /// Reloads after the server said the email is confirmed already.
  Future<void> refreshAfterEmailConfirmed() =>
      _authService.refreshAfterEmailConfirmed();

  Future<void> forgotPassword({required String email}) {
    return _authService.forgotPassword(email);
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return forgotPassword(email: email);
  }

  Future<UserCredential?> signInWithGoogle() {
    return _authService.signInWithGoogle();
  }

  Future<void> updateCurrentUserProfile({
    required String displayName,
    String? photoUrl,
  }) {
    return _authService.updateCurrentUserProfile(
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Signs out of Firebase Auth and of Google Sign-In.
  Future<void> logout() {
    return _authService.logout();
  }

  Future<bool> hasAcceptedDisclaimer() => _authService.hasAcceptedDisclaimer();

  /// Stores `acceptedDisclaimerAt` on `users/{uid}`.
  Future<void> recordDisclaimerAccepted() {
    return _authService.recordDisclaimerAccepted();
  }

  User? get currentUser => _authService.currentUser;

  /// Signed in with Google only: no password to change.
  bool get isGoogleOnly => _authService.isGoogleOnly;

  Future<void> reauthenticateWithPassword(String password) =>
      _authService.reauthenticateWithPassword(password);

  /// False if the user cancelled.
  Future<bool> reauthenticateWithGoogle() =>
      _authService.reauthenticateWithGoogle();

  Future<void> deleteCurrentUser() => _authService.deleteCurrentUser();

  /// Signs out of Google only (after the account is deleted).
  Future<void> signOutFromGoogle() => _authService.signOutOfGoogleQuietly();

  Future<User?> waitForAuthState() => _authService.waitForAuthState();
}
