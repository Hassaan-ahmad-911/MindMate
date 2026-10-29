import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Bindings/initial_binding.dart';
import '../../services/theme_controller.dart';
import '../shared/app_theme_data.dart';
import '../shared/mindmate_theme.dart';
import 'app_pages.dart';
import 'app_routes.dart';

class MindMateApp extends StatelessWidget {
  const MindMateApp({super.key});

  static final ThemeData lightTheme = MindMateThemeData.build(
    MindMateColors.light,
  );
  static final ThemeData darkTheme = MindMateThemeData.build(
    MindMateColors.dark,
  );

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>()
        : Get.put<ThemeController>(ThemeController(), permanent: true);

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MindMate',
        initialBinding: InitialBinding(),
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: theme.effectiveMode.value,
        builder: (BuildContext context, Widget? child) =>
            ThemeSync(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
