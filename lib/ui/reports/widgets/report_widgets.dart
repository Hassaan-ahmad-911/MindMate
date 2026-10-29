import 'package:flutter/material.dart';

import '../../../Models/mood_catalog.dart';
import '../../../Models/report_calculator.dart';
import '../../../Models/report_period.dart';
import '../../home/widgets/home_skeleton.dart';
import '../../mood_tracking/widgets/mood_icon.dart';
import '../../mood_tracking/widgets/mood_visuals.dart';
import '../../mood_tracking/widgets/mood_widgets.dart';
import '../../shared/app_card.dart';
import '../../shared/mindmate_theme.dart';
import '../reports_viewmodel.dart';

const String reportsFooter =
    'Made on your phone from what you logged. Not a diagnosis.';

/// A white card with a title and an optional small label on the right.
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.body(
                    size: 17,
                    weight: FontWeight.w700,
                    color: context.mm.textPrimary,
                  ),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: AppFonts.label(size: 12.5)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// "Could not load. Tap to retry", shown in the one section that failed.
class SectionRetry extends StatelessWidget {
  const SectionRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.mm.accentText;
    return Semantics(
      button: true,
      label: 'Could not load. Tap to retry',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onRetry,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: <Widget>[
              Icon(Icons.refresh_rounded, color: accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Could not load. Tap to retry',
                  style: AppFonts.body(
                    size: 14.5,
                    weight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lock line at the bottom of a report screen.
class LockLine extends StatelessWidget {
  const LockLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final Color body = context.mm.textBody;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.lock_outline_rounded, size: 15, color: body),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppFonts.label(size: 13, color: body)),
        ),
      ],
    );
  }
}

/// Week / Month, with the selected side on the blue blend.
class KindSwitch extends StatelessWidget {
  const KindSwitch({super.key, required this.kind, required this.onChanged});

  final ReportKind kind;
  final ValueChanged<ReportKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    Widget side(ReportKind k, String label) {
      final bool selected = k == kind;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onChanged(k),
            child: AnimatedContainer(
              duration: AppMotion.of(
                context,
                const Duration(milliseconds: 200),
              ),
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected ? c.blueBlendHorizontal : null,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                label,
                style: AppFonts.body(
                  size: 15.5,
                  weight: FontWeight.w600,
                  color: selected ? Colors.white : c.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(26),
        border: c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
      ),
      child: Row(
        children: <Widget>[
          side(ReportKind.week, 'Week'),
          side(ReportKind.month, 'Month'),
        ],
      ),
    );
  }
}

