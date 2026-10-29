import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/mood_catalog.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'log_mood_viewmodel.dart';
import 'widgets/log_step_scaffold.dart';
import 'widgets/mood_widgets.dart';

/// Log step 2: how strong the mood is, and what's affecting it.
class LogMoodStrengthView extends GetView<LogMoodViewModel> {
  const LogMoodStrengthView({super.key});

  @override
  Widget build(BuildContext context) {
    final MoodDefinition? mood = controller.selectedMood.value;

    return LogStepScaffold(
      step: 2,
      onLeading: controller.goBack,
      bottom: GradientButton(
        label: 'Continue',
        onPressed: controller.continueToNote,
      ),
      children: <Widget>[
        if (mood != null)
          Row(
            children: <Widget>[
              MoodAvatar(mood: mood.name, group: mood.group, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "You're feeling",
                      style: AppFonts.body(
                        size: 15,
                        color: context.mm.textBody,
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(mood.name, style: AppFonts.title(size: 36)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 26),
        _Heading('How strong is it?'),
        const SizedBox(height: 12),
        Obx(
          () => Row(
            children: <Widget>[
              for (
                int i = 0;
                i < MoodCatalog.intensities.length;
                i += 1
              ) ...<Widget>[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _StrengthCard(
                    label: MoodCatalog.intensities[i],
                    level: i + 1,
                    selected:
                        controller.intensity.value ==
                        MoodCatalog.intensities[i],
                    onTap: () =>
                        controller.setIntensity(MoodCatalog.intensities[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        _Heading("What's affecting it?"),
        const SizedBox(height: 2),
        Text('Pick any that apply.', style: AppFonts.label(size: 14)),
        const SizedBox(height: 12),
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 10,
            children: MoodCatalog.factors
                .map(
                  (String factor) => _FactorChip(
                    label: factor,
                    selected: controller.isFactorSelected(factor),
                    onTap: () => controller.toggleFactor(factor),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppFonts.body(
        size: 17,
        weight: FontWeight.w600,
        color: context.mm.textPrimary,
      ),
    );
  }
}

class _StrengthCard extends StatelessWidget {
  const _StrengthCard({
    required this.label,
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final BorderRadius radius = BorderRadius.circular(18);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 180)),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected
                ? c.selectedRing
                : (c.surfaceBorder ?? Colors.transparent),
            width: 3,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.shadow,
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: <Widget>[
                  _SignalBars(level: level),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: AppFonts.body(
                      size: 15,
                      weight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three rising bars; the first [level] are filled.
class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 1; i <= 3; i += 1) ...<Widget>[
            if (i > 1) const SizedBox(width: 3),
            Container(
              width: 6,
              height: 8.0 + 7 * (i - 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i <= level
                    ? context.mm.textPrimary
                    : AppColors.secondary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactorChip extends StatelessWidget {
  const _FactorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final BorderRadius radius = BorderRadius.circular(24);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 160)),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: selected ? c.blueBlend : null,
          color: selected ? null : c.surface,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.secondary.withValues(alpha: 0.55),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (selected) ...<Widget>[
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: AppFonts.body(
                      size: 15,
                      weight: FontWeight.w500,
                      color: selected ? Colors.white : c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
