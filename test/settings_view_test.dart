import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/settings_repository.dart';
import 'package:mindmate/Models/theme_preferences.dart';
import 'package:mindmate/services/theme_controller.dart';
import 'package:mindmate/ui/settings/settings_view.dart';
import 'package:mindmate/ui/settings/settings_viewmodel.dart';
import 'package:mindmate/ui/shared/app_theme_data.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_app.dart';
import 'helpers/settings_fakes.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    Get.reset();
    MindMateColors.current = MindMateColors.light;
  });

  Future<void> pumpSettings(WidgetTester tester, MindMateColors colors) async {
    // A small phone, 360 x 740.
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    MindMateColors.current = colors;
    final AuthTestApp app = AuthTestApp();
    final ThemeController theme = ThemeController(
      mode: colors.isDark ? AppThemeMode.dark : AppThemeMode.light,
      persist: false,
    );
    Get.put<SettingsViewModel>(
      SettingsViewModel(
        app.authRepository,
        profiles: app.profileRepository,
        settings: SettingsRepository(FakeSettingsService()),
        theme: theme,
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MindMateThemeData.build(colors),
        home: const SettingsView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final MindMateColors colors in <MindMateColors>[
    MindMateColors.light,
    MindMateColors.dark,
  ]) {
    final String name = colors.isDark ? 'Dark' : 'Light';

    testWidgets('Settings renders in $name without overflow', (
      WidgetTester tester,
    ) async {
      // Any overflow fails the test on its own, with the details.
      await pumpSettings(tester, colors);

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Mood at 20:00'), findsOneWidget);
      expect(find.text(name), findsOneWidget, reason: 'the Theme row value');
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ??
            Theme.of(
              tester.element(find.byType(SettingsView)),
            ).scaffoldBackgroundColor,
        isNotNull,
      );

      // Scroll to the end: every group fits.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.textContaining('Version 1.0.0'), findsOneWidget);
    });
  }
}
