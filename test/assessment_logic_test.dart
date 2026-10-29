import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/assessment_definition.dart';
import 'package:mindmate/Models/assessment_result.dart';
import 'package:mindmate/Models/assessment_rules.dart';
import 'package:mindmate/Models/assessment_scorer.dart';

AssessmentContent loadContent() => AssessmentContent.fromJson(
  File('assets/assessments/assessments_content.json').readAsStringSync(),
);

void main() {
  final AssessmentContent content = loadContent();
  AssessmentDefinition def(String id) => content.byId(id)!;

  List<int> lowest(AssessmentDefinition d) =>
      d.items.map((AssessmentItem i) => i.minValue).toList();
  List<int> highest(AssessmentDefinition d) =>
      d.items.map((AssessmentItem i) => i.maxValue).toList();

  /// Answers whose scored value (after reversing) is the lowest / highest.
  List<int> scoredAt(AssessmentDefinition d, {required bool high}) => d.items
      .map((AssessmentItem i) => (high != i.reverse) ? i.maxValue : i.minValue)
      .toList();

  AssessmentScore score(String id, List<int> answers) =>
      AssessmentScorer.score(def(id), answers);

  group('The content file', () {
    test('parses all seven questionnaires with the right item counts', () {
      expect(
        <String, int>{
          for (final AssessmentDefinition d in content.assessments)
            d.id: d.items.length,
        },
        <String, int>{
          'phq4': 4,
          'phq9': 9,
          'gad7': 7,
          'cbi': 19,
          'pss10': 10,
          'who5': 5,
          'workplace': 15,
        },
      );
      expect(content.hubGroups, hasLength(3));
      expect(content.suggestOrder.first, 'phq4');
      expect(content.item9.continueLabel, "I'm safe, continue");
    });

    test('CBI items take their answer set from the file', () {
      final AssessmentDefinition cbi = def('cbi');
      expect(cbi.items[0].options.first.label, 'Always');
      expect(cbi.items[6].options.first.label, 'To a very high degree');
      expect(cbi.items[9].options.first.label, 'Always');
      expect(cbi.items[16].options.first.label, 'To a very high degree');
      expect(cbi.items[12].reverse, isTrue);
      expect(cbi.hasTotal, isFalse);
    });

    test('PHQ-9 marks question 9 and has the difficulty question', () {
      final AssessmentDefinition phq = def('phq9');
      expect(phq.items[8].safety, isTrue);
      expect(phq.items.where((AssessmentItem i) => i.safety), hasLength(1));
      expect(phq.extraItem?.id, 'difficulty');
    });

    test('the workplace areas and reversed items match the old screen', () {
      final AssessmentDefinition w = def('workplace');
      int count(String area) =>
          w.items.where((AssessmentItem i) => i.area == area).length;
      expect(count('workload'), 4);
      expect(count('shifts'), 3);
      expect(count('emotional'), 3);
      expect(count('team'), 3);
      expect(count('resources'), 2);
      expect(
        w.items.where((AssessmentItem i) => i.reverse).map((i) => i.n),
        <int>[4, 8, 9],
      );
      expect(w.lowerIsBetter, isFalse);
    });

    test('every practice id exists in the meditation file', () {
      final String practices = File(
        'assets/meditation/meditation_sessions.json',
      ).readAsStringSync();
      for (final AssessmentDefinition d in content.assessments) {
        final String? id = d.practice?.practiceId;
        if (id != null) {
          expect(practices, contains('"id": "$id"'), reason: d.id);
        }
      }
    });
  });

  group('Scoring', () {
    test('PHQ-9 and GAD-7 sum from 0 to their maximum', () {
      expect(score('phq9', lowest(def('phq9'))).total, 0);
      expect(score('phq9', highest(def('phq9'))).total, 27);
      expect(score('gad7', lowest(def('gad7'))).total, 0);
      expect(score('gad7', highest(def('gad7'))).total, 21);
      expect(score('phq9', highest(def('phq9'))).bandId, 'severe');
    });

    test('PSS-10 reverses items 4, 5, 7 and 8', () {
      // All "Never": the 4 reversed items count 4 each.
      expect(score('pss10', lowest(def('pss10'))).total, 16);
      // All "Very often": the 6 others count 4 each.
      expect(score('pss10', highest(def('pss10'))).total, 24);
      expect(score('pss10', scoredAt(def('pss10'), high: false)).total, 0);
      expect(score('pss10', scoredAt(def('pss10'), high: true)).total, 40);
      // Only item 4 answered "Very often": reversed to 0.
      final List<int> answers = List<int>.filled(10, 0);
      answers[3] = 4;
      expect(score('pss10', answers).total, 12);
    });

    test('WHO-5 is raw x 4, higher is better', () {
      final AssessmentScore zero = score('who5', lowest(def('who5')));
      expect(zero.rawTotal, 0);
      expect(zero.total, 0);
      expect(zero.bandId, 'very_low');
      final AssessmentScore top = score('who5', highest(def('who5')));
      expect(top.rawTotal, 25);
      expect(top.total, 100);
      expect(top.bandId, 'good');
      expect(score('who5', <int>[2, 2, 1, 1, 1]).total, 28);
      expect(score('who5', <int>[3, 3, 3, 2, 2]).total, 52);
    });

    test('WHO-5 ranges at 28, 50 and 52', () {
      final List<AssessmentBand> bands = def('who5').bands;
      expect(AssessmentScorer.bandFor(bands, 28)?.id, 'very_low');
      expect(AssessmentScorer.bandFor(bands, 50)?.id, 'low');
      expect(AssessmentScorer.bandFor(bands, 52)?.id, 'good');
    });

    test('CBI scores each area as a mean, reverses item 13, no total', () {
      final AssessmentScore zero = score('cbi', lowest(def('cbi')));
      expect(zero.total, isNull);
      expect(zero.bandId, isNull);
      expect(zero.areas!['personal'], 0);
      expect(zero.areas!['patients'], 0);
      // Item 13 answered "Never" counts 100.
      expect(zero.areas!['work'], closeTo(100 / 7, 0.001));
      final AssessmentScore top = score('cbi', highest(def('cbi')));
      expect(top.areas!['personal'], 100);
      expect(top.areas!['work'], closeTo(600 / 7, 0.001));
      expect(top.areaBands!['personal'], 'severe');
      expect(top.areaBands!['work'], 'high');
      expect(top.highestArea, anyOf('personal', 'patients'));
    });

    test('workplace areas reach 0% and 100%', () {
      final AssessmentScore bottom = score(
        'workplace',
        scoredAt(def('workplace'), high: false),
      );
      expect(bottom.total, 0);
      expect(bottom.areas!.values, everyElement(0));
      expect(bottom.bandId, 'needs_significant_attention');
      final AssessmentScore top = score(
        'workplace',
        scoredAt(def('workplace'), high: true),
      );
      expect(top.total, 100);
      expect(top.areas!.values, everyElement(100));
      expect(top.bandId, 'very_positive');
      // All "Neutral" is the middle.
      expect(score('workplace', List<int>.filled(15, 3)).total, 50);
    });

    test('PHQ-9 range edges', () {
      final List<AssessmentBand> bands = def('phq9').bands;
      String? at(int v) => AssessmentScorer.bandFor(bands, v)?.id;
      expect(at(4), 'minimal');
      expect(at(5), 'mild');
      expect(at(9), 'mild');
      expect(at(10), 'moderate');
      expect(at(14), 'moderate');
      expect(at(15), 'moderately_severe');
      expect(at(19), 'moderately_severe');
      expect(at(20), 'severe');
    });

    test('a CBI area between two ranges falls into the higher one', () {
      expect(AssessmentScorer.bandFor(def('cbi').bands, 49.995)?.id, 'low');
      expect(AssessmentScorer.bandFor(def('cbi').bands, 50)?.id, 'moderate');
    });

    test('question 9 is positive when answered above 0', () {
      final List<int> answers = List<int>.filled(9, 0);
      expect(score('phq9', answers).item9Positive, isFalse);
      answers[8] = 1;
      expect(score('phq9', answers).item9Positive, isTrue);
      expect(score('phq9', answers).bandId, 'minimal');
    });
  });

  group('Next steps and practices', () {
    test('the first matching next step wins', () {
      final AssessmentDefinition phq = def('phq9');
      AssessmentScore total(int t) => AssessmentScore(
        total: t.toDouble(),
        rawTotal: null,
        bandId: null,
        areas: null,
        areaBands: null,
        item9Positive: false,
      );
      expect(AssessmentScorer.nextStep(phq, total(9)), isNull);
      expect(AssessmentScorer.nextStep(phq, total(11)), contains('10 or more'));
      expect(AssessmentScorer.nextStep(phq, total(22)), contains('soon'));
      expect(AssessmentScorer.practiceId(phq, total(9)), isNull);
      expect(
        AssessmentScorer.practiceId(phq, total(10)),
        'self_compassion_break',
      );
      final AssessmentDefinition who = def('who5');
      expect(AssessmentScorer.nextStep(who, total(28)), contains('soon'));
      expect(
        AssessmentScorer.nextStep(who, total(48)),
        contains('50 or below'),
      );
      expect(AssessmentScorer.nextStep(who, total(52)), isNull);
    });

    test('CBI next step and practice look at any area', () {
      final AssessmentDefinition cbi = def('cbi');
      final AssessmentScore s = AssessmentScorer.score(
        cbi,
        lowest(cbi)
          ..[6] = 100
          ..[7] = 100
          ..[8] = 100
          ..[9] = 100
          ..[10] = 100,
      );
      expect(s.areas!['work'], greaterThanOrEqualTo(75));
      expect(AssessmentScorer.nextStep(cbi, s), contains('burnout'));
      expect(AssessmentScorer.practiceId(cbi, s), 'leaving_work');
    });
  });

  group('The flow', () {
    final AssessmentItem item9 = def('phq9').items[8];
    final AssessmentItem item1 = def('phq9').items[0];

    test('question 9 support shows above 0, once per attempt', () {
      expect(AssessmentFlowRules.shouldShowSafety(item9, 0, false), isFalse);
      expect(AssessmentFlowRules.shouldShowSafety(item9, 1, false), isTrue);
      expect(AssessmentFlowRules.shouldShowSafety(item9, 3, false), isTrue);
      expect(AssessmentFlowRules.shouldShowSafety(item9, 2, true), isFalse);
      expect(AssessmentFlowRules.shouldShowSafety(item1, 3, false), isFalse);
    });

    test('the difficulty question shows only if any item is above 0', () {
      final AssessmentDefinition phq = def('phq9');
      expect(
        AssessmentFlowRules.showsExtra(phq, List<int?>.filled(9, 0)),
        isFalse,
      );
      expect(
        AssessmentFlowRules.showsExtra(phq, List<int?>.filled(9, 0)..[4] = 1),
        isTrue,
      );
      expect(
        AssessmentFlowRules.showsExtra(def('gad7'), List<int?>.filled(7, 3)),
        isFalse,
      );
    });
  });

  group('The hub suggestion', () {
    AssessmentResult taken(String id, DateTime at) => AssessmentResult(
      assessmentId: id,
      contentVersion: 1,
      answers: const <int>[],
      total: 1,
      bandId: null,
      startedAt: at,
      completedAt: at,
    );
    final DateTime now = DateTime(2026, 10, 8, 12);

    test('the first never-taken one in suggestOrder', () {
      final AssessmentSuggestion? s = AssessmentSuggestion.pick(
        all: content.assessments,
        order: content.suggestOrder,
        latest: <String, AssessmentResult>{
          'phq4': taken('phq4', now),
          'cbi': taken('cbi', now),
        },
        now: now,
      );
      expect(s?.def.id, 'phq9');
      expect(s?.neverTaken, isTrue);
    });

    test('then the most overdue one', () {
      final Map<String, AssessmentResult> latest = <String, AssessmentResult>{
        for (final AssessmentDefinition d in content.assessments)
          d.id: taken(d.id, now.subtract(const Duration(days: 1))),
      };
      latest['gad7'] = taken('gad7', DateTime(2026, 9, 1)); // 23 days late
      latest['pss10'] = taken('pss10', DateTime(2026, 8, 1)); // 38 days late
      final AssessmentSuggestion? s = AssessmentSuggestion.pick(
        all: content.assessments,
        order: content.suggestOrder,
        latest: latest,
        now: now,
      );
      expect(s?.def.id, 'pss10');
      expect(s?.lastTaken, DateTime(2026, 8, 1));
    });

    test('nothing when all are up to date', () {
      final AssessmentSuggestion? s = AssessmentSuggestion.pick(
        all: content.assessments,
        order: content.suggestOrder,
        latest: <String, AssessmentResult>{
          for (final AssessmentDefinition d in content.assessments)
            d.id: taken(d.id, now),
        },
        now: now,
      );
      expect(s, isNull);
    });
  });

  group('Change and dates', () {
    AssessmentResult phq(double total, DateTime at) => AssessmentResult(
      assessmentId: 'phq9',
      contentVersion: 1,
      answers: const <int>[],
      total: total,
      bandId: null,
      startedAt: at,
      completedAt: at,
    );

    test('the change since the previous result', () {
      final AssessmentResult now = phq(11, DateTime(2026, 10, 8));
      final AssessmentResult before = phq(14, DateTime(2026, 9, 24));
      expect(AssessmentMath.change(now, before), -3);
      expect(AssessmentMath.change(before, now), 3);
      expect(AssessmentMath.change(now, null), isNull);
      expect(
        AssessmentMath.changeLabel(-3, before.completedAt),
        '3 since 24 Sep',
      );
      expect(
        AssessmentMath.changeLabel(0, before.completedAt),
        'No change since 24 Sep',
      );
    });

    test('the CBI change uses the highest area', () {
      AssessmentResult cbi(double work) => AssessmentResult(
        assessmentId: 'cbi',
        contentVersion: 1,
        answers: const <int>[],
        total: null,
        bandId: null,
        areas: <String, double>{'work': work, 'personal': 40, 'patients': 10},
        areaBands: const <String, String>{},
        startedAt: DateTime(2026, 10, 8),
        completedAt: DateTime(2026, 10, 8),
      );
      expect(AssessmentMath.change(cbi(68), cbi(60)), 8);
    });

    test('next suggested line', () {
      final AssessmentDefinition phq = def('phq9');
      expect(
        AssessmentMath.nextSuggestedLine(
          phq,
          DateTime(2026, 10, 8, 9),
          DateTime(2026, 10, 8, 20),
        ),
        'Next suggested: in 14 days, around 22 Oct',
      );
      expect(
        AssessmentMath.nextSuggestedLine(
          phq,
          DateTime(2026, 9, 1),
          DateTime(2026, 10, 8),
        ),
        'Good time for another look',
      );
    });

    test('range tones: best gold, heavy blue, the rest light blue', () {
      final AssessmentDefinition phq = def('phq9');
      expect(AssessmentMath.toneFor(phq, 'minimal'), RangeTone.best);
      expect(AssessmentMath.toneFor(phq, 'moderate'), RangeTone.middle);
      expect(AssessmentMath.toneFor(phq, 'severe'), RangeTone.heavy);
      expect(AssessmentMath.toneFor(def('who5'), 'good'), RangeTone.best);
      expect(AssessmentMath.toneFor(def('who5'), 'very_low'), RangeTone.heavy);
      expect(
        AssessmentMath.toneFor(def('workplace'), 'very_positive'),
        RangeTone.best,
      );
    });
  });

  group('The stored result', () {
    test('survives toMap and fromMap, with no total for the CBI', () {
      final AssessmentDefinition cbi = def('cbi');
      final AssessmentResult r = AssessmentResult.fromAttempt(
        def: cbi,
        contentVersion: 1,
        answers: highest(cbi),
        startedAt: DateTime(2026, 10, 8, 9),
        completedAt: DateTime(2026, 10, 8, 9, 4),
      );
      final AssessmentResult back = AssessmentResult.fromMap(r.toMap());
      expect(back.total, isNull);
      expect(back.answers, highest(cbi));
      expect(back.areas!['personal'], 100);
      expect(back.headlineBandId, 'severe');
      expect(back.completedAt, DateTime(2026, 10, 8, 9, 4));
    });
  });
}
