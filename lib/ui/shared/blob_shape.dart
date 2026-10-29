import 'package:flutter/material.dart';

// Background shapes. Each list is: start x, start y, then groups of six
// numbers (control 1, control 2, end point) for cubic curves, on a 200 grid.

const List<double> blobShapeA = <double>[
  44,
  28,
  70,
  4,
  126,
  2,
  158,
  26,
  188,
  49,
  198,
  94,
  180,
  130,
  164,
  163,
  128,
  184,
  90,
  180,
  54,
  176,
  24,
  150,
  16,
  114,
  8,
  80,
  20,
  50,
  44,
  28,
];

const List<double> blobShapeB = <double>[
  30,
  60,
  50,
  20,
  110,
  8,
  150,
  34,
  186,
  58,
  198,
  108,
  178,
  146,
  160,
  180,
  116,
  196,
  78,
  186,
  40,
  176,
  10,
  146,
  8,
  108,
  7,
  90,
  16,
  74,
  30,
  60,
];

/// Paints one of the blob shapes above, filled with [gradient].
class BlobPainter extends CustomPainter {
  const BlobPainter(this.gradient, this.points);

  final Gradient gradient;
  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / 200;
    final Path path = Path()..moveTo(points[0] * k, points[1] * k);
    for (int i = 2; i + 5 < points.length; i += 6) {
      path.cubicTo(
        points[i] * k,
        points[i + 1] * k,
        points[i + 2] * k,
        points[i + 3] * k,
        points[i + 4] * k,
        points[i + 5] * k,
      );
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(BlobPainter oldDelegate) =>
      oldDelegate.gradient != gradient || oldDelegate.points != points;
}

/// A blob shape of the given [size].
class BlobShape extends StatelessWidget {
  const BlobShape({
    super.key,
    required this.size,
    required this.gradient,
    this.points = blobShapeA,
  });

  final double size;
  final Gradient gradient;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: BlobPainter(gradient, points),
    );
  }
}

/// A circle. With no [color] it uses [gradient] and a soft glow.
class GlowDot extends StatelessWidget {
  const GlowDot({
    super.key,
    required this.size,
    this.color,
    this.gradient,
    this.glowColor,
  });

  final double size;
  final Color? color;
  final Gradient? gradient;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        gradient: color == null ? gradient : null,
        boxShadow: glowColor == null
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: glowColor!,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
    );
  }
}
