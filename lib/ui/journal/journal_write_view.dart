import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/journal_content.dart';
import '../../Models/journal_model.dart';
import '../../Models/journal_rules.dart';
import '../../Models/mood_model.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'journal_write_viewmodel.dart';
import 'widgets/journal_widgets.dart';

/// Writing (and editing) an entry.
class JournalWriteView extends GetView<JournalWriteViewModel> {
  const JournalWriteView({super.key});

  Future<void> _close(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!controller.hasUnsavedText) {
      await controller.discardAndClose();
      return;
    }
    if (controller.isEditing) {
      final bool? discard = await showJournalChoice(
        context,
        title: 'Discard your changes?',
        confirm: 'Discard',
        cancel: 'Keep editing',
      );
      if (discard == true) {
        await controller.discardAndClose();
      }
      return;
    }
    final bool? keep = await showJournalChoice(
      context,
      title: 'Keep this as a draft?',
      message: 'You can carry on from where you left off.',
      confirm: 'Keep draft',
      cancel: 'Discard',
    );
    if (keep == true) {
      await controller.keepDraftAndClose();
    } else if (keep == false) {
      await controller.discardAndClose();
    }
  }

  void _primaryAction() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!controller.isEditing &&
        controller.type.value == JournalTypes.letItOut) {
      controller.finishLetItOut();
    } else {
      controller.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _close(context);
        }
      },
      child: Scaffold(
        backgroundColor: context.mm.background,
        body: Stack(
          children: <Widget>[
            const Positioned.fill(child: JournalBackground(blob: false)),
            SafeArea(
              child: Obx(() {
                if (controller.hasError.value) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: JournalRoundButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Close',
                            onPressed: () => Get.back<void>(),
                          ),
                        ),
                        const SizedBox(height: 40),
                        MoodMessageCard(
                          icon: Icons.error_outline_rounded,
                          title: 'Something went wrong',
                          message: 'The writing screen did not load.',
                          actionLabel: 'Try again',
                          onAction: controller.load,
                        ),
                      ],
                    ),
                  );
                }
                if (!controller.isReady.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TopBar(
                      controller: controller,
                      onClose: () => _close(context),
                      onChangeType: () => _showTypeSheet(context),
                    ),
                    Expanded(child: _Editor(controller: controller)),
                    _BottomBar(
                      controller: controller,
                      onPressed: _primaryAction,
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTypeSheet(BuildContext context) {
    final JournalContent? content = controller.content;
    if (content == null) {
      return Future<void>.value();
    }
    // Let it out cannot be chosen while editing a saved entry.
    final List<JournalTemplate> options = content.templates
        .where(
          (JournalTemplate t) =>
              !controller.isEditing || t.id != JournalTypes.letItOut,
        )
        .toList(growable: false);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.mm.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Change how you write',
                  style: AppFonts.body(
                    size: 19,
                    weight: FontWeight.w700,
                    color: sheetContext.mm.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'What you have written so far is kept.',
                  style: AppFonts.body(size: 14.5),
                ),
                const SizedBox(height: 12),
                for (final JournalTemplate t in options)
                  _SheetRow(
                    leading: JournalTypeTile(type: t.id, size: 42),
                    title: t.title,
                    subtitle: t.line,
                    selected: controller.type.value == t.id,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      controller.changeType(t.id);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.onClose,
    required this.onChangeType,
  });

  final JournalWriteViewModel controller;
  final VoidCallback onClose;
  final VoidCallback onChangeType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: <Widget>[
          JournalRoundButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onPressed: onClose,
          ),
          Expanded(
            child: Obx(() {
              final String status = controller.isEditing
                  ? 'Editing'
                  : controller.draftSaved.value
                  ? 'Draft saved'
                  : '';
              return Column(
                children: <Widget>[
                  Text(
                    controller.template.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.body(
                      size: 16,
                      weight: FontWeight.w700,
                      color: context.mm.textPrimary,
                    ),
                  ),
                  SizedBox(
                    height: 18,
                    child: status.isEmpty
                        ? null
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              if (!controller.isEditing)
                                Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: context.mm.accentText,
                                ),
                              const SizedBox(width: 3),
                              Text(
                                status,
                                style: AppFonts.label(
                                  size: 12.5,
                                  color: context.mm.textBody,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            }),
          ),
          JournalRoundButton(
            icon: Icons.shuffle_rounded,
            tooltip: 'Change how you write',
            onPressed: onChangeType,
          ),
        ],
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.controller});

  final JournalWriteViewModel controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final JournalTemplate template = controller.template;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: <Widget>[
          Text(
            JournalDates.longDateTime(controller.writtenAt),
            style: AppFonts.label(size: 14, color: context.mm.textBody),
          ),
          TextField(
            controller: controller.titleController,
            maxLength: JournalModel.titleMaxLength,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            style: AppFonts.body(
              size: 25,
              weight: FontWeight.w700,
              color: context.mm.textPrimary,
              height: 1.25,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              hintText: 'Give it a title',
              hintStyle: AppFonts.body(
                size: 25,
                weight: FontWeight.w700,
                color: context.mm.textPrimary.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _MoodRow(controller: controller),
          const SizedBox(height: 16),
          if (controller.showsPrompt) ...<Widget>[
            _PromptNote(text: controller.prompt!),
            const SizedBox(height: 12),
          ],
          if (template.isGuided)
            for (int i = 0; i < template.questions.length; i += 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuestionCard(
                  controller: controller,
                  number: i + 1,
                  question: template.questions[i],
                ),
              )
          else
            _FreeCard(
              controller: controller,
              letItOut: template.id == JournalTypes.letItOut,
            ),
        ],
      );
    });
  }
}

class _PromptNote extends StatelessWidget {
  const _PromptNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        // Full peach in Dark so the navy text stays easy to read.
        color: context.mm.isDark
            ? AppColors.softSurface
            : AppColors.softSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: AppColors.headerBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppFonts.body(
                size: 15.5,
                weight: FontWeight.w600,
                color: AppColors.headerBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.controller});

  final JournalWriteViewModel controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final JournalMoodLink? link = controller.mood.value;
      if (link == null) {
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _showMoodSheet(context, controller),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: context.mm.accentText,
              size: 20,
            ),
            label: Text(
              'Link a mood',
              style: AppFonts.body(
                size: 15,
                weight: FontWeight.w600,
                color: context.mm.textPrimary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent,
              ),
            ),
          ),
        );
      }
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: <Widget>[
          JournalMoodChip(label: link.chipLabel),
          Text(
            controller.isEditing ? 'linked mood ·' : "from today's mood ·",
            style: AppFonts.label(size: 13.5, color: context.mm.textBody),
          ),
          Semantics(
            button: true,
            label: 'Change the linked mood',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _showMoodSheet(context, controller),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Change',
                  style: AppFonts.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: context.mm.textPrimary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

Future<void> _showMoodSheet(
  BuildContext context,
  JournalWriteViewModel controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.mm.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetContext) {
      final List<MoodModel> moods = controller.dayMoods.toList();
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: <Widget>[
              Text(
                controller.isEditing ? 'Moods from that day' : "Today's moods",
                style: AppFonts.body(
                  size: 19,
                  weight: FontWeight.w700,
                  color: sheetContext.mm.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              for (final MoodModel mood in moods)
                _SheetRow(
                  leading: MoodAvatar(mood: mood.mood, group: mood.group),
                  title: '${mood.mood} · ${mood.intensity}',
                  subtitle: JournalDates.time(mood.date),
                  selected: controller.mood.value?.id == mood.id,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.selectMood(mood);
                  },
                ),
              _SheetRow(
                leading: const JournalMoodTile(moodLabel: null, size: 44),
                title: 'No mood',
                selected: controller.mood.value == null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.selectMood(null);
                },
              ),
              if (moods.isEmpty && !controller.isEditing)
                _SheetRow(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppBlends.gold,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: AppColors.headerBlue,
                    ),
                  ),
                  title: 'Log a mood',
                  subtitle: 'Then come back to your entry',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.logMood();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppFonts.body(
                        size: 16,
                        weight: FontWeight.w600,
                        color: context.mm.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: AppFonts.label(size: 13.5)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, color: context.mm.accentText),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.controller,
    required this.number,
    required this.question,
  });

  final JournalWriteViewModel controller;
  final int number;
  final JournalQuestion question;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Obx(() {
      final bool active = controller.activeQuestion.value == question.id;
      return AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 160)),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        decoration: BoxDecoration(
          color: c.input,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? c.selectedRing
                : c.surfaceBorder ?? Colors.transparent,
            width: 1.6,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.shadow,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: active ? AppBlends.gold : AppBlends.lightBlue,
                  ),
                  child: Text(
                    '$number',
                    style: AppFonts.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.headerBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.text,
                    style: AppFonts.body(
                      size: 16,
                      weight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            TextField(
              controller: controller.answerController(question.id),
              focusNode: controller.focusFor(question.id),
              minLines: 2,
              maxLines: null,
              maxLength: controller.answerMaxLength,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: AppFonts.body(size: 16, color: c.textBody),
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: '',
                hintText: question.placeholder,
                hintStyle: AppFonts.body(size: 16, color: c.textMuted),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _FreeCard extends StatelessWidget {
  const _FreeCard({required this.controller, required this.letItOut});

  final JournalWriteViewModel controller;
  final bool letItOut;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(20),
        border: c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller.bodyController,
        minLines: 10,
        maxLines: null,
        maxLength: JournalModel.bodyMaxLength,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: AppFonts.body(size: 16.5, color: c.textBody, height: 1.5),
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: letItOut
              ? 'Write whatever is there. No one else will read it.'
              : 'Start writing…',
          hintStyle: AppFonts.body(size: 16.5, color: c.textMuted),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, required this.onPressed});

  final JournalWriteViewModel controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Obx(() {
        final bool letItOut =
            !controller.isEditing &&
            controller.type.value == JournalTypes.letItOut;
        final int words = controller.wordCount.value;
        return Row(
          children: <Widget>[
            Text(
              words == 1 ? '1 word' : '$words words',
              style: AppFonts.label(size: 14, color: context.mm.textBody),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: GradientButton(
                label: controller.isEditing
                    ? 'Save changes'
                    : letItOut
                    ? 'Done'
                    : 'Save entry',
                icon: letItOut
                    ? Icons.arrow_forward_rounded
                    : Icons.check_rounded,
                isLoading: controller.isSaving.value,
                onPressed: onPressed,
              ),
            ),
          ],
        );
      }),
    );
  }
}
