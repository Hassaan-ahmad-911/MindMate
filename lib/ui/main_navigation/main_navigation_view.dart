import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../viewmodels/main_navigation_viewmodel.dart';
import '../ai_chat/ai_chat_view.dart';
import '../home/home_view.dart';
import '../journal/journal_view.dart';
import '../mood_tracking/mood_tracking_view.dart';
import '../settings/settings_view.dart';
import '../shared/custom_bottom_nav_bar.dart';
import '../shared/mindmate_theme.dart';

/// The five tabs and the bar under them. Their ViewModels are registered by
/// [MainNavigationBinding].
class MainNavigationView extends GetView<MainNavigationViewModel> {
  const MainNavigationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: controller.selectedTabIndex.value == 0,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop && controller.selectedTabIndex.value != 0) {
            controller.selectTab(0);
          }
        },
        child: Scaffold(
          backgroundColor: context.mm.background,
          body: Obx(
            () => IndexedStack(
              index: controller.selectedTabIndex.value,
              children: const <Widget>[
                HomeView(),
                MoodTrackingView(),
                AiChatView(),
                JournalView(),
                SettingsView(),
              ],
            ),
          ),
          bottomNavigationBar: Obx(
            () => CustomBottomNavBar(
              selectedIndex: controller.selectedTabIndex.value,
              onTabChanged: (int index) {
                controller.selectTab(index);
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
          ),
        ),
      ),
    );
  }
}
