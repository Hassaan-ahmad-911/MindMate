import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/check_in_questions.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../profile_setup/widgets/setup_widgets.dart';
import '../shared/blended_background.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'check_in_viewmodel.dart';

/// One check-in question at a time, with a progress bar, answer cards, "Next"
/// and "Skip this question". Back returns to the previous question.
class CheckInQuestionView extends GetView<CheckInViewModel> {
  const CheckInQuestionView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          controller.back();
        }
      },
      child: Scaffold(
        backgroundColor: context.mm.background,
        body: BlendedBackground(
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _TopBar(controller: controller),
                ),
                Expanded(
                  child: Obx(() {
                    final int index = controller.index.value;
                    return AnimatedSwitcher(
                      duration: AppMotion.of(
                        context,
                        const Duration(milliseconds: 250),
                      ),
                      child: _QuestionBody(
                        key: ValueKey<int>(index),
                        controller: controller,
                      ),
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Obx(
                        () => GradientButton(
                          label: controller.isLastQuestion ? 'Finish' : 'Next',
                          onPressed: controller.hasAnswer
                              ? controller.next
                              : null,
                        ),
                      ),
                      Center(
                        child: MoodTextLink(
                          label: 'Skip this question',
                          onTap: controller.skip,
                        ),
                      ),
                    ],
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final CheckInViewModel controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        CircleIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Back',
          onPressed: controller.back,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Obx(() {
            final int step = controller.index.value + 1;
            final int total = controller.questionCount;
            return Semantics(
              label: 'Question $step of $total',
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 6,
                  color: AppColors.secondary.withValues(alpha: 0.35),
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: AppMotion.of(
                      context,
                      const Duration(milliseconds: 250),
                    ),
                    widthFactor: step / total,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            AppColors.accent,
                            AppColors.primary,
                            AppColors.headerBlue,
                          ],
                          stops: <double>[0, 0.45, 1],
                        ),
                      ),
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 14),
        Obx(
          () => Text(
            '${controller.index.value + 1} of ${controller.questionCount}',
            style: AppFonts.label(size: 14, color: context.mm.textBody),
          ),
        ),
      ],
    );
  }
}

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({super.key, required this.controller});

  final CheckInViewModel controller;

  @override
  Widget build(BuildContext context) {
    final CheckInQuestion question = controller.question;

    return Obx(
      () => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        children: <Widget>[
          if (question.eyebrow != null) ...<Widget>[
            Text(
              question.eyebrow!.toUpperCase(),
              style: AppFonts.label(
                size: 13,
                weight: FontWeight.w600,
                letterSpacing: 1.6,
                color: context.mm.textBody,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Semantics(
            header: true,
            child: Text(
              question.title,
              style: AppFonts.title(size: 32, height: 1.2),
            ),
          ),
          if (question.multiSelect) ...<Widget>[
            const SizedBox(height: 6),
            Text('Choose any that apply.', style: AppFonts.label(size: 14)),
          ],
          const SizedBox(height: 18),
          for (final CheckInOption option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnswerCard(
                label: option.label,
                multiSelect: question.multiSelect,
                selected: controller.isSelected(option),
                onTap: () => controller.select(option),
              ),
            ),
        ],
      ),
    );
  }
}