/// "<  5 – 11 October  >".
class PeriodPill extends StatelessWidget {
  const PeriodPill({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;

  /// Null on the current period.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Previous',
            onPressed: onPrevious,
            icon: Icon(Icons.chevron_left_rounded, color: c.textPrimary),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.body(
                size: 15.5,
                weight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: onNext == null
                  ? c.textPrimary.withValues(alpha: 0.25)
                  : c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The blue highlights card.
class HighlightsCard extends StatelessWidget {
  const HighlightsCard({
    super.key,
    required this.label,
    required this.lines,
    required this.nothingLogged,
    required this.onLogMood,
  });

  final String label;
  final List<Highlight> lines;
  final bool nothingLogged;
  final VoidCallback onLogMood;

  static IconData icon(HighlightIcon i) {
    switch (i) {
      case HighlightIcon.up:
        return Icons.arrow_upward_rounded;
      case HighlightIcon.heart:
        return Icons.favorite_border_rounded;
      case HighlightIcon.leaf:
        return Icons.spa_outlined;
      case HighlightIcon.moon:
        return Icons.nightlight_round;
      case HighlightIcon.factor:
        return Icons.label_outline_rounded;
      case HighlightIcon.clipboard:
        return Icons.assignment_outlined;
      case HighlightIcon.pen:
        return Icons.edit_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: c.blueBlend,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.isDark ? c.shadow : const Color(0x401F3550),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppFonts.label(
              size: 12.5,
              weight: FontWeight.w600,
              letterSpacing: 1.4,
              color: AppColors.softSurface,
            ),
          ),
          const SizedBox(height: 10),
          if (nothingLogged) ...<Widget>[
            Text(
              'Nothing logged this ${label.split(' ').last} yet. A mood takes '
              '10 seconds.',
              style: AppFonts.body(size: 16, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppBlends.gold,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onLogMood,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    child: Text(
                      'Log mood',
                      style: AppFonts.body(
                        size: 16,
                        weight: FontWeight.w700,
                        color: AppColors.headerBlue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else
            for (final Highlight h in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppBlends.gold,
                      ),
                      child: Icon(
                        icon(h.icon),
                        size: 15,
                        color: AppColors.headerBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        h.text,
                        style: AppFonts.body(
                          size: 15.5,
                          color: Colors.white,
                          height: 1.35,
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

/// A mood face on its group colour; a dashed circle when nothing was logged.
class DayCircle extends StatelessWidget {
  const DayCircle({super.key, required this.day, this.size = 38});

  final ReportDay day;
  final double size;

  @override
  Widget build(BuildContext context) {
    final MoodGroup? group = day.group;
    final Widget circle = group == null
        ? CustomPaint(
            size: Size.square(size),
            painter: DashedCirclePainter(
              color: AppColors.secondary.withValues(alpha: 0.9),
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: group == MoodGroup.between
                  ? null
                  : MoodVisuals.gradientFor(group),
              color: group == MoodGroup.between ? AppColors.secondary : null,
            ),
            alignment: Alignment.center,
            child: MoodIcon(
              day.mood ?? 'Okay',
              size: size * 0.56,
              color: MoodVisuals.foregroundFor(group),
            ),
          );
    return Opacity(opacity: day.isFuture ? 0.35 : 1, child: circle);
  }
}

/// Three small dots: practice, journal, break (grey when not done). A
/// module that is not available has no dot.
class ActivityDots extends StatelessWidget {
  const ActivityDots({super.key, required this.day});

  final ReportDay day;

  @override
  Widget build(BuildContext context) {
    Widget dot(bool? done, Color color) {
      if (done == null) {
        return const SizedBox.shrink();
      }
      return Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : AppColors.secondary.withValues(alpha: 0.35),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        dot(day.practised, AppColors.accent),
        dot(day.journaled, context.mm.textPrimary),
        dot(day.tookBreak, AppColors.secondary),
      ],
    );
  }
}

/// A small legend item: a mark and its label.
class LegendItem extends StatelessWidget {
  const LegendItem({
    super.key,
    required this.label,
    this.color,
    this.gradient,
    this.round = true,
    this.ring = false,
  });

  final String label;
  final Color? color;
  final Gradient? gradient;
  final bool round;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: round ? null : BorderRadius.circular(3),
            color: ring ? null : color,
            gradient: ring ? null : gradient,
            border: ring ? Border.all(color: color!, width: 2) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppFonts.label(size: 12.5, color: context.mm.textBody),
        ),
      ],
    );
  }
}

/// A number tile: blue blend for the main one, white for the rest.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.change,
    this.blue = false,
    this.failed = false,
    this.onRetry,
  });

  final String value;

  /// A small word after the value, e.g. "min" or "of 7".
  final String? unit;
  final String label;
  final String? change;
  final bool blue;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final Color ink = blue ? Colors.white : c.textPrimary;
    final Color soft = blue ? c.onBlueMuted : c.textBody;
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: blue ? c.blueBlend : null,
        color: blue ? null : c.surface,
        borderRadius: BorderRadius.circular(20),
        border: blue || c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: blue && !c.isDark
                ? AppColors.headerBlue.withValues(alpha: 0.25)
                : c.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: failed
          ? SectionRetry(onRetry: onRetry ?? () {})
          : Semantics(
              label: '$value ${unit ?? ''} $label. ${change ?? ''}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: value,
                          style: AppFonts.body(
                            size: 26,
                            weight: FontWeight.w700,
                            color: ink,
                            height: 1.1,
                          ),
                        ),
                        if (unit != null)
                          TextSpan(
                            text: ' $unit',
                            style: AppFonts.body(
                              size: 14,
                              weight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: AppFonts.label(size: 13, color: soft)),
                  if (change != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      change!,
                      style: AppFonts.label(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: blue ? AppColors.softSurface : c.accentText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// A "Look closer" card.
class LookCloserCard extends StatelessWidget {
  const LookCloserCard({
    super.key,
    required this.title,
    required this.line,
    required this.icon,
    required this.gradient,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String line;
  final IconData icon;
  final Gradient gradient;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $line',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppFonts.body(
                      size: 16.5,
                      weight: FontWeight.w700,
                      color: context.mm.textPrimary,
                    ),
                  ),
                  Text(line, style: AppFonts.label(size: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.mm.textPrimary),
          ],
        ),
      ),
    );
  }
}

/// A rounded placeholder while a section loads.
class ReportSkeleton extends StatelessWidget {
  const ReportSkeleton({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) => SkeletonBar(height: height, radius: 22);
}

/// "Look closer" with its three cards.
class LookCloserSection extends StatelessWidget {
  const LookCloserSection({
    super.key,
    required this.onHelped,
    required this.onCheckIns,
    required this.onShare,
  });

  final VoidCallback onHelped;
  final VoidCallback onCheckIns;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 6, 0, 10),
          child: MoodSectionLabel('Look closer'),
        ),
        LookCloserCard(
          title: 'What helped',
          line: 'How your days and habits connect',
          icon: Icons.share_outlined,
          gradient: AppBlends.gold,
          iconColor: AppColors.headerBlue,
          onTap: onHelped,
        ),
        const SizedBox(height: 10),
        LookCloserCard(
          title: 'Check-ins and writing',
          line: 'Your latest results and journal tone',
          icon: Icons.article_outlined,
          gradient: AppBlends.lightBlue,
          iconColor: AppColors.headerBlue,
          onTap: onCheckIns,
        ),
        const SizedBox(height: 10),
        LookCloserCard(
          title: 'Share a summary',
          line: 'Make a PDF for your doctor',
          icon: Icons.ios_share_rounded,
          gradient: context.mm.blueBlend,
          iconColor: AppColors.accent,
          onTap: onShare,
        ),
      ],
    );
  }
}
