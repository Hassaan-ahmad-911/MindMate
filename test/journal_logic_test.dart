import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Data/repositories/journal_repository.dart';
import 'package:mindmate/Models/journal_content.dart';
import 'package:mindmate/Models/journal_model.dart';
import 'package:mindmate/Models/journal_rules.dart';
import 'package:mindmate/services/journal_safety_service.dart';
import 'package:mindmate/services/journal_tone_service.dart';

import 'helpers/journal_fakes.dart';

const String ward4Entry =
    'Two admissions back to back and a family who needed more time than I '
    'had. I felt rushed all night.\n\n'
    'I stayed calm with the family and explained the plan twice. Sara '
    'covered my break, so I said thank you.\n\n'
    'The feeling that I should have done more. I did what one person could '
    'do.';

void main() {
  final JournalContent content = loadJournalContent();
  final JournalToneService tone = JournalToneService.fromContent(content);
  final JournalSafetyService safety = JournalSafetyService.fromContent(content);

  group('The content file', () {
    test('has the four templates, prompts and suggestions', () {
      expect(content.templates.map((JournalTemplate t) => t.id), <String>[
        'after_shift',
        'moment',
        'let_it_out',
        'free',
      ]);
      expect(content.templateFor('after_shift').questions, hasLength(3));
      expect(content.templateFor('moment').questions, hasLength(4));
      expect(content.templateFor('let_it_out').saved, isFalse);
      expect(content.prompts, hasLength(20));
      expect(content.practiceSuggestions.heavy, 'self_compassion_break');
      expect(content.practiceSuggestions.light, isNull);
    });
  });

  group('Tone', () {
    JournalTone? toneOf(String text) => tone.analyse(text).tone;

    test('the Ward 4 entry is Mixed', () {
      expect(toneOf(ward4Entry), JournalTone.mixed);
    });

    test('a rest day entry is Light', () {
      expect(
        toneOf(
          'Slept in, walked to the market with Ammi, and did not check the '
          'ward group once. Felt rested and happy.',
        ),
        JournalTone.light,
      );
    });

    test('the handover entry is Heavy', () {
      expect(
        toneOf(
          'I keep replaying it. The handover went wrong, I was blamed and '
          'felt so guilty and exhausted.',
        ),
        JournalTone.heavy,
      );
    });

    test('"ok" is too short to read', () {
      final JournalAnalysis result = tone.analyse('ok');
      expect(result.tone, isNull);
      expect(result.toneScore, isNull);
    });

    test('negation flips both words in "not happy, not good"', () {
      final ToneScore score = JournalToneService.scoreTone(
        JournalToneService.tokenize('not happy, not good'),
        content.tone,
      );
      expect(score.tone, JournalTone.heavy);
      // happy 2 x -0.8 = -1.6, good 1 x -0.8 = -0.8.
      expect(score.score, closeTo(-1.2, 0.0001));
    });

    test('an intensifier strengthens the next word, within -2..2', () {
      final ToneScore score = JournalToneService.scoreTone(
        JournalToneService.tokenize('so tired, so guilty'),
        content.tone,
      );
      // tired -1 x 1.5 = -1.5; guilty -1.5 x 1.5 = -2.25, clamped to -2.
      expect(score.score, closeTo(-1.75, 0.0001));
    });

    test('curly apostrophes count as straight ones', () {
      expect(JournalToneService.tokenize('I didn’t sleep'), <String>[
        'i',
        "didn't",
        'sleep',
      ]);
    });
  });

  group('Topics', () {
    test('a keyword counts only as a whole word', () {
      expect(
        tone.analyse('The team was great. Teamwork helped.').topics,
        <String>['Team'],
      );
      expect(tone.analyse('Nightingale ward').topics, <String>['Patients']);
    });

    test('keeps the top 3 by number of hits', () {
      final List<String> topics = tone
          .analyse(
            'Night shift again, a long night. My team covered for me and '
            'the team lead was kind. Slept badly. Walked home. Family dinner.',
          )
          .topics;
      expect(topics, hasLength(3));
      expect(topics, <String>['Team', 'Night shift', 'Family']);
    });

    test('nothing found gives no topics', () {
      expect(tone.analyse('A quiet day.').topics, isEmpty);
    });
  });

  group('The support check', () {
    test('a matching phrase returns true', () {
      expect(safety.matchesSupport('Some days I want to die.'), isTrue);
      expect(safety.matchesSupport("I don't want to be here"), isTrue);
      expect(safety.matchesSupport('I dont want to be here'), isTrue);
    });

    test('a normal shift entry returns false', () {
      expect(safety.matchesSupport(ward4Entry), isFalse);
      expect(safety.matchesSupport('I attend it all week'), isFalse);
      expect(safety.matchesSupport(''), isFalse);
    });

    test('punctuation and capitals do not stop a match', () {
      expect(safety.matchesSupport('End. It. All'), isTrue);
      expect(safety.matchesSupport('thinking about SELF-HARM again'), isTrue);
    });
  });

  group('The prompt card', () {
    final List<JournalPrompt> prompts = content.prompts;

    test('the label follows the time of day', () {
      expect(
        JournalPromptPicker.label(DateTime(2026, 10, 8, 5)),
        "This morning's prompt",
      );
      expect(
        JournalPromptPicker.label(DateTime(2026, 10, 8, 11, 59)),
        "This morning's prompt",
      );
      expect(
        JournalPromptPicker.label(DateTime(2026, 10, 8, 12)),
        "Today's prompt",
      );
      expect(
        JournalPromptPicker.label(DateTime(2026, 10, 8, 17)),
        "Tonight's prompt",
      );
      expect(
        JournalPromptPicker.label(DateTime(2026, 10, 8, 4, 59)),
        "Tonight's prompt",
      );
    });

    test('prompts come from the right pool', () {
      for (final JournalPrompt p in JournalPromptPicker.pool(
        prompts,
        DateTime(2026, 10, 8, 8),
      )) {
        expect(<String>['morning', 'any'], contains(p.when));
      }
      for (final JournalPrompt p in JournalPromptPicker.pool(
        prompts,
        DateTime(2026, 10, 8, 14),
      )) {
        expect(p.when, 'any');
      }
      for (final JournalPrompt p in JournalPromptPicker.pool(
        prompts,
        DateTime(2026, 10, 8, 22),
      )) {
        expect(<String>['evening', 'any'], contains(p.when));
      }
    });

    test('the same prompt all day', () {
      final JournalPrompt early = JournalPromptPicker.today(
        prompts,
        DateTime(2026, 10, 8, 17),
      );
      final JournalPrompt late = JournalPromptPicker.today(
        prompts,
        DateTime(2026, 10, 8, 23, 59),
      );
      expect(late.text, early.text);
      final JournalPrompt morning = JournalPromptPicker.today(
        prompts,
        DateTime(2026, 10, 8, 6),
      );
      expect(
        JournalPromptPicker.today(prompts, DateTime(2026, 10, 8, 11)).text,
        morning.text,
      );
    });

    test('a different day can give a different prompt', () {
      final Set<String> seen = <String>{
        for (int d = 1; d <= 10; d += 1)
          JournalPromptPicker.today(prompts, DateTime(2026, 10, d, 21)).text,
      };
      expect(seen.length, greaterThan(1));
    });

    test('shuffle never shows the same prompt twice in a row', () {
      final DateTime now = DateTime(2026, 10, 8, 21);
      final Random random = Random(3);
      JournalPrompt current = JournalPromptPicker.today(prompts, now);
      for (int i = 0; i < 60; i += 1) {
        final JournalPrompt next = JournalPromptPicker.shuffle(
          prompts,
          now,
          current,
          random: random,
        );
        expect(next.text, isNot(current.text));
        expect(<String>['evening', 'any'], contains(next.when));
        current = next;
      }
    });
  });

  group('Dates', () {
    final DateTime now = DateTime(2026, 10, 8, 21, 45);

    test('Today, Yesterday, then short dates', () {
      expect(
        JournalDates.groupLabel(DateTime(2026, 10, 8, 0, 5), now),
        'Today',
      );
      expect(
        JournalDates.groupLabel(DateTime(2026, 10, 7, 23, 50), now),
        'Yesterday',
      );
      expect(
        JournalDates.groupLabel(DateTime(2026, 10, 5, 8), now),
        'Mon 5 Oct',
      );
    });

    test('entries are grouped in order under each label', () {
      final List<JournalDayGroup> groups = JournalDates.group(<JournalModel>[
        journalEntry(id: 'a', createdAt: DateTime(2026, 10, 8, 21, 40)),
        journalEntry(id: 'b', createdAt: DateTime(2026, 10, 8, 8)),
        journalEntry(id: 'c', createdAt: DateTime(2026, 10, 7, 18)),
        journalEntry(id: 'd', createdAt: DateTime(2026, 10, 5, 8)),
      ], now);
      expect(groups.map((JournalDayGroup g) => g.label), <String>[
        'Today',
        'Yesterday',
        'Mon 5 Oct',
      ]);
      expect(groups.first.entries.map((JournalModel e) => e.id), <String>[
        'a',
        'b',
      ]);
    });

    test('the long date on an entry', () {
      expect(
        JournalDates.longDateTime(DateTime(2026, 10, 8, 21, 40)),
        'Thursday 8 October · 21:40',
      );
    });

    test('"Edited" shows only after more than a minute', () {
      final DateTime created = DateTime(2026, 10, 8, 21, 40);
      expect(journalEntry(createdAt: created).wasEdited, isFalse);
      expect(
        journalEntry(
          createdAt: created,
          updatedAt: created.add(const Duration(seconds: 60)),
        ).wasEdited,
        isFalse,
      );
      expect(
        journalEntry(
          createdAt: created,
          updatedAt: created.add(const Duration(seconds: 61)),
        ).wasEdited,
        isTrue,
      );
    });

    test('weeks of the month', () {
      expect(JournalDates.weekOfMonth(DateTime(2026, 10, 1)), 1);
      expect(JournalDates.weekOfMonth(DateTime(2026, 10, 7)), 1);
      expect(JournalDates.weekOfMonth(DateTime(2026, 10, 8)), 2);
      expect(JournalDates.weekOfMonth(DateTime(2026, 10, 28)), 4);
      expect(JournalDates.weekOfMonth(DateTime(2026, 10, 29)), 5);
      expect(JournalDates.weeksInMonth(DateTime(2026, 10)), 5);
      expect(JournalDates.weeksInMonth(DateTime(2026, 2)), 4);
    });

    test('the default template follows the time of day', () {
      expect(
        JournalDefaults.templateFor(DateTime(2026, 10, 8, 17)),
        JournalTypes.afterShift,
      );
      expect(
        JournalDefaults.templateFor(DateTime(2026, 10, 8, 4, 59)),
        JournalTypes.afterShift,
      );
      expect(
        JournalDefaults.templateFor(DateTime(2026, 10, 8, 9)),
        JournalTypes.free,
      );
    });
  });

  group('Insights', () {
    JournalSummary summary(int day, JournalTone? tone, [List<String>? t]) {
      return JournalSummary.fromEntry(
        journalEntry(
          id: 'd$day-${tone?.id}',
          createdAt: DateTime(2026, 10, day, 21),
          tone: tone,
          topics: t ?? const <String>[],
        ),
      );
    }

    test('counts entries, days and tones per week', () {
      final JournalInsights insights = JournalInsights.from(<JournalSummary>[
        summary(2, JournalTone.heavy, <String>['Team']),
        summary(2, JournalTone.mixed, <String>['Team', 'Sleep']),
        summary(9, JournalTone.light, <String>['Team']),
        summary(10, JournalTone.mixed, <String>['Sleep']),
        summary(30, JournalTone.mixed),
        summary(30, null, <String>['Team']),
      ], DateTime(2026, 10));

      expect(insights.entryCount, 6);
      expect(insights.daysWritten, 4);
      expect(insights.mostCommonTone, JournalTone.mixed);
      expect(insights.weeks, hasLength(5));
      expect(insights.weeks[0].heavy, 1);
      expect(insights.weeks[0].mixed, 1);
      expect(insights.weeks[1].light, 1);
      expect(insights.weeks[1].mixed, 1);
      expect(insights.weeks[4].mixed, 1);
      expect(insights.weeks[4].total, 1, reason: 'no tone is not counted');
      expect(insights.topTopics.first.topic, 'Team');
      expect(insights.topTopics.first.count, 4);
      expect(insights.showPatterns, isTrue);
    });

    test('no tones gives no most common tone', () {
      final JournalInsights insights = JournalInsights.from(<JournalSummary>[
        summary(3, null),
      ], DateTime(2026, 10));
      expect(insights.mostCommonTone, isNull);
      expect(insights.showPatterns, isFalse);
    });

    test('the topic line needs 3 entries with one of this entry\'s topics', () {
      final JournalModel entry = journalEntry(topics: <String>['Team']);
      final List<JournalSummary> month = <JournalSummary>[
        summary(1, null, <String>['Team']),
        summary(2, null, <String>['Team']),
        summary(3, null, <String>['Sleep']),
      ];
      expect(JournalInsights.topicLineFor(entry, month), isNull);
      month.add(summary(4, null, <String>['Team']));
      expect(JournalInsights.topicLineFor(entry, month)?.count, 3);
      expect(JournalTopicWords.phrase('Team'), 'your team');
      expect(JournalTopicWords.phrase('Night shift'), 'night shifts');
    });

    test('the practice for each tone', () {
      final JournalPracticeSuggestions s = content.practiceSuggestions;
      final DateTime evening = DateTime(2026, 10, 8, 21);
      final DateTime noon = DateTime(2026, 10, 8, 12);
      expect(
        JournalPracticePicker.practiceFor(JournalTone.heavy, noon, s),
        'self_compassion_break',
      );
      expect(
        JournalPracticePicker.practiceFor(JournalTone.mixed, evening, s),
        'leaving_work',
      );
      expect(
        JournalPracticePicker.practiceFor(JournalTone.mixed, noon, s),
        'three_step_pause',
      );
      expect(
        JournalPracticePicker.practiceFor(JournalTone.light, noon, s),
        isNull,
      );
      expect(JournalPracticePicker.practiceFor(null, noon, s), isNull);
    });
  });

  group('The entry model', () {
    test('reads an old document with missing fields', () {
      final JournalModel old = JournalModel.fromMap(<String, dynamic>{
        'userId': 'user-1',
        'title': 'Long day',
        'content': 'It was a long day on the ward.',
        'moodEmoji': '😐',
        'moodLabel': 'Neutral',
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1, 20)),
      }, id: 'old-1');

      expect(old.id, 'old-1');
      expect(old.type, JournalTypes.free);
      expect(old.body, 'It was a long day on the ward.');
      expect(old.answers, isEmpty);
      expect(old.moodLabel, 'Okay');
      expect(old.moodIntensity, isNull);
      expect(old.tone, isNull);
      expect(old.topics, isEmpty);
      expect(old.wordCount, 8);
      expect(old.updatedAt, old.createdAt);
      expect(old.needsAnalysis, isTrue);
    });

    test('a new entry survives toMap and fromMap', () {
      final JournalModel entry =
          journalEntry(topics: <String>['Team'], moodLabel: 'Tired').copyWith(
            answers: const <JournalAnswer>[
              JournalAnswer(questionId: 'happened', question: 'Q', text: 'A'),
            ],
            moodIntensity: () => 'Moderate',
          );
      final JournalModel back = JournalModel.fromMap(entry.toMap(), id: 'e1');
      expect(back.title, entry.title);
      expect(back.type, JournalTypes.afterShift);
      expect(back.answers.single.text, 'A');
      expect(back.moodLabel, 'Tired');
      expect(back.moodIntensity, 'Moderate');
      expect(back.tone, JournalTone.mixed);
      expect(back.topics, <String>['Team']);
      expect(back.needsAnalysis, isFalse);
    });

    test('an empty title becomes the first 6 words', () {
      expect(
        JournalModel.titleOrFallback(
          '  ',
          'Slept in, walked to the market with Ammi today.',
        ),
        'Slept in, walked to the market',
      );
    });
  });

  group('Moving old entries', () {
    Map<String, dynamic> oldDoc(int i, {String uid = 'user-1'}) {
      return <String, dynamic>{
        'userId': uid,
        'title': 'Entry $i',
        'content': 'Text $i',
        'moodEmoji': '😊',
        'moodLabel': 'Happy',
        'createdAt': Timestamp.fromDate(
          DateTime(2026, 9, 1).add(Duration(hours: i)),
        ),
      };
    }

    test(
      'a full move copies every entry, deletes the old ones and marks it',
      () async {
        final FakeJournalService service = FakeJournalService();
        for (int i = 0; i < 250; i += 1) {
          service.legacy['old-$i'] = oldDoc(i);
        }
        service.legacy['someone-else'] = oldDoc(0, uid: 'user-2');
        final JournalRepository repo = buildJournalRepository(service);

        await repo.migrateLegacyIfNeeded('user-1');

        expect(service.batchesCommitted, 2, reason: '200 per batch');
        expect(service.entries, hasLength(250));
        expect(service.legacy.keys, <String>['someone-else']);
        expect(service.migrated, isTrue);

        final JournalModel moved = JournalModel.fromMap(
          service.entries['old-7']!,
          id: 'old-7',
        );
        expect(moved.title, 'Entry 7');
        expect(moved.body, 'Text 7');
        expect(moved.type, JournalTypes.free);
        expect(moved.moodLabel, 'Happy');
        expect(moved.createdAt, DateTime(2026, 9, 1, 7));
        expect(moved.updatedAt, moved.createdAt);
        expect(moved.needsAnalysis, isTrue);
      },
    );

    test('a failed batch leaves the old documents and is retried', () async {
      final FakeJournalService service = FakeJournalService()..failBatch = 1;
      for (int i = 0; i < 3; i += 1) {
        service.legacy['old-$i'] = oldDoc(i);
      }
      final JournalRepository repo = buildJournalRepository(service);

      await expectLater(repo.ensureMigrated(), throwsStateError);
      expect(service.legacy, hasLength(3));
      expect(service.entries, isEmpty);
      expect(service.migrated, isFalse);

      // Next launch.
      service.failBatch = null;
      await repo.ensureMigrated();
      expect(service.legacy, isEmpty);
      expect(service.entries, hasLength(3));
      expect(service.migrated, isTrue);
    });

    test('a later batch failing keeps the rest and does not mark it', () async {
      final FakeJournalService service = FakeJournalService()..failBatch = 2;
      for (int i = 0; i < 250; i += 1) {
        service.legacy['old-$i'] = oldDoc(i);
      }
      final JournalRepository repo = buildJournalRepository(service);

      await expectLater(repo.migrateLegacyIfNeeded('user-1'), throwsStateError);
      // Every entry is in exactly one place.
      expect(service.entries.length + service.legacy.length, 250);
      expect(service.legacy, hasLength(50));
      expect(service.migrated, isFalse);
    });

    test('already moved: nothing is read again', () async {
      final FakeJournalService service = FakeJournalService()..migrated = true;
      service.legacy['old-1'] = oldDoc(1);
      await buildJournalRepository(service).ensureMigrated();
      expect(service.legacy, hasLength(1));
      expect(service.batchesCommitted, 0);
    });
  });
}
