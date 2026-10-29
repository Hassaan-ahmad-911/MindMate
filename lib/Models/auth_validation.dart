/// How strong a new password looks, for the four-segment bar on Create
/// account.
class PasswordStrength {
  const PasswordStrength._(this.level, this.label);

  /// 1 to 4 segments, or 0 for an empty field.
  final int level;
  final String label;

  static const PasswordStrength none = PasswordStrength._(0, '');
  static const PasswordStrength tooShort = PasswordStrength._(1, 'Too short');
  static const PasswordStrength okay = PasswordStrength._(2, 'Okay');
  static const PasswordStrength good = PasswordStrength._(3, 'Good');
  static const PasswordStrength strong = PasswordStrength._(4, 'Strong');

  /// 1 segment under 8 characters, 2 at 8 or more, 3 with letters and
  /// numbers, 4 with a symbol or 12 or more characters.
  static PasswordStrength of(String? password) {
    final String value = password ?? '';
    if (value.isEmpty) {
      return none;
    }
    if (value.length < AuthValidation.minPasswordLength) {
      return tooShort;
    }

    final bool hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final bool hasDigit = RegExp(r'[0-9]').hasMatch(value);
    final bool hasSymbol = RegExp(r'[^A-Za-z0-9\s]').hasMatch(value);

    if (hasSymbol || value.length >= 12) {
      return strong;
    }
    if (hasLetter && hasDigit) {
      return good;
    }
    return okay;
  }
}

/// The messages under the fields of the account screens. Plain words, and
/// nothing here ever sees more than the text it is asked about.
class AuthValidation {
  const AuthValidation._();

  /// Passwords made on sign-up need at least this many characters.
  static const int minPasswordLength = 8;

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? emailError(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Enter your email address.';
    }
    if (!_email.hasMatch(email)) {
      return 'That email does not look right. Check it and try again.';
    }
    return null;
  }

  /// Log in only asks for a password: accounts made before the 8-character
  /// rule keep working.
  static String? loginPasswordError(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Enter your password.';
    }
    return null;
  }

  /// A new password.
  static String? newPasswordError(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return 'Choose a password.';
    }
    if (password.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    return null;
  }

  static String? confirmPasswordError(String? password, String? confirm) {
    if ((confirm ?? '').isEmpty) {
      return 'Type your password again.';
    }
    if (confirm != password) {
      return 'The two passwords do not match.';
    }
    return null;
  }

  static String? consentError(bool accepted) {
    return accepted ? null : 'Please tick this box to continue.';
  }

  /// The line next to the strength bar.
  static String strengthLine(PasswordStrength strength) {
    switch (strength.level) {
      case 0:
        return 'Use 8 or more characters';
      case 4:
        return strength.label;
      default:
        return '${strength.label}. 8 or more characters';
    }
  }
}
