import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'check_in_viewmodel.dart';

/// "A quick check-in": what it is, and a choice to begin or do it later.
class CheckInIntroView extends GetView<CheckInViewModel> {
  const CheckInIntroView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          const Positioned(
            right: -120,
            top: -150,
            child: BlobShape(size: 340, gradient: AppBlends.blueShape),
          ),
          const Positioned(
            left: 36,
            top: 130,
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
                      const _Hero(),
                      Semantics(
                        header: true,
                        child: Text(
                          'A quick check-in',
                          style: AppFonts.title(size: 42),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A few questions about how you have been lately, so '
                        'MindMate can suggest what fits you.',
                        style: AppFonts.body(size: 16, height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      const _Points(),
                      const SizedBox(height: 14),
                      const _Note(),
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
                        label: 'Begin',
                        onPressed: controller.begin,
                      ),
                      Center(
                        child: MoodTextLink(
                          label: 'Do this later',
                          onTap: controller.doLater,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A heart in a cream disc, on the blue shape.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return SizedBox(
      height: 190,
      child: Align(
        alignment: const Alignment(0.5, 0),
        child: Container(
          width: 156,
          height: 156,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surface.withValues(alpha: 0.35),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 132,
            height: 132,
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
            child: Icon(
              Icons.favorite_border_rounded,
              size: 58,
              color: c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Points extends StatelessWidget {
  const _Points();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: <Widget>[
          const _Point(
            icon: Icons.schedule_rounded,
            gradient: AppBlends.gold,
            text: 'About 2 minutes, 9 questions',
          ),
          Divider(height: 1, color: context.mm.divider),
          _Point(
            icon: Icons.lock_outline_rounded,
            gradient: AppBlends.blue,
            iconColor: Colors.white,
            text: 'Private. Never shared with your employer.',
          ),
          Divider(height: 1, color: context.mm.divider),
          const _Point(
            icon: Icons.skip_next_rounded,
            gradient: AppBlends.lightBlue,
            text: 'Skip any question you like',
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({
    required this.icon,
    required this.gradient,
    required this.text,
    this.iconColor = AppColors.headerBlue,
  });

  final IconData icon;
  final Gradient gradient;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: AppFonts.body(
                size: 16,
                weight: FontWeight.w500,
                color: context.mm.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "This is a self check-in, not a diagnosis or a medical assessment."
class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.headerBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is a self check-in, not a diagnosis or a medical '
              'assessment.',
              style: AppFonts.body(
                size: 14.5,
                color: AppColors.textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
