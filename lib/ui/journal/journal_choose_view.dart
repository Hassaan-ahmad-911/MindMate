import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/journal_content.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'journal_choose_viewmodel.dart';
import 'widgets/journal_widgets.dart';

/// "How do you want to write?"
class JournalChooseView extends GetView<JournalChooseViewModel> {
  const JournalChooseView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: JournalBackground()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: JournalRoundButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onPressed: controller.close,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Semantics(
                        header: true,
                        child: Text(
                          'How do you\nwant to write?',
                          style: AppFonts.title(size: 38),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick one. There is no wrong way.',
                        style: AppFonts.body(size: 16),
                      ),
                      const SizedBox(height: 22),
                      Obx(() {
                        if (controller.hasError.value) {
                          return MoodMessageCard(
                            icon: Icons.error_outline_rounded,
                            title: 'Something went wrong',
                            message: 'The writing options did not load.',
                            actionLabel: 'Try again',
                            onAction: controller.load,
                          );
                        }
                        return Column(
                          children: <Widget>[
                            for (final JournalTemplate t
                                in controller.templates)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _TemplateCard(
                                  template: t,
                                  selected: controller.selected.value == t.id,
                                  onTap: () => controller.select(t.id),
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Obx(
                    () => GradientButton(
                      label: 'Start writing',
                      onPressed: controller.templates.isEmpty
                          ? null
                          : controller.startWriting,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final JournalTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: '${template.title}. ${template.line}. ${template.hint}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 180)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? context.mm.selectedRing : Colors.transparent,
            width: 2,
          ),
        ),
        child: AppCard(
          onTap: onTap,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            children: <Widget>[
              JournalTypeTile(type: template.id),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      template.title,
                      style: AppFonts.body(
                        size: 17.5,
                        weight: FontWeight.w700,
                        color: context.mm.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      template.line,
                      style: AppFonts.body(size: 14, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      template.hint,
                      style: AppFonts.label(
                        size: 13,
                        weight: FontWeight.w600,
                        color: context.mm.accentText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Selector(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Selector extends StatelessWidget {
  const _Selector({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected ? AppBlends.gold : null,
        border: selected
            ? null
            : Border.all(color: AppColors.secondary, width: 1.8),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: 18,
              color: AppColors.headerBlue,
            )
          : null,
    );
  }
}
