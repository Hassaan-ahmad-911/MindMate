import 'programme_schedule.dart';

/// Everything the schedule needs for a user in a hospital.
class ProgrammeStatus {
  const ProgrammeStatus({
    required this.membership,
    required this.config,
    required this.lastDone,
    this.questionCounts = const <String, int>{},
  });

  final HospitalMembership membership;
  final ProgrammeConfig config;

  /// The newest `completedAt` of each check-in.
  final Map<String, DateTime> lastDone;

  /// How many questions each check-in has ("4 questions").
  final Map<String, int> questionCounts;
}

/// Wording that changes for people in a hospital programme.
class ProgrammeWording {
  const ProgrammeWording._();

  /// The footnote of the PHQ-9 question 9 support screen for someone in a
  /// hospital: [lead] in the normal style, then [bold].
  static ({String lead, String bold}) item9Footnote(HospitalMembership m) {
    final String hospital = m.name.trim().isEmpty
        ? "your hospital's"
        : "${m.name.trim()}'s";
    final String officer = m.officerName.trim();
    return (
      lead:
          'If you might act on these thoughts, call your local emergency '
          'number now. MindMate is not an emergency service. Because you are '
          'part of $hospital wellbeing programme, ',
      bold: officer.isEmpty
          ? 'your wellbeing officer will be asked to contact you today.'
          : '$officer, your wellbeing officer, will be asked to contact you '
                'today.',
    );
  }
}

/// The user's hospital, as the app may show it: never the officer's email.
class HospitalMembership {
  const HospitalMembership({
    required this.orgId,
    required this.joinedAt,
    this.name = '',
    this.officerName = '',
    this.officerRole = '',
  });

  final String orgId;
  final DateTime joinedAt;
  final String name;
  final String officerName;
  final String officerRole;

  /// "SM" for "Dr. Sana Malik": titles such as "Dr." are left out.
  String get officerInitials {
    final List<String> words = officerName
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty && !w.endsWith('.'))
        .toList();
    if (words.isEmpty) {
      return '';
    }
    final String first = words.first[0];
    final String last = words.length > 1 ? words.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

/// A record at `users/{uid}/wellbeing_alerts/{id}`: the server asked the
/// officer to reach out. Written only by the server.
class WellbeingAlert {
  const WellbeingAlert({
    required this.id,
    required this.sentAt,
    required this.urgent,
    required this.officerName,
  });

  final String id;
  final DateTime sentAt;
  final bool urgent;
  final String officerName;
}

/// What `POST /v1/wellbeing/evaluate` answered. Never logged.
class EvaluateOutcome {
  const EvaluateOutcome({
    required this.status,
    this.urgent = false,
    this.officerName = '',
  });

  static const String alertSent = 'alert_sent';

  /// `ok`, `watching`, `recently_alerted`, `not_in_programme` or
  /// `alert_sent`.
  final String status;
  final bool urgent;
  final String officerName;

  bool get sent => status == alertSent;

  factory EvaluateOutcome.fromJson(Map<String, dynamic> json) {
    final Object? status = json['status'];
    final Object? officer = json['officerName'];
    return EvaluateOutcome(
      status: status is String ? status : 'ok',
      urgent: json['kind'] == 'urgent',
      officerName: officer is String ? officer : '',
    );
  }
}

/// What `POST /v1/org/join` answered.
class JoinedHospital {
  const JoinedHospital({
    required this.orgId,
    required this.name,
    required this.officerName,
    this.officerRole = '',
  });

  final String orgId;
  final String name;
  final String officerName;
  final String officerRole;

  factory JoinedHospital.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final Object? value = json[key];
      return value is String ? value : '';
    }

    return JoinedHospital(
      orgId: text('orgId'),
      name: text('name'),
      officerName: text('officerName'),
      officerRole: text('officerRole'),
    );
  }
}

/// The hospital code field and the join errors.
class JoinRules {
  const JoinRules._();

  /// Upper case; only letters, digits and dashes are kept.
  static String normalise(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');

  /// At least 4 characters of letters, digits and dashes (the server allows
  /// up to 20).
  static bool isValidCode(String raw) =>
      RegExp(r'^[A-Z0-9-]{4,20}$').hasMatch(normalise(raw));

  static const String emailNotVerified = 'email_not_verified';

  /// The message for a join error, or null for `email_not_verified` (which
  /// opens the email code screen instead).
  static String? message(String code) {
    switch (code) {
      case 'unknown_code':
        return "We couldn't find that code. Check it with your hospital.";
      case 'consent_required':
        return 'Please tick the box to continue.';
      case emailNotVerified:
        return null;
      case 'network':
        return 'No internet connection. Check it and try again.';
      case 'too_many_requests':
        return 'Too many tries. Please wait a few minutes and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
