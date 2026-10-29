/// One line on the support page: who to turn to and how to reach them.
class SupportContact {
  const SupportContact({
    required this.name,
    required this.detail,
    required this.howToReach,
  });

  final String name;

  /// What they can help with.
  final String detail;

  /// A phone number or address. A placeholder until it is filled in.
  final String howToReach;
}

/// The people and services on the support page.
///
/// PLACEHOLDERS: replace each `howToReach` with the real local number before
/// release. Nothing here is a real helpline.
class SupportContacts {
  const SupportContacts._();

  static const String notEmergencyLine =
      'MindMate is not an emergency service.';

  static const String urgentLine =
      'If you or someone near you is in danger, call your local emergency '
      'number now.';

  static const String placeholderNumber = 'Add the number here';

  static const List<SupportContact> all = <SupportContact>[
    SupportContact(
      name: 'Local emergency number',
      detail: 'For immediate danger to life.',
      howToReach: placeholderNumber,
    ),
    SupportContact(
      name: 'Crisis helpline',
      detail: 'Free, confidential listening, day and night.',
      howToReach: placeholderNumber,
    ),
    SupportContact(
      name: 'Staff support at your workplace',
      detail: 'Occupational health or an employee assistance line.',
      howToReach: placeholderNumber,
    ),
    SupportContact(
      name: 'Your doctor or a mental health professional',
      detail: 'For ongoing support and treatment.',
      howToReach: placeholderNumber,
    ),
  ];
}
