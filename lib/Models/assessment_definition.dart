import 'dart:convert';

import 'programme_schedule.dart';

/// One answer choice and the value it scores.
class AnswerOption {
  const AnswerOption({required this.label, required this.value});

  final String label;
  final int value;

  factory AnswerOption.fromMap(Map<String, dynamic> map) {
    return AnswerOption(
      label: _requiredString(map, 'label'),
      value: _requiredInt(map, 'value'),
    );
  }
}

/// One question. Its answer choices come from the content file: the item's
/// own `answerSet`, or the questionnaire's.
class AssessmentItem {
  const AssessmentItem({
    required this.n,
    required this.text,
    required this.options,
    this.area,
    this.reverse = false,
    this.safety = false,
    this.part,
  });

  /// 1-based item number.
  final int n;
  final String text;
  final List<AnswerOption> options;

  /// The area this item counts towards (CBI and workplace).
  final String? area;

  /// The short scale inside a longer one: `phq2` or `gad2` in the PHQ-4.
  final String? part;

  /// Scored as (lowest + highest value) minus the answer.
  final bool reverse;

  /// PHQ-9 item 9: any answer above the lowest shows the support screen.
  final bool safety;

  int get minValue => options.map((AnswerOption o) => o.value).reduce(_min);

  int get maxValue => options.map((AnswerOption o) => o.value).reduce(_max);

  /// The value that counts towards the score.
  int scored(int answer) => reverse ? minValue + maxValue - answer : answer;

  String? labelFor(int? value) {
    for (final AnswerOption o in options) {
      if (o.value == value) {
        return o.label;
      }
    }
    return null;
  }
}

/// A question asked at the end that is not scored (PHQ-9's difficulty
/// question).
class ExtraItem {
  const ExtraItem({
    required this.id,
    required this.text,
    required this.options,
    required this.showIfAnyAbove,
  });

  final String id;
  final String text;
  final List<AnswerOption> options;

  /// Asked only if some scored answer is above this value.
  final int showIfAnyAbove;

  String? labelFor(int? value) {
    for (final AnswerOption o in options) {
      if (o.value == value) {
        return o.label;
      }
    }
    return null;
  }
}

/// A named range of scores.
class AssessmentBand {
  const AssessmentBand({
    required this.id,
    required this.label,
    required this.min,
    required this.max,
    this.line,
  });

  final String id;
  final String label;

  /// Inclusive.
  final double min;

  /// Inclusive.
  final double max;
  final String? line;

  bool contains(num value) => value >= min && value <= max;

  factory AssessmentBand.fromMap(Map<String, dynamic> map) {
    return AssessmentBand(
      id: _requiredString(map, 'id'),
      label: _requiredString(map, 'label'),
      min: _requiredNum(map, 'min').toDouble(),
      max: _requiredNum(map, 'max').toDouble(),
      line: _optionalString(map, 'line'),
    );
  }
}

/// One area of the CBI or the workplace questionnaire.
class AssessmentArea {
  const AssessmentArea({required this.id, required this.label, this.sub});

  final String id;
  final String label;
  final String? sub;

  factory AssessmentArea.fromMap(Map<String, dynamic> map) {
    return AssessmentArea(
      id: _requiredString(map, 'id'),
      label: _requiredString(map, 'label'),
      sub: _optionalString(map, 'sub'),
    );
  }
}

/// A condition on the score: `from` (total at least), `upTo` (total at
/// most) or `anyAreaFrom` (some area at least).
class ScoreCondition {
  const ScoreCondition({this.from, this.upTo, this.anyAreaFrom});

  final double? from;
  final double? upTo;
  final double? anyAreaFrom;

  factory ScoreCondition.fromMap(Map<String, dynamic> map) {
    return ScoreCondition(
      from: (map['from'] as num?)?.toDouble(),
      upTo: (map['upTo'] as num?)?.toDouble(),
      anyAreaFrom: (map['anyAreaFrom'] as num?)?.toDouble(),
    );
  }

  bool matches(num? total, Map<String, double>? areas) {
    if (from != null && (total == null || total < from!)) {
      return false;
    }
    if (upTo != null && (total == null || total > upTo!)) {
      return false;
    }
    if (anyAreaFrom != null &&
        (areas == null || !areas.values.any((double v) => v >= anyAreaFrom!))) {
      return false;
    }
    return from != null || upTo != null || anyAreaFrom != null;
  }
}

/// A next-step line shown on the result when its condition matches.
class NextStep {
  const NextStep({required this.when, required this.text});

  final ScoreCondition when;
  final String text;
}

/// A practice suggested on the result when its condition matches.
class PracticeRule {
  const PracticeRule({required this.when, required this.practiceId});

