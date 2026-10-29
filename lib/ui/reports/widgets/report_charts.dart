import 'package:flutter/material.dart';

import '../../../Models/report_calculator.dart';
import '../../shared/mindmate_theme.dart';

/// "Week by week": a bar per week around a zero line, gold above, the blue
/// blend below, with the value above each bar and the week under the axis.
class WeekByWeekChart extends StatelessWidget {
  const WeekByWeekChart({super.key, required this.weeks});

  final List<WeekAverage> weeks;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      label: weeks
          .map(
            (WeekAverage w) =>
                '${w.label}: ${w.average == null ? 'not enough days' : ReportCalculator.signed(w.average!)}',
          )
          .join('. '),
      excludeSemantics: true,
      child: SizedBox(
        height: 170,
        width: double.infinity,
        child: CustomPaint(
          painter: _WeekPainter(
            weeks: weeks,
            valueStyle: AppFonts.label(
              size: 12.5,
              weight: FontWeight.w700,
              color: c.textPrimary,
            ),
            labelStyle: AppFonts.label(size: 12, color: c.textBody),
            downBlend: c.blueBlend,
          ),
        ),
      ),
    );
  }
}

class _WeekPainter extends CustomPainter {
  _WeekPainter({
    required this.weeks,
    required this.valueStyle,
    required this.labelStyle,
    required this.downBlend,
  });

  final List<WeekAverage> weeks;
  final TextStyle valueStyle;
  final TextStyle labelStyle;

  /// The blend for bars below the zero line.
  final Gradient downBlend;

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty) {
      return;
    }
    const double top = 22;
    const double bottom = 24;
    final double zero = top + (size.height - top - bottom) / 2;
    final double half = (size.height - top - bottom) / 2 - 4;
    final double slot = size.width / weeks.length;
    final double barWidth = (slot * 0.42).clamp(12.0, 34.0);

    canvas.drawLine(
      Offset(0, zero),
      Offset(size.width, zero),
      Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 1.2,
    );

    for (int i = 0; i < weeks.length; i += 1) {
      final double cx = slot * i + slot / 2;
      final double? v = weeks[i].average;
      if (v != null && v.abs() > 0.001) {
        final double h = (v.abs() / 2).clamp(0.0, 1.0) * half;
        final bool up = v > 0;
        final Rect rect = Rect.fromLTRB(
          cx - barWidth / 2,
          up ? zero - h : zero,
          cx + barWidth / 2,
          up ? zero : zero + h,
        );
        // Rounded only at the data end.
        final RRect bar = RRect.fromRectAndCorners(
          rect,
          topLeft: up ? const Radius.circular(5) : Radius.zero,
          topRight: up ? const Radius.circular(5) : Radius.zero,
          bottomLeft: up ? Radius.zero : const Radius.circular(5),
          bottomRight: up ? Radius.zero : const Radius.circular(5),
        );
        canvas.drawRRect(
          bar,
          Paint()
            ..shader = (up ? AppBlends.gold : downBlend).createShader(rect),
        );
      }
      final String value = v == null ? '—' : ReportCalculator.signed(v);
      // Values sit in one row along the top, above every bar.
      _text(canvas, value, Offset(cx, 9), valueStyle);
      _text(canvas, weeks[i].label, Offset(cx, size.height - 12), labelStyle);
    }
  }

  void _text(Canvas canvas, String text, Offset center, TextStyle style) {
    final TextPainter p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, Offset(center.dx - p.width / 2, center.dy - p.height / 2));
  }

  @override
  bool shouldRepaint(_WeekPainter old) =>
      old.weeks != weeks ||
      old.valueStyle != valueStyle ||
      old.labelStyle != labelStyle ||
      old.downBlend != downBlend;
}

/// One "Your mood on days when you…" scale from Hard (-2) to Good (+2): a
/// gold dot for those days, a light-blue ring for other days, a navy line
/// between them and a tick at the centre.
class ComparisonScale extends StatelessWidget {
  const ComparisonScale({super.key, required this.on, required this.other});

