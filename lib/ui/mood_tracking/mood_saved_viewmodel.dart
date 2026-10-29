import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/journal_content.dart';
import '../../Models/mood_catalog.dart';
import '../../Models/meditation_suggester.dart';
import '../../Models/mood_model.dart';
import '../app/app_routes.dart';
import '../journal/journal_args.dart';
import '../journal/journal_write_viewmodel.dart';
import 'mood_tracking_viewmodel.dart';
import 'widgets/mood_visuals.dart';

/// The "Saved" screen shown after logging. Receives the saved entry as the
/// route argument.
class MoodSavedViewModel extends GetxController {
  MoodSavedViewModel(this.entry);

  final MoodModel? entry;

  static const String wentWellPrompt = 'What went well today?';

  int get streak {
    if (Get.isRegistered<MoodTrackingViewModel>()) {
      return Get.find<MoodTrackingViewModel>().streak;
    }
    return entry == null ? 0 : 1;
  }

  /// e.g. "Calm · Mild · Today, 8:10".
  String get summaryLine {
    final MoodModel? saved = entry;
    if (saved == null) {
      return 'Your entry was saved.';
    }
    final String when = MoodFormat.entryWhen(saved.date, now: DateTime.now());
    return '${saved.mood} · ${saved.intensity} · $when';
  }

  MoodNextStep get nextStep {
    switch (entry?.group ?? MoodGroup.between) {
      case MoodGroup.good:
        return MoodNextStep(
          text: 'Write down what went well today',
          icon: Icons.menu_book_rounded,
          route: AppRoutes.journalWrite,
          arguments: JournalWriteArgs(
            type: JournalTypes.free,
            prompt: wentWellPrompt,
            linkMood: entry,
          ),
        );
      case MoodGroup.between:
        return const MoodNextStep(
          text: 'Take a 3-minute breathing break',
          icon: Icons.air_rounded,
          route: AppRoutes.meditationDetails,
          arguments: MeditationSuggester.threeStepPauseId,
        );
      case MoodGroup.hard:
        return MoodNextStep(
          text: 'Try a short breathing exercise',
          icon: Icons.air_rounded,
          route: AppRoutes.meditationDetails,
          // A hard mood at Strong gets the self-compassion break.
          arguments: entry?.intensity == MoodCatalog.strong
              ? MeditationSuggester.selfCompassionId
              : MeditationSuggester.sensesId,
        );
    }
  }

  /// Hard mood logged as Strong.
  bool get showSupportLine =>
      entry?.group == MoodGroup.hard && entry?.intensity == MoodCatalog.strong;

  void openNextStep() {
    final MoodNextStep step = nextStep;
    // The mood was logged from inside the journal: go back to that entry,
    // which links the new mood, instead of opening a second one.
    if (step.route == AppRoutes.journalWrite &&
        Get.isRegistered<JournalWriteViewModel>()) {
      Get.back<void>();
      return;
    }
    Get.offNamed(step.route, arguments: step.arguments);
  }

  void openInsights() => Get.offNamed(AppRoutes.moodInsights);

  void done() => Get.back();
}

class MoodNextStep {
  const MoodNextStep({
    required this.text,
    required this.icon,
    required this.route,
    this.arguments,
  });

  final String text;
  final IconData icon;
  final String route;

  /// Passed to the route, e.g. the id of the practice to open.
  final Object? arguments;
}
