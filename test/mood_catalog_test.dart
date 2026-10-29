import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/mood_catalog.dart';
import 'package:mindmate/Models/mood_model.dart';

void main() {
  group('Mood score table', () {
    const Map<String, int> expected = <String, int>{
      'Happy': 2,
      'Grateful': 2,
      'Proud': 2,
      'Calm': 1,
      'Motivated': 1,
      'Hopeful': 1,
      'Okay': 0,
      'Tired': 0,
      'Restless': 0,
      'Stressed': -1,
      'Anxious': -1,
      'Lonely': -1,
      'Sad': -2,
      'Angry': -2,
      'Overwhelmed': -2,
    };

    test('has exactly the 15 moods with their scores', () {
      expect(MoodCatalog.moods, hasLength(15));
      for (final MapEntry<String, int> mood in expected.entries) {
        expect(MoodCatalog.valenceFor(mood.key), mood.value, reason: mood.key);
      }
    });

    test('groups match the scores', () {
      for (final MoodDefinition mood in MoodCatalog.moods) {
        expect(
          mood.group,
          MoodCatalog.groupForValence(mood.valence),
          reason: mood.name,
        );
      }
    });

    test('keeps the design display order in each group', () {
      List<String> names(MoodGroup group) => MoodCatalog.inGroup(
        group,
      ).map((MoodDefinition mood) => mood.name).toList();

      expect(names(MoodGroup.good), <String>[
        'Happy',
        'Calm',
        'Grateful',
        'Motivated',
        'Hopeful',
        'Proud',
      ]);
      expect(names(MoodGroup.between), <String>['Okay', 'Tired', 'Restless']);
      expect(names(MoodGroup.hard), <String>[
        'Stressed',
        'Anxious',
        'Sad',
        'Angry',
        'Overwhelmed',
        'Lonely',
      ]);
    });
  });

  group('Reading old entries', () {
    final Timestamp createdAt = Timestamp.fromDate(DateTime(2026, 10, 1, 9));

    test('works out valence from the mood when it is missing', () {
      final MoodModel entry = MoodModel.fromMap(<String, dynamic>{
        'mood': 'Sad',
        'intensity': 'Mild',
        'note': '',
        'createdAt': createdAt,
      });
      expect(entry.valence, -2);
      expect(entry.group, MoodGroup.hard);
    });

    test('treats Neutral as Okay', () {
      final MoodModel entry = MoodModel.fromMap(<String, dynamic>{
        'mood': 'Neutral',
        'intensity': 'Moderate',
        'createdAt': createdAt,
      });
      expect(entry.mood, 'Okay');
      expect(entry.valence, 0);
      expect(entry.group, MoodGroup.between);
    });

    test('treats and displays Severe as Strong', () {
      final MoodModel entry = MoodModel.fromMap(<String, dynamic>{
        'mood': 'Angry',
        'intensity': 'Severe',
        'createdAt': createdAt,
      });
      expect(entry.intensity, 'Strong');
    });

    test('reads numeric intensities from the oldest entries', () {
      expect(MoodCatalog.normalizeIntensity(1), 'Mild');
      expect(MoodCatalog.normalizeIntensity(2), 'Moderate');
      expect(MoodCatalog.normalizeIntensity(3), 'Strong');
    });

    test('uses an empty factor list when factors are missing', () {
      final MoodModel entry = MoodModel.fromMap(<String, dynamic>{
        'mood': 'Calm',
        'intensity': 'Mild',
        'createdAt': createdAt,
      });
      expect(entry.factors, isEmpty);
      expect(entry.note, '');
      expect(entry.date, DateTime(2026, 10, 1, 9));
    });

    test('keeps a stored valence and the new fields', () {
      final MoodModel entry = MoodModel.fromMap(<String, dynamic>{
        'mood': 'Calm',
        'valence': 1,
        'intensity': 'Mild',
        'factors': <String>['Sleep', 'Family'],
        'note': 'Slept well',
        'createdAt': createdAt,
      }, id: 'abc');
      expect(entry.id, 'abc');
      expect(entry.valence, 1);
      expect(entry.factors, <String>['Sleep', 'Family']);
      expect(entry.detailLabel, 'Mild · Sleep, Family');
    });

    test('writes the new document shape', () {
      final MoodModel entry = MoodModel.create(
        mood: MoodCatalog.find('Stressed')!,
        intensity: 'Strong',
        factors: <String>['Night shift'],
        note: '',
      );
      expect(entry.toMap(), <String, dynamic>{
        'mood': 'Stressed',
        'valence': -1,
        'intensity': 'Strong',
        'factors': <String>['Night shift'],
        'note': '',
      });
    });
  });
}
