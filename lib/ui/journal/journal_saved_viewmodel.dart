import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/journal_repository.dart';
import '../../Data/repositories/meditation_repository.dart';
import '../../Models/journal_content.dart';
import '../../Models/journal_model.dart';
import '../../Models/journal_rules.dart';
import '../../Models/meditation_models.dart';
import '../app/app_routes.dart';
import 'journal_args.dart';

/// "Saved", after a new entry. Shows the tone and a practice, or the support
/// card instead when the entry matched the support check.
class JournalSavedViewModel extends GetxController {
  JournalSavedViewModel(
    this._repository,
    this.args, {
    MeditationRepository? meditation,
    DateTime Function()? clock,
  }) : _meditation = meditation,
       _clock = clock ?? DateTime.now;

  final JournalRepository _repository;
  final JournalSavedArgs args;
  final MeditationRepository? _meditation;
  final DateTime Function() _clock;

  final Rxn<JournalContent> content = Rxn<JournalContent>();
  final Rxn<MeditationSession> practice = Rxn<MeditationSession>();
  final RxString practiceGroup = ''.obs;

  JournalModel get entry => args.entry;

  bool get showSupport => args.showSupport;

  @override
  void onInit() {
    super.onInit();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final JournalContent loaded = await _repository.loadContent();
      content.value = loaded;
      if (!showSupport) {
        await _loadPractice(loaded);
      }
    } catch (_) {
      // Without the content file the screen still shows "Saved".
    }
  }

  Future<void> _loadPractice(JournalContent loaded) async {
    final MeditationRepository? meditation = _meditation;
    final String? id = JournalPracticePicker.practiceFor(
      entry.tone,
      _clock(),
      loaded.practiceSuggestions,
    );
    if (meditation == null || id == null) {
      return;
    }
    try {
      final MeditationSession? session = await meditation.findSession(id);
      if (session == null || isClosed) {
        return;
      }
      practiceGroup.value = meditation.groupById(session.groupId)?.title ?? '';
      practice.value = session;
    } catch (_) {
      // No practice card if the meditation content is missing.
    }
  }

  /// "After-shift debrief · 21:42".
  String get summaryLine {
    final String title =
        content.value?.templateFor(entry.type).title ??
        JournalTypes.shortLabel(entry.type);
    return '$title · ${JournalDates.time(entry.createdAt)}';
  }

  String get toneLine {
    final Map<String, String> lines =
        content.value?.tone.savedLines ?? const <String, String>{};
    return lines[entry.tone?.id ?? 'none'] ?? '';
  }

  /// Where the marker sits on the Heavy-Light bar, from 0 to 1.
  double get markerPosition {
    final double score = entry.toneScore ?? 0;
    return ((score + 2) / 4).clamp(0.0, 1.0);
  }

  /// "After a shift · 8 min".
  String get practiceLabel {
    final MeditationSession? session = practice.value;
    if (session == null) {
      return '';
    }
    return practiceGroup.value.isEmpty
        ? session.lengthLabel
        : '${practiceGroup.value} · ${session.lengthLabel}';
  }

  void openPractice() {
    final MeditationSession? session = practice.value;
    if (session != null) {
      Get.toNamed<void>(AppRoutes.meditationDetails, arguments: session.id);
    }
  }

  void done() => Get.back<void>();

  void readEntry() =>
      Get.offNamed<void>(AppRoutes.journalEntry, arguments: entry);

  void talkToSomeone() => Get.toNamed<void>(AppRoutes.support);

  void breatheFirst() => Get.toNamed<void>(AppRoutes.breathingBubble);
}
