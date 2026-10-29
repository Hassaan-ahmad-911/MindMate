import 'dart:convert';

/// The four ways to write. The ids match `type` on a saved entry.
class JournalTypes {
  const JournalTypes._();

  static const String afterShift = 'after_shift';
  static const String moment = 'moment';
  static const String free = 'free';
  static const String letItOut = 'let_it_out';

  static const List<String> all = <String>[afterShift, moment, letItOut, free];

  /// Short name used on chips and under entry cards, e.g. "After shift".
  static String shortLabel(String type) {
    switch (type) {
      case afterShift:
        return 'After shift';
      case moment:
        return 'A moment';
      case letItOut:
        return 'Let it out';
      default:
        return 'Free write';
    }
  }

  /// An unknown or missing type is read as a free write.
  static String normalize(Object? value) {
    final String type = value?.toString() ?? '';
    return all.contains(type) ? type : free;
  }
}

/// One question in a guided template.
class JournalQuestion {
  const JournalQuestion({
    required this.id,
    required this.text,
    required this.placeholder,
  });

  final String id;
  final String text;
  final String placeholder;

  factory JournalQuestion.fromMap(Map<String, dynamic> map) {
    return JournalQuestion(
      id: _requiredString(map, 'id'),
      text: _requiredString(map, 'text'),
      placeholder: _optionalString(map, 'placeholder'),
    );
  }
}

/// A way to write: guided (with questions) or free.
class JournalTemplate {
  const JournalTemplate({
    required this.id,
    required this.title,
    required this.line,
    required this.hint,
    required this.saved,
    required this.questions,
  });

  final String id;
  final String title;
  final String line;
  final String hint;

  /// False for "Let it out", which asks before keeping anything.
  final bool saved;
  final List<JournalQuestion> questions;

  bool get isGuided => questions.isNotEmpty;

  factory JournalTemplate.fromMap(Map<String, dynamic> map) {
    final Object? questions = map['questions'];
    return JournalTemplate(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      line: _optionalString(map, 'line'),
      hint: _optionalString(map, 'hint'),
      saved: map['saved'] != false,
      questions: questions is List
          ? List<JournalQuestion>.unmodifiable(
              questions.map(
                (Object? q) =>
                    JournalQuestion.fromMap((q as Map).cast<String, dynamic>()),
              ),
            )
          : const <JournalQuestion>[],
    );
  }
}

/// A writing prompt for the card on Journal home.
class JournalPrompt {
  const JournalPrompt({required this.text, required this.when});

  final String text;

  /// "morning", "evening" or "any".
  final String when;

  factory JournalPrompt.fromMap(Map<String, dynamic> map) {
    return JournalPrompt(
      text: _requiredString(map, 'text'),
      when: _optionalString(map, 'when').isEmpty
          ? 'any'
          : _optionalString(map, 'when'),
    );
  }
}

/// The settings for reading the tone of an entry. See `JournalToneService`.
class JournalToneSettings {
  const JournalToneSettings({
    required this.minMatchedWords,
    required this.lightAtOrAbove,
    required this.heavyAtOrBelow,
    required this.negations,
    required this.negationWindow,
    required this.negationFactor,
    required this.intensifiers,
    required this.intensifierFactor,
    required this.labels,
    required this.savedLines,
    required this.lexicon,
  });

  final int minMatchedWords;
  final double lightAtOrAbove;
  final double heavyAtOrBelow;
  final Set<String> negations;
  final int negationWindow;
  final double negationFactor;
  final Set<String> intensifiers;
  final double intensifierFactor;

  /// "light" -> "Light" and so on.
  final Map<String, String> labels;

  /// The line on the Saved screen for "light", "mixed", "heavy" and "none".
  final Map<String, String> savedLines;

  /// Word -> weight from -2 (very heavy) to +2 (very light).
  final Map<String, double> lexicon;

  factory JournalToneSettings.fromMap(Map<String, dynamic> map) {
    final Object? lexicon = map['lexicon'];
    if (lexicon is! Map) {
      throw const FormatException('The tone settings need a "lexicon".');
    }
    return JournalToneSettings(
      minMatchedWords: _number(map, 'minMatchedWords', 2).round(),
      lightAtOrAbove: _number(map, 'lightAtOrAbove', 0.5),
      heavyAtOrBelow: _number(map, 'heavyAtOrBelow', -0.5),
      negations: Set<String>.unmodifiable(_stringList(map['negations'])),
      negationWindow: _number(map, 'negationWindow', 2).round(),
      negationFactor: _number(map, 'negationFactor', -0.8),
      intensifiers: Set<String>.unmodifiable(_stringList(map['intensifiers'])),
      intensifierFactor: _number(map, 'intensifierFactor', 1.5),
      labels: _stringMap(map['labels']),
      savedLines: _stringMap(map['savedLines']),
      lexicon: Map<String, double>.unmodifiable(<String, double>{
        for (final MapEntry<dynamic, dynamic> entry in lexicon.entries)
          if (entry.value is num)
            entry.key.toString().toLowerCase(): (entry.value as num).toDouble(),
      }),
    );
  }
}

