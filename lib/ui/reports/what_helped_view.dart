import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/report_calculator.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/mindmate_theme.dart';
import 'what_helped_viewmodel.dart';
import 'widgets/report_charts.dart';
import 'widgets/report_widgets.dart';

/// "What helped".
class WhatHelpedView extends GetView<WhatHelpedViewModel> {
  const WhatHelpedView({super.key});

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
                    child: Text('What helped', style: AppFonts.title(size: 38)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Patterns from the last 30 days. They show what goes '
                    'together, not what causes what.',
                    style: AppFonts.body(size: 15.5),
                  ),
                  const SizedBox(height: 16),
                  if (controller.isLoading.value) ...const <Widget>[
                    ReportSkeleton(height: 220),
                    SizedBox(height: 12),
                    ReportSkeleton(height: 180),
                  ] else ...<Widget>[
                    if (controller.moods.value.available) ...<Widget>[
                      _comparison(c),
                      const SizedBox(height: 12),
                    ],
                    if (controller.practice.value.available) ...<Widget>[
                      _beforeAfter(c),
                      const SizedBox(height: 12),
                    ],
                    if (controller.moods.value.available) _harder(c),
                  ],
                  const SizedBox(height: 16),
                  const LockLine(reportsFooter),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparison(MindMateColors c) {
    final List<ComparisonRow> rows = controller.rows;
    return ReportCard(
      title: 'Your mood on days when you…',
      child: controller.comparisonFailed && rows.isEmpty
          ? SectionRetry(onRetry: controller.load)
          : rows.isEmpty
          ? Text(
              'Log your mood on a few more days to see what goes together.',
              style: AppFonts.body(size: 15),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 14,
                  children: <Widget>[
                    const LegendItem(
                      label: 'On those days',
                      color: AppColors.accent,
                    ),
                    LegendItem(
                      label: 'Other days',
                      color: c.accentText,
                      ring: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final ComparisonRow r in rows)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Semantics(
                      label:
                          '${r.label}: average mood ${ReportCalculator.signed(r.onAverage)} '
                          'on ${r.onDays} days, ${ReportCalculator.signed(r.otherAverage)} '
                          'on ${r.otherDays} other days',
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  r.label,
                                  style: AppFonts.body(
                                    size: 15,
                                    weight: FontWeight.w600,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '${r.onDays} days vs ${r.otherDays}',
                                style: AppFonts.label(size: 12.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ComparisonScale(
                            on: r.onAverage,
                            other: r.otherAverage,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (final String l in <String>['Hard', 'Okay', 'Good'])
                      Text(l, style: AppFonts.label(size: 12)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _beforeAfter(MindMateColors c) {
    if (controller.practice.value.failed) {
      return ReportCard(
        title: 'Before and after practice',
        child: SectionRetry(onRetry: controller.load),
      );
    }
    final BeforeAfter? ba = controller.beforeAfter;
    if (ba == null) {
      return const SizedBox.shrink();
    }
    return ReportCard(
      title: 'Before and after practice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              style: AppFonts.body(size: 15, color: c.textBody),
              children: <InlineSpan>[
                const TextSpan(text: 'You felt better after '),
                TextSpan(
                  text: '${ba.better} of ${ba.count}',
                  style: AppFonts.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const TextSpan(text: ' practices.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BeforeAfterBars(before: ba.before, after: ba.after),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Average feeling, from 1 (very low) to 5 (very good)',
              textAlign: TextAlign.center,
              style: AppFonts.label(size: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _harder(MindMateColors c) {
    if (controller.moods.value.failed) {
      return ReportCard(
        title: 'On harder days',
        child: SectionRetry(onRetry: controller.load),
      );
    }
    final HarderDays? h = controller.harder;
    if (h == null) {
      return const SizedBox.shrink();
    }
    return ReportCard(
      title: 'On harder days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (h.sentence != null) ...<Widget>[
            Text(
              h.sentence!,
              style: AppFonts.body(size: 15, color: c.textBody),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (int i = 0; i < h.topFactors.length; i += 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: i == 0 ? c.blueBlend : AppBlends.lightBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${h.topFactors[i].key} ${h.topFactors[i].value}',
                    style: AppFonts.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: i == 0 ? Colors.white : AppColors.headerBlue,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
