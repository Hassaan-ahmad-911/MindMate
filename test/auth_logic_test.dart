import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mindmate/Models/auth_validation.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/ui/auth/auth_errors.dart';

void main() {
  group('Email', () {
    test('is required', () {
      expect(AuthValidation.emailError(''), isNotNull);
      expect(AuthValidation.emailError('   '), isNotNull);
      expect(AuthValidation.emailError(null), isNotNull);
    });

    test('must look like an email', () {
      for (final String bad in <String>[
        'ayesha',
        'ayesha@',
        '@email.com',
        'ayesha@email',
        'ayesha khan@email.com',
        'a@@b.com',
      ]) {
        expect(AuthValidation.emailError(bad), isNotNull, reason: bad);
      }
    });

    test('accepts a normal address, and ignores spaces around it', () {
      expect(AuthValidation.emailError('ayesha.khan@email.com'), isNull);
      expect(AuthValidation.emailError('  a+b@x.co.uk  '), isNull);
    });

    test('the messages are plain words', () {
      expect(AuthValidation.emailError(''), 'Enter your email address.');
      expect(
        AuthValidation.emailError('nope'),
        'That email does not look right. Check it and try again.',
      );
    });
  });

  group('Passwords', () {
    test('log in only asks for a password, so older accounts still work', () {
      expect(AuthValidation.loginPasswordError(''), isNotNull);
      expect(AuthValidation.loginPasswordError(null), isNotNull);
      expect(AuthValidation.loginPasswordError('abc'), isNull);
    });

    test('a new password needs at least 8 characters', () {
      expect(AuthValidation.newPasswordError(''), 'Choose a password.');
      expect(
        AuthValidation.newPasswordError('1234567'),
        'Use at least 8 characters.',
      );
      expect(AuthValidation.newPasswordError('12345678'), isNull);
      expect(AuthValidation.newPasswordError('a much longer one'), isNull);
    });

    test('the confirmation must be filled in and match', () {
      expect(AuthValidation.confirmPasswordError('abcdefgh', ''), isNotNull);
      expect(
        AuthValidation.confirmPasswordError('abcdefgh', 'abcdefgH'),
        'The two passwords do not match.',
      );
      expect(
        AuthValidation.confirmPasswordError('abcdefgh', 'abcdefgh'),
        isNull,
      );
    });

    test('the notice must be ticked', () {
      expect(AuthValidation.consentError(false), isNotNull);
      expect(AuthValidation.consentError(true), isNull);
    });
  });

  group('Password strength', () {
    int level(String password) => PasswordStrength.of(password).level;

    test('nothing typed shows no segments', () {
      expect(level(''), 0);
      expect(PasswordStrength.of(null).level, 0);
    });

    test('1 segment under 8 characters, however it is made', () {
      expect(level('a'), 1);
      expect(level('abc123'), 1);
      expect(level('a1!b2@c'), 1);
      expect(PasswordStrength.of('abc').label, 'Too short');
    });

    test('2 segments at 8 or more characters', () {
      expect(level('abcdefgh'), 2);
      expect(level('12345678'), 2);
      expect(PasswordStrength.of('abcdefgh').label, 'Okay');
    });

    test('3 segments with letters and numbers', () {
      expect(level('abcd1234'), 3);
      expect(level('Abcdefg1'), 3);
      expect(PasswordStrength.of('abcd1234').label, 'Good');
    });

    test('4 segments with a symbol or 12 or more characters', () {
      expect(level('abcd123!'), 4);
      expect(level('abcdefgh!'), 4);
      expect(level('abcdefghijkl'), 4);
      expect(level('123456789012'), 4);
      expect(PasswordStrength.of('abcd123!').label, 'Strong');
    });

    test('a space is not a symbol', () {
      expect(level('abcd 123'), 3);
    });

    test('the line next to the bar', () {
      expect(
        AuthValidation.strengthLine(PasswordStrength.of('abcd1234')),
        'Good. 8 or more characters',
      );
      expect(
        AuthValidation.strengthLine(PasswordStrength.of('abc')),
        'Too short. 8 or more characters',
      );
      expect(
        AuthValidation.strengthLine(PasswordStrength.of('abcd123!')),
        'Strong',
      );
    });
  });

  group('Error messages', () {
    String? message(String code) =>
        AuthErrors.messageFor(FirebaseAuthException(code: code));

    test('a wrong email and a wrong password say the same thing', () {
      final String? wrongPassword = message('wrong-password');
      final String? unknownEmail = message('user-not-found');
      final String? either = message('invalid-credential');

      expect(wrongPassword, AuthErrors.wrongCredentials);
      expect(unknownEmail, wrongPassword);
      expect(either, wrongPassword);
      expect(wrongPassword, isNot(contains('password is')));
    });

    test('an email that already has an account', () {
      expect(
        message('email-already-in-use'),
        contains('An account already exists'),
      );
    });

    test('too many attempts', () {
      expect(message('too-many-requests'), AuthErrors.tooManyAttempts);
    });

    test('no internet', () {
      expect(message('network-request-failed'), AuthErrors.noInternet);
    });

    test('cancelling Google sign-in shows nothing', () {
      expect(message('popup-closed-by-user'), isNull);
      expect(message('cancelled-popup-request'), isNull);
      expect(message('web-storage-unsupported'), isNull);
      expect(
        AuthErrors.messageFor(
          const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
        ),
        isNull,
      );
    });

    test('other Google problems get a friendly line', () {
      expect(
        AuthErrors.messageFor(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ),
        'Google sign-in did not work. Please try again.',
      );
    });

    test('anything unknown is generic and never shows the error text', () {
      expect(
        AuthErrors.messageFor(
          FirebaseAuthException(
            code: 'something-new',
            message: 'The email ayesha@example.com is broken',
          ),
        ),
        AuthErrors.generic,
      );
      expect(
        AuthErrors.messageFor(StateError('ayesha@example.com')),
        AuthErrors.generic,
      );
    });
  });

  group('A stored profile', () {
    test('has a uid; a document with only the agreement is not one', () {
      expect(
        UserProfile.isStoredProfile(<String, dynamic>{
          'uid': 'u1',
          'name': 'Ayesha',
        }),
        isTrue,
      );
      expect(
        UserProfile.isStoredProfile(<String, dynamic>{
          'acceptedDisclaimerAt': DateTime(2026),
        }),
        isFalse,
      );
      expect(UserProfile.isStoredProfile(null), isFalse);
      expect(UserProfile.isStoredProfile(<String, dynamic>{}), isFalse);
    });
  });
}
