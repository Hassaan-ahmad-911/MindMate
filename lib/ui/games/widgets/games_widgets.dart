import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../Models/calm_match_game.dart';
import '../../mood_tracking/widgets/mood_widgets.dart';
import '../../shared/mindmate_theme.dart';
import 'calm_icons.dart';

/// A round button and a Lobster title (the one main title on the screen).
/// Used where the leading button is a cross rather than a back arrow.
class GamesHeader extends StatelessWidget {
  const GamesHeader({
    super.key,
    required this.title,
    required this.onLeading,
    this.icon = Icons.close_rounded,
    this.tooltip = 'Close',
  });

  final String title;
  final VoidCallback onLeading;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        CircleIconButton(icon: icon, onPressed: onLeading, tooltip: tooltip),
        const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: AppFonts.title(size: 36)),
          ),
        ),
      ],
    );
  }
}

/// A small pill: gold for a gentle highlight, white or light blue otherwise.
class GamesChip extends StatelessWidget {
  const GamesChip(
    this.text, {
    super.key,
    this.gold = false,
    this.white = false,
  });

  final String text;
  final bool gold;
  final bool white;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final Color background = gold
        ? AppColors.softSurface
        : white
        ? c.surface
        : AppColors.secondary.withValues(alpha: 0.28);
    // Navy on peach; on the white (surface) pill and the faint light-blue
    // pill the text follows the page, so it stays readable in Dark.
    final Color textColor = gold ? AppColors.headerBlue : c.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: white && !gold && c.surfaceBorder != null
            ? Border.all(color: c.surfaceBorder!)
            : null,
      ),
      child: Text(
        text,
        style: AppFonts.body(
          size: 14.5,
          weight: FontWeight.w600,
          color: textColor,
          height: 1.1,
        ),
      ),
    );
  }
}

/// A glossy sphere, light at the top left and blue at the edge.
class BubbleSphere extends StatelessWidget {
  const BubbleSphere({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFD5E4EC),
            AppColors.secondary,
            AppColors.primary,
          ],
          stops: <double>[0, 0.3, 0.65, 1],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.mm.isDark
                ? context.mm.shadow
                : AppColors.headerBlue.withValues(alpha: 0.22),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.07),
          ),
        ],
      ),
    );
  }
}

/// The art tile on a hub card. Decorative only.
enum GameArt { bubble, match, garden }

class GameArtTile extends StatelessWidget {
  const GameArtTile({super.key, required this.art, this.size = 114});

  final GameArt art;
  final double size;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(size * 0.2);
    switch (art) {
      case GameArt.bubble:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFD5E4EC), AppColors.secondary],
            ),
          ),
          alignment: Alignment.center,
          child: BubbleSphere(size: size * 0.5),
        );
      case GameArt.match:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: AppBlends.blue,
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: size * 0.7,
            height: size * 0.5,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  top: size * 0.04,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: _MiniCard(
                      size: size * 0.38,
                      gold: false,
                      symbol: CalmSymbol.moon,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: size * 0.02,
                  child: Transform.rotate(
                    angle: 0.14,
                    child: _MiniCard(
                      size: size * 0.38,
                      gold: true,
                      symbol: null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case GameArt.garden:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: AppBlends.gold,
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: Size.square(size * 0.52),
            painter: const _FlowerGlyphPainter(AppColors.headerBlue),
          ),
        );
    }
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.size,
    required this.gold,
    required this.symbol,
  });

  final double size;
  final bool gold;
  final CalmSymbol? symbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.25,
      decoration: BoxDecoration(
        color: gold ? null : Colors.white,
        gradient: gold ? AppBlends.gold : null,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      alignment: Alignment.center,
      child: symbol == null
          ? null
          : CalmSymbolIcon(
              symbol: symbol!,
              size: size * 0.6,
              color: AppColors.headerBlue,
            ),
    );
  }
}

/// A small outlined flower: a head, a stem and two leaves.
class _FlowerGlyphPainter extends CustomPainter {
  const _FlowerGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < 6; i += 1) {
      final double angle = i * math.pi / 3;
      final Offset centre = Offset(
        s * 0.5 + s * 0.17 * math.cos(angle),
        s * 0.3 + s * 0.17 * math.sin(angle),
      );
      canvas.drawCircle(centre, s * 0.1, stroke);
    }
    canvas.drawCircle(Offset(s * 0.5, s * 0.3), s * 0.06, stroke);
    canvas.drawLine(
      Offset(s * 0.5, s * 0.5),
      Offset(s * 0.5, s * 0.92),
      stroke,
    );

    final Path leftLeaf = Path()
      ..moveTo(s * 0.5, s * 0.74)
      ..quadraticBezierTo(s * 0.26, s * 0.76, s * 0.22, s * 0.58)
      ..quadraticBezierTo(s * 0.44, s * 0.56, s * 0.5, s * 0.74);
    final Path rightLeaf = Path()
      ..moveTo(s * 0.5, s * 0.68)
      ..quadraticBezierTo(s * 0.74, s * 0.7, s * 0.78, s * 0.52)
      ..quadraticBezierTo(s * 0.56, s * 0.5, s * 0.5, s * 0.68);
    canvas.drawPath(leftLeaf, stroke);
    canvas.drawPath(rightLeaf, stroke);
  }

  @override
  bool shouldRepaint(_FlowerGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
