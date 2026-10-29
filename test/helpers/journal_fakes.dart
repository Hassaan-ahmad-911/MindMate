import 'dart:io';

import 'package:mindmate/Data/repositories/journal_repository.dart';
import 'package:mindmate/Models/journal_content.dart';
import 'package:mindmate/Models/journal_draft.dart';
import 'package:mindmate/Models/journal_model.dart';
import 'package:mindmate/services/journal_content_service.dart';
import 'package:mindmate/services/journal_draft_store.dart';
import 'package:mindmate/services/journal_firestore_service.dart';

/// The text of the real content file, read synchronously so it also works
/// inside a widget test's fake clock.
String journalContentText() =>
    File('assets/journal/journal_content.json').readAsStringSync();

JournalContent loadJournalContent() =>
    JournalContent.fromJson(journalContentText());

JournalContentService fileJournalContentService() =>
    JournalContentService(loader: () async => journalContentText());

/// Keeps entries in memory instead of Firestore, at both the old and the new
/// location.
class FakeJournalService extends JournalFirestoreService {
  FakeJournalService({this.uid = 'user-1'});

  final String uid;

  /// `users/{uid}/journals`, by id.
  final Map<String, Map<String, dynamic>> entries =
      <String, Map<String, dynamic>>{};

  /// The old top-level `journals` collection, by id.
  final Map<String, Map<String, dynamic>> legacy =
      <String, Map<String, dynamic>>{};

  bool migrated = false;
  int batchesCommitted = 0;

  /// Batch number (1-based) that fails, or null.
  int? failBatch;
  bool failLoading = false;
  int _next = 0;

  @override
  String currentUid() => uid;

  void addEntry(JournalModel entry) {
    entries[entry.id] = entry.toMap();
  }

  List<JournalModel> _sorted() {
    final List<JournalModel> list = entries.entries
        .map(
          (MapEntry<String, Map<String, dynamic>> e) =>
              JournalModel.fromMap(e.value, id: e.key),
        )
        .toList();
    list.sort(
      (JournalModel a, JournalModel b) => b.createdAt.compareTo(a.createdAt),
    );
    return list;
  }

  @override
  Future<JournalPage> getPage({Object? after, required int limit}) async {
    if (failLoading) {
      throw StateError('offline');
    }
    final int start = after is int ? after : 0;
    final List<JournalModel> all = _sorted();
    final List<JournalModel> page = all.skip(start).take(limit).toList();
    return JournalPage(
      entries: page,
      cursor: start + page.length,
      hasMore: start + page.length < all.length,
    );
  }

  @override
  Future<JournalModel?> getEntry(String id) async {
    final Map<String, dynamic>? data = entries[id];
    return data == null ? null : JournalModel.fromMap(data, id: id);
  }

  @override
  Future<List<JournalModel>> getEntriesBetween(
    DateTime start,
    DateTime end,
  ) async {
    if (failLoading) {
      throw StateError('offline');
    }
    return _sorted()
        .where(
          (JournalModel e) =>
              !e.createdAt.isBefore(start) && e.createdAt.isBefore(end),
        )
        .toList();
  }

  @override
  Future<JournalModel> createEntry(JournalModel entry) async {
    final JournalModel saved = entry.copyWith(id: 'entry-${++_next}');
    entries[saved.id] = saved.toMap();
    return saved;
  }

  @override
  Future<void> updateEntry(JournalModel entry) async {
    entries[entry.id] = entry.toMap();
  }

  @override
  Future<void> deleteEntry(String id) async {
    entries.remove(id);
  }

  @override
  Future<bool> isLegacyMigrated(String uid) async => migrated;

  @override
  Future<List<LegacyJournalDoc>> getLegacyJournals(String uid) async {
    return legacy.entries
        .where(
          (MapEntry<String, Map<String, dynamic>> e) =>
              e.value['userId'] == uid,
        )
        .map(
          (MapEntry<String, Map<String, dynamic>> e) =>
              LegacyJournalDoc(e.key, e.value),
        )
        .toList();
  }

  @override
  Future<void> moveLegacyBatch(
    String uid,
    Map<String, Map<String, dynamic>> convertedById,
  ) async {
    if (failBatch == batchesCommitted + 1) {
      throw StateError('batch failed');
    }
    // Atomic, like a Firestore batch: all of it or none of it.
    for (final MapEntry<String, Map<String, dynamic>> e
        in convertedById.entries) {
      entries[e.key] = e.value;
      legacy.remove(e.key);
    }
    batchesCommitted += 1;
  }

  @override
  Future<void> markLegacyMigrated(String uid) async {
    migrated = true;
  }
}

/// Keeps the draft in memory instead of on the phone.
class FakeDraftStore extends JournalDraftStore {
  final Map<String, JournalDraft> drafts = <String, JournalDraft>{};

  @override
  Future<JournalDraft?> read(String uid) async => drafts[uid];

  @override
  Future<void> write(String uid, JournalDraft draft) async {
    drafts[uid] = draft;
  }

  @override
  Future<void> clear(String uid) async {
    drafts.remove(uid);
  }
}

JournalRepository buildJournalRepository(
  FakeJournalService service, {
  FakeDraftStore? drafts,
}) {
  return JournalRepository(
    service,
    fileJournalContentService(),
    drafts ?? FakeDraftStore(),
  );
}

JournalModel journalEntry({
  String id = 'e1',
  String title = 'Long night on Ward 4',
  String type = JournalTypes.afterShift,
  String body = 'Two admissions back to back.',
  DateTime? createdAt,
  DateTime? updatedAt,
  JournalTone? tone = JournalTone.mixed,
  List<String> topics = const <String>[],
  String? moodLabel,
}) {
  final DateTime created = createdAt ?? DateTime(2026, 10, 8, 21, 40);
  return JournalModel(
    id: id,
    title: title,
    type: type,
    body: body,
    tone: tone,
    toneScore: tone == null ? null : 0.2,
    topics: topics,
    moodLabel: moodLabel,
    wordCount: JournalModel.countWords(body),
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}
