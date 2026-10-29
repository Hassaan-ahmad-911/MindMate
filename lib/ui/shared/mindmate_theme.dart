import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The colours of one theme (Light or Dark), as a [ThemeExtension]. Read them
/// with `context.mm` in widgets, or `MindMateColors.current` where there is
/// no context (painters, text style defaults).
///
/// Mood faces, mood group colours and tone pills keep their own gradients in
/// both themes; text on gold or light blue is always navy ([onAccent]).
@immutable
class MindMateColors extends ThemeExtension<MindMateColors> {
  const MindMateColors({
    required this.isDark,
    required this.background,
    required this.glowTopRight,
    required this.glowBottomLeft,
    required this.surface,
    required this.surfaceBorder,
    required this.input,
    required this.textPrimary,
    required this.textBody,
    required this.textMuted,
    required this.accentText,
    required this.divider,
    required this.shadow,
    required this.blueBlend,
    required this.blueBlendHorizontal,
    required this.selectedRing,
  });

  final bool isDark;

  /// The page colour.
  final Color background;
  final Color glowTopRight;
  final Color glowBottomLeft;

  /// Cards, sheets, the nav bar, round buttons, chips.
  final Color surface;

  /// A 1 px line inside surfaces (Dark only).
  final Color? surfaceBorder;

  /// Text fields.
  final Color input;

  /// Titles and values.
  final Color textPrimary;
  final Color textBody;
  final Color textMuted;

  /// Values such as "Mood at 20:00", links and small labels on surfaces.
  final Color accentText;
  final Color divider;

  /// Card shadows.
  final Color shadow;

  /// Hero cards, main buttons, selected states.
  final LinearGradient blueBlend;
  final LinearGradient blueBlendHorizontal;

  /// The ring around a selected card.
  final Color selectedRing;

  // The same in both themes.

  static const Color navy = Color(0xFF1F3550);
  static const Color primary = Color(0xFF4C7F9A);
  static const Color lightBlue = Color(0xFF95B7CA);
  static const Color gold = Color(0xFFE4B266);
  static const Color peach = Color(0xFFEFCD9F);
  static const Color cream = Color(0xFFFDF7EE);

  /// Text and icons on the gold, peach and light-blue blends.
  Color get onAccent => navy;

  /// Titles on the blue blend.
  Color get onBlue => Colors.white;

  /// Secondary lines on the blue blend (at least 88% opacity).
  Color get onBlueMuted => Colors.white.withValues(alpha: 0.88);

  LinearGradient get goldBlend => AppBlends.gold;

  LinearGradient get lightBlueBlend => AppBlends.lightBlue;

  static const MindMateColors light = MindMateColors(
    isDark: false,
    background: cream,
    glowTopRight: Color(0x9995B7CA), // light blue at 60%
    glowBottomLeft: Color(0xBFEFCD9F), // peach at 75%
    surface: Colors.white,
    surfaceBorder: null,
    input: Colors.white,
    textPrimary: navy,
    textBody: Color(0xFF263845),
    textMuted: Color(0xCC263845), // 80%
    accentText: primary,
    divider: Color(0x4795B7CA), // 28%
    shadow: Color(0x121F3550), // 7%
    blueBlend: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[primary, navy],
    ),
    blueBlendHorizontal: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[primary, navy],
    ),
    selectedRing: primary,
  );

  static const MindMateColors dark = MindMateColors(
    isDark: true,
    background: Color(0xFF13202D),
    glowTopRight: Color(0x804C7F9A), // primary at 50%
    glowBottomLeft: Color(0x29E4B266), // gold at 16%
    surface: navy,
    surfaceBorder: Color(0x2E95B7CA), // light blue at 18%
    input: Color(0xFF1A2C40),
    textPrimary: cream,
    textBody: cream,
    textMuted: Color(0xB8FDF7EE), // 72%
    accentText: lightBlue,
    divider: Color(0x3395B7CA), // 20%
    shadow: Color(0x4D000000), // black at 30%
    blueBlend: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[primary, Color(0xFF2C4A66)],
    ),
    blueBlendHorizontal: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[primary, Color(0xFF2C4A66)],
    ),
    selectedRing: gold,
  );

  /// The theme on screen now. Kept in step by the app's builder, so code
  /// with no context (painters, text style defaults) follows the theme.
  static MindMateColors current = light;

  @override
  MindMateColors copyWith() => this;

  @override
  MindMateColors lerp(ThemeExtension<MindMateColors>? other, double t) =>
      t < 0.5 || other is! MindMateColors ? this : other;
}

