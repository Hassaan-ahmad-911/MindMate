import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/break_log.dart';
import '../app/app_routes.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/mindmate_theme.dart';
import 'games_hub_viewmodel.dart';
import 'widgets/games_widgets.dart';

/// "Take a break": three short, calm activities.
class GamesHubView extends GetView<GamesHubViewModel> {
  const GamesHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    children: <Widget>[
                      MoodPageHeader(
                        title: 'Take a break',
                        onBack: controller.back,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Short, calm activities. No scores, no timers.',
                        style: AppFonts.body(size: 16),
                      ),
                      const SizedBox(height: 20),
                      _ActivityCard(
                        art: GameArt.bubble,
                        title: 'Breathing bubble',
                        description:
                            'Hold to breathe in, let go to breathe out.',
                        chip: const GamesChip('2 min'),
                        onTap: () => controller.open(AppRoutes.breathingBubble),
                      ),
                      const SizedBox(height: 14),
                      _ActivityCard(
                        art: GameArt.match,
                        title: 'Calm match',
                        description:
                            'Find the matching pairs, at your own pace.',
                        chip: const GamesChip('3 min'),
                        onTap: () => controller.open(AppRoutes.calmMatch),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _ActivityCard(
                          art: GameArt.garden,
                          title: 'Gratitude garden',
                          description: 'One good thing a day grows a flower.',
                          chip: GamesChip(
                            controller.gardenChip,
                            gold: controller.plantedToday.value != true,
                          ),
                          onTap: () =>
                              controller.open(AppRoutes.gratitudeGarden),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Obx(
                    () => _WeekFooter(count: controller.breaksThisWeek.value),
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.art,
    required this.title,
    required this.description,
    required this.chip,
    required this.onTap,
  });

  final GameArt art;
  final String title;
  final String description;
  final Widget chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $description',
      onTap: onTap,
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        radius: 24,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(child: GameArtTile(art: art, size: 96)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppFonts.body(
                      size: 21,
                      weight: FontWeight.w700,
                      color: context.mm.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppFonts.body(size: 14.5, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  chip,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "4 breaks taken this week". With nothing to count yet, only the kind line.
class _WeekFooter extends StatelessWidget {
  const _WeekFooter({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final int? known = count;
    final bool hasCount = known != null && known > 0;
    final String line = known == null
        ? 'A few minutes for yourself counts.'
        : BreakStats.footerLine(known);

    return Semantics(
      container: true,
      label: hasCount ? '$known $line' : line,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: AppBlends.blueHorizontal,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: <Widget>[
            if (hasCount) ...<Widget>[
              Text(
                '$known',
                style: AppFonts.body(
                  size: 38,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                line,
                style: AppFonts.body(
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.94),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
