/// One choice in the profile setup: what the user sees, and what is stored.
class ProfileOption {
  const ProfileOption(this.label, this.key);

  final String label;
  final String key;
}

/// The choices on the two profile setup screens, and the check-in states.
class ProfileOptions {
  const ProfileOptions._();

  static const List<String> setupGenders = <String>[
    'Female',
    'Male',
    'Prefer not to say',
  ];

  /// The role is stored as the text shown.
  static const List<String> roles = <String>[
    'Doctor',
    'Nurse',
    'Technician',
    'Pharmacist',
    'Admin staff',
    'Other',
  ];

  static const List<ProfileOption> shifts = <ProfileOption>[
    ProfileOption('Day', 'day'),
    ProfileOption('Night', 'night'),
    ProfileOption('Rotating', 'rotating'),
    ProfileOption('On call', 'on_call'),
  ];

  static const List<ProfileOption> years = <ProfileOption>[
    ProfileOption('Under 2', 'under_2'),
    ProfileOption('2 to 5', '2_to_5'),
    ProfileOption('6 to 10', '6_to_10'),
    ProfileOption('Over 10', 'over_10'),
  ];

  static const String checkInPending = 'pending';
  static const String checkInCompleted = 'completed';
  static const String checkInDismissed = 'dismissed';
}
