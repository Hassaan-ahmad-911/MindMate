import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/meditation_feeling.dart';
import '../../Models/meditation_models.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/breathing_tick.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'meditation_player_viewmodel.dart';
import 'widgets/feeling_widgets.dart';
import 'widgets/meditation_widgets.dart';

/// "Well done": how the user feels now, and this week so far.
class MeditationCompleteView extends GetView<MeditationPlayerViewModel> {
  const MeditationCompleteView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back leaves the practice, rather than going back into the player.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          controller.done();
        }
      },
      child: PracticeLoader(
        controller: controller,
        builder: (BuildContext context, MeditationSession session) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(
              children: <Widget>[
                const Positioned.fill(child: BlendedBackground()),
                const Positioned(
                  right: -110,
                  top: -140,
                  child: BlobShape(size: 300, gradient: AppBlends.blueShape),
                ),
                const Positioned(
                  left: 44,
                  top: 100,
                  child: GlowDot(
                    size: 30,
                    gradient: AppBlends.gold,
                    glowColor: Color(0x80E4B266),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      // A smaller tick on short screens.
                      final double tick = (constraints.maxHeight * 0.3)
                          .clamp(130.0, 210.0)
                          .toDouble();

                      return Column(
                        children: <Widget>[
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Center(
                                    child: BreathingTick(
                                      size: tick,
                                      semanticLabel: 'Practice complete',
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      'Well done',
                                      textAlign: TextAlign.center,
                                      style: AppFonts.title(size: 46),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${session.title} · ${session.lengthLabel}',
                                    textAlign: TextAlign.center,
                                    style: AppFonts.body(size: 16),
                                  ),
                                  const SizedBox(height: 20),
                                  const _FeelingCard(),
                                  const SizedBox(height: 14),
                                  const _WeekChips(),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                GradientButton(
                                  label: 'Done',
                                  icon: null,
                                  onPressed: controller.done,
                                ),
                                Center(
                                  child: MoodTextLink(
                                    label: 'Log this in Mood',
                                    onTap: controller.logInMood,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "How do you feel now?" with the five faces, and the before-and-after line.
class _FeelingCard extends GetView<MeditationPlayerViewModel> {
  const _FeelingCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'How do you feel now?',
            style: AppFonts.body(
              size: 17.5,
              weight: FontWeight.w600,
              color: context.mm.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Obx(
            () => FeelingPicker(
              value: controller.feelAfter.value,
              onSelected: controller.setFeelAfter,
              style: FeelingPickerStyle.gold,
            ),
          ),
          Obx(() {
            final String? before = MeditationFeeling.labelFor(
              controller.feelBefore.value,
            );
            final String? after = MeditationFeeling.labelFor(
              controller.feelAfter.value,
            );
            if (before == null || after == null) {
              return const SizedBox.shrink();
            }

            final TextStyle style = AppFonts.body(
              size: 15,
              weight: FontWeight.w600,
              color: AppColors.headerBlue,
            );
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Semantics(
                label: 'Before: $before. Now: $after.',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    // Nearly solid peach in Dark, so the navy text stays
                    // readable.
                    color: AppColors.softSurface.withValues(
                      alpha: context.mm.isDark ? 0.92 : 0.65,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(child: Text('Before: $before', style: style)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.headerBlue,
                        ),
                      ),
                      Flexible(child: Text('Now: $after', style: style)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// "27 min this week" and "4 day streak".
class _WeekChips extends GetView<MeditationPlayerViewModel> {
  const _WeekChips();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: <Widget>[
          InfoChip(
            icon: Icons.schedule_rounded,
            label: '${controller.weekMinutes.value} min this week',
          ),
          InfoChip(
            icon: Icons.local_fire_department_rounded,
            label: '${controller.streak.value} day streak',
          ),
        ],
      ),
    );
  }
}