extension MindMateContext on BuildContext {
  /// The current theme's colours.
  MindMateColors get mm =>
      Theme.of(this).extension<MindMateColors>() ?? MindMateColors.current;
}

/// The MindMate palette. The brand colours are the same in both themes. The
/// getters at the bottom follow the current theme; prefer `context.mm` in
/// widgets.
class AppColors {
  const AppColors._();

  static const Color primary = MindMateColors.primary;
  static const Color secondary = MindMateColors.lightBlue;
  static const Color accent = MindMateColors.gold;
  static const Color softSurface = MindMateColors.peach;
  static const Color textDark = Color(0xFF263845);

  /// Navy. In both themes this is the colour of text and icons on the gold,
  /// peach and light-blue blends, and a gradient stop. For titles on the
  /// page or on cards use [ink] (or `context.mm.textPrimary`).
  static const Color headerBlue = MindMateColors.navy;

  /// The page colour of the current theme.
  static Color get background => MindMateColors.current.background;

  /// Cards, sheets and round buttons.
  static Color get surface => MindMateColors.current.surface;

  /// Titles and values on the page or on cards.
  static Color get ink => MindMateColors.current.textPrimary;

  /// Body copy.
  static Color get bodyText => MindMateColors.current.textBody;

  /// Secondary lines and hints.
  static Color get mutedText => MindMateColors.current.textMuted;

  /// Links, values and small labels on the page or on cards.
  static Color get accentText => MindMateColors.current.accentText;

  static Color get divider => MindMateColors.current.divider;

  static Color get shadow => MindMateColors.current.shadow;
}

/// Gradients made only from the palette. The blue blends follow the theme.
class AppBlends {
  const AppBlends._();

  /// Main buttons, selected states and "hard" mood tiles.
  static LinearGradient get blue => MindMateColors.current.blueBlend;

  /// The blue blend running left to right, used on wide buttons.
  static LinearGradient get blueHorizontal =>
      MindMateColors.current.blueBlendHorizontal;

  /// Arrow circles, "good" mood tiles and highlights.
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.softSurface, AppColors.accent],
  );

  /// "In between" mood tiles.
  static const LinearGradient lightBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x7395B7CA), AppColors.secondary],
  );

  /// Large background shapes: light blue into navy.
  static const LinearGradient blueShape = LinearGradient(
    begin: Alignment(0.35, -1),
    end: Alignment(-0.35, 1),
    colors: <Color>[
      AppColors.secondary,
      AppColors.primary,
      AppColors.headerBlue,
    ],
    stops: <double>[0, 0.45, 1],
  );
}

/// Fonts: Lobster Two Bold for the name and the one main title on a screen,
/// Jost for everything else. With no colour given, text follows the theme.
class AppFonts {
  const AppFonts._();

  /// Lobster Two Bold. The font file is bundled in assets/fonts.
  static TextStyle title({
    double size = 40,
    Color? color,
    double height = 1.1,
  }) {
    return GoogleFonts.lobsterTwo(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color ?? MindMateColors.current.textPrimary,
      height: height,
    );
  }

  static TextStyle body({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.4,
    double letterSpacing = 0,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    return GoogleFonts.jost(
      fontSize: size,
      fontWeight: weight,
      color: color ?? MindMateColors.current.textBody,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationThickness: decoration == null ? null : 2,
    );
  }

  static TextStyle label({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0,
  }) {
    return body(
      size: size,
      weight: weight,
      color: color ?? MindMateColors.current.textMuted,
      height: 1.3,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle button({Color color = Colors.white}) {
    return GoogleFonts.jost(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: color,
    );
  }
}

/// Helpers for the phone's reduce-motion setting.
class AppMotion {
  const AppMotion._();

  static bool reduced(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// [duration], or zero when the phone has animations turned off.
  static Duration of(BuildContext context, Duration duration) {
    return reduced(context) ? Duration.zero : duration;
  }
}
