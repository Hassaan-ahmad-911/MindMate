import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/assessment_definition.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'assessment_flow_viewmodel.dart';
import 'assessment_result_view.dart';
import 'widgets/assessment_widgets.dart';

/// One questionnaire: intro, questions, question 9 support, result.
class AssessmentFlowView extends GetView<AssessmentFlowViewModel> {
  const AssessmentFlowView({super.key});

  Future<void> _close(BuildContext context) async {
    if (!controller.closeNeedsConfirm) {
      controller.close();
      return;
    }
    if (await confirmLeaveCheckIn(context)) {
      controller.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final AssessmentStep step = controller.step.value;
      return PopScope(
        canPop: !controller.closeNeedsConfirm,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) {
            _close(context);
          }
        },
        child: Scaffold(
          backgroundColor: context.mm.background,
          body: Stack(
            children: <Widget>[
              const Positioned.fill(child: BlendedBackground()),
              if (step != AssessmentStep.question)
                const Positioned(
                  right: -120,
                  top: -150,
                  child: BlobShape(size: 300, gradient: AppBlends.blueShape),
                ),
              SafeArea(child: _body(context, step)),
            ],
          ),
        ),
      );
    });
  }

  Widget _body(BuildContext context, AssessmentStep step) {
    switch (step) {
      case AssessmentStep.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case AssessmentStep.error:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: CircleIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onPressed: controller.close,
                ),
              ),
              const SizedBox(height: 40),
              MoodMessageCard(
                icon: Icons.error_outline_rounded,
                title: 'This check-in did not load',
                message: 'Please try again.',
                actionLabel: 'Try again',
                onAction: controller.load,
              ),
            ],
          ),
        );
      case AssessmentStep.intro:
        return _IntroView(
          controller: controller,
          onClose: () => _close(context),
        );
      case AssessmentStep.question:
        return _QuestionView(
          controller: controller,
          onClose: () => _close(context),
        );
      case AssessmentStep.safety:
        return _SafetyView(
          controller: controller,
          onClose: () => _close(context),
        );
      case AssessmentStep.result:
        return controller.def.hasAreas
            ? AreaResultView(controller: controller)
            : ResultView(controller: controller);
    }
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({required this.controller, required this.onClose});

  final AssessmentFlowViewModel controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AssessmentDefinition def = controller.def;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: CircleIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onPressed: onClose,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: AssessmentIconTile(icon: def.icon, size: 84),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(def.checkTitle, style: AppFonts.title(size: 38)),
              ),
              const SizedBox(height: 6),
              Text(
                '${def.scale} · ${def.items.length} questions · '
                'about ${def.minutes} minutes',
                style: AppFonts.body(
                  size: 15,
                  weight: FontWeight.w600,
                  color: context.mm.accentText,
                ),
              ),
              const SizedBox(height: 18),
              AppCard(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  children: <Widget>[
                    IntroBullet(icon: Icons.schedule_rounded, text: def.intro),
                    const IntroBullet(
                      icon: Icons.favorite_border_rounded,
                      text: 'There are no right or wrong answers',
                    ),
                    const IntroBullet(
                      icon: Icons.lock_outline_rounded,
                      text: 'Only you can see your answers',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(def.about, style: AppFonts.body(size: 14, height: 1.45)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: GradientButton(label: 'Start', onPressed: controller.start),
        ),
      ],
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({required this.controller, required this.onClose});

  final AssessmentFlowViewModel controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Obx(() {
      final int count = controller.itemCount;
      final bool extra = controller.onExtra;
      final int number = extra ? count : controller.index.value + 1;
      final String? stem = controller.stem;
      final int? selected = controller.selected;
      final List<AnswerOption> options = controller.options;

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
                  onPressed: onClose,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SegmentedProgress(count: count, current: number),
                ),
                const SizedBox(width: 12),
                Text(
                  extra ? 'One more' : '$number of $count',
                  style: AppFonts.label(size: 14, color: c.textBody),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: ValueKey<int>(controller.index.value),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              children: <Widget>[
                if (stem != null) ...<Widget>[
                  Text(stem, style: AppFonts.body(size: 15, color: c.textBody)),
                  const SizedBox(height: 8),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    controller.questionText,
                    style: AppFonts.body(
                      size: 23,
                      weight: FontWeight.w700,
                      color: c.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                for (final AnswerOption o in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnswerCard(
                      label: o.label,
                      selected: selected == o.value,
                      onTap: () => controller.select(o.value),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: <Widget>[
                _BackPill(onTap: controller.back),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    label: controller.nextLabel,
                    onPressed: controller.canGoNext ? controller.next : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _BackPill extends StatelessWidget {
  const _BackPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(29),
          side: c.surfaceBorder == null
              ? BorderSide.none
              : BorderSide(color: c.surfaceBorder!),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(29),
          onTap: onTap,
          child: SizedBox(
            height: GradientButton.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.chevron_left_rounded, color: c.textPrimary),
                  Text(
                    'Back',
                    style: AppFonts.body(
                      size: 17,
                      weight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown after PHQ-9 question 9 is answered above "Not at all".
class _SafetyView extends StatelessWidget {
  const _SafetyView({required this.controller, required this.onClose});

  final AssessmentFlowViewModel controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final s = controller.safety;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppBlends.gold,
                    border: Border.all(color: c.surface, width: 4),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x40E4B266),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: AppColors.headerBlue,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(s.title, style: AppFonts.title(size: 34)),
              ),
              const SizedBox(height: 10),
              Text(
                s.body,
                style: AppFonts.body(size: 16, color: c.textBody, height: 1.45),
              ),
              const SizedBox(height: 18),
              _SupportOption(
                title: s.talkTitle,
                sub: s.talkSub,
                icon: Icons.phone_outlined,
                filled: true,
                onTap: controller.openSupport,
              ),
              const SizedBox(height: 10),
              _SupportOption(
                title: s.trustTitle,
                sub: s.trustSub,
                icon: Icons.people_outline_rounded,
                filled: false,
                onTap: controller.reachOut,
              ),
              const SizedBox(height: 16),
              Text(
                s.footnote,
                style: AppFonts.label(size: 13, color: c.textBody),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            children: <Widget>[
              GradientButton(
                label: s.continueLabel,
                onPressed: controller.continueAfterSafety,
              ),
              MoodTextLink(label: s.stopLabel, onTap: controller.stopHere),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupportOption extends StatelessWidget {
  const _SupportOption({
    required this.title,
    required this.sub,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String title;
  final String sub;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final BorderRadius radius = BorderRadius.circular(20);
    final Color ink = filled ? c.onBlue : c.textPrimary;
    return Semantics(
      button: true,
      label: '$title. $sub',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: filled ? AppBlends.blue : null,
          color: filled ? null : c.surface,
          border: filled || c.surfaceBorder == null
              ? null
              : Border.all(color: c.surfaceBorder!),
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.isDark
                  ? c.shadow
                  : AppColors.headerBlue.withValues(
                      alpha: filled ? 0.25 : 0.06,
                    ),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: filled ? AppBlends.gold : AppBlends.lightBlue,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: AppColors.headerBlue),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: AppFonts.body(
                            size: 16,
                            weight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        Text(
                          sub,
                          style: AppFonts.label(
                            size: 13,
                            color: filled ? c.onBlueMuted : c.textBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
