import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Data/repositories/report_repository.dart';
import '../../Models/mood_catalog.dart';
import '../../Models/report_calculator.dart';
import '../../Models/report_period.dart';
import '../mood_tracking/widgets/mood_visuals.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/mindmate_theme.dart';
import 'reports_viewmodel.dart';
import 'widgets/report_charts.dart';
import 'widgets/report_widgets.dart';

/// Reports: the week or the month.
class ReportsView extends GetView<ReportsViewModel> {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          const Positioned(
            right: -120,
            top: -150,
            child: BlobShape(size: 300, gradient: AppBlends.blueShape),
          ),
          SafeArea(
            child: Obx(() {
              final ReportPeriod p = controller.period.value;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleIconButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Back',
                      onPressed: controller.back,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    header: true,
                    child: Text('Reports', style: AppFonts.title(size: 40)),
                  ),
                  const SizedBox(height: 14),
                  KindSwitch(kind: p.kind, onChanged: controller.setKind),
                  const SizedBox(height: 10),
                  PeriodPill(
                    label: p.label,
                    onPrevious: controller.previousPeriod,
                    onNext: controller.canGoForward
                        ? controller.nextPeriod
                        : null,
                  ),
                  const SizedBox(height: 14),
                  if (controller.isLoading.value ||
                      controller.bundle.value == null)
                    ..._skeleton()
                  else if (p.kind == ReportKind.week)
                    ..._week(p, c)
                  else
                    ..._month(p, c),
                  const SizedBox(height: 16),
                  const LockLine(reportsFooter),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  List<Widget> _skeleton() => const <Widget>[
    ReportSkeleton(height: 150),
    SizedBox(height: 12),
    ReportSkeleton(height: 130),
    SizedBox(height: 12),
    ReportSkeleton(height: 200),
  ];

  Widget _highlights(ReportPeriod p) {
    final PeriodStats now = controller.current;
    final List<Highlight> lines = controller.highlights;
    final bool nothing = !now.hasAnyData;
    if (!nothing && lines.isEmpty) {
      return const SizedBox.shrink();
    }
    return HighlightsCard(
      label: 'Your ${p.unit}',
      lines: lines,
      nothingLogged: nothing,
      onLogMood: controller.logMood,
    );
  }

  List<Widget> _week(ReportPeriod p, MindMateColors c) {
    return <Widget>[
      _highlights(p),
      const SizedBox(height: 12),
      _dayByDay(c),
      const SizedBox(height: 12),
      ..._weekTiles(),
      const SizedBox(height: 10),
      LookCloserSection(
        onHelped: controller.openHelped,
        onCheckIns: controller.openCheckIns,
        onShare: controller.openShare,
      ),
    ];
  }

  List<Widget> _month(ReportPeriod p, MindMateColors c) {
    return <Widget>[
      _calendar(c),
      const SizedBox(height: 12),
      if (controller.available(ReportSource.moods)) ...<Widget>[
        ReportCard(
          title: 'Week by week',
          trailing: 'Average mood',
          child: controller.failed(ReportSource.moods)
              ? SectionRetry(onRetry: controller.retry)
              : WeekByWeekChart(weeks: controller.weeks),
        ),
        const SizedBox(height: 12),
      ],
      _monthTiles(),
      const SizedBox(height: 12),
      _highlights(p),
      const SizedBox(height: 10),
      LookCloserSection(
        onHelped: controller.openHelped,
        onCheckIns: controller.openCheckIns,
        onShare: controller.openShare,
      ),
    ];
  }

  Widget _dayByDay(MindMateColors c) {
    if (!controller.available(ReportSource.moods)) {
      return const SizedBox.shrink();
    }
    final List<ReportDay> days = controller.days;
    const List<String> names = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return ReportCard(
      title: 'Day by day',
      trailing: 'Mood and activity',
      child: controller.failed(ReportSource.moods)
          ? SectionRetry(onRetry: controller.retry)
          : Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    for (int i = 0; i < days.length; i += 1)
                      Expanded(
                        child: Semantics(
                          button: !days[i].isFuture,
                          label: _dayLabel(names[i], days[i]),
                          excludeSemantics: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: days[i].isFuture
                                ? null
                                : () => controller.openDay(days[i].day),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: <Widget>[
                                  Text(
                                    names[i],
                                    style: AppFonts.label(
                                      size: 12,
                                      color: c.textBody,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DayCircle(day: days[i], size: 36),
                                  const SizedBox(height: 6),
                                  ActivityDots(day: days[i]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    if (controller.available(ReportSource.practice))
                      const LegendItem(
                        label: 'Practice',
                        color: AppColors.accent,
                      ),
                    if (controller.available(ReportSource.journal))
                      LegendItem(label: 'Journal', color: c.textPrimary),
                    if (controller.available(ReportSource.breaks))
                      const LegendItem(
                        label: 'Break',
                        color: AppColors.secondary,
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  static String _dayLabel(String name, ReportDay d) {
    final List<String> parts = <String>[
      name,
      d.group == null ? 'no mood' : d.group!.shortLabel,
      if (d.practised == true) 'practised',
      if (d.journaled == true) 'journal',
      if (d.tookBreak == true) 'break',
    ];
    return parts.join(', ');
  }

  List<Widget> _weekTiles() {
    final PeriodStats now = controller.current;
    final List<Widget> tiles = <Widget>[
      if (controller.available(ReportSource.moods))
        StatTile(
          value: '${now.moodDays}',
          unit: 'of 7',
          label: 'days with a mood',
          blue: true,
          failed: controller.failed(ReportSource.moods),
          onRetry: controller.retry,
        ),
      if (controller.available(ReportSource.practice))
        StatTile(
          value: '${now.calmMinutes}',
          unit: 'min',
          label: 'calm minutes',
          change: controller.change((PeriodStats s) => s.calmMinutes),
          failed: controller.failed(ReportSource.practice),
          onRetry: controller.retry,
        ),
      if (controller.available(ReportSource.journal))
        StatTile(
          value: '${now.journalEntries}',
          label: 'journal entries',
          change: controller.change((PeriodStats s) => s.journalEntries),
          failed: controller.failed(ReportSource.journal),
          onRetry: controller.retry,
        ),
      if (controller.available(ReportSource.breaks))
        StatTile(
          value: '${now.breaks}',
          label: 'short breaks',
          change: controller.change((PeriodStats s) => s.breaks),
          failed: controller.failed(ReportSource.breaks),
          onRetry: controller.retry,
        ),
    ];
    return <Widget>[
      for (int i = 0; i < tiles.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: tiles[i]),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _monthTiles() {
    final PeriodStats now = controller.current;
    final List<Widget> tiles = <Widget>[
      if (controller.available(ReportSource.moods))
        StatTile(
          value: '${now.moodDays}',
          label: 'days logged',
          blue: true,
          failed: controller.failed(ReportSource.moods),
          onRetry: controller.retry,
        ),
      if (controller.available(ReportSource.practice))
        StatTile(
          value: ReportCalculator.hoursMinutes(now.calmMinutes),
          label: 'calm time',
          failed: controller.failed(ReportSource.practice),
          onRetry: controller.retry,
        ),
      if (controller.available(ReportSource.journal))
        StatTile(
          value: '${now.journalEntries}',
          label: 'entries',
          failed: controller.failed(ReportSource.journal),
          onRetry: controller.retry,
        ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < tiles.length; i += 1) ...<Widget>[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  Widget _calendar(MindMateColors c) {
    if (!controller.available(ReportSource.moods)) {
      return const SizedBox.shrink();
    }
    if (controller.failed(ReportSource.moods)) {
      return ReportCard(
        title: 'Your month',
        child: SectionRetry(onRetry: controller.retry),
      );
    }
    final List<ReportDay> days = controller.days;
    final int lead = days.first.day.weekday - 1;
    const List<String> letters = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final List<Widget> cells = <Widget>[
      for (int i = 0; i < lead; i += 1) const SizedBox.shrink(),
      for (final ReportDay d in days)
        _CalendarCell(day: d, onTap: controller.openDay),
    ];
    return ReportCard(
      title: 'Your month',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              for (final String l in letters)
                Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: AppFonts.label(size: 12, color: c.textBody),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: cells,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: <Widget>[
              const LegendItem(
                label: 'Good',
                gradient: AppBlends.gold,
                round: false,
              ),
              const LegendItem(
                label: 'In between',
                color: AppColors.secondary,
                round: false,
              ),
              LegendItem(label: 'Hard', gradient: c.blueBlend, round: false),
              if (controller.available(ReportSource.practice))
                LegendItem(label: 'Practised', color: c.textPrimary),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({required this.day, required this.onTap});

  final ReportDay day;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final MoodGroup? g = day.group;
    // Navy on the gold and light-blue tiles, white on the blue "hard" tile,
    // the theme's text colour on an empty cell.
    final Color text = g == MoodGroup.hard
        ? Colors.white
        : (g == null ? c.textPrimary : AppColors.headerBlue);
    return Opacity(
      opacity: day.isFuture ? 0.35 : 1,
      child: Semantics(
        button: !day.isFuture,
        label:
            '${day.day.day}: ${g == null ? 'no mood' : g.shortLabel}'
            '${day.practised == true ? ', practised' : ''}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: day.isFuture ? null : () => onTap(day.day),
          child: Container(
            decoration: BoxDecoration(
              gradient: g == null || g == MoodGroup.between
                  ? null
                  : MoodVisuals.gradientFor(g),
              color: g == MoodGroup.between
                  ? AppColors.secondary
                  : (g == null ? c.surface : null),
              borderRadius: BorderRadius.circular(10),
              border: g == null
                  ? Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.6),
                    )
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Text(
                  '${day.day.day}',
                  style: AppFonts.body(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: g == null ? c.textBody : text,
                  ),
                ),
                if (day.practised == true)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: text,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
