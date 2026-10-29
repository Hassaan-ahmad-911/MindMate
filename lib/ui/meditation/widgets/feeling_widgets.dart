import 'package:flutter/material.dart';

import '../../../Models/meditation_feeling.dart';
import '../../shared/mindmate_theme.dart';

/// One of the five faces of the "How do you feel?" scale, drawn as a simple
/// outline in the same style as the mood icons. [value] is 1 (very low) to
/// 5 (very good).
class FeelingFace extends StatelessWidget {
  const FeelingFace(
    this.value, {
    super.key,
    this.size = 28,
    this.color = AppColors.headerBlue,
  });

  final int value;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _FeelingFacePainter(value, color),
      ),
    );
  }
}

/// Draws on a 24 x 24 grid.
class _FeelingFacePainter extends CustomPainter {
  const _FeelingFacePainter(this.value, this.color);

  final int value;
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

    canvas.drawCircle(const Offset(12, 12), 9.5, line);
    canvas.drawCircle(const Offset(9, 10), 1.25, fill);
    canvas.drawCircle(const Offset(15, 10), 1.25, fill);

    final Path mouth = Path();
    switch (value) {
      case 1: // Very low: worried brows and a deep frown.
        canvas.drawPath(
          Path()
            ..moveTo(7, 8.2)
            ..lineTo(10.4, 6.9)
            ..moveTo(17, 8.2)
            ..lineTo(13.6, 6.9),
          line,
        );
        mouth
          ..moveTo(8, 16.4)
          ..quadraticBezierTo(12, 12.6, 16, 16.4);
      case 2: // Low: a gentle frown.
        mouth
          ..moveTo(9, 15.8)
          ..quadraticBezierTo(12, 13.6, 15, 15.8);
      case 3: // Okay: a flat mouth.
        mouth
          ..moveTo(9, 15)
          ..lineTo(15, 15);
      case 4: // Good: a gentle smile.
        mouth
          ..moveTo(9, 14.2)
          ..quadraticBezierTo(12, 16.8, 15, 14.2);
      default: // Very good: a wide smile.
        mouth
          ..moveTo(7.8, 13.4)
          ..quadraticBezierTo(12, 19, 16.2, 13.4);
    }
    canvas.drawPath(mouth, line);
  }

  @override
  bool shouldRepaint(_FeelingFacePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

/// How a selected face looks.
enum FeelingPickerStyle {
  /// Navy circle with a gold ring (before the practice).
  dark,

  /// Gold circle with a navy ring (after the practice).
  gold,
}

/// The five faces in a row: Very low, Low, Okay, Good, Very good.
class FeelingPicker extends StatelessWidget {
  const FeelingPicker({
    super.key,
    required this.value,
    required this.onSelected,
    this.style = FeelingPickerStyle.dark,
  });

  /// The selected face, 1 to 5, or null if none.
  final int? value;
  final ValueChanged<int> onSelected;
  final FeelingPickerStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const int count = MeditationFeeling.highest;
        final double slot = constraints.maxWidth / count;
        final double circle = (slot - 8).clamp(40.0, 56.0).toDouble();

        return Row(
          children: List<Widget>.generate(count, (int index) {
            final int face = index + 1;
            return Expanded(
              child: _FeelingOption(
                value: face,
                size: circle,
                selected: value == face,
                style: style,
                onTap: () => onSelected(face),
              ),
            );
          }),
        );
      },
    );
  }
}

class _FeelingOption extends StatelessWidget {
  const _FeelingOption({
    required this.value,
    required this.size,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final int value;
  final double size;
  final bool selected;
  final FeelingPickerStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = MeditationFeeling.labelFor(value) ?? '';
    final bool dark = style == FeelingPickerStyle.dark;
    final MindMateColors c = context.mm;
    // The navy ring around the gold circle would vanish on the Dark page.
    final Color ringColor = dark
        ? AppColors.accent
        : (c.isDark ? c.selectedRing : AppColors.headerBlue);
    final Gradient fill = dark ? AppBlends.blue : AppBlends.gold;
    // White on the blue blend, navy on the gold blend, the title colour on
    // an unselected surface circle.
    final Color faceColor = selected
        ? (dark ? Colors.white : AppColors.headerBlue)
        : c.textPrimary;

    final Widget circle = selected
        ? Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 2.5),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: fill),
              child: Center(
                child: FeelingFace(value, size: size * 0.5, color: faceColor),
              ),
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface,
              border: c.surfaceBorder == null
                  ? null
                  : Border.all(color: c.surfaceBorder!),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: FeelingFace(value, size: size * 0.5, color: faceColor),
            ),
          );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: size * 0.7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            circle,
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppFonts.label(
                    size: 12.5,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? c.textPrimary : c.textBody,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
