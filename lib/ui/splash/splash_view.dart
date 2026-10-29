import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shared/mindmate_theme.dart';

import 'splash_animation.dart';
import 'splash_viewmodel.dart';

class SplashView extends GetView<SplashViewModel> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    // The splash keeps its light look in both themes.
    return Scaffold(
      backgroundColor: MindMateColors.cream,
      body: MindMateSplashAnimation(onFinished: controller.onAnimationFinished),
    );
  }
}
