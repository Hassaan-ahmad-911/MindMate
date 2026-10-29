import '../Models/journal_content.dart';

/// Checks whether an entry contains one of the support phrases, so the app
/// can show the support card.
///
/// It returns true or false and nothing else. The result is never stored,
/// logged, counted or sent anywhere.
class JournalSafetyService {
  JournalSafetyService(Iterable<String> phrases)
    : _phrases = List<String>.unmodifiable(
        phrases.map(normalize).where((String p) => p.isNotEmpty),
      );

  factory JournalSafetyService.fromContent(JournalContent content) {
    return JournalSafetyService(content.supportPhrases);
  }

  final List<String> _phrases;

  bool matchesSupport(String text) {
    if (text.trim().isEmpty) {
      return false;
    }
    // Spaces at both ends so a phrase only matches whole words.
    final String padded = ' ${normalize(text)} ';
    for (final String phrase in _phrases) {
      if (padded.contains(' $phrase ')) {
        return true;
      }
    }
    return false;
  }

  /// Lower-cases [text], drops apostrophes ("don't" -> "dont"), turns other
  /// punctuation into spaces and collapses runs of spaces.
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp("['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
