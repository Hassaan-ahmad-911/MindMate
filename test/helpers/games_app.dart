import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/break_repository.dart';
import 'package:mindmate/Data/repositories/gratitude_repository.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/games/breathing_bubble_view.dart';
import 'package:mindmate/ui/games/breathing_bubble_viewmodel.dart';
import 'package:mindmate/ui/games/calm_match_view.dart';
import 'package:mindmate/ui/games/calm_match_viewmodel.dart';
import 'package:mindmate/ui/games/games_hub_view.dart';
import 'package:mindmate/ui/games/games_hub_viewmodel.dart';
import 'package:mindmate/ui/games/gratitude_garden_view.dart';
import 'package:mindmate/ui/games/gratitude_garden_viewmodel.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';

import 'games_fakes.dart';

/// The real "Take a break" screens and routes (as in `app_pages.dart`), wired
/// to fakes instead of Firestore.
class GamesTestApp {
  GamesTestApp({
    FakeBreakService? breaks,
    FakeGratitudeService? gratitude,
    DateTime Function()? clock,
    this.random,
  }) : breaks = breaks ?? FakeBreakService(),
       gratitude = gratitude ?? FakeGratitudeService(),
       clock = clock ?? DateTime.now;

  final FakeBreakService breaks;
  final FakeGratitudeService gratitude;
  final DateTime Function() clock;
  final Random? random;

  /// A page under the hub, so "back" has somewhere to land.
  static const String homePlaceholder = '/home-placeholder';

  Widget build({String initialRoute = AppRoutes.games}) {
    final BreakRepository breakRepo = BreakRepository(breaks);
    final GratitudeRepository gratitudeRepo = GratitudeRepository(gratitude);

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      initialRoute: initialRoute,
      getPages: <GetPage<dynamic>>[
        GetPage(
          name: homePlaceholder,
          page: () => const Scaffold(body: Center(child: Text('HOME'))),
        ),
        GetPage(
          name: AppRoutes.games,
          page: () => const GamesHubView(),
          binding: BindingsBuilder(() {
            Get.put<GamesHubViewModel>(
              GamesHubViewModel(breakRepo, gratitudeRepo, clock: clock),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.breathingBubble,
          page: () => const BreathingBubbleView(),
          binding: BindingsBuilder(() {
            Get.put<BreathingBubbleViewModel>(
              BreathingBubbleViewModel(breakRepo, clock: clock),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.calmMatch,
          page: () => const CalmMatchView(),
          binding: BindingsBuilder(() {
            Get.put<CalmMatchViewModel>(
              CalmMatchViewModel(breakRepo, random: random, clock: clock),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.gratitudeGarden,
          page: () => const GratitudeGardenView(),
          binding: BindingsBuilder(() {
            Get.put<GratitudeGardenViewModel>(
              GratitudeGardenViewModel(gratitudeRepo, breakRepo, clock: clock),
            );
          }),
        ),
      ],
    );
  }
}
