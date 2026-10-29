import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/assessment_rules.dart';
import '../home/widgets/home_skeleton.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'assessment_history_viewmodel.dart';
import 'widgets/assessment_widgets.dart';
import 'widgets/history_chart.dart';

/// "Over time".
class AssessmentHistoryView extends GetView<AssessmentHistoryViewModel> {
  const AssessmentHistoryView({super.key});

  /// One line colour per area. The first follows the theme so it shows on
  /// the card in both themes.
  static List<Color> _areaColors(MindMateColors c) => <Color>[
    c.textPrimary,
    AppColors.primary,
    AppColors.secondary,
  ];

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          SafeArea(
            child: Obx(
              () => ListView(
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
                    child: Text('Over time', style: AppFonts.title(size: 38)),
                  ),
                  const SizedBox(height: 14),
                  _chips(c),
                  const SizedBox(height: 16),
                  ..._body(c),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(MindMateColors c) {
    final AssessmentContent? content = controller.content.value;
    if (content == null) {
      return const SizedBox(height: 44);
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: content.assessments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final AssessmentDefinition d = content.assessments[i];
          final bool selected = controller.selectedId.value == d.id;
          return Semantics(
            button: true,
            selected: selected,
            label: d.name,
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: selected ? AppBlends.blue : null,
                  color: selected ? null : c.surface,
                  border: selected || c.surfaceBorder == null
                      ? null
                      : Border.all(color: c.surfaceBorder!),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => controller.select(d.id),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    child: Text(
                      d.name,
                      style: AppFonts.body(
                        size: 14.5,
                        weight: FontWeight.w600,
                        color: selected ? Colors.white : c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _body(MindMateColors c) {
    final AssessmentDefinition? def = controller.def;
    if (controller.hasError.value) {
      return <Widget>[
        MoodMessageCard(
          icon: Icons.cloud_off_rounded,
          title: 'Your results did not load',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: controller.load,
        ),
      ];
    }
    if (controller.isLoading.value || def == null) {
      return const <Widget>[
        SkeletonBar(height: 250, radius: 22),
        SizedBox(height: 12),
        SkeletonBar(height: 64, radius: 20),
        SizedBox(height: 10),
        SkeletonBar(height: 64, radius: 20),
      ];
    }
    final List<AssessmentResult> results = controller.results;
    final InitialWho5? first = controller.firstCheckIn.value;
    if (results.isEmpty && first == null) {
      return <Widget>[
        AppCard(
          radius: 22,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Text(
                'Take this check-in to start seeing changes over time.',
                textAlign: TextAlign.center,
                style: AppFonts.body(size: 16, color: c.textBody),
              ),
              const SizedBox(height: 16),
              GradientButton(label: 'Start', onPressed: controller.start),
            ],
          ),
        ),
      ];
    }

    final String? footer = controller.footer;
    return <Widget>[
      _chartCard(def, c),
      const SizedBox(height: 14),
      for (int i = 0; i < results.length; i += 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ResultRow(
            def: def,
            result: results[i],
            change: controller.changeAt(i),
            date: AssessmentMath.listDate(
              results[i].completedAt,
              controller.now,
            ),
            onTap: () => controller.openResult(results[i]),
          ),
        ),
      if (first != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _FirstCheckInRow(def: def, first: first),
        ),
      if (footer != null) ...<Widget>[
        const SizedBox(height: 12),
        Text(
          footer,
          textAlign: TextAlign.center,
          style: AppFonts.label(size: 13.5, color: c.textBody),
        ),
      ],
    ];
  }

  Widget _chartCard(AssessmentDefinition def, MindMateColors c) {
    final bool areas = !def.hasTotal;
    final List<Color> areaColors = _areaColors(c);
    final List<List<double>> series;
    final List<String> labels;
    bool hollowFirst = false;
    if (areas) {
      final Map<String, List<double>> byArea = controller.areaSeries;
      series = <List<double>>[
        for (final AssessmentArea a in def.areas) byArea[a.id] ?? <double>[],
      ];
      labels = controller.areaDates.map(AssessmentMath.shortDate).toList();
    } else {
      final List<HistoryPoint> points = controller.chartPoints;
      series = <List<double>>[points.map((HistoryPoint p) => p.value).toList()];
      labels = points
          .map(
            (HistoryPoint p) =>
                p.firstCheckIn ? 'First' : AssessmentMath.shortDate(p.date),
          )
          .toList();
      hollowFirst = points.isNotEmpty && points.first.firstCheckIn;
    }

    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  areas ? '${def.scale} areas' : '${def.scale} score',
                  style: AppFonts.body(
                    size: 16,
                    weight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(
                def.lowerIsBetter ? 'Lower is better' : 'Higher is better',
                style: AppFonts.label(size: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          HistoryChart(
            series: series,
            colors: areas ? areaColors : <Color>[c.textPrimary],
            max: def.max,
            xLabels: labels,
            bands: areas ? null : def.bands,
            lowerIsBetter: def.lowerIsBetter,
            hollowFirst: hollowFirst,
            semanticLabel: '${def.scale} results over time',
          ),
          if (areas) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: <Widget>[
                for (int i = 0; i < def.areas.length; i += 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 14,
                        height: 4,
                        decoration: BoxDecoration(
                          color: areaColors[i % areaColors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        def.areas[i].label,
                        style: AppFonts.label(size: 12.5),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.text, required this.tone});

  final String text;
  final RangeTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AssessmentVisuals.toneGradient(tone),
        borderRadius: BorderRadius.circular(14),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            style: AppFonts.body(
              size: 18,
              weight: FontWeight.w700,
              color: AssessmentVisuals.toneText(tone),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.def,
    required this.result,
    required this.change,
    required this.date,
    required this.onTap,
  });

  final AssessmentDefinition def;
  final AssessmentResult result;
  final int? change;
  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors mm = context.mm;
    final double? value = result.headline;
    final AssessmentBand? band = def.bandById(result.headlineBandId);
    final int? c = change;
    final String changeText = c == null
        ? ''
        : c == 0
        ? '0'
        : c > 0
        ? '+$c'
        : '−${c.abs()}';
    return Semantics(
      button: true,
      label:
          '${band?.label ?? ''}, '
          '${value == null ? '' : AssessmentMath.formatScore(def, value)}, '
          '$date',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        radius: 20,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: <Widget>[
            _ScoreTile(
              text: value == null
                  ? '—'
                  : AssessmentMath.formatScore(def, value),
              tone: AssessmentMath.toneFor(def, band?.id),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    band?.label ?? '',
                    style: AppFonts.body(
                      size: 16,
                      weight: FontWeight.w700,
                      color: mm.textPrimary,
                    ),
                  ),
                  Text(date, style: AppFonts.label(size: 13)),
                ],
              ),
            ),
            Text(
              changeText,
              style: AppFonts.body(
                size: 14.5,
                weight: FontWeight.w600,
                color: mm.accentText,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: mm.textPrimary),
          ],
        ),
      ),
    );
  }
}

class _FirstCheckInRow extends StatelessWidget {
  const _FirstCheckInRow({required this.def, required this.first});

  final AssessmentDefinition def;
  final InitialWho5 first;

  @override
  Widget build(BuildContext context) {
    final AssessmentBand? band = def.bands
        .where((AssessmentBand b) => b.contains(first.score))
        .firstOrNull;
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: <Widget>[
          _ScoreTile(
            text: first.score.round().toString(),
            tone: AssessmentMath.toneFor(def, band?.id),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'First check-in',
                  style: AppFonts.body(
                    size: 16,
                    weight: FontWeight.w700,
                    color: context.mm.textPrimary,
                  ),
                ),
                Text(
                  '${band?.label ?? ''} · '
                  '${AssessmentMath.shortDate(first.completedAt)}',
                  style: AppFonts.label(size: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
