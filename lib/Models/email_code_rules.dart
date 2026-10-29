import 'package:flutter/services.dart';

import '../services/email_code_service.dart';

/// The words shown for each email-code problem.
class EmailCodeMessages {
  const EmailCodeMessages._();

  static const String invalidEmail = 'Please enter a valid email.';
  static const String emailInUse =
      'This email already has an account. Log in instead.';
  static const String weakPassword = 'Use at least 8 characters.';
  static const String allDigits = 'Enter all 6 digits.';
  static const String expired = 'This code has expired. Send a new one.';
  static const String tooManyTries = 'Too many tries. Send a new code.';
  static const String sendNew = 'Please send a new code.';
  static const String tooManyRequests =
      'Too many tries from this network. Please wait a few minutes.';
  static const String logInAgain = 'Please log in again.';
  static const String unreachable =
      "We couldn't reach MindMate. Check your connection and try again.";
  static const String notSetUp = 'Sign-up is not set up yet.';

  /// No new email this time: the code sent moments ago still works.
  static const String codeSentEarlier =
      'We sent a code to this email a moment ago, and it still works. '
      'Check your inbox and Spam, or send a new code when the timer ends.';

  /// "That code isn't right. 3 tries left." ("1 try left" for one.)
  static String wrongCode(int? attemptsLeft) {
    if (attemptsLeft == null) {
      return "That code isn't right.";
    }
    final String tries = attemptsLeft == 1 ? 'try' : 'tries';
    return "That code isn't right. $attemptsLeft $tries left.";
  }

  /// "Try again in 12 minutes." from a wait in seconds, rounded up.
  static String tooManyCodes(int? retryAfter) {
    final int minutes = retryAfter == null || retryAfter <= 0
        ? 60
        : (retryAfter / 60).ceil();
    final String unit = minutes == 1 ? 'minute' : 'minutes';
    return "You've asked for a lot of codes. Try again in $minutes $unit.";
  }

  /// What to show for [error]. Null for `wait_before_resend`, which restarts
  /// the countdown instead.
  static String? forError(EmailCodeException error) {
    switch (error.code) {
      case 'invalid_email':
        return invalidEmail;
      case 'email_in_use':
        return emailInUse;
      case 'weak_password':
        return weakPassword;
      case 'invalid_code_format':
        return allDigits;
      case 'wrong_code':
        return wrongCode(error.attemptsLeft);
      case 'code_expired':
        return expired;
      case 'too_many_attempts':
        return tooManyTries;
      case 'no_code':
        return sendNew;
      case 'wait_before_resend':
        return null;
      case 'too_many_codes':
        return tooManyCodes(error.retryAfter);
      case 'too_many_requests':
        return tooManyRequests;
      case 'unauthorized':
        return logInAgain;
      case EmailCodeException.notConfigured:
        return notSetUp;
      default:
        // server_error, network, a timeout, anything unexpected.
        return unreachable;
    }
  }

  /// After these the current code is spent: "Create account" stays off until
  /// a new code is sent.
  static bool needsNewCode(String code) =>
      code == 'code_expired' ||
      code == 'too_many_attempts' ||
      code == 'no_code';
}

/// "Didn't get it? Resend in 0:42".
class ResendCountdown {
  DateTime? _endsAt;

  /// Starts (or restarts) the wait at [seconds] from [now].
  void start(int seconds, DateTime now) {
    _endsAt = now.add(Duration(seconds: seconds < 0 ? 0 : seconds));
  }

  /// Whole seconds left, rounded up; 0 when a new code can be asked for.
  int remaining(DateTime now) {
    final DateTime? end = _endsAt;
    if (end == null || !now.isBefore(end)) {
      return 0;
    }
    return (end.difference(now).inMilliseconds / 1000).ceil();
  }

  bool canResend(DateTime now) => remaining(now) == 0;

  /// 42 -> "0:42", 75 -> "1:15".
  static String format(int seconds) {
    final int s = seconds < 0 ? 0 : seconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// The six-digit code as typed or pasted.
class CodeInput {
  const CodeInput._();

  static const int length = 6;

  /// Digits only, at most six: "123 456" and "Code: 123456" both give
  /// "123456"; letters are dropped.
  static String sanitize(String raw) {
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > length ? digits.substring(0, length) : digits;
  }

  /// "6-digit code, 4 of 6 entered".
  static String semanticsLabel(int entered) =>
      '6-digit code, $entered of $length entered';
}

/// Keeps the hidden code field to six digits, also when a whole code is
/// pasted or suggested by the keyboard.
class CodeInputFormatter extends TextInputFormatter {
  const CodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String clean = CodeInput.sanitize(newValue.text);
    return TextEditingValue(
      text: clean,
      selection: TextSelection.collapsed(offset: clean.length),
    );
  }
}
