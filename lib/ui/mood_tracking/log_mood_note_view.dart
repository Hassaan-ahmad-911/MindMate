import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../Models/mood_catalog.dart';
import '../shared/app_card.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'log_mood_viewmodel.dart';
import 'widgets/log_step_scaffold.dart';
import 'widgets/mood_icon.dart';
import 'widgets/mood_widgets.dart';

/// Log step 3: an optional private note, then save.
class LogMoodNoteView extends GetView<LogMoodViewModel> {
  const LogMoodNoteView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return LogStepScaffold(
      step: 3,
      onLeading: controller.goBack,
      bottom: Obx(() {
        final bool saving = controller.isSaving.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GradientButton(
              label: 'Save entry',
              icon: Icons.check_rounded,
              isLoading: saving,
              onPressed: controller.save,
            ),
            Center(
              child: MoodTextLink(
                label: 'Skip the note',
                onTap: saving
                    ? () {}
                    : () => controller.save(includeNote: false),
              ),
            ),
          ],
        );
      }),
      children: <Widget>[
        Semantics(
          header: true,
          child: Text('Add a note', style: AppFonts.title(size: 36)),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Icon(Icons.lock_outline_rounded, size: 15, color: c.textMuted),
            const SizedBox(width: 6),
            Text(
              'Optional. Only you can see it.',
              style: AppFonts.body(size: 15),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _DraftSummary(),
        const SizedBox(height: 16),
        const _NoteField(),
        const SizedBox(height: 22),
        Text(
          'Not sure what to write?',
          style: AppFonts.body(
            size: 15,
            weight: FontWeight.w500,
            color: c.textBody,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: LogMoodViewModel.notePrompts
              .map(
                (String prompt) => _PromptChip(
                  label: prompt,
                  onTap: () => controller.insertPrompt(prompt),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

/// "Calm · Mild" chip followed by the chosen factors.
class _DraftSummary extends GetView<LogMoodViewModel> {
  const _DraftSummary();

  @override
  Widget build(BuildContext context) {
    final MoodDefinition? mood = controller.selectedMood.value;

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
          decoration: BoxDecoration(
            gradient: AppBlends.gold,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                alignment: Alignment.center,
                child: MoodIcon(
                  mood?.name ?? 'Okay',
                  size: 16,
                  color: AppColors.headerBlue,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                controller.summaryLabel,
                style: AppFonts.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.headerBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            controller.factorsLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.label(size: 14),
          ),
        ),
      ],
    );
  }
}

class _NoteField extends GetView<LogMoodViewModel> {
  const _NoteField();

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Column(
        children: <Widget>[
          TextField(
            controller: controller.noteController,
            minLines: 7,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(MoodCatalog.noteMaxLength),
            ],
            style: AppFonts.body(size: 16, color: c.textBody),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: 'Write anything you want to remember.',
              hintStyle: AppFonts.body(size: 16, color: c.textMuted),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Obx(
              () => Text(
                '${controller.noteLength.value} / ${MoodCatalog.noteMaxLength}',
                style: AppFonts.label(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(24);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: AppFonts.body(
              size: 14,
              weight: FontWeight.w500,
              color: context.mm.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
