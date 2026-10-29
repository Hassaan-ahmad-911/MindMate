import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/meditation_models.dart';
import '../../Models/meditation_suggester.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/mindmate_theme.dart';
import 'meditation_viewmodel.dart';
import 'widgets/meditation_widgets.dart';

/// The meditation library.
class MeditationView extends GetView<MeditationViewModel> {
  const MeditationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlendedBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: <Widget>[
                MoodPageHeader(
                  title: 'Meditation',
                  onBack: Get.back,
                  trailing: CircleIconButton(
                    icon: Icons.info_outline_rounded,
                    tooltip: 'About these practices',
                    onPressed: () => _showAbout(context),
                  ),
                ),
                const SizedBox(height: 18),
                const _StatsRow(),
                const SizedBox(height: 14),
                const _SuggestionSection(),
                const _FilterChips(),
                const SizedBox(height: 14),
                const _PracticeList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "About these practices", with the audio credits.
Future<void> _showAbout(BuildContext context) {
  final MindMateColors c = context.mm;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'About these practices',
              style: AppFonts.body(
                size: 19,
                weight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Short guided practices for calm and focus. They are not '
              'therapy. Stop any time.',
              style: AppFonts.body(size: 15.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Voice made with the Kokoro text-to-speech model (Apache 2.0 '
              'licence). Background sounds made for MindMate.',
              style: AppFonts.label(size: 13.5, color: c.textBody),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatsRow extends GetView<MeditationViewModel> {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool loaded = controller.statsLoaded.value;
      final int sessions = controller.sessionsThisWeek;

      return Row(
        children: <Widget>[
          Expanded(
            child: StatTile(
              value: loaded ? '${controller.minutesThisWeek}' : '–',
              label: 'min this week',
              gradient: AppBlends.blue,
              foreground: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              value: loaded ? '$sessions' : '–',
              label: sessions == 1 ? 'session' : 'sessions',
              gradient: AppBlends.gold,
              foreground: AppColors.headerBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              value: loaded ? '${controller.streak}' : '–',
              label: 'day streak',
              gradient: AppBlends.lightBlue,
              foreground: AppColors.headerBlue,
            ),
          ),
        ],
      );
    });
  }
}

class _SuggestionSection extends GetView<MeditationViewModel> {
  const _SuggestionSection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final MeditationSuggestion? suggestion = controller.suggestion.value;
      if (suggestion == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: _SuggestionCard(
          suggestion: suggestion,
          onTap: controller.openSuggestion,
        ),
      );
    });
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final MeditationSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(24);
    final MeditationSession session = suggestion.session;
    final MindMateColors c = context.mm;

    return Semantics(
      button: true,
      label:
          'Suggested for you: ${session.title}, ${session.lengthLabel}. '
          '${suggestion.reason}',
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppBlends.blue,
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.isDark ? c.shadow : const Color(0x4D1F3550),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'SUGGESTED FOR YOU',
                          style: AppFonts.label(
                            size: 12.5,
                            weight: FontWeight.w600,
                            letterSpacing: 1.6,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          session.title,
                          style: AppFonts.body(
                            size: 22,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${session.lengthLabel} · ${suggestion.reason}',
                          style: AppFonts.body(
                            size: 14.5,
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppBlends.gold,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 28,
                      color: AppColors.headerBlue,
                    ),
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

class _FilterChips extends GetView<MeditationViewModel> {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final List<MeditationGroup> groups = controller.groups.toList(
        growable: false,
      );
      final String? selected = controller.selectedGroupId.value;
      if (groups.isEmpty) {
        return const SizedBox.shrink();
      }

      return SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: groups.length + 1,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int index) {
            final MeditationGroup? group = index == 0
                ? null
                : groups[index - 1];
            return _FilterChip(
              label: group?.title ?? 'All',
              selected: selected == group?.id,
              onTap: () => controller.selectGroup(group?.id),
            );
          },
        ),
      );
    });
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(22);
    final MindMateColors c = context.mm;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 160)),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: selected ? AppBlends.blueHorizontal : null,
          color: selected ? null : c.surface,
          border: selected || c.surfaceBorder == null
              ? null
              : Border.all(color: c.surfaceBorder!),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: selected && !c.isDark
                  ? AppColors.headerBlue.withValues(alpha: 0.22)
                  : c.shadow,
              blurRadius: selected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: Text(
                  label,
                  style: AppFonts.body(
                    size: 15,
                    weight: FontWeight.w600,
                    color: selected ? Colors.white : c.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeList extends GetView<MeditationViewModel> {
  const _PracticeList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }
      if (controller.hasLoadError.value) {
        return MoodMessageCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not load the practices',
          message: 'Please try again.',
          actionLabel: 'Try again',
          onAction: controller.load,
        );
      }

      final List<MeditationSession> visible = controller.visibleSessions;
      if (visible.isEmpty) {
        return const MoodMessageCard(
          icon: Icons.self_improvement_rounded,
          title: 'No practices here yet',
          message: 'Try another filter.',
        );
      }

      return Column(
        children: visible
            .map(
              (MeditationSession session) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PracticeCard(
                  session: session,
                  subtitle: _subtitleFor(session),
                  onTap: () => controller.openSession(session),
                ),
              ),
            )
            .toList(growable: false),
      );
    });
  }

  /// "Between patients · Breathing space".
  String _subtitleFor(MeditationSession session) {
    final String group = controller.groupTitleFor(session);
    return <String>[
      group,
      session.technique,
    ].where((String part) => part.isNotEmpty).join(' · ');
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.session,
    required this.subtitle,
    required this.onTap,
  });

  final MeditationSession session;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${session.title}. $subtitle. ${session.lengthLabel}',
      onTap: onTap,
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            SessionIconTile(session: session),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    session.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.body(
                      size: 17,
                      weight: FontWeight.w600,
                      color: context.mm.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.label(size: 13.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            LengthChip(session.lengthLabel),
          ],
        ),
      ),
    );
  }
}
