import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../Models/mood_catalog.dart';
import '../../../Models/mood_model.dart';
import '../../shared/app_card.dart';
import '../../shared/mindmate_theme.dart';
import 'mood_icon.dart';
import 'mood_visuals.dart';

/// A mood icon in a round tile coloured by its group.
class MoodAvatar extends StatelessWidget {
  const MoodAvatar({
    super.key,
    required this.mood,
    required this.group,
    this.size = 44,
  });

  final String mood;
  final MoodGroup group;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: MoodVisuals.gradientFor(group),
      ),
      alignment: Alignment.center,
      child: MoodIcon(
        mood,
        size: size * 0.5,
        color: MoodVisuals.foregroundFor(group),
      ),
    );
  }
}

/// White round button used for close, back and filter actions.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Material(
      color: c.surface,
      shape: c.surfaceBorder == null
          ? const CircleBorder()
          : CircleBorder(side: BorderSide(color: c.surfaceBorder!)),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: c.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Back button and a Lobster title, with an optional action on the right.
class MoodPageHeader extends StatelessWidget {
  const MoodPageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        CircleIconButton(
          icon: Icons.chevron_left_rounded,
          onPressed: onBack,
          tooltip: 'Back',
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: AppFonts.title(size: 36)),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Close/back button, a 3-part progress bar and "x of 3".
class LogStepHeader extends StatelessWidget {
  const LogStepHeader({
    super.key,
    required this.step,
    required this.onLeading,
    this.isFirstStep = false,
  });

  final int step;
  final VoidCallback onLeading;
  final bool isFirstStep;

  static const int totalSteps = 3;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Row(
      children: <Widget>[
        CircleIconButton(
          icon: isFirstStep ? Icons.close_rounded : Icons.chevron_left_rounded,
          onPressed: onLeading,
          tooltip: isFirstStep ? 'Close' : 'Back',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Semantics(
            label: 'Step $step of $totalSteps',
            excludeSemantics: true,
            child: Row(
              children: List<Widget>.generate(totalSteps, (int index) {
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(
                      right: index == totalSteps - 1 ? 0 : 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: index < step ? c.blueBlendHorizontal : null,
                      color: index < step
                          ? null
                          : AppColors.secondary.withValues(
                              alpha: c.isDark ? 0.25 : 0.35,
                            ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          '$step of $totalSteps',
          style: AppFonts.label(size: 14, color: c.textBody),
        ),
      ],
    );
  }
}

/// One mood entry: avatar, mood name, strength and factors, and time.
class MoodEntryCard extends StatelessWidget {
  const MoodEntryCard({
    super.key,
    required this.entry,
    required this.timeLabel,
    this.showNote = false,
    this.onTap,
  });

  final MoodModel entry;
  final String timeLabel;
  final bool showNote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final String note = entry.note.trim().replaceAll('\n', ' ');

    return AppCard(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MoodAvatar(mood: entry.mood, group: entry.group),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.mood,
                        style: AppFonts.body(
                          size: 17,
                          weight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Text(timeLabel, style: AppFonts.label(color: c.textBody)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.detailLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.label(),
                ),
                if (showNote && note.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.body(size: 14, color: c.textBody),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small letter-spaced section title, e.g. "FEELING GOOD".
class MoodSectionLabel extends StatelessWidget {
  const MoodSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppFonts.label(
        size: 13,
        weight: FontWeight.w600,
        letterSpacing: 1.6,
        color: context.mm.textBody,
      ),
    );
  }
}

/// A friendly message inside a card, for empty and error states.
class MoodMessageCard extends StatelessWidget {
  const MoodMessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.22),
            ),
            child: Icon(icon, color: c.accentText, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppFonts.body(
              size: 17,
              weight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppFonts.body(size: 15),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: AppFonts.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Underlined text link with a gold underline.
class MoodTextLink extends StatelessWidget {
  const MoodTextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.mm.textPrimary;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(64, 44),
      ),
      child: Text(
        label,
        style: AppFonts.body(
          size: 16,
          weight: FontWeight.w700,
          color: ink,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.accent,
        ),
      ),
    );
  }
}

/// Dashed circle outline for a day with no entry.
class DashedCirclePainter extends CustomPainter {
  const DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final Rect rect = (Offset.zero & size).deflate(1);
    const int dashes = 16;
    const double sweep = 2 * math.pi / dashes;
    for (int i = 0; i < dashes; i += 1) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
