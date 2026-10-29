import 'dart:async';

import 'package:mindmate/Data/repositories/break_repository.dart';
import 'package:mindmate/Data/repositories/gratitude_repository.dart';
import 'package:mindmate/Models/break_log.dart';
import 'package:mindmate/Models/gratitude_entry.dart';
import 'package:mindmate/services/break_log_service.dart';
import 'package:mindmate/services/gratitude_service.dart';

/// Keeps breaks in memory instead of Firestore.
class FakeBreakService extends BreakLogService {
  /// What the store holds (the week query filters these).
  final List<BreakLogEntry> stored = <BreakLogEntry>[];

  /// Every write, in order.
  final List<BreakLogEntry> saved = <BreakLogEntry>[];

  bool failSaving = false;
  bool failLoading = false;
  int _next = 0;

  @override
  String newId() => 'break-${++_next}';

  @override
  Future<void> saveBreak(BreakLogEntry entry) async {
    if (failSaving) {
      throw StateError('offline');
    }
    saved.add(entry);
    stored.add(entry);
  }

  @override
  Future<List<BreakLogEntry>> getBreaksSince(DateTime start) async {
    if (failLoading) {
      throw StateError('offline');
    }
    return stored
        .where((BreakLogEntry e) => !e.startedAt.isBefore(start))
        .toList();
  }
}

/// Keeps gratitude entries in memory instead of Firestore.
class FakeGratitudeService extends GratitudeService {
  FakeGratitudeService([Iterable<GratitudeEntry> entries = const []]) {
    for (final GratitudeEntry entry in entries) {
      store[entry.dateKey] = entry;
    }
  }

  final Map<String, GratitudeEntry> store = <String, GratitudeEntry>{};
  int creates = 0;
  int edits = 0;
  int deletes = 0;

  /// The next write or read fails with this.
  Object? failWith;

  /// Writes never finish (like being offline).
  bool neverFinishes = false;

  @override
  Future<List<GratitudeEntry>> getEntries() async {
    final Object? failure = failWith;
    if (failure != null) {
      throw failure;
    }
    final List<GratitudeEntry> list = store.values.toList();
    list.sort((GratitudeEntry a, GratitudeEntry b) {
      return b.dateKey.compareTo(a.dateKey);
    });
    return list;
  }

  Future<void> _write(void Function() apply) {
    if (neverFinishes) {
      return Completer<void>().future;
    }
    final Object? failure = failWith;
    if (failure != null) {
      return Future<void>.error(failure);
    }
    apply();
    return Future<void>.value();
  }

  @override
  Future<void> create(GratitudeEntry entry) {
    return _write(() {
      creates += 1;
      store[entry.dateKey] = entry;
    });
  }

  @override
  Future<void> updateText(GratitudeEntry entry) {
    return _write(() {
      edits += 1;
      store[entry.dateKey] = entry;
    });
  }

  @override
  Future<void> delete(String dateKey) {
    return _write(() {
      deletes += 1;
      store.remove(dateKey);
    });
  }
}

GratitudeEntry entryOn(DateTime day, String text) {
  final DateTime noon = DateTime(day.year, day.month, day.day, 12);
  return GratitudeEntry(
    dateKey: GratitudeRules.dateKey(day),
    text: text,
    createdAt: noon,
    updatedAt: noon,
  );
}

BreakRepository breakRepository(FakeBreakService service) =>
    BreakRepository(service);

GratitudeRepository gratitudeRepository(FakeGratitudeService service) =>
    GratitudeRepository(service);
