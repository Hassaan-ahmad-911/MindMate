import 'account_data_service.dart';

/// The steps of deleting an account, in order.
enum DeletionStep {
  subcollections,
  legacyJournals,
  profilePhoto,
  userDocument,
  authUser,
  googleSignOut,
  localSettings,
}

/// Thrown when a step fails. The user stays signed in; running the deletion
/// again picks up where it stopped, because every step is safe to repeat.
class AccountDeletionException implements Exception {
  const AccountDeletionException(this.step);

  final DeletionStep step;

  @override
  String toString() => 'Account deletion stopped at $step';
}

/// Deletes everything, in this order: the subcollections under `users/{uid}`,
/// old top-level journals, the profile photo, the user document, the
/// Firebase Auth user, then signs out of Google and clears the phone's saved
/// settings.
class AccountDeletionService {
  AccountDeletionService({
    required AccountDataBackend data,
    required Future<void> Function() deleteAuthUser,
    required Future<void> Function() signOutGoogle,
    required Future<void> Function(String uid) clearLocalSettings,
    void Function(DeletionStep step)? onStep,
  }) : _data = data,
       _deleteAuthUser = deleteAuthUser,
       _signOutGoogle = signOutGoogle,
       _clearLocal = clearLocalSettings,
       _onStep = onStep;

  final AccountDataBackend _data;
  final Future<void> Function() _deleteAuthUser;
  final Future<void> Function() _signOutGoogle;
  final Future<void> Function(String uid) _clearLocal;
  final void Function(DeletionStep step)? _onStep;

  /// The user must have re-authenticated just before.
  Future<void> deleteAccount() async {
    final String uid = _data.currentUid();

    Future<void> step(DeletionStep s, Future<void> Function() run) async {
      _onStep?.call(s);
      try {
        await run();
      } catch (_) {
        throw AccountDeletionException(s);
      }
    }

    await step(DeletionStep.subcollections, () async {
      for (final String name in AccountDataBackend.subcollections) {
        await _data.deleteSubcollection(uid, name);
      }
    });
    await step(
      DeletionStep.legacyJournals,
      () => _data.deleteLegacyJournals(uid),
    );
    await step(DeletionStep.profilePhoto, () => _data.deleteProfilePhoto(uid));
    await step(DeletionStep.userDocument, () => _data.deleteUserDocument(uid));
    await step(DeletionStep.authUser, _deleteAuthUser);
    // After this point the account is gone; these never stop the deletion.
    _onStep?.call(DeletionStep.googleSignOut);
    try {
      await _signOutGoogle();
    } catch (_) {}
    _onStep?.call(DeletionStep.localSettings);
    try {
      await _clearLocal(uid);
    } catch (_) {}
  }
}
