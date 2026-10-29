import 'package:flutter/material.dart';

import '../../../Models/mood_catalog.dart';
import '../../shared/mindmate_theme.dart';

/// A mood drawn as a simple outlined face or symbol, all in one line style.
class MoodIcon extends StatelessWidget {
  const MoodIcon(
    this.mood, {
    super.key,
    this.size = 24,
    this.color = AppColors.headerBlue,
  });

  /// Mood name, e.g. "Calm". Old names such as "Neutral" are mapped.
  final String mood;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _MoodIconPainter(MoodCatalog.normalizeName(mood), color),
      ),
    );
  }
}

/// Draws on a 24 x 24 grid.
class _MoodIconPainter extends CustomPainter {
  const _MoodIconPainter(this.mood, this.color);

  final String mood;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);

    final Paint line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint fill = Paint()..color = color;

    switch (mood) {
      case 'Grateful':
        canvas.drawPath(_heart(), line);
        return;
      case 'Motivated':
        canvas.drawPath(
          Path()
            ..moveTo(13.2, 2.5)
            ..lineTo(5.2, 13.4)
            ..lineTo(11.4, 13.4)
            ..lineTo(10.6, 21.5)
            ..lineTo(18.8, 10.2)
            ..lineTo(12.6, 10.2)
            ..close(),
          line,
        );
        return;
      case 'Hopeful':
        _sunrise(canvas, line);
        return;
      case 'Proud':
        canvas.drawPath(_star(), line);
        return;
    }

    // Faces.
    canvas.drawCircle(const Offset(12, 12), 9.5, line);

    void eyes({double y = 10}) {
      canvas.drawCircle(Offset(9, y), 1.25, fill);
      canvas.drawCircle(Offset(15, y), 1.25, fill);
    }

    void stroke(Path path) => canvas.drawPath(path, line);

    switch (mood) {
      case 'Happy':
        eyes();
        stroke(
          Path()
            ..moveTo(8, 13.5)
            ..quadraticBezierTo(12, 17.8, 16, 13.5),
        );
      case 'Calm':
        stroke(
          Path()
            ..moveTo(7.5, 10.2)
            ..quadraticBezierTo(9, 11.8, 10.5, 10.2)
            ..moveTo(13.5, 10.2)
            ..quadraticBezierTo(15, 11.8, 16.5, 10.2),
        );
        stroke(
          Path()
            ..moveTo(9, 14.6)
            ..quadraticBezierTo(12, 16.8, 15, 14.6),
        );
      case 'Tired':
        stroke(
          Path()
            ..moveTo(7.5, 10.5)
            ..lineTo(10.5, 10.5)
            ..moveTo(13.5, 10.5)
            ..lineTo(16.5, 10.5),
        );
        stroke(
          Path()
            ..moveTo(10, 15.6)
            ..quadraticBezierTo(12, 14.6, 14, 15.6),
        );
      case 'Restless':
        eyes();
        stroke(
          Path()
            ..moveTo(8, 15)
            ..quadraticBezierTo(9.33, 13.8, 10.67, 15)
            ..quadraticBezierTo(12, 16.2, 13.33, 15)
            ..quadraticBezierTo(14.67, 13.8, 16, 15),
        );
      case 'Stressed':
        stroke(
          Path()
            ..moveTo(7.5, 8.8)
            ..lineTo(10, 10.2)
            ..lineTo(7.5, 11.6)
            ..moveTo(16.5, 8.8)
            ..lineTo(14, 10.2)
            ..lineTo(16.5, 11.6),
        );
        stroke(
          Path()
            ..moveTo(8, 15.6)
            ..lineTo(9.6, 14.4)
            ..lineTo(11.2, 15.6)
            ..lineTo(12.8, 14.4)
            ..lineTo(14.4, 15.6)
            ..lineTo(16, 14.4),
        );
      case 'Anxious':
        stroke(
          Path()
            ..moveTo(7.2, 8)
            ..lineTo(10.2, 7)
            ..moveTo(16.8, 8)
            ..lineTo(13.8, 7),
        );
        eyes(y: 10.6);
        canvas.drawCircle(const Offset(12, 15.6), 1.7, line);
      case 'Sad':
        eyes();
        stroke(
          Path()
            ..moveTo(8.5, 16)
            ..quadraticBezierTo(12, 12.8, 15.5, 16),
        );
      case 'Angry':
        stroke(
          Path()
            ..moveTo(7, 7.2)
            ..lineTo(10.3, 8.6)
            ..moveTo(17, 7.2)
            ..lineTo(13.7, 8.6),
        );
        eyes(y: 10.8);
        stroke(
          Path()
            ..moveTo(9, 15.8)
            ..quadraticBezierTo(12, 14, 15, 15.8),
        );
      case 'Overwhelmed':
        canvas.drawCircle(const Offset(9, 10), 1.6, line);
        canvas.drawCircle(const Offset(15, 10), 1.6, line);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(12, 15.6), width: 4, height: 3),
          line,
        );
      case 'Lonely':
        eyes(y: 10.5);
        stroke(
          Path()
            ..moveTo(9.5, 15.8)
            ..quadraticBezierTo(12, 14.2, 14.5, 15.8),
        );
        stroke(
          Path()
            ..moveTo(15.4, 12.4)
            ..quadraticBezierTo(14.3, 14.1, 15.4, 14.7)
            ..quadraticBezierTo(16.5, 14.1, 15.4, 12.4),
        );
      default: // Okay, and any unknown mood
        eyes();
        stroke(
          Path()
            ..moveTo(9, 15)
            ..lineTo(15, 15),
        );
    }
  }

  Path _heart() {
    return Path()
      ..moveTo(12, 20.5)
      ..cubicTo(6, 16, 3, 12.5, 3, 8.8)
      ..cubicTo(3, 6, 5.2, 4, 7.6, 4)
      ..cubicTo(9.4, 4, 10.9, 5, 12, 6.6)
      ..cubicTo(13.1, 5, 14.6, 4, 16.4, 4)
      ..cubicTo(18.8, 4, 21, 6, 21, 8.8)
      ..cubicTo(21, 12.5, 18, 16, 12, 20.5)
      ..close();
  }

  Path _star() {
    const Offset center = Offset(12, 12.6);
    final Path path = Path();
    for (int i = 0; i < 10; i += 1) {
      final double radius = i.isEven ? 9.6 : 4.3;
      final double angle = -1.5708 + i * 0.6283;
      final Offset point = center + Offset.fromDirection(angle, radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  void _sunrise(Canvas canvas, Paint line) {
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(12, 17), radius: 5),
      3.1416,
      3.1416,
      false,
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(2.5, 17)
        ..lineTo(21.5, 17)
        ..moveTo(7, 20.8)
        ..lineTo(17, 20.8)
        ..moveTo(12, 6)
        ..lineTo(12, 8.6)
        ..moveTo(5, 9.4)
        ..lineTo(6.8, 11.2)
        ..moveTo(19, 9.4)
        ..lineTo(17.2, 11.2),
      line,
    );
  }

  @override
  bool shouldRepaint(_MoodIconPainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.color != color;
}
