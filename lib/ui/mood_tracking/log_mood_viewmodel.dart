import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Data/repositories/mood_repository.dart';
import '../../Models/mood_catalog.dart';
import '../../Models/mood_model.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../app/app_routes.dart';
import '../shared/app_feedback.dart';
import 'mood_tracking_viewmodel.dart';

/// Holds the draft entry across the three log steps and saves it once.
/// Closing the flow discards the draft along with this controller.
class LogMoodViewModel extends GetxController {
  LogMoodViewModel(this._moodRepository);

  final MoodRepository _moodRepository;

  static const List<String> notePrompts = <String>[
    'What happened?',
    'What helped?',
    'What do I need?',
  ];

  static const Set<String> _flowRoutes = <String>{
    AppRoutes.moodLog,
    AppRoutes.moodLogStrength,
    AppRoutes.moodLogNote,
  };

  final Rxn<MoodDefinition> selectedMood = Rxn<MoodDefinition>();
  final RxString intensity = MoodCatalog.mild.obs;
  final RxList<String> factors = <String>[].obs;
  final TextEditingController noteController = TextEditingController();
  final RxInt noteLength = 0.obs;
  final RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    noteController.addListener(_syncNoteLength);
  }

  bool get canContinue => selectedMood.value != null;

  /// e.g. "Calm · Mild".
  String get summaryLabel =>
      '${selectedMood.value?.name ?? ''} · ${intensity.value}';

  String get factorsLabel => factors.join(', ');

  void selectMood(MoodDefinition mood) {
    selectedMood.value = mood;
  }

  void setIntensity(String value) {
    intensity.value = value;
  }

  bool isFactorSelected(String factor) => factors.contains(factor);

  void toggleFactor(String factor) {
    if (factors.contains(factor)) {
      factors.remove(factor);
    } else {
      factors.add(factor);
    }
  }

  /// Adds [prompt] as a starting line for the note.
  void insertPrompt(String prompt) {
    final String current = noteController.text.trimRight();
    final String next = current.isEmpty ? '$prompt\n' : '$current\n$prompt\n';
    if (next.length > MoodCatalog.noteMaxLength) {
      showMindMateSnackBar(
        'Note is full',
        'Notes can be up to ${MoodCatalog.noteMaxLength} characters.',
      );
      return;
    }
    noteController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void continueToStrength() {
    if (!canContinue) {
      return;
    }
    Get.toNamed(AppRoutes.moodLogStrength);
  }

  void continueToNote() => Get.toNamed(AppRoutes.moodLogNote);

  void goBack() => Get.back();

  /// Saves the entry. [includeNote] is false for "Skip the note".
  Future<void> save({bool includeNote = true}) async {
    final MoodDefinition? mood = selectedMood.value;
    if (mood == null || isSaving.value) {
      return;
    }

    isSaving.value = true;
    try {
      final MoodModel saved = await _moodRepository.saveMood(
        MoodModel.create(
          mood: mood,
          intensity: intensity.value,
          factors: factors.toList(growable: false),
          note: includeNote ? noteController.text.trim() : '',
        ),
      );
      _notifyListeners(saved);
      Get.offNamedUntil(
        AppRoutes.moodSaved,
        (Route<dynamic> route) => !_flowRoutes.contains(route.settings.name),
        arguments: saved,
      );
    } catch (error) {
      showMindMateSnackBar('Could not save', moodErrorMessage(error));
    } finally {
      if (!isClosed) {
        isSaving.value = false;
      }
    }
  }

  void _notifyListeners(MoodModel saved) {
    if (Get.isRegistered<MoodTrackingViewModel>()) {
      Get.find<MoodTrackingViewModel>().addEntry(saved);
    }
    if (Get.isRegistered<HomeViewModel>()) {
      unawaited(Get.find<HomeViewModel>().refreshQuiet());
    }
  }

  void _syncNoteLength() {
    noteLength.value = noteController.text.length;
  }

  @override
  void onClose() {
    noteController.removeListener(_syncNoteLength);
    noteController.dispose();
    super.onClose();
  }
}
