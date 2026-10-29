import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Models/meditation_audio.dart';
import '../../shared/mindmate_theme.dart';

/// "Background sound": Off, Soft rain or Warm tones, and the volume. A
/// choice plays at once so it can be heard.
/// Used by the meditation player and by Settings, so both change the same
/// remembered choice. [selected] and [volume] are read inside an Obx, so
/// pass getters of Rx values.
Future<void> showBackgroundSoundSheet(
  BuildContext context, {
  required AmbientChoice Function() selected,
  required double Function() volume,
  required ValueChanged<AmbientChoice> onSelect,
  required ValueChanged<double> onVolume,
  required VoidCallback onVolumeEnd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.mm.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Obx(() {
            final AmbientChoice current = selected();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    'Background sound',
                    style: AppFonts.body(
                      size: 19,
                      weight: FontWeight.w700,
                      color: sheetContext.mm.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (final AmbientChoice choice in AmbientChoice.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SoundOption(
                      choice: choice,
                      selected: choice == current,
                      onTap: () => onSelect(choice),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.volume_down_rounded,
                      color: sheetContext.mm.textPrimary,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(sheetContext).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.secondary.withValues(
                            alpha: 0.35,
                          ),
                          thumbColor: AppColors.accent,
                          overlayColor: AppColors.accent.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: volume(),
                          max: MeditationAudioRules.maxAmbientVolume,
                          label: 'Volume',
                          semanticFormatterCallback: (double v) =>
                              '${(v / MeditationAudioRules.maxAmbientVolume * 100).round()} percent',
                          onChanged: current == AmbientChoice.off
                              ? null
                              : onVolume,
                          onChangeEnd: (_) => onVolumeEnd(),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.volume_up_rounded,
                      color: sheetContext.mm.textPrimary,
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      );
    },
  );
}

class _SoundOption extends StatelessWidget {
  const _SoundOption({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final AmbientChoice choice;
  final bool selected;
  final VoidCallback onTap;

  static IconData _icon(AmbientChoice c) {
    switch (c) {
      case AmbientChoice.off:
        return Icons.volume_off_rounded;
      case AmbientChoice.softRain:
        return Icons.water_drop_outlined;
      case AmbientChoice.warmTones:
        return Icons.graphic_eq_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(18);
    final MindMateColors c = context.mm;
    final Color ink = selected ? Colors.white : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: choice.label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: selected ? AppBlends.blueHorizontal : null,
          color: selected ? null : c.surface,
          border: selected || c.surfaceBorder == null
              ? null
              : Border.all(color: c.surfaceBorder!),
          borderRadius: radius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: <Widget>[
                  Icon(_icon(choice), color: ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      choice.label,
                      style: AppFonts.body(
                        size: 16.5,
                        weight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppBlends.gold,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.headerBlue,
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
