import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/mood_catalog.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'log_mood_viewmodel.dart';
import 'widgets/log_step_scaffold.dart';
import 'widgets/mood_icon.dart';
import 'widgets/mood_visuals.dart';
import 'widgets/mood_widgets.dart';

/// Log step 1: pick a mood.
class LogMoodPickView extends GetView<LogMoodViewModel> {
  const LogMoodPickView({super.key});

  @override
  Widget build(BuildContext context) {
    return LogStepScaffold(
      step: 1,
      onLeading: controller.goBack,
      bottom: Obx(
        () => GradientButton(
          label: 'Continue',
          onPressed: controller.canContinue
              ? controller.continueToStrength
              : null,
        ),
      ),
      children: <Widget>[
        Semantics(
          header: true,
          child: Text('How are you feeling?', style: AppFonts.title(size: 36)),
        ),
        const SizedBox(height: 4),
        Text('Pick the one that fits best.', style: AppFonts.body(size: 15)),
        for (final MoodGroup group in MoodGroup.values) ...<Widget>[
          const SizedBox(height: 22),
          MoodSectionLabel(group.sectionTitle),
          const SizedBox(height: 10),
          _MoodGrid(moods: MoodCatalog.inGroup(group)),
        ],
      ],
    );
  }
}

class _MoodGrid extends GetView<LogMoodViewModel> {
  const _MoodGrid({required this.moods});

  final List<MoodDefinition> moods;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.3,
      clipBehavior: Clip.none,
      children: moods
          .map(
            (MoodDefinition mood) => Obx(
              () => _MoodTile(
                mood: mood,
                selected: controller.selectedMood.value == mood,
                onTap: () => controller.selectMood(mood),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final MoodDefinition mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final Color foreground = selected
        ? c.textPrimary
        : MoodVisuals.foregroundFor(mood.group);
    final BorderRadius radius = BorderRadius.circular(18);

    return Semantics(
      button: true,
      selected: selected,
      label: mood.name,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: AnimatedContainer(
              duration: AppMotion.of(
                context,
                const Duration(milliseconds: 180),
              ),
              decoration: BoxDecoration(
                borderRadius: radius,
                color: selected ? c.surface : null,
                gradient: selected ? null : MoodVisuals.gradientFor(mood.group),
                border: Border.all(
                  color: selected ? c.selectedRing : Colors.transparent,
                  width: 3,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: c.isDark
                        ? c.shadow
                        : AppColors.headerBlue.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: radius,
                  onTap: onTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      MoodIcon(mood.name, size: 26, color: foreground),
                      const SizedBox(height: 6),
                      Text(
                        mood.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.body(
                          size: 14,
                          weight: FontWeight.w600,
                          color: foreground,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Gold badge with a navy tick in Dark, to match the ring.
                  color: c.isDark ? AppColors.accent : AppColors.headerBlue,
                  border: Border.all(color: c.surface, width: 2),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: c.isDark ? AppColors.headerBlue : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