  final double on;
  final double other;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return SizedBox(
      height: 22,
      width: double.infinity,
      child: CustomPaint(
        painter: _ScalePainter(
          on: on,
          other: other,
          link: c.textPrimary,
          ringFill: c.surface,
          ring: c.accentText,
        ),
      ),
    );
  }
}

class _ScalePainter extends CustomPainter {
  _ScalePainter({
    required this.on,
    required this.other,
    required this.link,
    required this.ringFill,
    required this.ring,
  });

  final double on;
  final double other;

  /// The line between the two marks.
  final Color link;

  /// The inside and outline of the "other days" ring.
  final Color ringFill;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    const double pad = 10;
    final double y = size.height / 2;
    double x(double v) =>
        pad + (v.clamp(-2.0, 2.0) + 2) / 4 * (size.width - 2 * pad);

    canvas.drawLine(
      Offset(pad, y),
      Offset(size.width - pad, y),
      Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.45)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(x(0), y - 6),
      Offset(x(0), y + 6),
      Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(x(other), y),
      Offset(x(on), y),
      Paint()
        ..color = link
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(x(other), y), 6, Paint()..color = ringFill);
    canvas.drawCircle(
      Offset(x(other), y),
      6,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    final Rect dot = Rect.fromCircle(center: Offset(x(on), y), radius: 7);
    canvas.drawOval(dot, Paint()..shader = AppBlends.gold.createShader(dot));
  }

  @override
  bool shouldRepaint(_ScalePainter old) =>
      old.on != on ||
      old.other != other ||
      old.link != link ||
      old.ringFill != ringFill ||
      old.ring != ring;
}

/// Two bars: before (light blue) and after (gold blend), values above.
class BeforeAfterBars extends StatelessWidget {
  const BeforeAfterBars({super.key, required this.before, required this.after});

  final double before;
  final double after;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    const double maxHeight = 90;
    Widget bar(String label, double value, Gradient? gradient, Color? color) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            value.toStringAsFixed(1),
            style: AppFonts.body(
              size: 18,
              weight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 52,
            height: maxHeight * (value / 5).clamp(0.05, 1.0),
            decoration: BoxDecoration(
              gradient: gradient,
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppFonts.label(size: 13, color: c.textBody)),
        ],
      );
    }

    return Semantics(
      label:
          'Average feeling before ${before.toStringAsFixed(1)}, after '
          '${after.toStringAsFixed(1)}, from 1 to 5',
      excludeSemantics: true,
      child: SizedBox(
        height: maxHeight + 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            bar('Before', before, null, AppColors.secondary),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 60),
              child: Icon(Icons.arrow_forward_rounded, color: c.accentText),
            ),
            bar('After', after, AppBlends.gold, null),
          ],
        ),
      ),
    );
  }
}

/// One stacked bar: Light, Mixed, Heavy, with 2 px gaps and the counts
/// inside each segment.
class ToneBar extends StatelessWidget {
  const ToneBar({
    super.key,
    required this.light,
    required this.mixed,
    required this.heavy,
  });

  final int light;
  final int mixed;
  final int heavy;

  @override
  Widget build(BuildContext context) {
    final List<(int, Gradient?, Color?, Color)> parts =
        <(int, Gradient?, Color?, Color)>[
          (light, AppBlends.gold, null, AppColors.headerBlue),
          (mixed, null, AppColors.secondary, AppColors.headerBlue),
          (heavy, context.mm.blueBlend, null, Colors.white),
        ].where(((int, Gradient?, Color?, Color) p) => p.$1 > 0).toList();
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: '$light light, $mixed mixed, $heavy heavy',
      excludeSemantics: true,
      child: SizedBox(
        height: 30,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < parts.length; i += 1) ...<Widget>[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: parts[i].$1,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: parts[i].$2,
                    color: parts[i].$3,
                    borderRadius: BorderRadius.horizontal(
                      left: i == 0 ? const Radius.circular(9) : Radius.zero,
                      right: i == parts.length - 1
                          ? const Radius.circular(9)
                          : Radius.zero,
                    ),
                  ),
                  child: Text(
                    '${parts[i].$1}',
                    style: AppFonts.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: parts[i].$4,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
