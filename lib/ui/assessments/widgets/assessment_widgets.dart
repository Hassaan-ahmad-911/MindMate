import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../Models/assessment_definition.dart';
import '../../../Models/assessment_rules.dart';
import '../../../Models/assessment_scorer.dart';
import '../../mood_tracking/widgets/mood_widgets.dart';
import '../../shared/app_card.dart';
import '../../shared/gradient_button.dart';
import '../../shared/mindmate_theme.dart';

/// The icon and blend of each questionnaire's tile.
class AssessmentVisuals {
  const AssessmentVisuals._();

  static IconData icon(String name) {
    switch (name) {
      case 'cloud':
        return Icons.cloud_outlined;
      case 'waves':
        return Icons.waves_rounded;
      case 'battery':
        return Icons.battery_3_bar_rounded;
      case 'pulse':
        return Icons.monitor_heart_outlined;
      case 'sun':
        return Icons.wb_sunny_outlined;
      case 'building':
        return Icons.apartment_rounded;
      case 'clipboard':
        return Icons.assignment_outlined;
      default:
        return Icons.checklist_rounded;
    }
  }

  static Gradient gradient(String name) {
    switch (name) {
      case 'cloud':
      case 'building':
        return AppBlends.blue;
      case 'battery':
      case 'sun':
        return AppBlends.gold;
      default:
        return AppBlends.lightBlue;
    }
  }

  static Color iconColor(String name) {
    final Gradient g = gradient(name);
    return g == AppBlends.blue ? AppColors.accent : AppColors.headerBlue;
  }

  static Gradient toneGradient(RangeTone tone) {
    switch (tone) {
      case RangeTone.best:
        return AppBlends.gold;
      case RangeTone.middle:
        return AppBlends.lightBlue;
      case RangeTone.heavy:
        return AppBlends.blue;
    }
  }

  static Color toneText(RangeTone tone) =>
      tone == RangeTone.heavy ? Colors.white : AppColors.headerBlue;
}

/// A questionnaire's icon on its rounded, blended tile.
class AssessmentIconTile extends StatelessWidget {
  const AssessmentIconTile({super.key, required this.icon, this.size = 46});

  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AssessmentVisuals.gradient(icon),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: size > 60
            ? <BoxShadow>[
                BoxShadow(
                  color: c.isDark ? c.shadow : const Color(0x401F3550),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Icon(
        AssessmentVisuals.icon(icon),
        size: size * 0.48,
        color: AssessmentVisuals.iconColor(icon),
      ),
    );
  }
}

/// A range as a pill: words, never an alarm colour.
class RangePill extends StatelessWidget {
  const RangePill({
    super.key,
    required this.label,
    required this.tone,
    this.large = false,
  });

  final String label;
  final RangeTone tone;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 10,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        gradient: AssessmentVisuals.toneGradient(tone),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppFonts.label(
          size: large ? 15.5 : 12.5,
          weight: FontWeight.w600,
          color: AssessmentVisuals.toneText(tone),
        ),
      ),
    );
  }
}

/// The score in a ring. The arc grows from 0 over a second (instantly with
/// reduce-motion on). Small ticks in the page colour mark where each range
/// starts.
class ScoreRing extends StatefulWidget {
  const ScoreRing({
    super.key,
    required this.value,
    required this.max,
    required this.label,
    this.rangeStarts = const <double>[],
    this.size = 190,
  });

  final double value;
  final double max;

  /// The text in the centre, e.g. "11".
  final String label;

  /// Where each range after the first starts, on the same scale as [value].
  final List<double> rangeStarts;
  final double size;

  @override
  State<ScoreRing> createState() => _ScoreRingState();
}

