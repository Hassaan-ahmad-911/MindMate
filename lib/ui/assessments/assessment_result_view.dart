import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/assessment_rules.dart';
import '../../Models/meditation_models.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'assessment_flow_viewmodel.dart';
import 'widgets/assessment_widgets.dart';

const String _notDiagnosis = 'This is a screening result, not a diagnosis.';

/// The result of PHQ-9, GAD-7, PSS-10 and WHO-5: a score ring and its range.
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.controller});

  final AssessmentFlowViewModel controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final AssessmentDefinition def = controller.def;
      final AssessmentResult result = controller.result.value!;
      final double total = result.total ?? 0;
      final AssessmentBand? band = controller.band;
      final int? change = controller.change;
      final AssessmentResult? previous = controller.previous.value;

      return _ResultFrame(
        controller: controller,
        header: def.checkTitle,
        children: <Widget>[
          if (controller.item9Positive) ...<Widget>[
            _Item9Card(controller: controller),
            const SizedBox(height: 18),
          ],
          Center(
            child: ScoreRing(
              value: total,
              max: def.max,
              label: AssessmentMath.formatScore(def, total),
              rangeStarts: <double>[
                for (final AssessmentBand b in def.bands.skip(1)) b.min,
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (band != null)
                RangePill(
                  label: '${band.label} range',
                  tone: AssessmentMath.toneFor(def, band.id),
                  large: true,
                ),
              if (change != null && previous != null)
                ChangePill(
                  change: change,
                  label: AssessmentMath.changeLabel(
                    change,
                    previous.completedAt,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (band?.line != null)
            Text(
              band!.line!,
              textAlign: TextAlign.center,
              style: AppFonts.body(size: 16, color: context.mm.textBody),
            ),
          Text(
            _notDiagnosis,
            textAlign: TextAlign.center,
            style: AppFonts.body(size: 15),
          ),
          if (def.bandsNote != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              def.bandsNote!,
              textAlign: TextAlign.center,
              style: AppFonts.label(size: 13),
            ),
          ],
        ],
      );
    });
  }
}

/// The result of the CBI and the workplace questionnaire: one card per area.
class AreaResultView extends StatelessWidget {
  const AreaResultView({super.key, required this.controller});

  final AssessmentFlowViewModel controller;

  static const List<String> _counts = <String>[
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final AssessmentDefinition def = controller.def;
      final AssessmentResult result = controller.result.value!;
      final String? topLine = controller.topLine;
      final int n = def.areas.length;
      final List<double> marks = def.hasTotal
          ? <double>[for (final AssessmentBand b in def.bands.skip(1)) b.min]
          : const <double>[50, 75];
      final AssessmentBand? overall = controller.band;

      return _ResultFrame(
        controller: controller,
        header: '${def.checkTitle} · ${def.scale}',
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              'Your ${n < _counts.length ? _counts[n] : n} areas',
              style: AppFonts.title(size: 34),
            ),
          ),
          const SizedBox(height: 6),
          if (topLine != null) Text(topLine, style: AppFonts.body(size: 16)),
          if (def.hasTotal && result.total != null && overall != null)
            Text(
              'Overall ${AssessmentMath.formatScore(def, result.total!)} · '
              '${overall.label}',
              style: AppFonts.body(
                size: 15.5,
                weight: FontWeight.w600,
                color: context.mm.accentText,
              ),
            ),
          const SizedBox(height: 16),
          AreaBars(def: def, areas: controller.sortedAreas, marks: marks),
          if (def.bandsNote != null)
            Text(def.bandsNote!, style: AppFonts.label(size: 13)),
          if (def.scale == 'MindMate')
            Text(
              'A MindMate questionnaire, not a clinical scale.',
              style: AppFonts.label(size: 13),
            ),
          const SizedBox(height: 4),
          Text(_notDiagnosis, style: AppFonts.label(size: 13)),
        ],
      );
    });
  }
}

/// The close button and header, the screen's own content, then the save
/// state, next step, practice, Done and "Review my answers".
class _ResultFrame extends StatelessWidget {
  const _ResultFrame({
    required this.controller,
    required this.header,
    required this.children,
  });

  final AssessmentFlowViewModel controller;
  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Obx(() => _build(context));
  }

  Widget _build(BuildContext context) {
    final String? nextStep = controller.nextStep;
    final MeditationSession? practice = controller.practice.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: <Widget>[
              CircleIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onPressed: controller.done,
              ),
              Expanded(
                child: Text(
                  header,
                  textAlign: TextAlign.center,
                  style: AppFonts.body(
                    size: 15,
                    weight: FontWeight.w600,
                    color: context.mm.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 46),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: <Widget>[
              ...children,
              if (controller.saveFailed.value) ...<Widget>[
                const SizedBox(height: 14),
                MoodMessageCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'Your result is not saved yet',
                  message: 'Check your connection and try again.',
                  actionLabel: 'Try again',
                  onAction: controller.retrySave,
                ),
              ],
              for (final FollowUpRule rule in controller.followUps) ...<Widget>[
                const SizedBox(height: 14),
                FollowUpCard(
                  text: rule.text,
                  onTake: () => controller.takeFollowUp(rule),
                ),
              ],
              if (nextStep != null) ...<Widget>[
                const SizedBox(height: 18),
                NextStepCard(text: nextStep, onSupport: controller.openSupport),
              ],
              if (practice != null) ...<Widget>[
                const SizedBox(height: 12),
                AssessmentPracticeCard(
                  label: controller.practiceLabel,
                  title: practice.title,
                  onTap: controller.openPractice,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            children: <Widget>[
              GradientButton(
                label: 'Done',
                icon: Icons.check_rounded,
                onPressed: controller.done,
              ),
              MoodTextLink(
                label: 'Review my answers',
                onTap: () => showReviewSheet(
                  context,
                  title: controller.def.checkTitle,
                  rows: controller.reviewRows,
                  onTakeAgain: controller.takeAgain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Above everything when PHQ-9 question 9 was answered above "Not at all",
/// whatever the total.
class _Item9Card extends StatelessWidget {
  const _Item9Card({required this.controller});

  final AssessmentFlowViewModel controller;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: AppBlends.blue,
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.isDark ? c.shadow : const Color(0x401F3550),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            controller.safety.resultCard,
            style: AppFonts.body(
              size: 16.5,
              weight: FontWeight.w600,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: controller.safety.talkTitle,
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppBlends.gold,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: controller.openSupport,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            controller.safety.talkTitle,
                            style: AppFonts.body(
                              size: 16.5,
                              weight: FontWeight.w700,
                              color: AppColors.headerBlue,
                            ),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.headerBlue,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
