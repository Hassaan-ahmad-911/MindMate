import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/meditation_models.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'meditation_player_viewmodel.dart';
import 'widgets/feeling_widgets.dart';
import 'widgets/meditation_widgets.dart';

/// "Before you begin": one tap to say how you feel, and the voice switch.
class MeditationCheckInView extends GetView<MeditationPlayerViewModel> {
  const MeditationCheckInView({super.key});

  @override
  Widget build(BuildContext context) {
    return PracticeLoader(
      controller: controller,
      builder: (BuildContext context, MeditationSession session) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: BlendedBackground(
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CircleIconButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Back',
                        onPressed: Get.back,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            'Before you begin',
                            style: AppFonts.title(size: 38),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PracticeSummary(session: session),
                        const SizedBox(height: 28),
                        Text(
                          'How do you feel right now?',
                          style: AppFonts.body(
                            size: 20,
                            weight: FontWeight.w600,
                            color: context.mm.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'One tap. It lets you see whether the practice made '
                          'a difference.',
                          style: AppFonts.body(size: 15, height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        Obx(
                          () => FeelingPicker(
                            value: controller.feelBefore.value,
                            onSelected: controller.setFeelBefore,
                          ),
                        ),
                        if (session.hasVoice) ...<Widget>[
                          const SizedBox(height: 26),
                          const _VoiceCard(),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        GradientButton(
                          label: 'Start practice',
                          icon: Icons.play_arrow_rounded,
                          onPressed: controller.startPractice,
                        ),
                        Center(
                          child: MoodTextLink(
                            label: 'Skip the check-in',
                            onTap: controller.skipCheckIn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PracticeSummary extends StatelessWidget {
  const _PracticeSummary({required this.session});

  final MeditationSession session;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Row(
        children: <Widget>[
          SessionIconTile(session: session, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.body(
                    size: 17,
                    weight: FontWeight.w600,
                    color: context.mm.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    session.lengthLabel,
                    if (session.technique.isNotEmpty) session.technique,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.label(size: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceCard extends GetView<MeditationPlayerViewModel> {
  const _VoiceCard();

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      radius: 20,
      child: Row(
        children: <Widget>[
          Icon(Icons.volume_up_outlined, size: 24, color: c.textPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Voice guidance',
                  style: AppFonts.body(
                    size: 16.5,
                    weight: FontWeight.w600,
                    color: c.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Each step is read aloud. Text always shows.',
                  style: AppFonts.label(size: 13.5),
                ),
              ],
            ),
          ),
          Obx(
            () => Semantics(
              label: 'Voice guidance',
              child: Switch(
                value: controller.voiceEnabled.value,
                onChanged: controller.setVoiceGuidance,
                thumbColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) =>
                      states.contains(WidgetState.selected)
                      ? AppColors.accent
                      : Colors.white,
                ),
                trackColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) =>
                      states.contains(WidgetState.selected)
                      // A navy track would vanish on the Dark navy card.
                      ? (c.isDark ? AppColors.primary : AppColors.headerBlue)
                      : AppColors.secondary.withValues(alpha: 0.6),
                ),
                trackOutlineColor: WidgetStateProperty.all<Color>(
                  Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
