import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'mood_saved_viewmodel.dart';
import 'widgets/mood_widgets.dart';

/// Shown after an entry is saved.
class MoodSavedView extends GetView<MoodSavedViewModel> {
  const MoodSavedView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final MoodNextStep step = controller.nextStep;

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          const Positioned(
            right: -110,
            top: -140,
            child: BlobShape(size: 300, gradient: AppBlends.blueShape),
          ),
          const Positioned(
            left: -120,
            top: 300,
            child: BlobShape(
              size: 220,
              gradient: AppBlends.gold,
              points: blobShapeB,
            ),
          ),
          const Positioned(
            left: 44,
            top: 118,
            child: GlowDot(
              size: 30,
              gradient: AppBlends.gold,
              glowColor: Color(0x80E4B266),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Spacer(),
                          const Center(child: _BreathingTick()),
                          const SizedBox(height: 18),
                          Semantics(
                            header: true,
                            child: Text(
                              'Saved',
                              textAlign: TextAlign.center,
                              style: AppFonts.title(size: 46),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            controller.summaryLine,
                            textAlign: TextAlign.center,
                            style: AppFonts.body(size: 16, color: c.textBody),
                          ),
                          const SizedBox(height: 14),
                          Center(child: _StreakChip(streak: controller.streak)),
                          const SizedBox(height: 26),
                          _NextStepCard(
                            step: step,
                            onTap: controller.openNextStep,
                          ),
                          if (controller.showSupportLine) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              'If things feel too heavy, talking to someone '
                              'you trust or a professional can help.',
                              textAlign: TextAlign.center,
                              style: AppFonts.body(size: 14, color: c.textBody),
                            ),
                          ],
                          const Spacer(flex: 2),
                          const SizedBox(height: 20),
                          GradientButton(
                            label: 'Done',
                            icon: null,
                            onPressed: controller.done,
                          ),
                          Center(
                            child: MoodTextLink(
                              label: 'See my insights',
                              onTap: controller.openInsights,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A tick in a navy circle with softly breathing rings around it.
class _BreathingTick extends StatefulWidget {
  const _BreathingTick();

  @override
  State<_BreathingTick> createState() => _BreathingTickState();
}

class _BreathingTickState extends State<_BreathingTick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _breath.stop();
      _breath.value = 0.5;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      label: 'Entry saved',
      child: SizedBox(
        width: 230,
        height: 230,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (BuildContext context, Widget? child) {
            final double t = Curves.easeInOut.transform(_breath.value);
            Widget ring(double size, double minScale, double opacity) {
              return Transform.scale(
                scale: minScale + (1 - minScale) * t,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary.withValues(alpha: opacity),
                  ),
                ),
              );
            }

            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ring(230, 0.78, 0.18),
                ring(172, 0.86, 0.28),
                ring(132, 0.92, 0.45),
                child!,
              ],
            );
          },
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: c.blueBlend,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
                width: 5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: c.isDark ? c.shadow : const Color(0x4D1F3550),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 52,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.local_fire_department_rounded,
            size: 16,
            color: AppColors.accent,
          ),
          const SizedBox(width: 6),
          Text(
            '$streak day streak',
            style: AppFonts.body(
              size: 14,
              weight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.step, required this.onTap});

  final MoodNextStep step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: context.mm.blueBlend,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(step.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const MoodSectionLabel('A small next step'),
                const SizedBox(height: 4),
                Text(
                  step.text,
                  style: AppFonts.body(
                    size: 17,
                    weight: FontWeight.w600,
                    color: context.mm.textPrimary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppBlends.gold,
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: AppColors.headerBlue,
            ),
          ),
        ],
      ),
    );
  }
}
