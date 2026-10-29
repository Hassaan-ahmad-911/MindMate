import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/journal_content.dart';
import 'package:mindmate/Models/meditation_suggester.dart';
import 'package:mindmate/Models/mood_catalog.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/journal/journal_args.dart';
import 'package:mindmate/ui/mood_tracking/mood_saved_viewmodel.dart';

MoodModel _entry(String mood, String intensity) {
  return MoodModel(
    mood: mood,
    valence: MoodCatalog.valenceFor(mood),
    intensity: intensity,
    note: '',
    date: DateTime(2026, 10, 7, 9),
  );
}

void main() {
  group('The next step after logging a mood', () {
    test('a good mood opens a free write with the mood linked', () {
      final MoodNextStep step = MoodSavedViewModel(
        _entry('Happy', 'Mild'),
      ).nextStep;
      expect(step.route, AppRoutes.journalWrite);
      final JournalWriteArgs args = step.arguments! as JournalWriteArgs;
      expect(args.type, JournalTypes.free);
      expect(args.prompt, 'What went well today?');
      expect(args.linkMood?.mood, 'Happy');
    });

    test('an in-between mood opens the 3-step pause', () {
      final MoodNextStep step = MoodSavedViewModel(
        _entry('Tired', 'Moderate'),
      ).nextStep;
      expect(step.route, AppRoutes.meditationDetails);
      expect(step.arguments, MeditationSuggester.threeStepPauseId);
      expect(step.arguments, 'three_step_pause');
    });

    test('a hard mood opens 5-4-3-2-1 senses', () {
      for (final String intensity in <String>['Mild', 'Moderate']) {
        final MoodNextStep step = MoodSavedViewModel(
          _entry('Anxious', intensity),
        ).nextStep;
        expect(step.route, AppRoutes.meditationDetails);
        expect(step.arguments, 'senses_54321');
      }
    });

    test('a hard mood at Strong opens the self-compassion break', () {
      final MoodSavedViewModel saved = MoodSavedViewModel(
        _entry('Overwhelmed', 'Strong'),
      );
      expect(saved.nextStep.route, AppRoutes.meditationDetails);
      expect(saved.nextStep.arguments, 'self_compassion_break');
      expect(saved.showSupportLine, isTrue);
    });

    test('a strong mood that is not hard does not get the break', () {
      final MoodNextStep step = MoodSavedViewModel(
        _entry('Restless', 'Strong'),
      ).nextStep;
      expect(step.arguments, 'three_step_pause');
    });
  });
}