class _ScoreRingState extends State<ScoreRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (AppMotion.reduced(context)) {
      _grow.value = 1;
    } else {
      _grow.forward();
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final double fraction = widget.max <= 0
        ? 0
        : (widget.value / widget.max).clamp(0.0, 1.0);
    return Semantics(
      label: '${widget.label} out of ${widget.max.round()}',
      excludeSemantics: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _grow,
          builder: (BuildContext context, Widget? child) {
            return CustomPaint(
              painter: _RingPainter(
                fraction: fraction * Curves.easeOutCubic.transform(_grow.value),
                ticks: <double>[
                  for (final double s in widget.rangeStarts)
                    if (widget.max > 0) s / widget.max,
                ],
                centre: c.surface,
                tick: c.background,
                arc: c.isDark
                    ? const <Color>[
                        AppColors.primary,
                        AppColors.secondary,
                        MindMateColors.cream,
                      ]
                    : const <Color>[
                        AppColors.secondary,
                        AppColors.primary,
                        AppColors.headerBlue,
                      ],
              ),
              child: child,
            );
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.label,
                  style: AppFonts.body(
                    size: widget.size * 0.27,
                    weight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'out of ${widget.max.round()}',
                  style: AppFonts.label(size: 13.5, color: c.textBody),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.ticks,
    required this.centre,
    required this.tick,
    required this.arc,
  });

  final double fraction;
  final List<double> ticks;

  /// The fill inside the ring.
  final Color centre;

  /// The range marks, drawn in the page colour.
  final Color tick;

  /// The arc's sweep, from its start to its tip.
  final List<Color> arc;

  @override
  void paint(Canvas canvas, Size size) {
    const double stroke = 16;
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 - stroke / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double start = -math.pi / 2;

    canvas.drawCircle(center, radius - stroke / 2, Paint()..color = centre);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.secondary.withValues(alpha: 0.3),
    );
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        start,
        2 * math.pi * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: 2 * math.pi,
            transform: const GradientRotation(start),
            colors: arc,
            stops: <double>[0, fraction * 0.6, math.max(fraction, 0.01)],
          ).createShader(rect),
      );
    }
    final Paint tickPaint = Paint()
      ..color = tick
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final double t in ticks) {
      final double angle = start + 2 * math.pi * t;
      final Offset dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + dir * (radius - stroke / 2 + 1),
        center + dir * (radius + stroke / 2 - 1),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.ticks != ticks ||
      old.centre != centre ||
      old.tick != tick ||
      old.arc != arc;
}

/// One answer choice: a surface with an empty circle, or the blue blend with a
/// gold tick when chosen.
class AnswerCard extends StatelessWidget {
  const AnswerCard({
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
    final BorderRadius radius = BorderRadius.circular(18);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 160)),
        decoration: BoxDecoration(
          gradient: selected ? AppBlends.blueHorizontal : null,
          color: selected ? null : c.surface,
          border: selected || c.surfaceBorder == null
              ? null
              : Border.all(color: c.surfaceBorder!),
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.isDark
                  ? c.shadow
                  : AppColors.headerBlue.withValues(
                      alpha: selected ? 0.22 : 0.05,
                    ),
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        label,
                        style: AppFonts.body(
                          size: 16.5,
                          weight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? Colors.white : c.textBody,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: selected ? AppBlends.gold : null,
                        border: selected
                            ? null
                            : Border.all(
                                color: AppColors.secondary,
                                width: 1.8,
                              ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: AppColors.headerBlue,
                            )
                          : null,
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

/// A line on the intro card with a small icon tile.
class IntroBullet extends StatelessWidget {
  const IntroBullet({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppBlends.lightBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.headerBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppFonts.body(size: 15.5, color: context.mm.textBody),
            ),
          ),
        ],
      ),
    );
  }
}

/// One segment per question; filled up to [current].
class SegmentedProgress extends StatelessWidget {
  const SegmentedProgress({
    super.key,
    required this.count,
    required this.current,
  });

  final int count;

  /// How many segments are filled.
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Question $current of $count',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < count; i += 1)
            Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: i == count - 1 ? 0 : 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: i < current ? AppBlends.blueHorizontal : null,
                  color: i < current
                      ? null
                      : AppColors.secondary.withValues(alpha: 0.35),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "↓ 3 since 24 Sep". Primary blue whichever way it goes.
class ChangePill extends StatelessWidget {
  const ChangePill({super.key, required this.change, required this.label});

  final int change;
  final String label;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.surface,
        border: c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (change != 0) ...<Widget>[
            Icon(
              change < 0
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 15,
              color: c.accentText,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppFonts.label(
              size: 14,
              weight: FontWeight.w600,
              color: c.accentText,
            ),
          ),
        ],
      ),
    );
  }
}

/// "A good next step" with a link to the support page.
class NextStepCard extends StatelessWidget {
  const NextStepCard({super.key, required this.text, required this.onSupport});