  final ScoreCondition when;
  final String practiceId;
}

/// A fuller check-in suggested on the result, when the answers to one part
/// add up to [from] or more (PHQ-4: PHQ-2 suggests PHQ-9, GAD-2 GAD-7).
class FollowUpRule {
  const FollowUpRule({
    required this.part,
    required this.from,
    required this.assessmentId,
    required this.text,
  });

  final String part;
  final int from;
  final String assessmentId;
  final String text;

  factory FollowUpRule.fromMap(Map<String, dynamic> map) {
    return FollowUpRule(
      part: _requiredString(map, 'part'),
      from: _requiredInt(map, 'from'),
      assessmentId: _requiredString(map, 'assessmentId'),
      text: _requiredString(map, 'text'),
    );
  }
}

enum ScoringMethod { sum, sumTimes4, areaMean, areaPercent }

/// One questionnaire, from the content file.
class AssessmentDefinition {
  const AssessmentDefinition({
    required this.id,
    required this.name,
    required this.scale,
    required this.group,
    required this.icon,
    required this.minutes,
    required this.retakeDays,
    required this.lowerIsBetter,
    required this.intro,
    required this.about,
    required this.stem,
    required this.items,
    required this.extraItem,
    required this.method,
    required this.max,
    required this.rawMax,
    required this.areas,
    required this.bands,
    required this.heavyBands,
    required this.bandsNote,
    required this.topLines,
    required this.nextSteps,
    required this.practice,
    this.followUps = const <FollowUpRule>[],
  });

  final String id;
  final String name;
  final String scale;
  final String group;
  final String icon;
  final int minutes;
  final int retakeDays;
  final bool lowerIsBetter;
  final String intro;
  final String about;
  final String? stem;
  final List<AssessmentItem> items;
  final ExtraItem? extraItem;
  final ScoringMethod method;

  /// The highest `total`: 27 for PHQ-9, 100 for WHO-5 and the areas.
  final double max;

  /// WHO-5's raw maximum (25).
  final int? rawMax;
  final List<AssessmentArea> areas;
  final List<AssessmentBand> bands;

  /// Ranges shown on the blue blend with white text.
  final Set<String> heavyBands;
  final String? bandsNote;
  final Map<String, String> topLines;
  final List<NextStep> nextSteps;
  final PracticeRule? practice;
  final List<FollowUpRule> followUps;

  bool get hasAreas =>
      method == ScoringMethod.areaMean || method == ScoringMethod.areaPercent;

  /// True for the CBI, which has area scores but no total.
  bool get hasTotal => method != ScoringMethod.areaMean;

  /// "Burnout check", or the name itself when it already reads as a title
  /// ("Your workplace", "3-day check").
  String get checkTitle =>
      name.startsWith('Your ') || name.toLowerCase().endsWith('check')
      ? name
      : '$name check';

  /// "about 1 minute", "about 4 minutes".
  String get aboutMinutes =>
      minutes == 1 ? 'about 1 minute' : 'about $minutes minutes';

  /// The follow-ups whose part adds up to their threshold, in file order.
  /// [answers] are the raw values in item order.
  List<FollowUpRule> followUpsFor(List<int> answers) {
    return <FollowUpRule>[
      for (final FollowUpRule rule in followUps)
        if (_partSum(rule.part, answers) >= rule.from) rule,
    ];
  }

  int _partSum(String part, List<int> answers) {
    int sum = 0;
    for (int i = 0; i < items.length && i < answers.length; i += 1) {
      if (items[i].part == part) {
        sum += answers[i];
      }
    }
    return sum;
  }

  /// The best range: the lowest when lower is better, else the highest.
  AssessmentBand get bestBand => lowerIsBetter ? bands.first : bands.last;

  AssessmentBand? bandById(String? id) {
    for (final AssessmentBand b in bands) {
      if (b.id == id) {
        return b;
      }
    }
    return null;
  }

  AssessmentArea? areaById(String id) {
    for (final AssessmentArea a in areas) {
      if (a.id == id) {
        return a;
      }
    }
    return null;
  }

