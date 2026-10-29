import 'package:flutter/services.dart';

import '../Models/meditation_models.dart';

/// Loads and parses the practices file once, then keeps the result.
class MeditationContentService {
  MeditationContentService({Future<String> Function()? loader})
    : _loader = loader ?? (() => rootBundle.loadString(assetPath));

  static const String assetPath = 'assets/meditation/meditation_sessions.json';

  final Future<String> Function() _loader;

  MeditationContent? _content;
  Future<MeditationContent>? _loading;

  /// The practices already loaded, or null before [load] has finished.
  MeditationContent? get content => _content;

  Future<MeditationContent> load() {
    final MeditationContent? cached = _content;
    if (cached != null) {
      return Future<MeditationContent>.value(cached);
    }
    return _loading ??= _loadAndParse();
  }

  Future<MeditationContent> _loadAndParse() async {
    try {
      final MeditationContent content = MeditationContent.fromJson(
        await _loader(),
      );
      _content = content;
      return content;
    } catch (_) {
      // Let the next call try again.
      _loading = null;
      rethrow;
    }
  }
}
