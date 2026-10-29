import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/account_data_service.dart';
import '../../services/account_deletion_service.dart';
import '../../services/data_export_service.dart';
import 'auth_repository.dart';
import 'settings_repository.dart';

/// Download my data, and deleting the account.
class AccountRepository {
  AccountRepository({
    required AccountDataBackend data,
    required AuthRepository auth,
    required SettingsRepository settings,
    Future<void> Function(List<int> bytes, String fileName)? shareFile,
    DateTime Function()? clock,
  }) : _data = data,
       _auth = auth,
       _settings = settings,
       _shareFile = shareFile ?? _shareWithSheet,
       _clock = clock ?? DateTime.now;

  final AccountDataBackend _data;
  final AuthRepository _auth;
  final SettingsRepository _settings;
  final Future<void> Function(List<int>, String) _shareFile;
  final DateTime Function() _clock;

  bool get isGoogleOnly => _auth.isGoogleOnly;

  String get email => _auth.currentUser?.email ?? '';

  /// Builds the JSON on the phone and opens the share sheet.
  Future<void> downloadMyData() async {
    final String json = await DataExportService(
      _data,
      clock: _clock,
    ).buildJson();
    await _shareFile(utf8.encode(json), DataExportService.fileName(_clock()));
  }

  static Future<void> _shareWithSheet(List<int> bytes, String fileName) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: 'application/json',
            name: fileName,
          ),
        ],
        fileNameOverrides: <String>[fileName],
      ),
    );
  }

  Future<void> reauthenticateWithPassword(String password) =>
      _auth.reauthenticateWithPassword(password);

  Future<bool> reauthenticateWithGoogle() => _auth.reauthenticateWithGoogle();

  /// Runs the deletion. Throws [AccountDeletionException] if a step fails.
  Future<void> deleteAccount({void Function(DeletionStep)? onStep}) {
    return AccountDeletionService(
      data: _data,
      deleteAuthUser: _auth.deleteCurrentUser,
      signOutGoogle: _auth.signOutFromGoogle,
      clearLocalSettings: _clearLocal,
      onStep: onStep,
    ).deleteAccount();
  }

  /// The phone's saved settings for this user: drafts, voice and sound.
  /// The theme stays: it belongs to the phone, not the account.
  Future<void> _clearLocal(String uid) async {
    _settings.clear();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final String key in prefs.getKeys().toList()) {
      if (key.contains(uid) || key == 'meditation_voice_enabled') {
        await prefs.remove(key);
      }
    }
  }
}