/// The wording on the support card.
class JournalSupportCard {
  const JournalSupportCard({
    required this.title,
    required this.body,
    required this.primary,
    required this.footnote,
    required this.secondary,
    required this.tertiary,
  });

  final String title;
  final String body;
  final String primary;
  final String footnote;
  final String secondary;
  final String tertiary;

  factory JournalSupportCard.fromMap(Map<String, dynamic> map) {
    return JournalSupportCard(
      title: _requiredString(map, 'title'),
      body: _requiredString(map, 'body'),
      primary: _requiredString(map, 'primary'),
      footnote: _requiredString(map, 'footnote'),
      secondary: _requiredString(map, 'secondary'),
      tertiary: _requiredString(map, 'tertiary'),
    );
  }
}

/// Which practice the Saved screen suggests for each tone. A null id means no
/// suggestion.
class JournalPracticeSuggestions {
  const JournalPracticeSuggestions({
    this.heavy,
    this.mixedFrom17,
    this.mixed,
    this.light,
  });

  final String? heavy;
  final String? mixedFrom17;
  final String? mixed;
  final String? light;

  factory JournalPracticeSuggestions.fromMap(Map<String, dynamic> map) {
    String? id(String key) {
      final Object? value = map[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    return JournalPracticeSuggestions(
      heavy: id('heavy'),
      mixedFrom17: id('mixedFrom17'),
      mixed: id('mixed'),
      light: id('light'),
    );
  }
}

/// Everything in `assets/journal/journal_content.json`.
class JournalContent {
  const JournalContent({
    required this.templates,
    required this.prompts,
    required this.tone,
    required this.topics,
    required this.supportPhrases,
    required this.supportCard,
    required this.practiceSuggestions,
  });

  static const String assetPath = 'assets/journal/journal_content.json';

  final List<JournalTemplate> templates;
  final List<JournalPrompt> prompts;
  final JournalToneSettings tone;

  /// Topic name (e.g. "Night shift") -> its keywords, in file order.
  final Map<String, List<String>> topics;
  final List<String> supportPhrases;
  final JournalSupportCard supportCard;
  final JournalPracticeSuggestions practiceSuggestions;

  /// The template for [type], falling back to Free write.
  JournalTemplate templateFor(String type) {
    for (final JournalTemplate template in templates) {
      if (template.id == type) {
        return template;
      }
    }
    for (final JournalTemplate template in templates) {
      if (template.id == JournalTypes.free) {
        return template;
      }
    }
    return templates.first;
  }

  /// Parses the content file. Throws a [FormatException] if it is not valid.
  factory JournalContent.fromJson(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The journal file is not a JSON object.');
    }
    final Object? templates = decoded['templates'];
    final Object? prompts = decoded['prompts'];
    final Object? tone = decoded['tone'];
    final Object? topics = decoded['topics'];
    final Object? support = decoded['support'];
    if (templates is! List ||
        templates.isEmpty ||
        prompts is! List ||
        prompts.isEmpty ||
        tone is! Map ||
        topics is! Map ||
        support is! Map) {
      throw const FormatException(
        'The journal file needs templates, prompts, tone, topics and support.',
      );
    }
    final Map<String, dynamic> supportMap = support.cast<String, dynamic>();
    final Object? card = supportMap['card'];
    if (card is! Map) {
      throw const FormatException('The journal file needs a support card.');
    }
    final Object? practices = decoded['practiceSuggestions'];

    return JournalContent(
      templates: List<JournalTemplate>.unmodifiable(
        templates.map(
          (Object? t) =>
              JournalTemplate.fromMap((t as Map).cast<String, dynamic>()),
        ),
      ),
      prompts: List<JournalPrompt>.unmodifiable(
        prompts.map(
          (Object? p) =>
              JournalPrompt.fromMap((p as Map).cast<String, dynamic>()),
        ),
      ),
      tone: JournalToneSettings.fromMap(tone.cast<String, dynamic>()),
      topics: Map<String, List<String>>.unmodifiable(<String, List<String>>{
        for (final MapEntry<dynamic, dynamic> entry in topics.entries)
          entry.key.toString(): List<String>.unmodifiable(
            _stringList(entry.value).map((String w) => w.toLowerCase()),
          ),
      }),
      supportPhrases: List<String>.unmodifiable(
        _stringList(supportMap['phrases']),
      ),
      supportCard: JournalSupportCard.fromMap(card.cast<String, dynamic>()),
      practiceSuggestions: practices is Map
          ? JournalPracticeSuggestions.fromMap(
              practices.cast<String, dynamic>(),
            )
          : const JournalPracticeSuggestions(),
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing "$key" in the journal file.');
  }
  return value;
}

String _optionalString(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  return value is String ? value : '';
}

double _number(Map<String, dynamic> map, String key, double fallback) {
  final Object? value = map[key];
  return value is num ? value.toDouble() : fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .whereType<String>()
      .where((String s) => s.trim().isNotEmpty)
      .toList(growable: false);
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  return Map<String, String>.unmodifiable(<String, String>{
    for (final MapEntry<dynamic, dynamic> entry in value.entries)
      if (entry.value is String) entry.key.toString(): entry.value as String,
  });
}
