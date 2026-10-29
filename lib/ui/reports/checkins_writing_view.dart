import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/assessment_rules.dart';
import '../../Models/journal_model.dart';
import '../../Models/report_calculator.dart';
import '../assessments/widgets/assessment_widgets.dart';
import '../journal/widgets/journal_widgets.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/mindmate_theme.dart';
import 'checkins_writing_viewmodel.dart';
import 'widgets/report_charts.dart';
import 'widgets/report_widgets.dart';

/// "Check-ins and writing".
class CheckInsWritingView extends GetView<CheckInsWritingViewModel> {
  const CheckInsWritingView({super.key});

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
                    child: Text(
                      'Check-ins and writing',
                      style: AppFonts.title(size: 34),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Last 30 days', style: AppFonts.body(size: 15.5)),
                  const SizedBox(height: 16),
                  if (controller.isLoading.value) ...const <Widget>[
                    ReportSkeleton(height: 220),
                    SizedBox(height: 12),
                    ReportSkeleton(height: 180),
                  ] else ...<Widget>[
                    _checkIns(c),
                    _journal(c),
                    if (!controller.checkIns.value.available &&
                        !controller.journal.value.available)
                      Text(
                        'Nothing to show yet.',
                        style: AppFonts.body(size: 15),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkIns(MindMateColors c) {
    if (!controller.checkIns.value.available) {
      return const SizedBox.shrink();
    }
    final AssessmentContent? content = controller.content.value;
    final List<AssessmentLatest> rows = controller.rows;
    final Widget body;
    if (controller.checkIns.value.failed || content == null) {
      body = SectionRetry(onRetry: controller.load);
    } else if (rows.isEmpty) {
      return const SizedBox.shrink();
    } else {
      final List<String> notTaken = controller.notTaken;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final AssessmentLatest r in rows)
            if (content.byId(r.latest.assessmentId) != null)
              _CheckInRow(def: content.byId(r.latest.assessmentId)!, row: r),
          if (notTaken.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Not taken in these 30 days: ${notTaken.join(', ')}',
              style: AppFonts.label(size: 13, color: c.textBody),
            ),
          ],
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: <Widget>[
          ReportCard(title: 'Latest check-ins', child: body),
          Positioned(
            right: 8,
            top: 4,
            child: MoodTextLink(label: 'See all', onTap: controller.seeAll),
          ),
        ],
      ),
    );
  }

  Widget _journal(MindMateColors c) {
    if (!controller.journal.value.available) {
      return const SizedBox.shrink();
    }
    if (controller.journal.value.failed) {
      return ReportCard(
        title: 'Journal tone',
        child: SectionRetry(onRetry: controller.load),
      );
    }
    final ToneSummary? t = controller.tone;
    if (t == null) {
      return const SizedBox.shrink();
    }
    final JournalTone? mostly = t.mostly;
    return ReportCard(
      title: 'Journal tone',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${t.entries} ${t.entries == 1 ? 'entry' : 'entries'}.'
            '${mostly == null ? '' : ' Mostly ${JournalToneVisuals.label(mostly).toLowerCase()}.'}',
            style: AppFonts.body(size: 15, color: c.textBody),
          ),
          const SizedBox(height: 12),
          ToneBar(light: t.light, mixed: t.mixed, heavy: t.heavy),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            children: <Widget>[
              const LegendItem(
                label: 'Light',
                gradient: AppBlends.gold,
                round: false,
              ),
              const LegendItem(
                label: 'Mixed',
                color: AppColors.secondary,
                round: false,
              ),
              LegendItem(label: 'Heavy', gradient: c.blueBlend, round: false),
            ],
          ),
          if (t.topTopics.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'You wrote most about',
              style: AppFonts.label(size: 13, color: c.textBody),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final MapEntry<String, int> topic in t.topTopics)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.accentText, width: 1.4),
                    ),
                    child: Text(
                      '${topic.key} ${topic.value}',
                      style: AppFonts.body(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const LockLine('Your journal text is never shown here.'),
        ],
      ),
    );
  }
}

class _CheckInRow extends StatelessWidget {
  const _CheckInRow({required this.def, required this.row});

  final AssessmentDefinition def;
  final AssessmentLatest row;

  @override
  Widget build(BuildContext context) {
    final AssessmentSummary s = row.latest;
    final double? headline = s.headline;
    final AssessmentBand? band = def.bandById(s.headlineBandId);
    final RangeTone tone = AssessmentMath.toneFor(def, band?.id);
    final int? change = ReportCalculator.checkInChange(row);
    final MindMateColors c = context.mm;
    final String sub;
    if (!def.hasTotal) {
      final String? top = s.areas == null || s.areas!.isEmpty
          ? null
          : s.areas!.entries
                .reduce(
                  (MapEntry<String, double> a, MapEntry<String, double> b) =>
                      b.value > a.value ? b : a,
                )
                .key;
      sub =
          '${def.scale} · highest area: ${def.areaById(top ?? '')?.label ?? ''}';
    } else {
      sub = '${def.scale} · ${AssessmentMath.shortDate(s.completedAt)}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AssessmentVisuals.toneGradient(tone),
              borderRadius: BorderRadius.circular(13),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  headline == null
                      ? '—'
                      : AssessmentMath.formatScore(def, headline),
                  style: AppFonts.body(
                    size: 17,
                    weight: FontWeight.w700,
                    color: AssessmentVisuals.toneText(tone),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${def.name} · ${band?.label ?? ''}',
                  style: AppFonts.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                Text(sub, style: AppFonts.label(size: 12.5)),
              ],
            ),
          ),
          if (change != null && change != 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  change < 0
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 14,
                  color: c.accentText,
                ),
                Text(
                  '${change.abs()}',
                  style: AppFonts.body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: c.accentText,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
