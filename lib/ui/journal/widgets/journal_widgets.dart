import 'package:flutter/material.dart';

import '../../../Models/journal_content.dart';
import '../../../Models/journal_model.dart';
import '../../../Models/mood_catalog.dart';
import '../../home/widgets/home_skeleton.dart';
import '../../mood_tracking/widgets/mood_icon.dart';
import '../../mood_tracking/widgets/mood_visuals.dart';
import '../../shared/app_card.dart';
import '../../shared/blended_background.dart';
import '../../shared/blob_shape.dart';
import '../../shared/mindmate_theme.dart';

/// The cream page with the blue blob in the top-right corner.
class JournalBackground extends StatelessWidget {
  const JournalBackground({super.key, this.blob = true});

  final bool blob;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: BlendedBackground()),
        if (blob)
          const Positioned(
            right: -120,
            top: -150,
            child: BlobShape(size: 300, gradient: AppBlends.blueShape),
          ),
      ],
    );
  }
}

/// The mood face on a rounded tile coloured by the mood's group, or a book on
/// light blue when no mood is linked.
class JournalMoodTile extends StatelessWidget {
  const JournalMoodTile({super.key, required this.moodLabel, this.size = 46});

  final String? moodLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? label = moodLabel;
    final MoodGroup? group = label == null
        ? null
        : MoodCatalog.find(label)?.group;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: group == null
            ? AppBlends.lightBlue
            : MoodVisuals.gradientFor(group),
      ),
      alignment: Alignment.center,
      child: group == null || label == null
          ? Icon(
              Icons.menu_book_rounded,
              size: size * 0.48,
              color: AppColors.headerBlue,
            )
          : MoodIcon(
              label,
              size: size * 0.52,
              color: MoodVisuals.foregroundFor(group),
            ),
    );
  }
}

/// The colours of a tone: Light gold, Mixed light blue, Heavy blue.
class JournalToneVisuals {
  const JournalToneVisuals._();

  static Gradient gradient(JournalTone tone) {
    switch (tone) {
      case JournalTone.light:
        return AppBlends.gold;
      case JournalTone.mixed:
        return AppBlends.lightBlue;
      case JournalTone.heavy:
        return AppBlends.blue;
    }
  }

  static Color foreground(JournalTone tone) =>
      tone == JournalTone.heavy ? Colors.white : AppColors.headerBlue;

  static String label(JournalTone tone) {
    switch (tone) {
      case JournalTone.light:
        return 'Light';
      case JournalTone.mixed:
        return 'Mixed';
      case JournalTone.heavy:
        return 'Heavy';
    }
  }
}

/// "Light", "Mixed" or "Heavy" on its colour.
class JournalTonePill extends StatelessWidget {
  const JournalTonePill({
    super.key,
    required this.tone,
    this.labels = const <String, String>{},
    this.large = false,
  });

  final JournalTone tone;

  /// Labels from the content file; the built-in ones are used otherwise.
  final Map<String, String> labels;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final String text = labels[tone.id] ?? JournalToneVisuals.label(tone);
    return Semantics(
      label: 'Tone: $text',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 14 : 10,
          vertical: large ? 7 : 4,
        ),
        decoration: BoxDecoration(
          gradient: JournalToneVisuals.gradient(tone),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: AppFonts.label(
            size: large ? 14 : 12.5,
            weight: FontWeight.w600,
            color: JournalToneVisuals.foreground(tone),
          ),
        ),
      ),
    );
  }
}

/// The icon and tile colour for each way of writing.
class JournalTypeVisuals {
  const JournalTypeVisuals._();

  static IconData icon(String type) {
    switch (type) {
      case JournalTypes.afterShift:
        return Icons.bedtime_outlined;
      case JournalTypes.moment:
        return Icons.schedule_rounded;
      case JournalTypes.letItOut:
        return Icons.air_rounded;
      default:
        return Icons.edit_outlined;
    }
  }
}

/// The icon tile on the "How do you want to write?" cards.
class JournalTypeTile extends StatelessWidget {
  const JournalTypeTile({super.key, required this.type, this.size = 54});

