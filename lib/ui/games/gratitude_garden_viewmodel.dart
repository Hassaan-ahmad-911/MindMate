import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Data/repositories/break_repository.dart';
import '../../Data/repositories/gratitude_repository.dart';
import '../../Models/break_log.dart';
import '../../Models/gratitude_entry.dart';
import '../shared/app_feedback.dart';
import 'break_logger.dart';

/// The gratitude garden: one good thing a day, each one a flower.
///
/// What the user types is never logged or printed, and when a save fails it
/// stays in the text field.
class GratitudeGardenViewModel extends GetxController {
  GratitudeGardenViewModel(
    this._repository,
    BreakRepository breaks, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _logger = BreakLogger(
         breaks,
         BreakActivity.gratitudeGarden,
         clock: clock,
       );

  /// A write with no connection only finishes when the phone is back online,
  /// so after this the entry is treated as saved on the phone.
  static const Duration _patience = Duration(seconds: 4);

  final GratitudeRepository _repository;
  final DateTime Function() _clock;
  final BreakLogger _logger;

  final TextEditingController textController = TextEditingController();

  /// Every flower, oldest first.
  final RxList<GratitudeEntry> entries = <GratitudeEntry>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool loadFailed = false.obs;
  final RxBool isSaving = false.obs;

  /// The last save did not go through; the text is still in the field.
  final RxBool saveFailed = false.obs;

  /// Changing today's flower instead of planting it.
  final RxBool isEditing = false.obs;

  /// The flower that just grew, so only it plays the grow animation.
  final RxnString justPlantedKey = RxnString();

  /// What is in the text field now (for the disabled button).
  final RxString draft = ''.obs;

  @override
  void onInit() {
    super.onInit();
    textController.addListener(() => draft.value = textController.text);
    unawaited(load());
  }

  DateTime get now => _clock();

  GratitudeEntry? get todayEntry => GratitudeRules.entryFor(entries, now);

  /// The latest flower before today, shown under "Yesterday".
  GratitudeEntry? get previousEntry =>
      GratitudeRules.previousEntry(entries, now);

  /// Whether the field is showing (not "Planted today").
  bool get isWriting => todayEntry == null || isEditing.value;

  bool get canSubmit =>
      !isSaving.value &&
      !isLoading.value &&
      GratitudeRules.canSave(draft.value);

  Future<void> load() async {
    isLoading.value = true;
    loadFailed.value = false;
    try {
      final List<GratitudeEntry> loaded = await _repository.getEntries();
      entries.assignAll(GratitudeRules.sorted(loaded));
    } catch (_) {
      loadFailed.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  /// "Plant today's flower" (or "Save" while editing).
  Future<void> submit() async {
    if (!canSubmit || loadFailed.value) {
      return;
    }
    final String? text = GratitudeRules.cleanText(textController.text);
    if (text == null) {
      return;
    }

    final DateTime moment = now;
    final GratitudeEntry? existing = todayEntry;
    final bool editing = isEditing.value && existing != null;
    if (editing && !GratitudeRules.canEdit(existing, moment)) {
      // The day changed while editing: yesterday's flower stays as it was.
      isEditing.value = false;
      showMindMateSnackBar(
        'That flower is from another day',
        'Flowers can only be changed on the day they were planted.',
      );
      return;
    }
    if (!editing && !GratitudeRules.canPlant(entries, moment)) {
      // Today already has a flower (planted elsewhere meanwhile).
      await load();
      return;
    }

    isSaving.value = true;
    saveFailed.value = false;
    try {
      if (editing) {
        final GratitudeEntry updated = existing.copyWith(
          text: text,
          updatedAt: moment,
        );
        await _repository.editText(updated).timeout(_patience);
        _replace(updated);
        isEditing.value = false;
      } else {
        final GratitudeEntry planted = GratitudeEntry(
          dateKey: GratitudeRules.dateKey(moment),
          text: text,
          createdAt: moment,
          updatedAt: moment,
        );
        await _repository.plant(planted).timeout(_patience);
        _replace(planted);
        isEditing.value = false;
        justPlantedKey.value = planted.dateKey;
        _logger.markInteraction();
        _logger.finish(completed: true);
      }
      textController.clear();
    } on TimeoutException {
      _afterSavedOnPhone(text, editing, existing, moment);
    } catch (_) {
      saveFailed.value = true;
      showMindMateSnackBar(
        'Could not save that',
        'Your words are still here. Please try again.',
      );
    } finally {
      isSaving.value = false;
    }
  }

  /// The write has not been confirmed yet (no connection). It is kept on the
  /// phone and will sync, so the garden shows it.
  void _afterSavedOnPhone(
    String text,
    bool editing,
    GratitudeEntry? existing,
    DateTime moment,
  ) {
    if (editing && existing != null) {
      _replace(existing.copyWith(text: text, updatedAt: moment));
      isEditing.value = false;
    } else {
      final GratitudeEntry planted = GratitudeEntry(
        dateKey: GratitudeRules.dateKey(moment),
        text: text,
        createdAt: moment,
        updatedAt: moment,
      );
      _replace(planted);
      isEditing.value = false;
      justPlantedKey.value = planted.dateKey;
      _logger.markInteraction();
      _logger.finish(completed: true);
    }
    textController.clear();
  }

  void _replace(GratitudeEntry entry) {
    final List<GratitudeEntry> next = <GratitudeEntry>[
      for (final GratitudeEntry e in entries)
        if (e.dateKey != entry.dateKey) e,
      entry,
    ];
    entries.assignAll(GratitudeRules.sorted(next));
  }

  /// The "Edit" link on today's flower.
  void startEdit() {
    final GratitudeEntry? entry = todayEntry;
    if (entry == null || !GratitudeRules.canEdit(entry, now)) {
      return;
    }
    textController.text = entry.text;
    textController.selection = TextSelection.collapsed(
      offset: textController.text.length,
    );
    saveFailed.value = false;
    isEditing.value = true;
  }

  void cancelEdit() {
    isEditing.value = false;
    saveFailed.value = false;
    textController.clear();
  }

  /// Removes a flower. It goes at once and comes back if that fails.
  Future<void> delete(GratitudeEntry entry) async {
    final List<GratitudeEntry> before = entries.toList();
    entries.removeWhere((GratitudeEntry e) => e.dateKey == entry.dateKey);
    if (isEditing.value && todayEntry == null) {
      cancelEdit();
    }
    try {
      await _repository.delete(entry.dateKey).timeout(_patience);
    } on TimeoutException {
      // Removed on the phone; it will sync.
    } catch (_) {
      entries.assignAll(before);
      showMindMateSnackBar(
        'Could not remove that flower',
        'Please try again in a moment.',
      );
    }
  }

  void back() => Get.back<void>();

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }
}
