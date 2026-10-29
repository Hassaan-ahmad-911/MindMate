import 'package:mindmate/services/account_data_service.dart';
import 'package:mindmate/services/settings_firestore_service.dart';

/// User documents in memory, one per uid. Every single-field write is
/// recorded and applied, so a fresh repository reads it back.
class FakeSettingsService extends SettingsFirestoreService {
  FakeSettingsService({Map<String, dynamic>? userDoc, this.uid = 'uid-1'}) {
    docs[uid] = userDoc ?? <String, dynamic>{};
  }

  String uid;
  final Map<String, Map<String, dynamic>> docs =
      <String, Map<String, dynamic>>{};
  final List<MapEntry<String, Object?>> updates = <MapEntry<String, Object?>>[];
  int creates = 0;

  Map<String, dynamic> get userDoc =>
      docs.putIfAbsent(uid, () => <String, dynamic>{});

  @override
  String currentUid() => uid;

  @override
  Future<Map<String, dynamic>?> readUserDocument() async => userDoc;

  @override
  Future<void> createSettings(Map<String, dynamic> settings) async {
    creates += 1;
    userDoc['settings'] = settings;
  }

  @override
  Future<void> updateField(String path, Object? value) async {
    updates.add(MapEntry<String, Object?>(path, value));
    Map<String, dynamic> node =
        userDoc.putIfAbsent('settings', () => <String, dynamic>{})
            as Map<String, dynamic>;
    final List<String> parts = path.split('.');
    for (final String part in parts.take(parts.length - 1)) {
      node =
          node.putIfAbsent(part, () => <String, dynamic>{})
              as Map<String, dynamic>;
    }
    node[parts.last] = value;
  }
}

/// Collections in memory. [failOn] makes one operation throw once.
class FakeAccountData implements AccountDataBackend {
  FakeAccountData({this.uid = 'uid-1'});

  final String uid;
  final List<String> calls = <String>[];
  Map<String, dynamic>? user = <String, dynamic>{'name': 'Ayesha'};
  final Map<String, List<Map<String, dynamic>>> collections =
      <String, List<Map<String, dynamic>>>{};
  List<Map<String, dynamic>> legacy = <Map<String, dynamic>>[];
  bool photo = true;

  /// e.g. 'deleteProfilePhoto' fails the next time it is called.
  String? failOn;

  void _maybeFail(String op) {
    calls.add(op);
    if (failOn == op) {
      failOn = null;
      throw StateError('offline');
    }
  }

  @override
  String currentUid() => uid;

  @override
  Future<Map<String, dynamic>?> readUserDocument(String uid) async => user;

  @override
  Future<List<Map<String, dynamic>>> readSubcollection(
    String uid,
    String name,
  ) async => collections[name] ?? <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> readLegacyJournals(String uid) async =>
      legacy;

  @override
  Future<int> deleteSubcollection(String uid, String name) async {
    _maybeFail('deleteSubcollection:$name');
    final int n = collections[name]?.length ?? 0;
    collections.remove(name);
    return n;
  }

  @override
  Future<int> deleteLegacyJournals(String uid) async {
    _maybeFail('deleteLegacyJournals');
    final int n = legacy.length;
    legacy = <Map<String, dynamic>>[];
    return n;
  }

  @override
  Future<void> deleteProfilePhoto(String uid) async {
    _maybeFail('deleteProfilePhoto');
    photo = false; // Deleting a missing photo is fine.
  }

  @override
  Future<void> deleteUserDocument(String uid) async {
    _maybeFail('deleteUserDocument');
    user = null;
  }
}