  final String type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Gradient? gradient;
    final Color iconColor;
    Border? border;
    switch (type) {
      case JournalTypes.afterShift:
        gradient = AppBlends.blue;
        iconColor = AppColors.softSurface;
      case JournalTypes.moment:
        gradient = AppBlends.gold;
        iconColor = AppColors.headerBlue;
      case JournalTypes.letItOut:
        gradient = AppBlends.lightBlue;
        iconColor = AppColors.headerBlue;
      default:
        gradient = null;
        iconColor = context.mm.accentText;
        border = Border.all(color: AppColors.secondary, width: 1.6);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? context.mm.background : null,
        border: border,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        JournalTypeVisuals.icon(type),
        color: iconColor,
        size: size * 0.48,
      ),
    );
  }
}

/// A gold-blend pill with a navy label and a navy arrow circle: the
/// "Start writing" button on the blue cards.
class GoldPillButton extends StatelessWidget {
  const GoldPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(Radius.circular(26));
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppBlends.gold,
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x40E4B266),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(
                        size: 17,
                        weight: FontWeight.w700,
                        color: AppColors.headerBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppBlends.blue,
                    ),
                    child: Icon(icon, size: 20, color: Colors.white),
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

/// A round 46 px button filled with the gold blend (or white).
class JournalRoundButton extends StatelessWidget {
  const JournalRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.gold = false,
    this.translucent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool gold;

