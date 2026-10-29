import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/mood_catalog.dart';
import '../../Models/mood_model.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/mindmate_theme.dart';
import 'mood_tracking_viewmodel.dart';
import 'widgets/mood_icon.dart';
import 'widgets/mood_visuals.dart';
import 'widgets/mood_widgets.dart';

/// Mood home: the Mood tab.
class MoodTrackingView extends GetView<MoodTrackingViewModel> {
  const MoodTrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          const Positioned(
            right: -96,
            top: -118,
            child: BlobShape(size: 250, gradient: AppBlends.blueShape),
          ),
          const Positioned(
            right: 132,
            top: 92,
            child: GlowDot(
              size: 24,
              gradient: AppBlends.gold,
              glowColor: Color(0x80E4B266),
            ),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: c.accentText,
              onRefresh: () => controller.loadMoods(showErrorSnackbar: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text('Mood', style: AppFonts.title(size: 44)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.todayLabel,
                    style: AppFonts.body(size: 15, color: c.textBody),
                  ),
                  const SizedBox(height: 22),
                  _CheckInCard(onLogMood: controller.startLogging),
                  const SizedBox(height: 16),
                  const _LastSevenDaysCard(),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ShortcutTile(
                          title: 'History',
                          subtitle: 'All entries',
                          icon: Icons.calendar_month_rounded,
                          gradient: c.blueBlend,
                          iconColor: Colors.white,
                          onTap: controller.openHistory,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ShortcutTile(
                          title: 'Insights',
                          subtitle: 'Your trends',
                          icon: Icons.bar_chart_rounded,
                          gradient: AppBlends.gold,
                          iconColor: AppColors.headerBlue,
                          onTap: controller.openInsights,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Recent',
                          style: AppFonts.body(
                            size: 17,
                            weight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      MoodTextLink(
                        label: 'See all',
                        onTap: controller.openHistory,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const _RecentEntries(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.onLogMood});

  final VoidCallback onLogMood;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      decoration: BoxDecoration(
        gradient: c.blueBlend,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.isDark ? c.shadow : const Color(0x4D1F3550),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(
            right: 20,
            bottom: 18,
            child: GlowDot(
              size: 58,
              gradient: AppBlends.gold,
              glowColor: Color(0x66E4B266),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 96, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'How are you feeling right now?',
                  style: AppFonts.body(
                    size: 22,
                    weight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 18),
                _GoldPillButton(label: 'Log mood', onTap: onLogMood),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldPillButton extends StatelessWidget {
  const _GoldPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(Radius.circular(24));
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppBlends.gold,
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x66E4B266),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 11, 16, 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: AppFonts.body(
                    size: 16,
                    weight: FontWeight.w700,
                    color: AppColors.headerBlue,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: AppColors.headerBlue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LastSevenDaysCard extends GetView<MoodTrackingViewModel> {
  const _LastSevenDaysCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Obx(() {
        final List<MoodDaySummary> days = controller.lastSevenDays;
        final int streak = controller.streak;
        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Last 7 days',
                    style: AppFonts.body(
                      size: 16,
                      weight: FontWeight.w600,
                      color: context.mm.textPrimary,
                    ),
                  ),
                ),
                _StreakLabel(streak: streak),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Each day also needs room for the today ring (9 px), so
                // size the circles to fit 7 across on narrow phones.
                final double size = (constraints.maxWidth / 7 - 11)
                    .clamp(24.0, 36.0)
                    .toDouble();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: days
                      .map(
                        (MoodDaySummary day) =>
                            _DayCircle(summary: day, size: size),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        );
      }),
    );
  }
}

class _StreakLabel extends StatelessWidget {
  const _StreakLabel({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.local_fire_department_rounded,
          size: 16,
          color: AppColors.accent,
        ),
        const SizedBox(width: 4),
        Text(
          '$streak day streak',
          maxLines: 1,
          style: AppFonts.body(
            size: 14,
            weight: FontWeight.w600,
            color: context.mm.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({required this.summary, required this.size});

  final MoodDaySummary summary;
  final double size;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final Widget circle = summary.group == null
        ? CustomPaint(
            size: Size.square(size),
            painter: DashedCirclePainter(color: AppColors.secondary),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: MoodVisuals.gradientFor(summary.group!),
            ),
            alignment: Alignment.center,
            child: MoodIcon(
              summary.latestMood ?? 'Okay',
              size: size * 0.53,
              color: MoodVisuals.foregroundFor(summary.group!),
            ),
          );

    final String description = summary.group == null
        ? 'no entry'
        : '${summary.latestMood}, ${summary.group!.shortLabel.toLowerCase()} day';

    return Semantics(
      label:
          '${summary.isToday ? 'Today' : MoodFormat.weekday(summary.day)}: '
          '$description',
      excludeSemantics: true,
      child: Column(
        children: <Widget>[
          Text(
            MoodFormat.weekdayLetter(summary.day),
            style: AppFonts.label(
              size: 12,
              weight: summary.isToday ? FontWeight.w700 : FontWeight.w500,
              color: summary.isToday ? c.textPrimary : c.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: summary.isToday ? c.textPrimary : Colors.transparent,
                width: 2,
              ),
            ),
            child: circle,
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
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
                Text(subtitle, style: AppFonts.label()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentEntries extends GetView<MoodTrackingViewModel> {
  const _RecentEntries();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final List<MoodModel> recent = controller.recentEntries;

      if (recent.isEmpty && controller.isLoading.value) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(color: context.mm.accentText),
          ),
        );
      }
      if (recent.isEmpty && controller.hasLoadError.value) {
        return MoodMessageCard(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load your moods',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => controller.loadMoods(showErrorSnackbar: true),
        );
      }
      if (recent.isEmpty) {
        return MoodMessageCard(
          icon: Icons.self_improvement_rounded,
          title: 'No entries yet',
          message: 'Log how you feel to start seeing your patterns.',
          actionLabel: 'Log mood',
          onAction: controller.startLogging,
        );
      }

      final DateTime now = DateTime.now();
      return Column(
        children: recent
            .map(
              (MoodModel entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MoodEntryCard(
                  entry: entry,
                  timeLabel: MoodFormat.entryWhen(entry.date, now: now),
                  onTap: controller.openHistory,
                ),
              ),
            )
            .toList(growable: false),
      );
    });
  }
}
