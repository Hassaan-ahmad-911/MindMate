import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/mood_stats.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/mindmate_theme.dart';
import 'mood_insights_viewmodel.dart';
import 'mood_line_chart.dart';
import 'widgets/mood_visuals.dart';
import 'widgets/mood_widgets.dart';

/// Insights: patterns over a week, a month or 3 months.
class MoodInsightsView extends GetView<MoodInsightsViewModel> {
  const MoodInsightsView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Scaffold(
      backgroundColor: c.background,
      body: BlendedBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: c.accentText,
            onRefresh: controller.loadInsights,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: <Widget>[
                MoodPageHeader(title: 'Insights', onBack: Get.back),
                const SizedBox(height: 18),
                const _PeriodSwitch(),
                const SizedBox(height: 16),
                Obx(() {
                  if (controller.isLoading.value &&
                      controller.entries.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(color: c.accentText),
                      ),
                    );
                  }
                  if (controller.hasLoadError.value &&
                      controller.entries.isEmpty) {
                    return MoodMessageCard(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load your insights',
                      message: 'Check your connection and try again.',
                      actionLabel: 'Try again',
                      onAction: controller.loadInsights,
                    );
                  }
                  return const _InsightsBody();
                }),
                const SizedBox(height: 22),
                Text(
                  'Patterns are for your own reflection, not a diagnosis.',
                  textAlign: TextAlign.center,
                  style: AppFonts.label(size: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodSwitch extends GetView<MoodInsightsViewModel> {
  const _PeriodSwitch();

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(26),
        border: c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
      ),
      child: Obx(() {
        final InsightsPeriod selected = controller.period.value;
        return Row(
          children: InsightsPeriod.values
              .map((InsightsPeriod period) {
                final bool isSelected = period == selected;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.selectPeriod(period),
                      child: AnimatedContainer(
                        duration: AppMotion.of(
                          context,
                          const Duration(milliseconds: 200),
                        ),
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: isSelected ? c.blueBlend : null,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          period.label,
                          style: AppFonts.body(
                            size: 15,
                            weight: FontWeight.w600,
                            color: isSelected ? Colors.white : c.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      }),
    );
  }
}

class _InsightsBody extends GetView<MoodInsightsViewModel> {
  const _InsightsBody();

  @override
  Widget build(BuildContext context) => Obx(() => _buildBody(context.mm));

  Widget _buildBody(MindMateColors c) {
    final InsightsPeriod period = controller.period.value;
    final int entryCount = controller.entryCount;
    final List<MapEntry<String, int>> topMoods = controller.topMoods;
    final List<MapEntry<String, int>> topFactors = controller.topFactors;
    final String? pattern = controller.patternSentence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                value: '${controller.streak}',
                label: 'day streak',
                gradient: c.blueBlend,
                foreground: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                value: '$entryCount',
                label: entryCount == 1 ? 'entry' : 'entries',
                gradient: AppBlends.gold,
                foreground: AppColors.headerBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                value: '${controller.goodDays} of ${controller.loggedDays}',
                label: 'good days',
                gradient: AppBlends.lightBlue,
                foreground: AppColors.headerBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CardTitle(period.chartTitle),
              const SizedBox(height: 2),
              Text(
                entryCount == 0
                    ? 'No entries in this period yet.'
                    : controller.chartSubtitle,
                style: AppFonts.label(),
              ),
              const SizedBox(height: 16),
              if (entryCount == 0)
                const SizedBox(height: 40)
              else
                MoodLineChart(
                  points: controller.chartPoints,
                  bottomLabel: (int index, MoodDayPoint point) =>
                      _bottomLabel(period, index, point),
                ),
            ],
          ),
        ),
        if (topMoods.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _CardTitle('Most logged moods'),
                const SizedBox(height: 12),
                for (final MapEntry<String, int> mood in topMoods)
                  _MoodBar(
                    label: mood.key,
                    count: mood.value,
                    maxCount: topMoods.first.value,
                  ),
              ],
            ),
          ),
        ],
        if (topFactors.isNotEmpty || pattern != null) ...<Widget>[
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _CardTitle('What comes up most'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: topFactors
                      .map(
                        (MapEntry<String, int> factor) => _FactorCount(
                          label: factor.key,
                          count: factor.value,
                        ),
                      )
                      .toList(growable: false),
                ),
                if (pattern != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _PatternNote(text: pattern),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Weekday letters for a week; a few dates for longer periods.
  static String _bottomLabel(
    InsightsPeriod period,
    int index,
    MoodDayPoint point,
  ) {
    final int fromEnd = period.days - 1 - index;
    switch (period) {
      case InsightsPeriod.week:
        return MoodFormat.weekdayLetter(point.day);
      case InsightsPeriod.month:
        return fromEnd % 7 == 0 ? '${point.day.day}' : '';
      case InsightsPeriod.threeMonths:
        return fromEnd % 30 == 0
            ? '${point.day.day} ${MoodFormat.shortMonth(point.day)}'
            : '';
    }
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppFonts.body(
        size: 17,
        weight: FontWeight.w600,
        color: context.mm.textPrimary,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.gradient,
    required this.foreground,
  });

  final String value;
  final String label;
  final Gradient gradient;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppFonts.body(
                size: 28,
                weight: FontWeight.w700,
                color: foreground,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.label(size: 13, color: foreground),
          ),
        ],
      ),
    );
  }
}

class _MoodBar extends StatelessWidget {
  const _MoodBar({
    required this.label,
    required this.count,
    required this.maxCount,
  });

  final String label;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      label: '$label, $count',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 104,
              child: Text(
                label,
                style: AppFonts.body(size: 14, color: c.textBody),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: maxCount == 0 ? 0 : count / maxCount,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: const LinearGradient(
                        colors: <Color>[AppColors.secondary, AppColors.primary],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$count',
                textAlign: TextAlign.right,
                style: AppFonts.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactorCount extends StatelessWidget {
  const _FactorCount({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        gradient: AppBlends.lightBlue,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: AppFonts.body(
              size: 14,
              weight: FontWeight.w500,
              color: AppColors.headerBlue,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Text(
              '$count',
              style: AppFonts.body(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.headerBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternNote extends StatelessWidget {
  const _PatternNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Stronger peach in Dark so the navy text stays easy to read.
        color: AppColors.softSurface.withValues(
          alpha: context.mm.isDark ? 0.9 : 0.55,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.headerBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppFonts.body(size: 14, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
