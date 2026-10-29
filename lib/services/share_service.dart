import 'package:flutter/services.dart';

/// Opens the phone's own share sheet with a short text. Uses a small native
/// method channel (see MainActivity.kt and AppDelegate.swift), so it needs no
/// package and no permissions. Nothing is sent by the app itself.
class ShareService {
  static const MethodChannel _channel = MethodChannel('mindmate/share');

  /// True if the share sheet opened.
  Future<bool> shareText(String text) async {
    try {
      final bool? opened = await _channel.invokeMethod<bool>(
        'shareText',
        <String, String>{'text': text},
      );
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
