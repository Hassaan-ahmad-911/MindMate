import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../Models/gratitude_entry.dart';
import '../../shared/mindmate_theme.dart';

/// The ground and the flowers, oldest on the left. Each flower has its own
/// slot, so the garden is as wide as the number of flowers needs.
class GardenPainter extends CustomPainter {
  GardenPainter({
    required this.entries,
    required this.slotWidth,
    required this.now,
    required this.onSelect,
    required this.textDirection,
    this.growingKey,
    this.growth = 1,
    this.stemColor = AppColors.headerBlue,
  });

  /// Oldest first.
  final List<GratitudeEntry> entries;
  final double slotWidth;
  final DateTime now;
  final void Function(GratitudeEntry entry) onSelect;

  /// Needed by the screen reader to read the flowers' labels.
  final TextDirection textDirection;

  /// The flower that is still growing, and how far (0 to 1).
  final String? growingKey;
  final double growth;

  /// The stems. Navy on the light sky; light blue on the night sky (Dark).
  final Color stemColor;

  static const double headRadius = 11;

  /// The ground takes this much of the height from the bottom.
  static const double groundFraction = 0.16;

  /// The garden's left padding, so the first flower is not on the edge.
  static const double sidePadding = 4;

  double _groundY(Size size) => size.height * (1 - groundFraction);

  Offset headCentre(Size size, int index, FlowerStyle style, double grow) {
    final double groundY = _groundY(size);
    final double top = headRadius + 6;
    final double reach = (groundY - top) * style.heightFraction * grow;
    return Offset(sidePadding + slotWidth * (index + 0.5), groundY - reach);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double groundY = _groundY(size);

    // Soft hill behind, then the dark ground in front.
    final Path hill = Path()
      ..moveTo(0, groundY)
      ..cubicTo(
        size.width * 0.2,
        groundY - 14,
        size.width * 0.45,
        groundY - 2,
        size.width * 0.7,
        groundY - 10,
      )
      ..cubicTo(
        size.width * 0.85,
        groundY - 14,
        size.width * 0.95,
        groundY - 6,
        size.width,
        groundY - 8,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      hill,
      Paint()..color = AppColors.primary.withValues(alpha: 0.9),
    );

    final Path ground = Path()
      ..moveTo(0, groundY + 6)
      ..cubicTo(
        size.width * 0.25,
        groundY - 4,
        size.width * 0.5,
        groundY + 14,
        size.width * 0.75,
        groundY + 4,
      )
      ..cubicTo(
        size.width * 0.88,
        groundY - 1,
        size.width * 0.96,
        groundY + 6,
        size.width,
        groundY + 2,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ground, Paint()..color = AppColors.headerBlue);

    final Paint stem = Paint()
      ..color = stemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final Paint outline = Paint()
      ..color = AppColors.headerBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    for (int i = 0; i < entries.length; i += 1) {
      final GratitudeEntry entry = entries[i];
      final FlowerStyle style = FlowerStyle.forDateKey(entry.dateKey);
      final double grow = entry.dateKey == growingKey ? growth : 1;
      final Offset head = headCentre(size, i, style, grow);
      final double radius = headRadius * (0.4 + 0.6 * grow);

      canvas.drawLine(Offset(head.dx, groundY + 4), head, stem);
      canvas.drawCircle(head, radius, Paint()..color = _fill(style.colour));
      canvas.drawCircle(head, radius, outline);
      canvas.drawCircle(
        head,
        radius * 0.3,
        Paint()..color = AppColors.headerBlue,
      );
    }
  }

  Color _fill(FlowerColour colour) {
    switch (colour) {
      case FlowerColour.gold:
        return AppColors.accent;
      case FlowerColour.blue:
        return AppColors.secondary;
      case FlowerColour.white:
        return Colors.white;
    }
  }

  /// The flower whose slot is at [dx], or null if there is none.
  GratitudeEntry? entryAt(double dx) {
    final int index = ((dx - sidePadding) / slotWidth).floor();
    if (index < 0 || index >= entries.length) {
      return null;
    }
    return entries[index];
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder {
    return (Size size) {
      return <CustomPainterSemantics>[
        for (int i = 0; i < entries.length; i += 1)
          CustomPainterSemantics(
            rect: Rect.fromLTWH(
              sidePadding + slotWidth * i,
              0,
              slotWidth,
              size.height,
            ),
            properties: SemanticsProperties(
              textDirection: textDirection,
              button: true,
              label:
                  'Flower from ${GratitudeRules.dayLabel(entries[i].dateKey, now)}: '
                  '${entries[i].text}',
              onTap: () => onSelect(entries[i]),
            ),
          ),
      ];
    };
  }

  @override
  bool shouldRepaint(GardenPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.slotWidth != slotWidth ||
        oldDelegate.growingKey != growingKey ||
        oldDelegate.growth != growth ||
        oldDelegate.stemColor != stemColor;
  }

  @override
  bool shouldRebuildSemantics(GardenPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.now != now;
  }
}