  factory AssessmentDefinition.fromMap(
    Map<String, dynamic> map,
    Map<String, List<AnswerOption>> answerSets,
  ) {
    final String id = _requiredString(map, 'id');
    List<AnswerOption> setFor(Object? name) {
      final List<AnswerOption>? set = answerSets[name];
      if (set == null || set.isEmpty) {
        throw FormatException('"$id" uses an unknown answer set "$name".');
      }
      return set;
    }

    final Object? rawItems = map['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw FormatException('"$id" has no items.');
    }
    final List<AssessmentItem> items = rawItems
        .map((Object? raw) {
          final Map<String, dynamic> item = (raw as Map)
              .cast<String, dynamic>();
          return AssessmentItem(
            n: _requiredInt(item, 'n'),
            text: _requiredString(item, 'text'),
            options: setFor(item['answerSet'] ?? map['answerSet']),
            area: _optionalString(item, 'area'),
            reverse: item['reverse'] == true,
            safety: item['safety'] == true,
            part: _optionalString(item, 'part'),
          );
        })
        .toList(growable: false);

    final Object? extra = map['extraItem'];
    final Map<String, dynamic> scoring = (map['scoring'] as Map? ?? const {})
        .cast<String, dynamic>();
    final Object? rawBands = map['bands'];
    if (rawBands is! List || rawBands.isEmpty) {
      throw FormatException('"$id" has no bands.');
    }
    final Object? practice = map['practice'];

    return AssessmentDefinition(
      id: id,
      name: _requiredString(map, 'name'),
      scale: _requiredString(map, 'scale'),
      group: _requiredString(map, 'group'),
      icon: _optionalString(map, 'icon') ?? 'cloud',
      minutes: _requiredInt(map, 'minutes'),
      retakeDays: _requiredInt(map, 'retakeDays'),
      lowerIsBetter: map['lowerIsBetter'] != false,
      intro: _requiredString(map, 'intro'),
      about: _requiredString(map, 'about'),
      stem: _optionalString(map, 'stem'),
      items: List<AssessmentItem>.unmodifiable(items),
      extraItem: extra is Map
          ? ExtraItem(
              id: _requiredString(extra.cast<String, dynamic>(), 'id'),
              text: _requiredString(extra.cast<String, dynamic>(), 'text'),
              options: setFor(extra['answerSet']),
              showIfAnyAbove: (extra['showIfAnyAbove'] as num? ?? 0).toInt(),
            )
          : null,
      method: _method(scoring['method'], id),
      max: (scoring['max'] as num? ?? 100).toDouble(),
      rawMax: (scoring['rawMax'] as num?)?.toInt(),
      areas: List<AssessmentArea>.unmodifiable(
        (scoring['areas'] as List? ?? const <Object>[]).map(
          (Object? a) => AssessmentArea.fromMap((a as Map).cast()),
        ),
      ),
      bands: List<AssessmentBand>.unmodifiable(
        rawBands.map((Object? b) => AssessmentBand.fromMap((b as Map).cast())),
      ),
      heavyBands: Set<String>.unmodifiable(
        (map['heavyBands'] as List? ?? const <Object>[]).whereType<String>(),
      ),
      bandsNote: _optionalString(map, 'bandsNote'),
      topLines: Map<String, String>.unmodifiable(
        (map['topLines'] as Map? ?? const <String, String>{}).map(
          (dynamic k, dynamic v) => MapEntry<String, String>('$k', '$v'),
        ),
      ),
      nextSteps: List<NextStep>.unmodifiable(
        (map['nextSteps'] as List? ?? const <Object>[]).map((Object? s) {
          final Map<String, dynamic> step = (s as Map).cast();
          return NextStep(
            when: ScoreCondition.fromMap(step),
            text: _requiredString(step, 'text'),
          );
        }),
      ),
      practice: practice is Map
          ? PracticeRule(
              when: ScoreCondition.fromMap(practice.cast()),
              practiceId: _requiredString(practice.cast(), 'id'),
            )
          : null,
      followUps: List<FollowUpRule>.unmodifiable(
        (map['followUp'] as List? ?? const <Object>[]).map(
          (Object? f) => FollowUpRule.fromMap((f as Map).cast()),
        ),
      ),
    );
  }

  static ScoringMethod _method(Object? value, String id) {
    switch (value) {
      case 'sum':
        return ScoringMethod.sum;
      case 'sumTimes4':
        return ScoringMethod.sumTimes4;
      case 'areaMean':
        return ScoringMethod.areaMean;
      case 'areaPercent':
        return ScoringMethod.areaPercent;
    }
    throw FormatException('"$id" has an unknown scoring method "$value".');
  }
}

/// A group of questionnaires on the hub.
class AssessmentHubGroup {
  const AssessmentHubGroup({required this.id, required this.label});

  final String id;
  final String label;
}

/// The wording around PHQ-9 question 9.
class Item9Safety {
  const Item9Safety({
    required this.title,
    required this.body,
    required this.talkTitle,
    required this.talkSub,
    required this.trustTitle,
    required this.trustSub,
    required this.trustMessage,
    required this.footnote,
    required this.continueLabel,
    required this.stopLabel,
    required this.resultCard,
    required this.hubBanner,
  });

