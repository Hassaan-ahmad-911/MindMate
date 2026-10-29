import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../Models/calm_match_game.dart';

/// A card picture, drawn as a simple outline (one style for all six).
class CalmSymbolIcon extends StatelessWidget {
  const CalmSymbolIcon({
    super.key,
    required this.symbol,
    required this.size,
    required this.color,
  });

  final CalmSymbol symbol;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CalmSymbolPainter(symbol, color),
    );
  }
}

class _CalmSymbolPainter extends CustomPainter {
  const _CalmSymbolPainter(this.symbol, this.color);

  final CalmSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset p(double x, double y) => Offset(x * s, y * s);

    switch (symbol) {
      case CalmSymbol.leaf:
        final Path leaf = Path()
          ..moveTo(0.2 * s, 0.8 * s)
          ..cubicTo(0.08 * s, 0.34 * s, 0.46 * s, 0.1 * s, 0.86 * s, 0.14 * s)
          ..cubicTo(0.9 * s, 0.56 * s, 0.62 * s, 0.92 * s, 0.2 * s, 0.8 * s)
          ..close();
        canvas.drawPath(leaf, stroke);
        canvas.drawLine(p(0.2, 0.8), p(0.62, 0.38), stroke);
      case CalmSymbol.moon:
        final Path outer = Path()
          ..addOval(Rect.fromCircle(center: p(0.5, 0.5), radius: 0.36 * s));
        final Path bite = Path()
          ..addOval(Rect.fromCircle(center: p(0.64, 0.38), radius: 0.31 * s));
        canvas.drawPath(
          Path.combine(PathOperation.difference, outer, bite),
          stroke,
        );
      case CalmSymbol.wave:
        for (final double y in <double>[0.38, 0.62]) {
          final Path wave = Path()
            ..moveTo(0.12 * s, y * s)
            ..cubicTo(
              0.25 * s,
              (y - 0.17) * s,
              0.37 * s,
              (y - 0.17) * s,
              0.5 * s,
              y * s,
            )
            ..cubicTo(
              0.63 * s,
              (y + 0.17) * s,
              0.75 * s,
              (y + 0.17) * s,
              0.88 * s,
              y * s,
            );
          canvas.drawPath(wave, stroke);
        }
      case CalmSymbol.heart:
        final Path heart = Path()
          ..moveTo(0.5 * s, 0.82 * s)
          ..cubicTo(0.14 * s, 0.58 * s, 0.1 * s, 0.3 * s, 0.28 * s, 0.2 * s)
          ..cubicTo(0.4 * s, 0.14 * s, 0.5 * s, 0.22 * s, 0.5 * s, 0.32 * s)
          ..cubicTo(0.5 * s, 0.22 * s, 0.6 * s, 0.14 * s, 0.72 * s, 0.2 * s)
          ..cubicTo(0.9 * s, 0.3 * s, 0.86 * s, 0.58 * s, 0.5 * s, 0.82 * s)
          ..close();
        canvas.drawPath(heart, stroke);
      case CalmSymbol.star:
        final Path star = Path();
        for (int i = 0; i < 10; i += 1) {
          final double radius = (i.isEven ? 0.4 : 0.18) * s;
          final double angle = -math.pi / 2 + i * math.pi / 5;
          final Offset point = Offset(
            0.5 * s + radius * math.cos(angle),
            0.54 * s + radius * math.sin(angle),
          );
          if (i == 0) {
            star.moveTo(point.dx, point.dy);
          } else {
            star.lineTo(point.dx, point.dy);
          }
        }
        star.close();
        canvas.drawPath(star, stroke);
      case CalmSymbol.sun:
        canvas.drawCircle(p(0.5, 0.5), 0.17 * s, stroke);
        for (int i = 0; i < 8; i += 1) {
          final double angle = i * math.pi / 4;
          canvas.drawLine(
            p(0.5 + 0.29 * math.cos(angle), 0.5 + 0.29 * math.sin(angle)),
            p(0.5 + 0.41 * math.cos(angle), 0.5 + 0.41 * math.sin(angle)),
            stroke,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_CalmSymbolPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.color != color;
}
