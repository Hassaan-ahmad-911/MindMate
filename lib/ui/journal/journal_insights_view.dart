import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/journal_model.dart';
import '../../Models/journal_rules.dart';
import '../home/widgets/home_skeleton.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/mindmate_theme.dart';
import 'journal_insights_viewmodel.dart';
import 'widgets/journal_widgets.dart';

/// "Your writing".
class JournalInsightsView extends GetView<JournalInsightsViewModel> {
  const JournalInsightsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: JournalBackground(blob: false)),
          SafeArea(
            child: Obx(
              () => ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      JournalRoundButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Back',
                        onPressed: controller.back,
                      ),
                      const Spacer(),
                      _MonthSwitcher(controller: controller),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Semantics(
                    header: true,
                    child: Text(
                      'Your writing',
                      style: AppFonts.title(size: 38),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._body(context),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: context.mm.textBody,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Worked out on your phone from your own words. '
                          'Not a diagnosis.',
                          style: AppFonts.label(
                            size: 13,
                            color: context.mm.textBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (controller.hasError.value) {
      return <Widget>[
        MoodMessageCard(
          icon: Icons.cloud_off_rounded,
          title: 'This month did not load',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: controller.load,
        ),
      ];
    }
    final JournalInsights? insights = controller.insights.value;
    if (controller.isLoading.value || insights == null) {
      return const <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: SkeletonBar(height: 84, radius: 20)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBar(height: 84, radius: 20)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBar(height: 84, radius: 20)),
          ],
        ),
        SizedBox(height: 14),
        SkeletonBar(height: 240, radius: 22),
      ];
    }

    final JournalTone? common = insights.mostCommonTone;
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: _Tile(
              value: '${insights.entryCount}',
              label: insights.entryCount == 1 ? 'entry' : 'entries',
              blue: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              value: '${insights.daysWritten}',
              label: insights.daysWritten == 1 ? 'day written' : 'days written',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              value: common == null ? '—' : JournalToneVisuals.label(common),
              label: 'most often',
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (!insights.showPatterns)
        AppCard(
          radius: 22,
          padding: const EdgeInsets.all(18),
          child: Text(
            'Write a few more entries this month to see your patterns.',
            style: AppFonts.body(size: 16, color: context.mm.textBody),
          ),
        )
      else ...<Widget>[
        _ToneByWeekCard(weeks: insights.weeks),
        if (insights.topTopics.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _TopicsCard(topics: insights.topTopics),
        ],
      ],
    ];
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.controller});

  final JournalInsightsViewModel controller;

  @override
  Widget build(BuildContext context) {
    final bool canGoForward = controller.canGoForward;
    final MindMateColors c = context.mm;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Previous month',
            onPressed: controller.previousMonth,
            icon: Icon(Icons.chevron_left_rounded, color: c.textPrimary),
          ),
          Text(
            controller.monthLabel,
            style: AppFonts.body(
              size: 15.5,
              weight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: canGoForward ? controller.nextMonth : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoForward
                  ? c.textPrimary
                  : c.textPrimary.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, this.blue = false});

  final String value;
  final String label;
  final bool blue;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        height: 84,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          gradient: blue ? AppBlends.blue : null,
          color: blue ? null : c.surface,
          border: blue || c.surfaceBorder == null
              ? null
              : Border.all(color: c.surfaceBorder!),
          borderRadius: BorderRadius.circular(20),
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
                  size: 26,
                  weight: FontWeight.w700,
                  color: blue ? Colors.white : c.textPrimary,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.label(
                size: 13,
                color: blue ? Colors.white.withValues(alpha: 0.88) : c.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToneByWeekCard extends StatelessWidget {
  const _ToneByWeekCard({required this.weeks});

  final List<JournalWeekTones> weeks;

  static const double _chartHeight = 130;

  @override
  Widget build(BuildContext context) {
    int maxTotal = 1;
    for (final JournalWeekTones w in weeks) {
      if (w.total > maxTotal) {
        maxTotal = w.total;
      }
    }

    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tone by week',
            style: AppFonts.body(
              size: 17,
              weight: FontWeight.w700,
              color: context.mm.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: _chartHeight + 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                for (final JournalWeekTones w in weeks)
                  _WeekBar(week: w, maxTotal: maxTotal, height: _chartHeight),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: <Widget>[
              _LegendDot(label: 'Heavy', gradient: AppBlends.blue),
              const _LegendDot(label: 'Mixed', gradient: AppBlends.lightBlue),
              const _LegendDot(label: 'Light', gradient: AppBlends.gold),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.week,
    required this.maxTotal,
    required this.height,
  });

  final JournalWeekTones week;
  final int maxTotal;
  final double height;

  @override
  Widget build(BuildContext context) {
    double part(int count) => height * count / maxTotal;
    final List<Widget> segments = <Widget>[
      if (week.light > 0) _segment(part(week.light), AppBlends.gold),
      if (week.mixed > 0) _segment(part(week.mixed), AppBlends.lightBlue),
      if (week.heavy > 0) _segment(part(week.heavy), AppBlends.blue),
    ];

    return Semantics(
      label:
          'Week ${week.week}: ${week.light} light, ${week.mixed} mixed, '
          '${week.heavy} heavy',
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          if (segments.isEmpty)
            Container(
              width: 34,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 34,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < segments.length; i += 1) ...<Widget>[
                      if (i > 0) const SizedBox(height: 2),
                      segments[i],
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Week ${week.week}',
            style: AppFonts.label(size: 12.5, color: context.mm.textBody),
          ),
        ],
      ),
    );
  }

  Widget _segment(double h, Gradient gradient) {
    return Container(
      height: h,
      decoration: BoxDecoration(gradient: gradient),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.gradient});

  final String label;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppFonts.label(size: 13, color: context.mm.textBody),
        ),
      ],
    );
  }
}

class _TopicsCard extends StatelessWidget {
  const _TopicsCard({required this.topics});

  final List<JournalTopicCount> topics;

  @override
  Widget build(BuildContext context) {
    final int max = topics.first.count;
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'What you wrote about',
            style: AppFonts.body(
              size: 17,
              weight: FontWeight.w700,
              color: context.mm.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (final JournalTopicCount t in topics)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Semantics(
                label: '${t.topic}: ${t.count} entries',
                excludeSemantics: true,
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 96,
                      child: Text(
                        t.topic,
                        style: AppFonts.body(
                          size: 15,
                          weight: FontWeight.w500,
                          color: context.mm.textBody,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              return Stack(
                                children: <Widget>[
                                  Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.22,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  Container(
                                    width: constraints.maxWidth * t.count / max,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      gradient: AppBlends.blueHorizontal,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ],
                              );
                            },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${t.count}',
                        textAlign: TextAlign.right,
                        style: AppFonts.body(
                          size: 15,
                          weight: FontWeight.w600,
                          color: context.mm.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
