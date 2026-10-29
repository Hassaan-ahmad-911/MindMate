import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'mindmate_theme.dart';

/// The Material theme for Light or Dark, built from [MindMateColors], so
/// dialogs, sheets, switches, inputs and snackbars follow the theme too.
class MindMateThemeData {
  const MindMateThemeData._();

  static ThemeData build(MindMateColors c) {
    final Brightness brightness = c.isDark ? Brightness.dark : Brightness.light;
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: MindMateColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: c.isDark ? MindMateColors.lightBlue : MindMateColors.primary,
          onPrimary: c.isDark ? MindMateColors.navy : MindMateColors.cream,
          secondary: MindMateColors.lightBlue,
          onSecondary: MindMateColors.navy,
          tertiary: MindMateColors.gold,
          onTertiary: MindMateColors.navy,
          surface: c.surface,
          onSurface: c.textBody,
          surfaceTint: Colors.transparent,
          outline: c.divider,
          shadow: c.shadow,
        );
    const BorderRadius inputRadius = BorderRadius.all(Radius.circular(18));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.divider,
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: (c.isDark ? ThemeData.dark() : ThemeData.light()).textTheme
          .apply(bodyColor: c.textBody, displayColor: c.textPrimary),
      iconTheme: IconThemeData(color: c.textPrimary),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: c.surfaceBorder == null
              ? BorderSide.none
              : BorderSide(color: c.surfaceBorder!),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.background,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.isDark ? c.surface : MindMateColors.primary,
        contentTextStyle: TextStyle(
          color: c.isDark ? c.textBody : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? MindMateColors.gold
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? (c.isDark ? MindMateColors.primary : MindMateColors.navy)
              : MindMateColors.lightBlue.withValues(alpha: 0.5),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MindMateColors.gold,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accentText,
        selectionColor: MindMateColors.lightBlue.withValues(alpha: 0.4),
        selectionHandleColor: MindMateColors.gold,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        labelStyle: TextStyle(color: c.textMuted),
        hintStyle: TextStyle(color: c.textMuted),
        border: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: c.surfaceBorder == null
              ? BorderSide.none
              : BorderSide(color: c.surfaceBorder!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: c.selectedRing, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: c.accentText, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: c.accentText, width: 1.4),
        ),
        errorStyle: TextStyle(color: c.accentText),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentText,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MindMateColors.primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: c.surfaceBorder == null
              ? BorderSide.none
              : BorderSide(color: c.surfaceBorder!),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accentText,
        inactiveTrackColor: MindMateColors.lightBlue.withValues(alpha: 0.3),
        thumbColor: MindMateColors.gold,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surface,
        dialHandColor: MindMateColors.gold,
        hourMinuteColor: c.input,
        dayPeriodColor: c.input,
      ),
    );
  }
}

/// Keeps [MindMateColors.current] in step with the theme on screen. When the
/// theme changes, every screen is rebuilt in place (no restart, no lost
/// state), so code that reads the colours without a context follows too.
class ThemeSync extends StatefulWidget {
  const ThemeSync({super.key, required this.child});

  final Widget child;

  @override
  State<ThemeSync> createState() => _ThemeSyncState();
}

class _ThemeSyncState extends State<ThemeSync> {
  @override
  Widget build(BuildContext context) {
    final MindMateColors colors =
        Theme.of(context).extension<MindMateColors>() ?? MindMateColors.light;
    if (!identical(colors, MindMateColors.current)) {
      final bool firstFrame = !_seen;
      MindMateColors.current = colors;
      if (!firstFrame) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.forceAppUpdate();
        });
      }
    }
    _seen = true;
    return widget.child;
  }

  bool _seen = false;
}
