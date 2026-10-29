import 'package:get/get.dart';

/// The details typed on Create account, carried to "Check your email".
///
/// Kept in memory only (never in route arguments, which can be logged or
/// restored), and cleared as soon as the account exists or the person
/// leaves the code screen.
class PendingSignup {
  String? _email;
  String? _password;
  String? _name;
  int _session = 0;

  /// Seconds before another code can be asked for, from the server.
  int resendIn = 60;

  /// How long the code works, in seconds.
  int expiresIn = 600;

  /// No new email was sent this time: a code went to this address moments
  /// ago and still works.
  bool codeSentEarlier = false;

  /// The one shared instance (registered in InitialBinding; created here for
  /// tests and early starts).
  static PendingSignup shared() {
    if (Get.isRegistered<PendingSignup>()) {
      return Get.find<PendingSignup>();
    }
    return Get.put<PendingSignup>(PendingSignup(), permanent: true);
  }

  String get email => _email ?? '';
  String? get password => _password;
  String? get name => _name;

  /// Changes each time [start] runs, so a screen that is closing late does
  /// not clear a newer sign-up.
  int get session => _session;

  bool get isReady => (_email ?? '').isNotEmpty && (_password ?? '').isNotEmpty;

  /// Returns the session number for [clear].
  int start({
    required String email,
    required String password,
    String? name,
    int resendIn = 60,
    int expiresIn = 600,
    bool codeSentEarlier = false,
  }) {
    _email = email;
    _password = password;
    _name = name;
    this.resendIn = resendIn;
    this.expiresIn = expiresIn;
    this.codeSentEarlier = codeSentEarlier;
    return ++_session;
  }

  /// Forgets everything (only if [session] is still the current one, when
  /// given).
  void clear({int? session}) {
    if (session != null && session != _session) {
      return;
    }
    _email = null;
    _password = null;
    _name = null;
  }
}
