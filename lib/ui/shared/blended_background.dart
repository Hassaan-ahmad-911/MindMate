import 'package:flutter/material.dart';

import 'mindmate_theme.dart';

/// Cream page background with a soft blue glow from one corner and a soft
/// peach glow from the bottom-left, both fading to clear.
class BlendedBackground extends StatelessWidget {
  const BlendedBackground({
    super.key,
    this.child,
    this.blueGlowColor,
    this.blueGlowCenter = Alignment.topRight,
    this.blueGlowRadius = 1.1,
    this.blueGlowOpacity,
    this.peachGlowRadius = 1.25,
    this.peachGlowOpacity,
  });

  final Widget? child;

  /// The colour of the corner glow: the theme's top-right glow unless said
  /// otherwise.
  final Color? blueGlowColor;
  final Alignment blueGlowCenter;
  final double blueGlowRadius;
  final double? blueGlowOpacity;
  final double peachGlowRadius;
  final double? peachGlowOpacity;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    // A screen's own glow colour or opacity applies in Light; Dark always
    // uses its own, softer glows.
    final Color topGlow =
        !c.isDark && (blueGlowColor != null || blueGlowOpacity != null)
        ? (blueGlowColor ?? AppColors.secondary).withValues(
            alpha: blueGlowOpacity ?? 0.6,
          )
        : c.glowTopRight;
    final Color bottomGlow = !c.isDark && peachGlowOpacity != null
        ? AppColors.softSurface.withValues(alpha: peachGlowOpacity)
        : c.glowBottomLeft;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.background),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: blueGlowCenter,
            radius: blueGlowRadius,
            colors: <Color>[topGlow, topGlow.withValues(alpha: 0)],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomLeft,
              radius: peachGlowRadius,
              colors: <Color>[bottomGlow, bottomGlow.withValues(alpha: 0)],
            ),
          ),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}
