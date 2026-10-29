import '../Models/hospital_programme.dart';
import 'email_code_service.dart';

/// The hospital programme's calls to the MindMate server (the same server,
/// address and HTTP client as the email code). Nothing here is logged: the
/// headers hold ID tokens and the answers can say an alert was sent.
///
/// Errors arrive as [EmailCodeException]: `unknown_code`, `consent_required`,
/// `email_not_verified`, `unauthorized`, `network`, ...
class WellbeingProgrammeService {
  WellbeingProgrammeService(this._server, {required this.idToken});

  final EmailCodeService _server;

  /// The signed-in user's Firebase ID token.
  final Future<String> Function() idToken;

  /// Links the account to the hospital with [code]. Only the server writes
  /// `orgId`, `orgJoinedAt` and `orgConsentAt`.
  Future<JoinedHospital> join(String code) async {
    final Map<String, dynamic> body = await _server.postJson(
      '/v1/org/join',
      <String, dynamic>{'code': code, 'consent': true},
      idToken: await idToken(),
    );
    return JoinedHospital.fromJson(body);
  }

  /// Asks the server to look at the user's own saved data again. The server
  /// decides whether the wellbeing officer is emailed; the app never works
  /// out any points itself.
  Future<EvaluateOutcome> evaluate() async {
    final Map<String, dynamic> body = await _server.postJson(
      '/v1/wellbeing/evaluate',
      const <String, dynamic>{},
      idToken: await idToken(),
    );
    return EvaluateOutcome.fromJson(body);
  }
}
