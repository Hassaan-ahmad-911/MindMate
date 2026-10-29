import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The address of the email-code server: the deployed one, unless
/// `--dart-define=OTP_BASE_URL=...` names another (a local test server).
class EmailCodeConfig {
  const EmailCodeConfig._();

  static const String deployedUrl =
      'https://mindmate-otp-server-eight.vercel.app';

  static const String otpBaseUrl = String.fromEnvironment(
    'OTP_BASE_URL',
    defaultValue: deployedUrl,
  );

  /// The address to use, or null when sign-up is not set up. A plain
  /// `http://` address (a server on this computer) only works in debug builds.
  static String? usable(String value, {bool release = kReleaseMode}) {
    final String url = value.trim();
    if (url.isEmpty) {
      return null;
    }
    if (release && !url.startsWith('https://')) {
      return null;
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}

/// A problem reported by the code server, or on the way to it. [code] is the
/// server's `error` value, `network` when it could not be reached, or
/// `not_configured` when no server address was given.
class EmailCodeException implements Exception {
  const EmailCodeException(this.code, {this.attemptsLeft, this.retryAfter});

  final String code;
  final int? attemptsLeft;

  /// Seconds to wait, for `wait_before_resend` and `too_many_codes`.
  final int? retryAfter;

  static const String network = 'network';
  static const String notConfigured = 'not_configured';

  @override
  String toString() => 'EmailCodeException($code)';
}

/// A code is on its way.
class CodeSent {
  const CodeSent({
    this.expiresIn = 600,
    this.resendIn = 60,
    this.alreadyVerified = false,
  });

  final int expiresIn;
  final int resendIn;

  /// The account's email was confirmed already: no code was sent.
  final bool alreadyVerified;
}

/// Every call to the email-code server. Nothing here is ever logged: the
/// bodies hold passwords and codes, and the headers hold ID tokens.
class EmailCodeService {
  EmailCodeService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = EmailCodeConfig.usable(baseUrl ?? EmailCodeConfig.otpBaseUrl);

  final http.Client _client;
  final String? _baseUrl;

  static const Duration timeout = Duration(seconds: 20);

  /// False when the app was built without a usable server address.
  bool get isConfigured => _baseUrl != null;

  /// Emails a sign-up code. Nothing is created yet.
  Future<CodeSent> sendSignupCode(String email) async {
    return _codeSent(
      await _post('/v1/signup/send-code', <String, dynamic>{'email': email}),
    );
  }

  /// Checks the code and creates the account, with its email confirmed.
  /// Returns the new account's uid.
  Future<String> verifySignup({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    final Map<String, dynamic> body =
        await _post('/v1/signup/verify', <String, dynamic>{
          'email': email,
          'code': code,
          'password': password,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        });
    final Object? uid = body['uid'];
    if (uid is! String || uid.isEmpty) {
      throw const EmailCodeException('server_error');
    }
    return uid;
  }

  /// Emails a code to the signed-in account's own address.
  Future<CodeSent> sendExistingCode(String idToken) async {
    return _codeSent(
      await _post(
        '/v1/verify-email/send-code',
        const <String, dynamic>{},
        idToken: idToken,
      ),
    );
  }

  /// Confirms the signed-in account's email with [code].
  Future<void> verifyExisting(String idToken, String code) async {
    final Map<String, dynamic> body = await _post(
      '/v1/verify-email/verify',
      <String, dynamic>{'code': code},
      idToken: idToken,
    );
    if (body['verified'] != true) {
      throw const EmailCodeException('server_error');
    }
  }

  static CodeSent _codeSent(Map<String, dynamic> body) {
    if (body['alreadyVerified'] == true) {
      return const CodeSent(alreadyVerified: true);
    }
    final Object? expiresIn = body['expiresIn'];
    final Object? resendIn = body['resendIn'];
    return CodeSent(
      expiresIn: expiresIn is num ? expiresIn.toInt() : 600,
      resendIn: resendIn is num ? resendIn.toInt() : 60,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? idToken,
  }) async {
    final String? base = _baseUrl;
    if (base == null) {
      throw const EmailCodeException(EmailCodeException.notConfigured);
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$base$path'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (idToken != null) 'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } catch (_) {
      // No internet, a timeout, or the server is down.
      throw const EmailCodeException(EmailCodeException.network);
    }

    Map<String, dynamic> json = <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      }
    } catch (_) {
      // Not JSON (a proxy page, say): handled below as a server error.
    }

    if (response.statusCode == 200) {
      return json;
    }
    final Object? error = json['error'];
    final Object? attemptsLeft = json['attemptsLeft'];
    final Object? retryAfter = json['retryAfter'];
    throw EmailCodeException(
      error is String && error.isNotEmpty ? error : 'server_error',
      attemptsLeft: attemptsLeft is num ? attemptsLeft.toInt() : null,
      retryAfter: retryAfter is num ? retryAfter.toInt() : null,
    );
  }
}
