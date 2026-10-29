import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../Models/mood_stats.dart';
import '../shared/mindmate_theme.dart';

/// Daily average mood score (-2..2) as a line. Days with no entry are
/// skipped and bridged with a dashed line; the latest point shows its mood.
class MoodLineChart extends StatelessWidget {
  const MoodLineChart({
    super.key,
    required this.points,
    required this.bottomLabel,
    this.height = 190,
  });

  /// One point per day, oldest first.
  final List<MoodDayPoint> points;

  /// Label under the point at an index, or an empty string for none.
  final String Function(int index, MoodDayPoint point) bottomLabel;
  final double height;

  static const double _maxScore = 2;

  /// The line colour: brand blue in Light, light blue in Dark so it stands
  /// out on the navy card.
  static Color _lineColor(MindMateColors c) =>
      c.isDark ? AppColors.secondary : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final List<int> logged = <int>[
      for (int i = 0; i < points.length; i += 1)
        if (points[i].score != null) i,
    ];
    if (logged.isEmpty) {
      return SizedBox(height: height);
    }

    final bool showAllDots = points.length <= 31;
    final List<LineChartBarData> bars = <LineChartBarData>[];
    final int lastIndex = logged.last;
    int? lastBarIndex;

    FlSpot spotAt(int index) =>
        FlSpot(index.toDouble(), points[index].score!.clamp(-2, 2).toDouble());

    // Solid lines for runs of consecutive days, dashed lines across gaps.
    List<FlSpot> run = <FlSpot>[spotAt(logged.first)];
    for (int i = 1; i <= logged.length; i += 1) {
      final bool continues =
          i < logged.length && logged[i] == logged[i - 1] + 1;
      if (continues) {
        run.add(spotAt(logged[i]));
        continue;
      }
      if (run.last.x == lastIndex) {
        lastBarIndex = bars.length;
      }
      bars.add(_solidBar(c, run, showAllDots, lastIndex));
      if (i < logged.length) {
        bars.add(_dashedBar(c, run.last, spotAt(logged[i])));
        run = <FlSpot>[spotAt(logged[i])];
      }
    }

    final LineChartBarData lastBar = bars[lastBarIndex!];
    final String latestMood = points[lastIndex].latestMood ?? '';

    return SizedBox(
      height: height,
      child: LineChart(
        duration: AppMotion.of(context, const Duration(milliseconds: 250)),
        LineChartData(
          minX: 0,
          maxX: points.length > 1 ? (points.length - 1).toDouble() : 1,
          minY: -_maxScore - 0.4,
          maxY: _maxScore + 0.4,
          clipData: const FlClipData.none(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 2,
            checkToShowHorizontalLine: (double value) => value % 2 == 0,
            getDrawingHorizontalLine: (double value) => FlLine(
              color: AppColors.secondary.withValues(
                alpha: c.isDark ? 0.3 : 0.35,
              ),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: 2,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final String label = switch (value.round()) {
                    2 => 'Good',
                    0 => 'Okay',
                    -2 => 'Hard',
                    _ => '',
                  };
                  if (label.isEmpty || value % 2 != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      label,
                      style: AppFonts.label(size: 12, color: c.textMuted),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.round();
                  if (value != index || index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final String label = bottomLabel(index, points[index]);
                  if (label.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      label,
                      style: AppFonts.label(
                        size: 12,
                        weight: index == points.length - 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: index == points.length - 1
                            ? c.textPrimary
                            : c.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: false,
            touchTooltipData: LineTouchTooltipData(
              // Navy in Light; gold in Dark, matching the latest dot.
              getTooltipColor: (LineBarSpot spot) =>
                  c.isDark ? AppColors.accent : AppColors.headerBlue,
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              tooltipMargin: 12,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (List<LineBarSpot> spots) => spots
                  .map(
                    (LineBarSpot spot) => LineTooltipItem(
                      latestMood,
                      AppFonts.label(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.isDark ? AppColors.headerBlue : Colors.white,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          showingTooltipIndicators: latestMood.isEmpty
              ? const <ShowingTooltipIndicators>[]
              : <ShowingTooltipIndicators>[
                  ShowingTooltipIndicators(<LineBarSpot>[
                    LineBarSpot(lastBar, lastBarIndex, lastBar.spots.last),
                  ]),
                ],
          lineBarsData: bars,
        ),
      ),
    );
  }

  LineChartBarData _solidBar(
    MindMateColors c,
    List<FlSpot> spots,
    bool showAllDots,
    int last,
  ) {
    final Color line = _lineColor(c);
    return LineChartBarData(
      spots: spots,
      color: line,
      barWidth: 2.6,
      isStrokeCapRound: true,
      belowBarData: BarAreaData(
        show: spots.length > 1,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.secondary.withValues(alpha: 0.35),
            AppColors.secondary.withValues(alpha: 0),
          ],
        ),
      ),
      dotData: FlDotData(
        checkToShowDot: (FlSpot spot, LineChartBarData bar) =>
            showAllDots || spot.x == last,
        getDotPainter:
            (FlSpot spot, double percent, LineChartBarData bar, int index) {
              if (spot.x == last) {
                return FlDotCirclePainter(
                  radius: 5.5,
                  color: c.isDark ? AppColors.accent : AppColors.headerBlue,
                  strokeWidth: 2.5,
                  strokeColor: c.surface,
                );
              }
              return FlDotCirclePainter(
                radius: 3.6,
                color: c.surface,
                strokeWidth: 2.2,
                strokeColor: line,
              );
            },
      ),
    );
  }

  LineChartBarData _dashedBar(MindMateColors c, FlSpot from, FlSpot to) {
    return LineChartBarData(
      spots: <FlSpot>[from, to],
      color: _lineColor(c).withValues(alpha: 0.6),
      barWidth: 2,
      dashArray: const <int>[4, 4],
      dotData: const FlDotData(show: false),
    );
  }
}
