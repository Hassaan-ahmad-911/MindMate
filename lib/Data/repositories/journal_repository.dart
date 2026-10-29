import '../../Models/journal_content.dart';
import '../../Models/journal_draft.dart';
import '../../Models/journal_model.dart';
import '../../services/journal_content_service.dart';
import '../../services/journal_draft_store.dart';
import '../../services/journal_firestore_service.dart';

/// Journal entries, the journal content file and the one draft.
class JournalRepository {
  JournalRepository(
    this._service,
    this._contentService,
    this._drafts, {
    void Function()? onSaved,
  }) : _onSaved = onSaved;

  static const int pageSize = 20;

  /// Called after an entry is saved (the hospital programme's evaluation,
  /// which reads the tone label only).
  final void Function()? _onSaved;

  /// Firestore allows 500 writes per batch; each entry moved is 2 (copy and
  /// delete), so 200 entries per batch.
  static const int maxBatchOperations = 400;

  final JournalFirestoreService _service;
  final JournalContentService _contentService;
  final JournalDraftStore _drafts;

  /// Users whose old entries were checked during this launch.
  final Set<String> _checked = <String>{};
  Future<void>? _migrating;

  /// Templates, prompts, tone words and support wording. Read once.
  Future<JournalContent> loadContent() => _contentService.load();

  JournalContent? get content => _contentService.content;

  // Moving entries out of the old top-level `journals` collection.

  /// Moves the signed-in user's old entries once. Safe to call often: it
  /// does the work at most once per launch, and only until it has succeeded.
  Future<void> ensureMigrated() {
    final String uid = _service.currentUid();
    if (_checked.contains(uid)) {
      return Future<void>.value();
    }
    return _migrating ??= migrateLegacyIfNeeded(uid).whenComplete(() {
      _migrating = null;
    });
  }

  /// Copies each old entry to `users/{uid}/journals/{sameId}` and deletes the
  /// old one, in batches. `journalsMigratedAt` is set only after every batch
  /// succeeded. If a batch fails, its old documents stay where they are, the
  /// error is rethrown and the next launch tries again; no entry is lost.
  Future<void> migrateLegacyIfNeeded(String uid) async {
    if (await _service.isLegacyMigrated(uid)) {
      _checked.add(uid);
      return;
    }

    final List<LegacyJournalDoc> legacy = await _service.getLegacyJournals(uid);
    const int perBatch = maxBatchOperations ~/ 2;
    for (int start = 0; start < legacy.length; start += perBatch) {
      final Iterable<LegacyJournalDoc> chunk = legacy
          .skip(start)
          .take(perBatch);
      await _service.moveLegacyBatch(uid, <String, Map<String, dynamic>>{
        for (final LegacyJournalDoc doc in chunk)
          doc.id: JournalModel.fromLegacyMap(doc.data),
      });
    }
    await _service.markLegacyMigrated(uid);
    _checked.add(uid);
  }

  // Entries.

  Future<JournalPage> getPage({Object? after, int limit = pageSize}) {
    return _service.getPage(after: after, limit: limit);
  }

  Future<JournalModel?> getEntry(String id) => _service.getEntry(id);

  /// The parts of each entry the Reports module needs (no body), for
  /// [start] <= createdAt < [end], newest first.
  Future<List<JournalSummary>> getEntriesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final List<JournalModel> entries = await _service.getEntriesBetween(
      start,
      end,
    );
    return entries.map(JournalSummary.fromEntry).toList(growable: false);
  }

  Future<JournalModel> createEntry(JournalModel entry) async {
    final JournalModel saved = await _service.createEntry(entry);
    _onSaved?.call();
    return saved;
  }

  Future<void> updateEntry(JournalModel entry) async {
    await _service.updateEntry(entry);
    _onSaved?.call();
  }

  Future<void> deleteEntry(String id) => _service.deleteEntry(id);

  // The draft, kept on this phone only.

  Future<JournalDraft?> readDraft() async {
    final JournalDraft? draft = await _drafts.read(_service.currentUid());
    return draft != null && draft.hasText ? draft : null;
  }

  Future<void> saveDraft(JournalDraft draft) {
    return _drafts.write(_service.currentUid(), draft);
  }

  Future<void> clearDraft() => _drafts.clear(_service.currentUid());
}
