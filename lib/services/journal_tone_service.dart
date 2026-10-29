import '../Models/journal_content.dart';
import '../Models/journal_model.dart';

/// What [JournalToneService.analyse] works out from an entry's text.
class JournalAnalysis {
  const JournalAnalysis({
    required this.tone,
    required this.toneScore,
    required this.topics,
  });

  /// Null when fewer than `minMatchedWords` words were recognised.
  final JournalTone? tone;
  final double? toneScore;

  /// Up to 3 topic names, most mentioned first.
  final List<String> topics;
}

/// The result of [JournalToneService.scoreTone].
class ToneScore {
  const ToneScore({
    required this.tone,
    required this.score,
    required this.matchedWords,
  });

  final JournalTone? tone;

  /// The average weight of the matched words, or null when [tone] is null.
  final double? score;
  final int matchedWords;
}

/// Reads the tone and topics of an entry, on the phone, from a word list.
/// No packages, no network: the text never leaves this class.
class JournalToneService {
  const JournalToneService(this.settings, this.topicKeywords);

  final JournalToneSettings settings;

  /// Topic name -> keywords, from the content file.
  final Map<String, List<String>> topicKeywords;

  static const int maxTopics = 3;

  factory JournalToneService.fromContent(JournalContent content) {
    return JournalToneService(content.tone, content.topics);
  }

  JournalAnalysis analyse(String text) {
    final List<String> words = tokenize(text);
    final ToneScore result = scoreTone(words, settings);
    return JournalAnalysis(
      tone: result.tone,
      toneScore: result.score,
      topics: findTopics(words, topicKeywords),
    );
  }

  /// Lower-cases [text] and splits it into words made of letters, digits and
  /// apostrophes. Curly apostrophes count as straight ones.
  static List<String> tokenize(String text) {
    final String lower = text.toLowerCase().replaceAll('’', "'");
    return RegExp(r"[a-z0-9']+")
        .allMatches(lower)
        .map((RegExpMatch m) => m.group(0)!)
        .toList(growable: false);
  }

  /// The tone of a list of words. This is the whole method:
  ///
  /// 1. Each word found in the lexicon gives its weight (-2 to +2).
  /// 2. If one of the `negationWindow` words before it is a negation
  ///    ("not", "never" ...), the weight is multiplied by `negationFactor`
  ///    (-0.8), so "not happy" counts as fairly heavy.
  /// 3. If the word right before it is an intensifier ("very", "so" ...),
  ///    the weight is multiplied by `intensifierFactor` (1.5).
  /// 4. Each weight is clamped to -2..2.
  /// 5. With fewer than `minMatchedWords` matches the tone is unknown (null).
  /// 6. Otherwise the score is the average weight: Light at or above
  ///    `lightAtOrAbove`, Heavy at or below `heavyAtOrBelow`, else Mixed.
  static ToneScore scoreTone(List<String> words, JournalToneSettings settings) {
    final List<double> weights = <double>[];

    for (int i = 0; i < words.length; i += 1) {
      final double? base = settings.lexicon[words[i]];
      if (base == null) {
        continue;
      }
      double weight = base;

      final int windowStart = i - settings.negationWindow < 0
          ? 0
          : i - settings.negationWindow;
      for (int j = windowStart; j < i; j += 1) {
        if (settings.negations.contains(words[j])) {
          weight *= settings.negationFactor;
          break;
        }
      }
      if (i > 0 && settings.intensifiers.contains(words[i - 1])) {
        weight *= settings.intensifierFactor;
      }
      weights.add(weight.clamp(-2.0, 2.0));
    }

    if (weights.isEmpty || weights.length < settings.minMatchedWords) {
      return ToneScore(tone: null, score: null, matchedWords: weights.length);
    }

    final double score =
        weights.reduce((double a, double b) => a + b) / weights.length;
    final JournalTone tone;
    if (score >= settings.lightAtOrAbove) {
      tone = JournalTone.light;
    } else if (score <= settings.heavyAtOrBelow) {
      tone = JournalTone.heavy;
    } else {
      tone = JournalTone.mixed;
    }
    return ToneScore(tone: tone, score: score, matchedWords: weights.length);
  }

  /// The topics whose keywords appear as whole words, most hits first (ties
  /// keep the file order), at most [maxTopics].
  static List<String> findTopics(
    List<String> words,
    Map<String, List<String>> topicKeywords,
  ) {
    final Map<String, int> counts = <String, int>{};
    for (final String word in words) {
      counts[word] = (counts[word] ?? 0) + 1;
    }

    final List<MapEntry<String, int>> hits = <MapEntry<String, int>>[];
    for (final MapEntry<String, List<String>> topic in topicKeywords.entries) {
      int total = 0;
      for (final String keyword in topic.value) {
        total += counts[keyword] ?? 0;
      }
      if (total > 0) {
        hits.add(MapEntry<String, int>(topic.key, total));
      }
    }
    // A stable sort, so equal counts stay in file order.
    final List<String> order = topicKeywords.keys.toList(growable: false);
    hits.sort((MapEntry<String, int> a, MapEntry<String, int> b) {
      final int byCount = b.value.compareTo(a.value);
      return byCount != 0
          ? byCount
          : order.indexOf(a.key).compareTo(order.indexOf(b.key));
    });
    return List<String>.unmodifiable(
      hits.take(maxTopics).map((MapEntry<String, int> e) => e.key),
    );
  }
}
