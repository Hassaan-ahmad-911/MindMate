import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/theme_preferences.dart';
import '../shared/mindmate_theme.dart';
import 'settings_viewmodel.dart';
import 'widgets/settings_widgets.dart';

/// Theme: Light, Dark or Match my phone, and "Dark after sunset". The screen
/// re-themes as soon as an option is tapped.
class ThemeView extends GetView<SettingsViewModel> {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final AppThemeMode? mode = controller.theme?.mode.value;
      final bool sunset = controller.theme?.darkAfterSunset.value ?? false;
      // Read so the footer follows the phone's own setting.
      controller.theme?.platformBrightness.value;
      final MindMateColors c = context.mm;
      return SettingsPage(
        title: 'Theme',
        subtitle: 'Pick how MindMate looks.',
        titleBelow: true,
        children: <Widget>[
          _ThemeOption(
            preview: _Preview.light,
            title: 'Light',
            line: 'Cream and blue. Easy to read in daylight.',
            selected: mode == AppThemeMode.light,
            onTap: () => controller.setThemeMode(AppThemeMode.light),
          ),
          _ThemeOption(
            preview: _Preview.dark,
            title: 'Dark',
            line: 'Gentler on your eyes at night and on night shifts.',
            selected: mode == AppThemeMode.dark,
            onTap: () => controller.setThemeMode(AppThemeMode.dark),
          ),
          _ThemeOption(
            preview: _Preview.split,
            title: 'Match my phone',
            line: "Follows your phone's light or dark setting.",
            selected: mode == AppThemeMode.system,
            onTap: () => controller.setThemeMode(AppThemeMode.system),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(22),
              border: c.surfaceBorder == null
                  ? null
                  : Border.all(color: c.surfaceBorder!),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                const SettingsIconTile(
                  icon: Icons.nightlight_round,
                  style: TileStyle.gold,
                  size: 46,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Dark after sunset',
                        style: AppFonts.body(
                          size: 16,
                          weight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        'Switch to Dark from 19:00 to 07:00',
                        style: AppFonts.label(size: 13, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                Switch(value: sunset, onChanged: controller.setDarkAfterSunset),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.info_outline_rounded, size: 16, color: c.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.theme?.footer ?? '',
                  style: AppFonts.label(size: 13, color: c.textMuted),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}

enum _Preview { light, dark, split }

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.preview,
    required this.title,
    required this.line,
    required this.selected,
    required this.onTap,
  });

  final _Preview preview;
  final String title;
  final String line;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final BorderRadius radius = BorderRadius.circular(22);
    final Color ink = selected ? Colors.white : c.textPrimary;
    final Color soft = selected ? c.onBlueMuted : c.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: '$title. $line',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: selected ? c.blueBlend : null,
            color: selected ? null : c.surface,
            borderRadius: radius,
            border: selected
                ? Border.all(color: c.selectedRing, width: 2)
                : (c.surfaceBorder == null
                      ? null
                      : Border.all(color: c.surfaceBorder!)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.shadow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Row(
                  children: <Widget>[
                    _MiniPhone(preview: preview),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: AppFonts.body(
                              size: 18,
                              weight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          Text(
                            line,
                            style: AppFonts.body(size: 13.5, color: soft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: selected ? AppBlends.gold : null,
                        border: selected
                            ? null
                            : Border.all(
                                color: AppColors.secondary,
                                width: 1.8,
                              ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: AppColors.headerBlue,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small phone showing a light, a dark, or a diagonally split screen.
class _MiniPhone extends StatelessWidget {
  const _MiniPhone({required this.preview});

  final _Preview preview;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 52,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.headerBlue, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(painter: _MiniPhonePainter(preview)),
      ),
    );
  }
}

class _MiniPhonePainter extends CustomPainter {
  const _MiniPhonePainter(this.preview);

  final _Preview preview;

  void _screen(Canvas canvas, Size size, MindMateColors c) {
    canvas.drawRect(Offset.zero & size, Paint()..color = c.background);
    final Paint card = Paint()..color = c.surface;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 6, size.width - 22, 5),
        const Radius.circular(2),
      ),
      Paint()..color = c.textPrimary,
    );
    final Rect hero = Rect.fromLTWH(5, 15, size.width - 10, 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(hero, const Radius.circular(4)),
      Paint()..shader = c.blueBlend.createShader(hero),
    );
    for (int i = 0; i < 3; i += 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(5, 35.0 + i * 11, size.width - 10, 8),
          const Radius.circular(3),
        ),
        card,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (preview) {
      case _Preview.light:
        _screen(canvas, size, MindMateColors.light);
      case _Preview.dark:
        _screen(canvas, size, MindMateColors.dark);
      case _Preview.split:
        _screen(canvas, size, MindMateColors.light);
        canvas.save();
        canvas.clipPath(
          Path()
            ..moveTo(size.width, 0)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close(),
        );
        _screen(canvas, size, MindMateColors.dark);
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MiniPhonePainter old) => old.preview != preview;
}
