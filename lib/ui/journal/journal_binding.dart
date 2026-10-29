import 'package:get/get.dart';

import '../../Data/repositories/journal_repository.dart';
import '../../services/journal_content_service.dart';
import '../../services/journal_draft_store.dart';
import '../../services/journal_firestore_service.dart';
import 'journal_viewmodel.dart';

/// Everything the journal needs. Used by the main navigation (the Journal
/// tab) and by every journal route, so the tab and the pushed Journal screen
/// share one [JournalViewModel]. Nothing is created until it is first used.
class JournalBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<JournalFirestoreService>(
      () => JournalFirestoreService(),
      fenix: true,
    );
    Get.lazyPut<JournalContentService>(
      () => JournalContentService(),
      fenix: true,
    );
    Get.lazyPut<JournalDraftStore>(() => JournalDraftStore(), fenix: true);
    Get.lazyPut<JournalRepository>(
      () => JournalRepository(
        Get.find<JournalFirestoreService>(),
        Get.find<JournalContentService>(),
        Get.find<JournalDraftStore>(),
      ),
      fenix: true,
    );
    Get.lazyPut<JournalViewModel>(
      () => JournalViewModel(Get.find<JournalRepository>()),
      fenix: true,
    );
  }
}