  final String title;
  final String body;
  final String talkTitle;
  final String talkSub;
  final String trustTitle;
  final String trustSub;

  /// The neutral message offered in the share sheet.
  final String trustMessage;
  final String footnote;
  final String continueLabel;
  final String stopLabel;
  final String resultCard;
  final String hubBanner;

  factory Item9Safety.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> talk = (map['talk'] as Map).cast();
    final Map<String, dynamic> trust = (map['trust'] as Map).cast();
    return Item9Safety(
      title: _requiredString(map, 'title'),
      body: _requiredString(map, 'body'),
      talkTitle: _requiredString(talk, 'title'),
      talkSub: _requiredString(talk, 'sub'),
      trustTitle: _requiredString(trust, 'title'),
      trustSub: _requiredString(trust, 'sub'),
      trustMessage:
          _optionalString(map, 'trustMessage') ??
          'Hi, are you free to talk today?',
      footnote: _requiredString(map, 'footnote'),
      continueLabel: _requiredString(map, 'continue'),
      stopLabel: _requiredString(map, 'stop'),
      resultCard: _requiredString(map, 'resultCard'),
      hubBanner: _requiredString(map, 'hubBanner'),
    );
  }
}

/// Everything in `assets/assessments/assessments_content.json`.
class AssessmentContent {
  const AssessmentContent({
    required this.version,
    required this.assessments,
    required this.hubGroups,
    required this.suggestOrder,
    required this.item9,
    required this.disclaimer,
    this.programme,
  });

  static const String assetPath = 'assets/assessments/assessments_content.json';

  final int version;
  final List<AssessmentDefinition> assessments;
  final List<AssessmentHubGroup> hubGroups;
  final List<String> suggestOrder;
  final Item9Safety item9;
  final String disclaimer;

  /// The hospital programme's required schedule, if the file has one.
  final ProgrammeConfig? programme;

  AssessmentDefinition? byId(String id) {
    for (final AssessmentDefinition a in assessments) {
      if (a.id == id) {
        return a;
      }
    }
    return null;
  }

  List<AssessmentDefinition> inGroup(String group) => assessments
      .where((AssessmentDefinition a) => a.group == group)
      .toList(growable: false);

  /// Parses the content file. Throws a [FormatException] if it is not valid.
  factory AssessmentContent.fromJson(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The check-in file is not a JSON object.');
    }
    final Object? sets = decoded['answerSets'];
    final Object? list = decoded['assessments'];
    final Object? safety = decoded['safety'];
    if (sets is! Map || list is! List || safety is! Map) {
      throw const FormatException(
        'The check-in file needs answerSets, assessments and safety.',
      );
    }
    final Map<String, List<AnswerOption>> answerSets =
        <String, List<AnswerOption>>{
          for (final MapEntry<dynamic, dynamic> e in sets.entries)
            if (e.value is List)
              '${e.key}': List<AnswerOption>.unmodifiable(
                (e.value as List).map(
                  (Object? o) => AnswerOption.fromMap((o as Map).cast()),
                ),
              ),
        };

    return AssessmentContent(
      version: (decoded['version'] as num? ?? 1).toInt(),
      assessments: List<AssessmentDefinition>.unmodifiable(
        list.map(
          (Object? a) =>
              AssessmentDefinition.fromMap((a as Map).cast(), answerSets),
        ),
      ),
      hubGroups: List<AssessmentHubGroup>.unmodifiable(
        (decoded['hubGroups'] as List? ?? const <Object>[]).map((Object? g) {
          final Map<String, dynamic> group = (g as Map).cast();
          return AssessmentHubGroup(
            id: _requiredString(group, 'id'),
            label: _requiredString(group, 'label'),
          );
        }),
      ),
      suggestOrder: List<String>.unmodifiable(
        (decoded['suggestOrder'] as List? ?? const <Object>[])
            .whereType<String>(),
      ),
      item9: Item9Safety.fromMap((safety['item9'] as Map).cast()),
      disclaimer: (decoded['disclaimer'] as String?) ?? '',
      programme: decoded['programme'] is Map
          ? ProgrammeConfig.fromMap((decoded['programme'] as Map).cast())
          : null,
    );
  }
}

int _min(int a, int b) => a < b ? a : b;

int _max(int a, int b) => a > b ? a : b;

String _requiredString(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing "$key" in the check-in file.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  return value is String && value.trim().isNotEmpty ? value : null;
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  if (value is! num) {
    throw FormatException('Missing "$key" in the check-in file.');
  }
  return value.toInt();
}

num _requiredNum(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  if (value is! num) {
    throw FormatException('Missing "$key" in the check-in file.');
  }
  return value;
}
