import 'package:get/get.dart';

import '../../Data/repositories/assessment_repository.dart';
import '../../services/assessment_content_service.dart';
import '../../services/assessment_firestore_service.dart';
import '../../services/share_service.dart';

/// The check-in services and repository, shared by every check-in route and
/// created the first time one is opened.
class AssessmentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AssessmentFirestoreService>(
      () => AssessmentFirestoreService(),
      fenix: true,
    );
    Get.lazyPut<AssessmentContentService>(
      () => AssessmentContentService(),
      fenix: true,
    );
    Get.lazyPut<AssessmentRepository>(
      () => AssessmentRepository(
        Get.find<AssessmentFirestoreService>(),
        Get.find<AssessmentContentService>(),
      ),
      fenix: true,
    );
    Get.lazyPut<ShareService>(() => ShareService(), fenix: true);
  }
}
