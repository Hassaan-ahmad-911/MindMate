import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/meditation_audio.dart';

import '../../Models/meditation_models.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'meditation_player_viewmodel.dart';
import 'widgets/meditation_visuals.dart';
import 'widgets/meditation_widgets.dart';

/// Session details: what a practice is, who it helps and where it comes from.
class MeditationDetailsView extends GetView<MeditationPlayerViewModel> {
  const MeditationDetailsView({super.key});

  /// Shown when a practice has no note of its own.
  static const String defaultNote =
      'Keep your eyes open if you prefer. You can stop at any time.';

  @override
  Widget build(BuildContext context) {
    return PracticeLoader(
      controller: controller,
      builder: (BuildContext context, MeditationSession session) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: <Widget>[
              const Positioned.fill(child: BlendedBackground()),
              const Positioned(
                right: -120,
                top: -150,
                child: BlobShape(size: 340, gradient: AppBlends.blueShape),
              ),
              const Positioned(
                left: 40,
                top: 150,
                child: GlowDot(
                  size: 30,
                  gradient: AppBlends.gold,
                  glowColor: Color(0x80E4B266),
                ),
              ),
              SafeArea(
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
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        children: <Widget>[
                          _Hero(session: session),
                          _Details(session: session),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: GradientButton(
                        label: 'Begin',
                        icon: Icons.play_arrow_rounded,
                        onPressed: controller.beginCheckIn,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The practice's icon in a disc of the page colour, on the blue shape.
class _Hero extends StatelessWidget {
  const _Hero({required this.session});

  final MeditationSession session;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;

    return SizedBox(
      height: 168,
      child: Align(
        alignment: const Alignment(0.45, 0),
        child: Container(
          width: 152,
          height: 152,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surface.withValues(alpha: 0.35),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.background,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: c.isDark ? c.shadow : const Color(0x331F3550),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.textPrimary, width: 3),
              ),
              child: Icon(
                MeditationVisuals.iconFor(session),
                size: 40,
                color: c.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends GetView<MeditationPlayerViewModel> {
  const _Details({required this.session});

  final MeditationSession session;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final String groupTitle = controller.groupTitle ?? session.technique;
    final String note = session.safetyNote.trim().isEmpty
        ? MeditationDetailsView.defaultNote
        : session.safetyNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (groupTitle.isNotEmpty) MoodSectionLabel(groupTitle),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: Text(
            session.title,
            style: AppFonts.title(size: 40, height: 1.1),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            InfoChip(
              label: session.lengthLabel,
              icon: Icons.schedule_rounded,
              gold: true,
            ),
            if (session.posture.isNotEmpty) InfoChip(label: session.posture),
            InfoChip(
              label: session.hasVoice ? 'Calm voice' : 'Breathing timer',
            ),
            Obx(
              () => controller.ambient.value == AmbientChoice.off
                  ? const SizedBox.shrink()
                  : InfoChip(label: controller.ambient.value.label),
            ),
          ],
        ),
        if (session.about.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          Text(session.about, style: AppFonts.body(size: 16, height: 1.5)),
        ],
        if (session.goodFor.isNotEmpty ||
            session.basedOn.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (session.goodFor.isNotEmpty) ...<Widget>[
                  const MoodSectionLabel('Good for'),
                  const SizedBox(height: 4),
                  Text(
                    session.goodFor,
                    style: AppFonts.body(
                      size: 16,
                      weight: FontWeight.w600,
                      color: c.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ],
                if (session.goodFor.isNotEmpty && session.basedOn.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: c.divider),
                  ),
                if (session.basedOn.isNotEmpty) ...<Widget>[
                  const MoodSectionLabel('Where it comes from'),
                  const SizedBox(height: 4),
                  Text(
                    session.basedOn,
                    style: AppFonts.body(size: 14.5, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Nearly solid peach in Dark, so the navy text stays readable.
            color: AppColors.softSurface.withValues(
              alpha: c.isDark ? 0.92 : 0.6,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.headerBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  note,
                  style: AppFonts.body(
                    size: 14.5,
                    color: AppColors.textDark,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
