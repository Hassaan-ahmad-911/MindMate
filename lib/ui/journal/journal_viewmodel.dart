import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';

import '../../Data/repositories/journal_repository.dart';
import '../../Models/journal_content.dart';
import '../../Models/journal_draft.dart';
import '../../Models/journal_model.dart';
import '../../Models/journal_rules.dart';
import '../app/app_routes.dart';
import '../shared/app_feedback.dart';
import 'journal_args.dart';

/// Journal home: the prompt card, filters, search and the list of entries.
/// One instance serves both the Journal tab and the pushed Journal screen.
class JournalViewModel extends GetxController {
  JournalViewModel(
    this._repository, {
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random();

  final JournalRepository _repository;
  final DateTime Function() _clock;
  final Random _random;

  /// When searching or filtering, more pages are fetched until at least this
  /// many entries show (or there are no more).
  static const int minVisibleResults = 10;
  static const int _maxAutoPages = 10;

  /// "all", or one of [JournalTypes].
  static const String allFilter = 'all';
  static const List<String> filters = <String>[
    allFilter,
    JournalTypes.afterShift,
    JournalTypes.moment,
    JournalTypes.letItOut,
    JournalTypes.free,
  ];

  final RxList<JournalModel> entries = <JournalModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasError = false.obs;
  final RxBool hasMore = false.obs;
  final RxString filter = allFilter.obs;
  final RxBool isSearching = false.obs;
  final RxString query = ''.obs;
  final Rxn<JournalPrompt> prompt = Rxn<JournalPrompt>();
  final RxString promptLabel = ''.obs;

  Object? _cursor;
  bool _filling = false;

  /// The ViewModel if it is already running, without creating it.
  static JournalViewModel? get active {
    if (Get.isRegistered<JournalViewModel>() &&
        !Get.isPrepared<JournalViewModel>()) {
      return Get.find<JournalViewModel>();
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  /// The entries that match the filter and the search, newest first.
  List<JournalModel> get visibleEntries {
    final String type = filter.value;
    final String search = query.value.trim().toLowerCase();
    return entries
        .where((JournalModel e) => type == allFilter || e.type == type)
        .where(
          (JournalModel e) =>
              search.isEmpty ||
              e.title.toLowerCase().contains(search) ||
              e.body.toLowerCase().contains(search),
        )
        .toList(growable: false);
  }

  List<JournalDayGroup> get groups =>
      JournalDates.group(visibleEntries, _clock());

  bool get isEmpty => !isLoading.value && !hasError.value && entries.isEmpty;

  static String filterLabel(String filter) =>
      filter == allFilter ? 'All' : JournalTypes.shortLabel(filter);

  Future<void> load() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      await _loadPrompt();
      try {
        await _repository.ensureMigrated();
      } catch (_) {
        // The old entries stay where they were; the next launch tries again.
        showMindMateSnackBar(
          'Some older entries are not here yet',
          'We will try to move them again next time you open the journal.',
        );
      }
      final JournalPage page = await _repository.getPage();
      entries.assignAll(page.entries);
      _cursor = page.cursor;
      hasMore.value = page.hasMore;
    } catch (_) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
    await _fillVisible();
  }

  Future<void> refreshEntries() => load();

  Future<void> loadMore() async {
    if (!hasMore.value || isLoadingMore.value || isLoading.value) {
      return;
    }
    isLoadingMore.value = true;
    try {
      final JournalPage page = await _repository.getPage(after: _cursor);
      final Set<String> known = entries.map((JournalModel e) => e.id).toSet();
      entries.addAll(
        page.entries.where((JournalModel e) => !known.contains(e.id)),
      );
      _cursor = page.cursor;
      hasMore.value = page.hasMore;
    } catch (_) {
      showMindMateSnackBar(
        'Could not load more',
        'Check your connection and scroll again.',
      );
    } finally {
      isLoadingMore.value = false;
    }
  }

  void setFilter(String value) {
    filter.value = value;
    unawaited(_fillVisible());
  }

  void openSearch() => isSearching.value = true;

  void closeSearch() {
    isSearching.value = false;
    query.value = '';
  }

  void setQuery(String value) {
    query.value = value;
    unawaited(_fillVisible());
  }

  /// Firestore has no full-text search, so search and the type filter work on
  /// the entries already loaded, fetching more pages while fewer than
  /// [minVisibleResults] match.
  Future<void> _fillVisible() async {
    if (_filling) {
      return;
    }
    _filling = true;
    try {
      int pages = 0;
      while ((filter.value != allFilter || query.value.trim().isNotEmpty) &&
          visibleEntries.length < minVisibleResults &&
          hasMore.value &&
          pages < _maxAutoPages) {
        await loadMore();
        pages += 1;
      }
    } finally {
      _filling = false;
    }
  }

  Future<void> _loadPrompt() async {
    final JournalContent content = await _repository.loadContent();
    final DateTime now = _clock();
    promptLabel.value = JournalPromptPicker.label(now);
    prompt.value = JournalPromptPicker.today(content.prompts, now);
  }

  void shufflePrompt() {
    final JournalContent? content = _repository.content;
    final JournalPrompt? current = prompt.value;
    if (content == null || current == null) {
      return;
    }
    prompt.value = JournalPromptPicker.shuffle(
      content.prompts,
      _clock(),
      current,
      random: _random,
    );
  }

  // Starting to write. The view asks "Continue your draft?" when there is one.

  /// The saved draft, if any.
  Future<JournalDraft?> pendingDraft() async {
    try {
      return await _repository.readDraft();
    } catch (_) {
      return null;
    }
  }

  void continueDraft(JournalDraft draft) {
    Get.toNamed<void>(
      AppRoutes.journalWrite,
      arguments: JournalWriteArgs(
        type: draft.type,
        prompt: draft.prompt,
        draft: draft,
      ),
    );
  }

  /// Opens "How do you want to write?", carrying the prompt when the user
  /// started from the prompt card.
  Future<void> startFresh({required bool fromPrompt}) async {
    try {
      await _repository.clearDraft();
    } catch (_) {
      // A stale draft is harmless; it is replaced on the next keystroke.
    }
    Get.toNamed<void>(
      AppRoutes.journalNew,
      arguments: JournalWriteArgs(
        prompt: fromPrompt ? prompt.value?.text : null,
      ),
    );
  }

  void openEntry(JournalModel entry) {
    Get.toNamed<void>(AppRoutes.journalEntry, arguments: entry);
  }

  void openInsights() => Get.toNamed<void>(AppRoutes.journalInsights);

  // Kept in step by the other journal screens.

  void onEntrySaved(JournalModel entry) {
    entries.removeWhere((JournalModel e) => e.id == entry.id);
    final int index = entries.indexWhere(
      (JournalModel e) => e.createdAt.isBefore(entry.createdAt),
    );
    if (index < 0) {
      entries.add(entry);
    } else {
      entries.insert(index, entry);
    }
  }

  void onEntryUpdated(JournalModel entry) {
    final int index = entries.indexWhere((JournalModel e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    }
  }

  void onEntryDeleted(String id) {
    entries.removeWhere((JournalModel e) => e.id == id);
  }
}