  final String text;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppBlends.gold,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              color: AppColors.headerBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const MoodSectionLabel('A good next step'),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: AppFonts.body(size: 15, color: context.mm.textBody),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: MoodTextLink(
                    label: 'Support and helplines',
                    onTap: onSupport,
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

/// PHQ-4: a fuller check-in its answers suggest, with "Take it now".
class FollowUpCard extends StatelessWidget {
  const FollowUpCard({super.key, required this.text, required this.onTake});

  final String text;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppBlends.lightBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppColors.headerBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const MoodSectionLabel('Suggested next'),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: AppFonts.body(size: 15, color: context.mm.textBody),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: MoodTextLink(label: 'Take it now', onTap: onTake),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A practice to try, with a gold play button.
class AssessmentPracticeCard extends StatelessWidget {
  const AssessmentPracticeCard({
    super.key,
    required this.label,
    required this.title,
    required this.onTap,
  });

  final String label;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Try this: $title. $label',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        radius: 22,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppBlends.lightBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.spa_outlined,
                color: AppColors.headerBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  MoodSectionLabel('Try this · $label'),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: AppFonts.body(
                      size: 16.5,
                      weight: FontWeight.w700,
                      color: context.mm.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppBlends.gold,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.headerBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One area card per area, the one needing most attention first and
/// highlighted. Each bar is out of 100 with thin marks at [marks].
class AreaBars extends StatelessWidget {
  const AreaBars({
    super.key,
    required this.def,
    required this.areas,
    required this.marks,
  });

  final AssessmentDefinition def;
  final List<MapEntry<AssessmentArea, double>> areas;
  final List<double> marks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < areas.length; i += 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AreaCard(
              def: def,
              area: areas[i].key,
              value: areas[i].value,
              highlighted: i == 0,
              marks: marks,
            ),
          ),
      ],
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.def,
    required this.area,
    required this.value,
    required this.highlighted,
    required this.marks,
  });

  final AssessmentDefinition def;
  final AssessmentArea area;
  final double value;
  final bool highlighted;
  final List<double> marks;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final Color ink = highlighted ? c.onBlue : c.textPrimary;
    final Color soft = highlighted ? c.onBlueMuted : c.textBody;
    final String range =
        AssessmentScorer.bandFor(def.bands, value)?.label ?? '';
    final String score = AssessmentMath.formatScore(def, value);

    return Semantics(
      label: '${area.label}: $score out of 100, $range',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: highlighted ? AppBlends.blue : null,
          color: highlighted ? null : c.surface,
          border: highlighted || c.surfaceBorder == null
              ? null
              : Border.all(color: c.surfaceBorder!),
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.isDark
                  ? c.shadow
                  : AppColors.headerBlue.withValues(
                      alpha: highlighted ? 0.25 : 0.06,
                    ),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        area.label,
                        style: AppFonts.body(
                          size: 17,
                          weight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      if (area.sub != null)
                        Text(
                          area.sub!,
                          style: AppFonts.label(size: 13, color: soft),
                        ),
                    ],
                  ),
                ),
                Text(
                  score,
                  style: AppFonts.body(
                    size: 28,
                    weight: FontWeight.w700,
                    color: ink,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MarkedBar(
              fraction: value / 100,
              marks: marks,
              highlighted: highlighted,
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    range,
                    style: AppFonts.label(
                      size: 13,
                      weight: FontWeight.w600,
                      color: soft,
                    ),
                  ),
                ),
                Text(
                  'out of 100',
                  style: AppFonts.label(size: 13, color: soft),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkedBar extends StatelessWidget {
  const _MarkedBar({
    required this.fraction,
    required this.marks,
    required this.highlighted,
  });

  final double fraction;
  final List<double> marks;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double w = constraints.maxWidth;
          return Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: 2,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: highlighted
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.secondary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 2,
                height: 8,
                width: w * fraction.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: highlighted
                        ? AppBlends.gold
                        : AppBlends.blueHorizontal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              for (final double m in marks)
                Positioned(
                  left: w * m / 100 - 1,
                  top: 0,
                  width: 2,
                  height: 12,
                  child: ColoredBox(
                    color: highlighted
                        ? Colors.white.withValues(alpha: 0.85)
                        : context.mm.textPrimary.withValues(alpha: 0.45),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Every question with the chosen answer, read only, and "Take it again".
Future<void> showReviewSheet(
  BuildContext context, {
  required String title,
  required List<MapEntry<String, String>> rows,
  required VoidCallback onTakeAgain,
}) async {
  bool again = false;
  final MindMateColors c = context.mm;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  title,
                  style: AppFonts.body(
                    size: 19,
                    weight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int i) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${i + 1}. ${rows[i].key}',
                          style: AppFonts.body(size: 15, color: c.textBody),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rows[i].value,
                          style: AppFonts.body(
                            size: 15,
                            weight: FontWeight.w700,
                            color: c.accentText,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: GradientButton(
                  label: 'Take it again',
                  icon: Icons.refresh_rounded,
                  onPressed: () {
                    again = true;
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (again) {
    onTakeAgain();
  }
}

/// "Leave this check-in?" Returns true to leave.
Future<bool> confirmLeaveCheckIn(BuildContext context) async {
  final MindMateColors c = context.mm;
  final bool? leave = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      backgroundColor: c.background,
      title: Text(
        'Leave this check-in?',
        style: AppFonts.body(
          size: 19,
          weight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
      content: Text(
        'Your answers will not be saved.',
        style: AppFonts.body(size: 15),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Keep going',
            style: AppFonts.body(
              size: 15,
              weight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Leave',
            style: AppFonts.body(
              size: 15,
              weight: FontWeight.w600,
              color: c.accentText,
            ),
          ),
        ),
      ],
    ),
  );
  return leave ?? false;
}
