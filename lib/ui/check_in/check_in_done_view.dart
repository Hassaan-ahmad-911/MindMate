import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/check_in_planner.dart';
import '../meditation/widgets/meditation_widgets.dart';
import '../mood_tracking/widgets/mood_icon.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'check_in_viewmodel.dart';

/// "All set": a welcome, one focus, and three places to start.
class CheckInDoneView extends GetView<CheckInViewModel> {
  const CheckInDoneView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back goes Home rather than into the questions again.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          controller.goHome();
        }
      },
      child: Scaffold(
        backgroundColor: context.mm.background,
        body: Stack(
          children: <Widget>[
            const Positioned.fill(child: BlendedBackground()),
            const Positioned(
              right: -100,
              top: -135,
              child: BlobShape(size: 260, gradient: AppBlends.blueShape),
            ),
            const Positioned(
              left: 44,
              top: 64,
              child: GlowDot(
                size: 28,
                gradient: AppBlends.gold,
                glowColor: Color(0x80E4B266),
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 118, 20, 16),
                      children: <Widget>[
                        const MoodSectionLabel('You are all set'),
                        const SizedBox(height: 6),
                        Obx(() {
                          final String name = controller.firstName.value;
                          return Semantics(
                            header: true,
                            child: Text(
                              name.isEmpty ? 'Welcome' : 'Welcome, $name',
                              style: AppFonts.title(size: 44, height: 1.1),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        Obx(
                          () => Text(
                            controller.answeredCheckIn.value
                                ? 'Here is where MindMate suggests you start, '
                                      'based on your answers.'
                                : 'Here is a gentle place to start. You can '
                                      'finish your check-in any time from Home.',
                            style: AppFonts.body(size: 16, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _FocusCard(),
                        const _SupportLine(),
                        const SizedBox(height: 14),
                        const _StartingPoints(),
                        const SizedBox(height: 10),
                        Text(
                          'You can change any of this later in Settings.',
                          textAlign: TextAlign.center,
                          style: AppFonts.label(size: 13.5),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: GradientButton(
                      label: 'Go to home',
                      onPressed: controller.goHome,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends GetView<CheckInViewModel> {
  const _FocusCard();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final CheckInPlan? plan = controller.plan.value;
      if (plan == null) {
        return const SizedBox.shrink();
      }
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          gradient: AppBlends.blue,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: context.mm.isDark
                  ? context.mm.shadow
                  : const Color(0x4D1F3550),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'YOUR FOCUS',
              style: AppFonts.label(
                size: 12.5,
                weight: FontWeight.w600,
                letterSpacing: 1.6,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              plan.focus.title,
              style: AppFonts.body(
                size: 24,
                weight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// A calm line, only when the answers suggest things have felt heavy.
class _SupportLine extends GetView<CheckInViewModel> {
  const _SupportLine();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!(controller.plan.value?.showSupportLine ?? false)) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Opaque in Dark so the navy text keeps its contrast.
            color: AppColors.softSurface.withValues(
              alpha: context.mm.isDark ? 1 : 0.6,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.favorite_border_rounded,
                  size: 18,
                  color: AppColors.headerBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  CheckInPlanner.supportLine,
                  style: AppFonts.body(
                    size: 14.5,
                    color: AppColors.textDark,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _StartingPoints extends GetView<CheckInViewModel> {
  const _StartingPoints();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        children: controller.startingPoints
            .map(
              (StartingPoint point) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  button: true,
                  label: '${point.title}. ${point.subtitle}',
                  onTap: () => controller.openStartingPoint(point),
                  excludeSemantics: true,
                  child: AppCard(
                    onTap: () => controller.openStartingPoint(point),
                    radius: 20,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        point.session == null
                            ? Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: AppBlends.gold,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: const MoodIcon('Happy', size: 24),
                              )
                            : SessionIconTile(
                                session: point.session!,
                                size: 46,
                              ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                point.title,
                                style: AppFonts.body(
                                  size: 16.5,
                                  weight: FontWeight.w600,
                                  color: context.mm.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                point.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.label(size: 13.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