  /// White at 20%, for use on the blue cards.
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final bool plain = !gold && !translucent;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gold ? AppBlends.gold : null,
              color: gold
                  ? null
                  : translucent
                  ? Colors.white.withValues(alpha: 0.2)
                  : c.surface,
              border: plain && c.surfaceBorder != null
                  ? Border.all(color: c.surfaceBorder!)
                  : null,
              boxShadow: translucent
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: c.shadow,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(
                icon,
                size: 22,
                color: translucent
                    ? Colors.white
                    : gold
                    ? AppColors.headerBlue
                    : c.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The prompt card on Journal home.
class JournalPromptCard extends StatelessWidget {
  const JournalPromptCard({
    super.key,
    required this.label,
    required this.prompt,
    required this.onStart,
    required this.onShuffle,
  });

  final String label;
  final String prompt;
  final VoidCallback onStart;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: AppBlends.blue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.mm.isDark
                ? context.mm.shadow
                : const Color(0x401F3550),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppFonts.label(
                    size: 12.5,
                    weight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: AppColors.softSurface,
                  ),
                ),
              ),
              const GlowDot(
                size: 12,
                gradient: AppBlends.gold,
                glowColor: Color(0x80E4B266),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: AppMotion.of(context, const Duration(milliseconds: 250)),
            child: Text(
              prompt,
              key: ValueKey<String>(prompt),
              style: AppFonts.body(
                size: 20,
                weight: FontWeight.w600,
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Flexible(
                child: GoldPillButton(
                  label: 'Start writing',
                  onPressed: onStart,
                ),
              ),
              const SizedBox(width: 12),
              JournalRoundButton(
                icon: Icons.shuffle_rounded,
                tooltip: 'Another prompt',
                translucent: true,
                onPressed: onShuffle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A filter chip: white, or the blue blend when selected.
class JournalChip extends StatelessWidget {
  const JournalChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? AppBlends.blue : null,
            color: selected ? null : c.surface,
            border: selected || c.surfaceBorder == null
                ? null
                : Border.all(color: c.surfaceBorder!),
            borderRadius: BorderRadius.circular(22),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppFonts.body(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: selected ? Colors.white : c.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One entry on Journal home.
class JournalEntryCard extends StatelessWidget {
  const JournalEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.toneLabels = const <String, String>{},
  });

  final JournalModel entry;
  final VoidCallback onTap;
  final Map<String, String> toneLabels;

  @override
  Widget build(BuildContext context) {
    final JournalTone? tone = entry.tone;
    return AppCard(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          JournalMoodTile(moodLabel: entry.moodLabel, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.body(
                          size: 17,
                          weight: FontWeight.w700,
                          color: context.mm.textPrimary,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (tone != null) ...<Widget>[
                      const SizedBox(width: 8),
                      JournalTonePill(tone: tone, labels: toneLabels),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.body(size: 14.5, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_time(entry.createdAt)} · '
                  '${JournalTypes.shortLabel(entry.type)}',
                  style: AppFonts.label(color: context.mm.textBody),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

/// Grey-blue placeholders while the list loads.
class JournalListSkeleton extends StatelessWidget {
  const JournalListSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your journal',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < count; i += 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                radius: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SkeletonBar(width: 44, height: 44, radius: 14),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const <Widget>[
                          SkeletonBar(width: 160, height: 16),
                          SizedBox(height: 10),
                          SkeletonBar(height: 12),
                          SizedBox(height: 6),
                          SkeletonBar(width: 200, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The blue card shown when an entry sounds like the writer may need
/// support right now. Its wording comes from the content file.
class JournalSupportCardView extends StatelessWidget {
  const JournalSupportCardView({
    super.key,
    required this.card,
    required this.onTalk,
  });

  final JournalSupportCard card;
  final VoidCallback onTalk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: AppBlends.blue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.mm.isDark
                ? context.mm.shadow
                : const Color(0x401F3550),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              card.title,
              style: AppFonts.body(
                size: 19,
                weight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.body,
            style: AppFonts.body(
              size: 15.5,
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _WideGoldButton(label: card.primary, onPressed: onTalk),
          ),
          const SizedBox(height: 14),
          Text(
            card.footnote,
            style: AppFonts.label(
              size: 13,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideGoldButton extends StatelessWidget {
  const _WideGoldButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(Radius.circular(27));
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppBlends.gold,
          borderRadius: radius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: SizedBox(
              height: 54,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 7, 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        label,
                        style: AppFonts.body(
                          size: 17,
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
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the support card in a bottom sheet. [onTalk] runs after the sheet
/// closes.
Future<void> showJournalSupportSheet(
  BuildContext context, {
  required JournalSupportCard card,
  required VoidCallback onTalk,
  String closeLabel = 'Not now',
}) async {
  bool talk = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.mm.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              JournalSupportCardView(
                card: card,
                onTalk: () {
                  talk = true;
                  Navigator.of(sheetContext).pop();
                },
              ),
              const SizedBox(height: 6),
              JournalTextLink(
                label: closeLabel,
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (talk) {
    onTalk();
  }
}

/// A two-choice dialog. Returns true for [confirm], false for [cancel], null
/// when dismissed.
Future<bool?> showJournalChoice(
  BuildContext context, {
  required String title,
  String? message,
  required String confirm,
  required String cancel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      backgroundColor: dialogContext.mm.background,
      title: Text(
        title,
        style: AppFonts.body(
          size: 19,
          weight: FontWeight.w600,
          color: dialogContext.mm.textPrimary,
        ),
      ),
      content: message == null
          ? null
          : Text(message, style: AppFonts.body(size: 15)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            cancel,
            style: AppFonts.body(
              size: 15,
              weight: FontWeight.w600,
              color: dialogContext.mm.accentText,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirm,
            style: AppFonts.body(
              size: 15,
              weight: FontWeight.w700,
              color: dialogContext.mm.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Bold navy text with a gold underline.
class JournalTextLink extends StatelessWidget {
  const JournalTextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.mm.textPrimary,
        minimumSize: const Size(64, 44),
      ),
      child: Text(
        label,
        style: AppFonts.body(
          size: 16,
          weight: FontWeight.w700,
          color: context.mm.textPrimary,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.accent,
        ),
      ),
    );
  }
}

/// A small mood chip: the face and e.g. "Tired · Moderate" on light blue.
class JournalMoodChip extends StatelessWidget {
  const JournalMoodChip({super.key, required this.label});

  /// The mood name, optionally followed by " · strength".
  final String label;

  @override
  Widget build(BuildContext context) {
    final String mood = label.split(' · ').first;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
      decoration: BoxDecoration(
        gradient: AppBlends.lightBlue,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: MoodIcon(mood, size: 18),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppFonts.body(
              size: 14.5,
              weight: FontWeight.w600,
              color: AppColors.headerBlue,
            ),
          ),
        ],
      ),
    );
  }
}
