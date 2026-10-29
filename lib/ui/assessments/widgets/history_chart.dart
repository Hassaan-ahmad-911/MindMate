import 'package:flutter/material.dart';

import '../../../Models/assessment_definition.dart';
import '../../shared/mindmate_theme.dart';

/// A line chart of results over time, drawn with a [CustomPainter].
///
/// With [bands], each range is shaded behind the line (lightest for the best
/// range, darker for each range after it) and named on the right. The newest
/// point of the first line is a gold dot.
class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.series,
    required this.colors,
    required this.max,
    required this.xLabels,
    this.bands,
    this.lowerIsBetter = true,
    this.hollowFirst = false,
    this.semanticLabel = '',
  });

  /// One list of values per line, all the same length, oldest first.
  final List<List<double>> series;
  final List<Color> colors;
  final double max;
  final List<String> xLabels;
  final List<AssessmentBand>? bands;
  final bool lowerIsBetter;

  /// Draws the first point hollow (the first check-in).
  final bool hollowFirst;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: CustomPaint(
          painter: _HistoryPainter(
            series: series,
            colors: colors,
            max: max,
            xLabels: xLabels,
            bands: bands,
            lowerIsBetter: lowerIsBetter,
            hollowFirst: hollowFirst,
            labelStyle: AppFonts.label(size: 10.5, color: c.textBody),
            dotFill: c.surface,
            bandBase: c.isDark ? 0.10 : 0.12,
            bandStep: c.isDark ? 0.08 : 0.11,
          ),
        ),
      ),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter({
    required this.series,
    required this.colors,
    required this.max,
    required this.xLabels,
    required this.bands,
    required this.lowerIsBetter,
    required this.hollowFirst,
    required this.labelStyle,
    required this.dotFill,
    required this.bandBase,
    required this.bandStep,
  });

  final List<List<double>> series;
  final List<Color> colors;
  final double max;
  final List<String> xLabels;
  final List<AssessmentBand>? bands;
  final bool lowerIsBetter;
  final bool hollowFirst;
  final TextStyle labelStyle;

  /// The fill of each point (the card's surface).
  final Color dotFill;

  /// The light-blue alpha of the best range's shading, and how much each
  /// range after it adds.
  final double bandBase;
  final double bandStep;

  static const double _bottom = 22;
  static const double _labelColumn = 74;

  @override
  void paint(Canvas canvas, Size size) {
    final List<AssessmentBand>? b = bands;
    final double right = b == null ? size.width : size.width - _labelColumn;
    final Rect plot = Rect.fromLTRB(0, 6, right, size.height - _bottom);
    double y(double v) =>
        plot.bottom - (v / (max <= 0 ? 1 : max)).clamp(0.0, 1.0) * plot.height;

    if (b != null) {
      for (int i = 0; i < b.length; i += 1) {
        final double top = i + 1 < b.length ? b[i + 1].min : max;
        final Rect rect = Rect.fromLTRB(
          plot.left,
          y(top),
          plot.right,
          y(b[i].min),
        );
        final int rank = lowerIsBetter ? i : b.length - 1 - i;
        canvas.drawRect(
          rect,
          Paint()
            ..color = AppColors.secondary.withValues(
              alpha: bandBase + bandStep * rank,
            ),
        );
        if (rect.height >= 12) {
          _text(
            canvas,
            b[i].label,
            Offset(right + 8, rect.center.dy),
            _labelColumn - 10,
            alignLeft: true,
          );
        }
      }
    } else {
      final Paint grid = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (final double v in <double>[0, 50, 100]) {
        canvas.drawLine(
          Offset(plot.left, y(v)),
          Offset(plot.right, y(v)),
          grid,
        );
      }
    }

    final int n = series.isEmpty ? 0 : series.first.length;
    if (n == 0) {
      return;
    }
    const double inset = 14;
    double x(int i) => n == 1
        ? plot.center.dx
        : plot.left + inset + (plot.width - 2 * inset) * i / (n - 1);

    for (int s = 0; s < series.length; s += 1) {
      final List<double> values = series[s];
      final Color color = colors[s % colors.length];
      final Path path = Path();
      for (int i = 0; i < values.length; i += 1) {
        final Offset p = Offset(x(i), y(values[i]));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
      for (int i = 0; i < values.length; i += 1) {
        final Offset p = Offset(x(i), y(values[i]));
        final bool newest = s == 0 && i == values.length - 1;
        final bool hollow = hollowFirst && s == 0 && i == 0;
        canvas.drawCircle(
          p,
          newest ? 6 : 4.5,
          Paint()..color = newest ? AppColors.accent : dotFill,
        );
        canvas.drawCircle(
          p,
          newest ? 6 : 4.5,
          Paint()
            ..color = hollow ? AppColors.primary : color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    final int step = n > 6 ? 2 : 1;
    for (int i = 0; i < n && i < xLabels.length; i += 1) {
      if (i % step != 0 && i != n - 1) {
        continue;
      }
      _text(canvas, xLabels[i], Offset(x(i), size.height - 9), 50);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor,
    double maxWidth, {
    bool alignLeft = false,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final double dx = alignLeft ? anchor.dx : anchor.dx - painter.width / 2;
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(_HistoryPainter old) =>
      old.series != series ||
      old.bands != bands ||
      old.xLabels != xLabels ||
      old.colors != colors ||
      old.labelStyle != labelStyle ||
      old.dotFill != dotFill ||
      old.bandBase != bandBase ||
      old.bandStep != bandStep;
}
