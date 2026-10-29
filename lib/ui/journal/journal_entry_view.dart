import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/journal_content.dart';
import '../../Models/journal_model.dart';
import '../../Models/journal_rules.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/mindmate_theme.dart';
import 'journal_entry_viewmodel.dart';
import 'widgets/journal_widgets.dart';

/// Reading one entry.
class JournalEntryView extends GetView<JournalEntryViewModel> {
  const JournalEntryView({super.key});

  Future<void> _edit(BuildContext context) async {
    final bool showSupport = await controller.edit();
    final JournalSupportCard? card = controller.content.value?.supportCard;
    if (showSupport && card != null && context.mounted) {
      await showJournalSupportSheet(
        context,
        card: card,
        onTalk: controller.openSupport,
        closeLabel: 'Back to my entry',
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final bool? confirmed = await showJournalChoice(
      context,
      title: 'Delete this entry?',
      message: 'This cannot be undone.',
      confirm: 'Delete',
      cancel: 'Keep',
    );
    if (confirmed == true) {
      await controller.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: JournalBackground(blob: false)),
          SafeArea(
            child: Obx(() {
              final JournalModel? entry = controller.entry.value;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      JournalRoundButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Back',
                        onPressed: () => Get.back<void>(),
                      ),
                      const Spacer(),
                      if (entry != null) ...<Widget>[
                        JournalRoundButton(
                          icon: Icons.edit_outlined,
                          tooltip: 'Edit',
                          gold: true,
                          onPressed: () => _edit(context),
                        ),
                        const SizedBox(width: 10),
                        JournalRoundButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Delete',
                          onPressed: controller.isDeleting.value
                              ? null
                              : () => _delete(context),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  ..._content(context, entry),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, JournalModel? entry) {
    if (controller.isLoading.value) {
      return const <Widget>[
        Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ];
    }
    if (controller.hasError.value || entry == null) {
      return <Widget>[
        MoodMessageCard(
          icon: Icons.error_outline_rounded,
          title: 'This entry did not load',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: controller.load,
        ),
      ];
    }

    final JournalTone? tone = entry.tone;
    final List<JournalAnswer> answers = controller.answeredQuestions;
    final JournalTopicCount? topic = controller.topicLine.value;
    final MindMateColors c = context.mm;
    final TextStyle bodyStyle = AppFonts.body(
      size: 16.5,
      color: c.textBody,
      height: 1.5,
    );

    return <Widget>[
      Text(
        JournalDates.longDateTime(entry.createdAt),
        style: AppFonts.label(size: 14, color: c.textBody),
      ),
      const SizedBox(height: 4),
      Semantics(
        header: true,
        child: Text(entry.title, style: AppFonts.title(size: 34)),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (entry.hasMood) JournalMoodChip(label: entry.moodLabel!),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: c.surface,
              border: c.surfaceBorder == null
                  ? null
                  : Border.all(color: c.surfaceBorder!),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              JournalTypes.shortLabel(entry.type),
              style: AppFonts.label(
                size: 14,
                weight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          if (tone != null)
            JournalTonePill(
              tone: tone,
              large: true,
              labels:
                  controller.content.value?.tone.labels ??
                  const <String, String>{},
            ),
        ],
      ),
      const SizedBox(height: 18),
      AppCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (answers.isEmpty)
              SelectableText(entry.body, style: bodyStyle)
            else
              for (int i = 0; i < answers.length; i += 1) ...<Widget>[
                if (i > 0) const SizedBox(height: 16),
                Text(
                  answers[i].question,
                  style: AppFonts.body(
                    size: 14.5,
                    weight: FontWeight.w700,
                    color: c.accentText,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(answers[i].text, style: bodyStyle),
              ],
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: <Widget>[
          Text(
            entry.wordCount == 1 ? '1 word' : '${entry.wordCount} words',
            style: AppFonts.label(color: c.textBody),
          ),
          const Spacer(),
          if (entry.wasEdited)
            Text(
              'Edited ${JournalDates.time(entry.updatedAt)}',
              style: AppFonts.label(color: c.textBody),
            ),
        ],
      ),
      if (topic != null) ...<Widget>[
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.75),
            border: c.surfaceBorder == null
                ? null
                : Border.all(color: c.surfaceBorder!),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppFonts.body(size: 15, color: c.textBody),
                    children: <InlineSpan>[
                      const TextSpan(text: 'You wrote about '),
                      TextSpan(
                        text: JournalTopicWords.phrase(topic.topic),
                        style: AppFonts.body(
                          size: 15,
                          weight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      TextSpan(text: ' in ${topic.count} entries this month.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}
