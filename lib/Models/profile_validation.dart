/// The rules for the name and age fields.
class ProfileValidation {
  const ProfileValidation._();

  static const int minAge = 18;
  static const int maxAge = 80;

  /// An error message, or null if [value] is a usable name.
  static const int minNameLength = 2;
  static const int maxNameLength = 40;

  static String? nameError(String? value) {
    final String name = (value ?? '').trim();
    if (name.isEmpty) {
      return 'Please enter your name.';
    }
    if (name.length < minNameLength || name.length > maxNameLength) {
      return 'Use $minNameLength to $maxNameLength characters.';
    }
    return null;
  }

  /// The age as a number: null if [value] is empty or is not a number.
  static int? parseAge(String? value) {
    final String trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : int.tryParse(trimmed);
  }

  /// An error message, or null. The age is optional, so empty is fine.
  static String? ageError(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final int? age = int.tryParse(trimmed);
    if (age == null || age < minAge || age > maxAge) {
      return 'Enter an age from $minAge to $maxAge.';
    }
    return null;
  }

  static bool isValid({required String? name, required String? age}) =>
      nameError(name) == null && ageError(age) == null;
}
