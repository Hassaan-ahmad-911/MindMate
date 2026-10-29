import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Models/meditation_models.dart';
import '../../mood_tracking/widgets/mood_widgets.dart';
import '../../shared/blended_background.dart';
import '../../shared/mindmate_theme.dart';
import '../meditation_player_viewmodel.dart';
import 'meditation_visuals.dart';

/// A practice's icon on its coloured tile.
class SessionIconTile extends StatelessWidget {
  const SessionIconTile({super.key, required this.session, this.size = 52});

  final MeditationSession session;
  final double size;

  @override
  Widget build(BuildContext context) {
    final MeditationTone tone = MeditationVisuals.toneFor(session);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(
        MeditationVisuals.iconFor(session),
        size: size * 0.5,
        color: tone.foreground,
      ),
    );
  }
}

/// A small rounded label. With [gold] it uses the gold blend.
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    this.icon,
    this.gold = false,
  });

  final String label;
  final IconData? icon;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    // Navy on the gold blend; the theme's title colour on a surface chip.
    final Color foreground = gold ? AppColors.headerBlue : c.textPrimary;

    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 14 : 11, 7, 14, 7),
      decoration: BoxDecoration(
        gradient: gold ? AppBlends.gold : null,
        color: gold ? null : c.surface,
        border: gold || c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: AppFonts.body(
                size: 14,
                weight: FontWeight.w600,
                color: foreground,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The length chip on a practice card, e.g. "3 min".
class LengthChip extends StatelessWidget {
  const LengthChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppFonts.body(
          size: 13,
          weight: FontWeight.w600,
          color: context.mm.textPrimary,
          height: 1.1,
        ),
      ),
    );
  }
}

/// A number with a label under it, on a coloured tile.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.gradient,
    required this.foreground,
  });

  final String value;
  final String label;
  final Gradient gradient;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppFonts.body(
                size: 28,
                weight: FontWeight.w700,
                color: foreground,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: AppFonts.label(size: 13, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a spinner while a practice loads and a message if it cannot be
/// opened; otherwise builds the screen for it.
class PracticeLoader extends StatelessWidget {
  const PracticeLoader({
    super.key,
    required this.controller,
    required this.builder,
  });

  final MeditationPlayerViewModel controller;
  final Widget Function(BuildContext context, MeditationSession session)
  builder;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final MeditationSession? session = controller.session.value;
      if (session != null) {
        return builder(context, session);
      }

      final bool failed =
          controller.hasLoadError.value && !controller.isLoading.value;
      return Scaffold(
        backgroundColor: AppColors.background,
        body: BlendedBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Back',
                    onPressed: Get.back,
                  ),
                  Expanded(
                    child: Center(
                      child: failed
                          ? MoodMessageCard(
                              icon: Icons.error_outline_rounded,
                              title: 'Could not open this practice',
                              message: 'Please go back and try again.',
                              actionLabel: 'Go back',
                              onAction: Get.back,
                            )
                          : const CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
