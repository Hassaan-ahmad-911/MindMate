import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/journal_repository.dart';
import '../../Models/journal_content.dart';
import '../../Models/journal_model.dart';
import '../../Models/journal_rules.dart';
import '../../services/journal_tone_service.dart';
import '../app/app_routes.dart';
import '../shared/app_feedback.dart';
import 'journal_args.dart';
import 'journal_viewmodel.dart';

/// Reading one entry, with edit and delete. Opened with the entry (or its
/// id) as the route argument.
class JournalEntryViewModel extends GetxController {
  JournalEntryViewModel(
    this._repository, {
    Object? source,
    DateTime Function()? clock,
  }) : _source = source,
       _clock = clock ?? DateTime.now;

  final JournalRepository _repository;
  final Object? _source;
  final DateTime Function() _clock;

  final Rxn<JournalModel> entry = Rxn<JournalModel>();
  final Rxn<JournalContent> content = Rxn<JournalContent>();
  final Rxn<JournalTopicCount> topicLine = Rxn<JournalTopicCount>();
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxBool isDeleting = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final JournalContent loaded = await _repository.loadContent();
      content.value = loaded;
      final Object? source = _source;
      JournalModel? found = source is JournalModel
          ? source
          : source is String
          ? await _repository.getEntry(source)
          : null;
      if (found == null) {
        hasError.value = true;
        return;
      }
      if (found.needsAnalysis) {
        found = await _analyseOldEntry(found, loaded);
      }
      entry.value = found;
    } catch (_) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
    unawaited(_loadTopicLine());
  }

  /// Entries written before tone and topics existed get them the first time
  /// they are opened. `updatedAt` is left alone: this is not an edit.
  Future<JournalModel> _analyseOldEntry(
    JournalModel old,
    JournalContent loaded,
  ) async {
    final JournalAnalysis analysis = JournalToneService.fromContent(
      loaded,
    ).analyse(old.body);
    final JournalModel updated = old.copyWith(
      tone: () => analysis.tone,
      toneScore: () => analysis.toneScore,
      topics: analysis.topics,
      wordCount: JournalModel.countWords(old.body),
      needsAnalysis: false,
    );
    try {
      await _repository.updateEntry(updated);
      JournalViewModel.active?.onEntryUpdated(updated);
    } catch (_) {
      // Shown anyway; it is worked out again next time.
    }
    return updated;
  }

  Future<void> _loadTopicLine() async {
    final JournalModel? current = entry.value;
    if (current == null) {
      return;
    }
    try {
      final DateTime now = _clock();
      final List<JournalSummary> month = await _repository.getEntriesBetween(
        JournalDates.monthStart(now),
        JournalDates.nextMonthStart(now),
      );
      if (!isClosed) {
        topicLine.value = JournalInsights.topicLineFor(current, month);
      }
    } catch (_) {
      // The topic line is a small extra; leave it out.
    }
  }

  /// The questions with their answers, leaving out empty ones.
  List<JournalAnswer> get answeredQuestions =>
      (entry.value?.answers ?? const <JournalAnswer>[])
          .where((JournalAnswer a) => a.text.trim().isNotEmpty)
          .toList(growable: false);

  /// Opens the writing screen filled in. Returns true when the edited entry
  /// matched the support check, so the view can show the support card.
  Future<bool> edit() async {
    final JournalModel? current = entry.value;
    if (current == null) {
      return false;
    }
    final Object? result = await Get.toNamed<Object?>(
      AppRoutes.journalWrite,
      arguments: JournalWriteArgs(editing: current),
    );
    if (result is! JournalEditResult || isClosed) {
      return false;
    }
    entry.value = result.entry;
    unawaited(_loadTopicLine());
    return result.showSupport;
  }

  Future<void> delete() async {
    final JournalModel? current = entry.value;
    if (current == null || isDeleting.value) {
      return;
    }
    isDeleting.value = true;
    try {
      await _repository.deleteEntry(current.id);
      JournalViewModel.active?.onEntryDeleted(current.id);
      Get.back<void>();
      showMindMateSnackBar('Entry deleted', 'It has been removed.');
    } catch (_) {
      showMindMateSnackBar(
        'Could not delete',
        'Check your connection and try again.',
      );
    } finally {
      if (!isClosed) {
        isDeleting.value = false;
      }
    }
  }

  void openSupport() => Get.toNamed<void>(AppRoutes.support);
}
