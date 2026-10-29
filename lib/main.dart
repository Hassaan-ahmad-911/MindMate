import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'firebase_options.dart';
import 'services/theme_controller.dart';
import 'ui/app/mindmate_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lobster Two Bold is bundled in assets/fonts under the SIL Open Font License.
  LicenseRegistry.addLicense(() async* {
    final String license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['google_fonts'], license);
  });

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError {
    // Firebase is only configured for the mobile/web targets in this app.
  }

  // The theme is kept on the phone, so it applies from the first frame,
  // before sign-in.
  Get.put<ThemeController>(await ThemeController.load(), permanent: true);

  runApp(const MindMateApp());
}
