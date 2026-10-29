import 'package:flutter/services.dart';

import '../Models/assessment_definition.dart';

/// Loads and parses the check-in content file once, then keeps the result.
class AssessmentContentService {
  AssessmentContentService({Future<String> Function()? loader})
    : _loader =
          loader ?? (() => rootBundle.loadString(AssessmentContent.assetPath));

  final Future<String> Function() _loader;

  AssessmentContent? _content;
  Future<AssessmentContent>? _loading;

  AssessmentContent? get content => _content;

  Future<AssessmentContent> load() {
    final AssessmentContent? cached = _content;
    if (cached != null) {
      return Future<AssessmentContent>.value(cached);
    }
    return _loading ??= _loadAndParse();
  }

  Future<AssessmentContent> _loadAndParse() async {
    try {
      final AssessmentContent content = AssessmentContent.fromJson(
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
