import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.imageUrl,
    required this.bio,
    required this.age,
    required this.gender,
    this.role = '',
    this.shiftPattern = '',
    this.yearsInHealthcare = '',
    this.department = '',
    this.reminderPreference = '',
    this.goals = const <String>[],
    this.checkInStatus = '',
    this.createdAt,
    this.updatedAt,
  });

  /// Whether a `users/{uid}` document holds a profile. The document can exist
  /// with only `acceptedDisclaimerAt` (the user agreed to the notice at sign-up
  /// but has not finished the profile setup yet); that is not a profile.
  static bool isStoredProfile(Map<String, dynamic>? data) {
    return data != null && data['uid'] != null;
  }

  final String uid;
  final String name;
  final String email;
  final String imageUrl;
  final String bio;
  final int? age;
  final String gender;

  /// Doctor, Nurse, ... (see `ProfileOptions.roles`). Empty if not set.
  final String role;

  /// `day`, `night`, `rotating` or `on_call`. Empty if not set.
  final String shiftPattern;

  /// `under_2`, `2_to_5`, `6_to_10` or `over_10`. Empty if not set.
  final String yearsInHealthcare;
  final String department;

  /// `before_shift`, `after_shift`, `evening` or `none`. Empty if not set.
  final String reminderPreference;

  /// What the user came for, from the first check-in question.
  final List<String> goals;

  /// `pending`, `completed` or `dismissed`. Empty for people who signed up
  /// before the check-in existed.
  final String checkInStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'name': name,
      'email': email,
      'imageUrl': imageUrl,
      'bio': bio,
      'age': age,
      'gender': gender,
      'role': role,
      'shiftPattern': shiftPattern,
      'yearsInHealthcare': yearsInHealthcare,
      'department': department,
      'reminderPreference': reminderPreference,
      'goals': goals,
      'checkInStatus': checkInStatus,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: data['uid'] as String? ?? uid,
      name: data['name'] as String? ?? 'User',
      email: data['email'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      age: _readAge(data['age']),
      gender: data['gender'] as String? ?? '',
      role: data['role'] as String? ?? '',
      shiftPattern: data['shiftPattern'] as String? ?? '',
      yearsInHealthcare: data['yearsInHealthcare'] as String? ?? '',
      department: data['department'] as String? ?? '',
      reminderPreference: data['reminderPreference'] as String? ?? '',
      goals: _readStrings(data['goals']),
      checkInStatus: data['checkInStatus'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  bool get hasImage => imageUrl.trim().isNotEmpty;

  /// The first word of the name, e.g. "Ayesha" for "Ayesha Khan".
  String get firstName {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? '' : parts.first;
  }

  String get initial {
    final String trimmedName = name.trim();
    return trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : 'U';
  }

  static int? _readAge(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static List<String> _readStrings(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(
      value.whereType<String>().where((String item) => item.trim().isNotEmpty),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
