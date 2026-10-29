import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/journal_repository.dart';
import '../../Models/journal_content.dart';
import '../../Models/journal_rules.dart';
import '../app/app_routes.dart';
import 'journal_args.dart';

/// "How do you want to write?": pick one of the four templates.
class JournalChooseViewModel extends GetxController {
  JournalChooseViewModel(
    this._repository, {
    JournalWriteArgs? args,
    DateTime Function()? clock,
  }) : _args = args ?? const JournalWriteArgs(),
       _clock = clock ?? DateTime.now;

  final JournalRepository _repository;
  final JournalWriteArgs _args;
  final DateTime Function() _clock;

  final RxList<JournalTemplate> templates = <JournalTemplate>[].obs;
  final RxString selected = ''.obs;
  final RxBool hasError = false.obs;

  @override
  void onInit() {
    super.onInit();
    selected.value = _args.type ?? JournalDefaults.templateFor(_clock());
    unawaited(load());
  }

  Future<void> load() async {
    hasError.value = false;
    try {
      final JournalContent content = await _repository.loadContent();
      templates.assignAll(content.templates);
    } catch (_) {
      hasError.value = true;
    }
  }

  void select(String type) => selected.value = type;

  void startWriting() {
    Get.offNamed<void>(
      AppRoutes.journalWrite,
      arguments: JournalWriteArgs(
        type: selected.value,
        prompt: _args.prompt,
        linkMood: _args.linkMood,
      ),
    );
  }

  void close() => Get.back<void>();
}
