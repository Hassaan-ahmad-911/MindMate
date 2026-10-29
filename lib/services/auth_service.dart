import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const String _googleWebClientId =
      '203338340444-piiuemqoehib229o7elgg9ba7l284jpv.apps.googleusercontent.com';

  Future<void>? _googleSignInInitialization;

  FirebaseFirestore get _firestore {
    _ensureFirebaseInitialized();
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get _auth {
    _ensureFirebaseInitialized();
    return FirebaseAuth.instance;
  }

  User? get currentUser {
    if (Firebase.apps.isEmpty) {
      return null;
    }

    return FirebaseAuth.instance.currentUser;
  }

  /// Waits for Firebase Auth to restore any persisted session, then returns
  /// the signed-in user (or null).
  Future<User?> waitForAuthState() async {
    if (Firebase.apps.isEmpty) {
      return null;
    }

    return FirebaseAuth.instance.authStateChanges().first;
  }

  // There is no sign-up here: new email accounts are created by the
  // email-code server only after the emailed code is checked
  // (EmailCodeService.verifySignup).

  Future<UserCredential> login(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// True for an email-and-password account whose email is not confirmed.
  /// Google accounts are always treated as confirmed. The account is
  /// reloaded first; offline, the last known state is used.
  Future<bool> needsEmailConfirmation() async {
    final User? user = currentUser;
    if (user == null) {
      return false;
    }
    final Set<String> providers = user.providerData
        .map((UserInfo i) => i.providerId)
        .toSet();
    if (providers.contains('google.com') || !providers.contains('password')) {
      return false;
    }
    try {
      await user.reload();
    } catch (_) {
      // Offline: keep what is known.
    }
    return !(currentUser?.emailVerified ?? true);
  }

  /// The signed-in user's Firebase ID token, for the email-code server.
  Future<String> idToken() async {
    final String? token = await _requireUser().getIdToken();
    if (token == null) {
      throw FirebaseAuthException(code: 'no-id-token');
    }
    return token;
  }

  /// After the server confirmed the email: reload the account and fetch a
  /// fresh ID token, so Firestore sees `email_verified` as true.
  Future<void> refreshAfterEmailConfirmed() async {
    final User user = _requireUser();
    await user.reload();
    await (currentUser ?? user).getIdToken(true);
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        return await _auth.signInWithPopup(GoogleAuthProvider());
      } on FirebaseAuthException catch (error) {
        if (error.code == 'popup-closed-by-user' ||
            error.code == 'web-storage-unsupported') {
          return null;
        }
        rethrow;
      }
    }

    final AuthCredential? credential = await _googleCredential();
    if (credential == null) {
      return null;
    }
    return _auth.signInWithCredential(credential);
  }

  /// Asks Google for the account and builds a Firebase credential. Null when
  /// the user cancels.
  Future<AuthCredential?> _googleCredential() async {
    await _ensureGoogleSignInInitialized();

    late final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final String? idToken = googleAuth.idToken;
    if (idToken == null) {
      return null;
    }

    final GoogleSignInClientAuthorization? authorization = await googleUser
        .authorizationClient
        .authorizationForScopes(<String>['email', 'profile']);

    return GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: authorization?.accessToken,
    );
  }

  /// True when the account signs in with Google only (no password), so it
  /// has no password to change and confirms with Google instead.
  bool get isGoogleOnly {
    final User? user = currentUser;
    if (user == null) {
      return false;
    }
    final List<String> providers = user.providerData
        .map((UserInfo i) => i.providerId)
        .toList();
    return providers.contains('google.com') && !providers.contains('password');
  }

  /// Confirms the signed-in user's password before a sensitive change.
  Future<void> reauthenticateWithPassword(String password) async {
    final User user = _requireUser();
    final String email = user.email?.trim() ?? '';
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// Confirms with Google before a sensitive change. False if cancelled.
  Future<bool> reauthenticateWithGoogle() async {
    final User user = _requireUser();
    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return true;
    }
    final AuthCredential? credential = await _googleCredential();
    if (credential == null) {
      return false;
    }
    await user.reauthenticateWithCredential(credential);
    return true;
  }

  /// Signs out of Google only, ignoring failures (after the account is
  /// deleted, Firebase is already signed out).
  Future<void> signOutOfGoogleQuietly() async {
    try {
      await signOutFromGoogle();
    } catch (_) {}
  }

  /// Deletes the Firebase Auth user (after re-authentication).
  Future<void> deleteCurrentUser() => _requireUser().delete();

  User _requireUser() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user is available.',
      );
    }
    return user;
  }

  Future<void> forgotPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateCurrentUserProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user is available.',
      );
    }

    await user.updateDisplayName(displayName);
    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }
    await user.reload();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user is available.',
      );
    }

    final String email = user.email?.trim() ?? '';
    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'The current user does not have an email address.',
      );
    }

    final AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
    await user.reload();
  }

  /// Signs out of Google and of Firebase, so the next Google sign-in shows the
  /// account chooser and the next person on this phone starts clean.
  ///
  /// Google goes first and can fail without stopping Firebase from signing
  /// out. If Firebase itself fails, the error is thrown so the screen can say
  /// so.
  Future<void> logout() async {
    try {
      await signOutFromGoogle();
    } catch (error) {
      debugPrint('Google sign-out failed (${error.runtimeType}).');
    }
    await signOutFromFirebase();
  }

  /// Clears the Google account kept by the Google sign-in plugin. It is set up
  /// first if needed: after the app restarts the plugin can still hold the
  /// last account even though nothing has signed in yet this run.
  @visibleForOverriding
  Future<void> signOutFromGoogle() async {
    if (kIsWeb || Firebase.apps.isEmpty) {
      return;
    }
    await _ensureGoogleSignInInitialized();
    await GoogleSignIn.instance.signOut();
  }

  @visibleForOverriding
  Future<void> signOutFromFirebase() async {
    if (Firebase.apps.isEmpty) {
      return;
    }
    await FirebaseAuth.instance.signOut();
  }

  /// Whether the signed-in user already agreed to the self-support notice.
  Future<bool> hasAcceptedDisclaimer() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    return snapshot.data()?['acceptedDisclaimerAt'] != null;
  }

  /// Stores when the signed-in user agreed to the self-support notice, as
  /// `acceptedDisclaimerAt` on `users/{uid}`. The first agreement is kept.
  ///
  /// This can create the document before the profile exists, which is why a
  /// profile is recognised by its `uid` field and not by the document alone.
  Future<void> recordDisclaimerAccepted() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user is available.',
      );
    }

    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('users')
        .doc(user.uid);
    try {
      final DocumentSnapshot<Map<String, dynamic>> existing = await docRef
          .get();
      if (existing.data()?['acceptedDisclaimerAt'] != null) {
        return;
      }
    } catch (_) {
      // Offline: write it anyway; it is sent when the phone is back online.
    }

    await docRef.set(<String, dynamic>{
      'acceptedDisclaimerAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _ensureFirebaseInitialized() {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase has not been initialized for this platform.');
    }
  }

  Future<void> _ensureGoogleSignInInitialized() {
    _googleSignInInitialization ??= GoogleSignIn.instance.initialize(
      serverClientId: _googleWebClientId,
    );
    return _googleSignInInitialization!;
  }
}
