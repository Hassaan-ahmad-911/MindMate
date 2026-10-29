import 'package:flutter/services.dart';

import '../Models/journal_content.dart';

/// Loads and parses the journal content file once, then keeps the result.
class JournalContentService {
  JournalContentService({Future<String> Function()? loader})
    : _loader =
          loader ?? (() => rootBundle.loadString(JournalContent.assetPath));

  final Future<String> Function() _loader;

  JournalContent? _content;
  Future<JournalContent>? _loading;

  /// The content already loaded, or null before [load] has finished.
  JournalContent? get content => _content;

  Future<JournalContent> load() {
    final JournalContent? cached = _content;
    if (cached != null) {
      return Future<JournalContent>.value(cached);
    }
    return _loading ??= _loadAndParse();
  }

  Future<JournalContent> _loadAndParse() async {
    try {
      final JournalContent content = JournalContent.fromJson(await _loader());
      _content = content;
      return content;
    } catch (_) {
      // Let the next call try again.
      _loading = null;
      rethrow;
    }
  }
}
