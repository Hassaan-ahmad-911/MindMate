import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class MainNavigationViewModel extends GetxController {
  MainNavigationViewModel({this.onHomeSelected});

  /// Called when the Home tab is opened from another tab.
  final VoidCallback? onHomeSelected;

  final RxInt selectedTabIndex = 0.obs;

  void selectTab(int index) {
    final int previous = selectedTabIndex.value;
    selectedTabIndex.value = index;
    if (index == 0 && previous != 0) {
      onHomeSelected?.call();
    }
  }
}
