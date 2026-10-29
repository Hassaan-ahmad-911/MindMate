import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'account_data_service.dart';

/// Builds "Download my data" on the phone: one JSON file with everything
/// stored for the user. Nothing is uploaded; the user shares it themselves.
class DataExportService {
  DataExportService(this._data, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AccountDataBackend _data;
  final DateTime Function() _clock;

  /// "MindMate-data-2026-10-10.json".
  static String fileName(DateTime day) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'MindMate-data-${day.year}-${two(day.month)}-${two(day.day)}.json';
  }

  Future<Map<String, dynamic>> collect() async {
    final String uid = _data.currentUid();
    final Map<String, dynamic> user = Map<String, dynamic>.from(
      await _data.readUserDocument(uid) ?? <String, dynamic>{},
    );
    final Object? settings = user.remove('settings');

    final Map<String, dynamic> out = <String, dynamic>{
      'exportedAt': _clock(),
      'app': 'MindMate',
      'profile': user,
      'settings': settings,
    };
    for (final String name in AccountDataBackend.subcollections) {
      out[name] = await _data.readSubcollection(uid, name);
    }
    // Entries not yet moved out of the old top-level collection.
    final List<Map<String, dynamic>> legacy = await _data.readLegacyJournals(
      uid,
    );
    if (legacy.isNotEmpty) {
      out['journals'] = <Map<String, dynamic>>[
        ...(out['journals'] as List<Map<String, dynamic>>),
        ...legacy,
      ];
    }
    return jsonSafe(out) as Map<String, dynamic>;
  }

  Future<String> buildJson() async =>
      const JsonEncoder.withIndent('  ').convert(await collect());

  /// Turns Firestore values into plain JSON: timestamps and dates become ISO
  /// strings, geo points and references become maps and paths.
  static Object? jsonSafe(Object? value) {
    if (value == null || value is String || value is bool || value is num) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is GeoPoint) {
      return <String, double>{
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is Map) {
      return <String, Object?>{
        for (final MapEntry<dynamic, dynamic> e in value.entries)
          '${e.key}': jsonSafe(e.value),
      };
    }
    if (value is Iterable) {
      return value.map(jsonSafe).toList();
    }
    return value.toString();
  }
}
