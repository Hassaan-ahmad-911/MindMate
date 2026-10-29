import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/calm_match_game.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/blended_background.dart';
import '../shared/breathing_tick.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'calm_match_viewmodel.dart';
import 'widgets/calm_icons.dart';
import 'widgets/games_widgets.dart';

/// Calm match: 12 cards, 6 pairs. No timer, no score.
class CalmMatchView extends GetView<CalmMatchViewModel> {
  const CalmMatchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          SafeArea(
            child: Obx(
              () => controller.finished.value
                  ? _Finished(controller: controller)
                  : _Playing(controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _Playing extends StatelessWidget {
  const _Playing({required this.controller});

  final CalmMatchViewModel controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        children: <Widget>[
          GamesHeader(title: 'Calm match', onLeading: controller.done),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Obx(() {
              final int pairs = controller.pairsFound.value;
              final int turns = controller.turns.value;
              return Semantics(
                liveRegion: true,
                label:
                    '$pairs of ${controller.pairTotal} pairs. '
                    '$turns ${turns == 1 ? 'turn' : 'turns'}.',
                excludeSemantics: true,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: <Widget>[
                    GamesChip(
                      '$pairs of ${controller.pairTotal} pairs',
                      gold: true,
                    ),
                    GamesChip(
                      '$turns ${turns == 1 ? 'turn' : 'turns'}',
                      white: true,
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Expanded(child: _Grid(controller: controller)),
          const SizedBox(height: 10),
          Text(
            'Take your time. There is no clock.',
            style: AppFonts.body(size: 15),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.controller});

  final CalmMatchViewModel controller;

  static const int columns = 3;
  static const int rows = 4;
  static const double gap = 14;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double cardWidth = (box.maxWidth - gap * (columns - 1)) / columns;
        final double cardHeight = math.min(
          cardWidth * 1.17,
          (box.maxHeight - gap * (rows - 1)) / rows,
        );
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int r = 0; r < rows; r += 1) ...<Widget>[
                if (r > 0) const SizedBox(height: gap),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int c = 0; c < columns; c += 1) ...<Widget>[
                      if (c > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: _MatchCard(
                          controller: controller,
                          index: r * columns + c,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.controller, required this.index});

  final CalmMatchViewModel controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final CardFace face = controller.faces[index];
      final bool faceUp = face != CardFace.down;
      void tap() => controller.flip(index);

      return Semantics(
        button: face == CardFace.down,
        label: controller.labelFor(index),
        onTap: face == CardFace.down ? tap : null,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: faceUp ? 1 : 0),
            duration: AppMotion.of(context, const Duration(milliseconds: 320)),
            curve: Curves.easeInOut,
            builder: (BuildContext context, double value, Widget? child) {
              final bool showFront = value >= 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(math.pi * value),
                child: showFront
                    // The front is turned half a circle so it reads normally.
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: _Front(
                          symbol: controller.symbolAt(index),
                          matched: face == CardFace.matched,
                        ),
                      )
                    : const _Back(),
              );
            },
          ),
        ),
      );
    });
  }
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      decoration: BoxDecoration(
        gradient: AppBlends.blue,
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.isDark
                ? c.shadow
                : AppColors.headerBlue.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.42,
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.softSurface.withValues(alpha: 0.9),
                width: 2.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Front extends StatelessWidget {
  const _Front({required this.symbol, required this.matched});

  final CalmSymbol symbol;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    // Navy on the gold matched card; on the surface card the outline and
    // the picture follow the page.
    final Color ink = matched ? AppColors.headerBlue : c.textPrimary;
    return AnimatedContainer(
      duration: AppMotion.of(context, const Duration(milliseconds: 260)),
      decoration: BoxDecoration(
        color: matched ? null : c.surface,
        gradient: matched ? AppBlends.gold : null,
        borderRadius: BorderRadius.circular(22),
        border: matched ? null : Border.all(color: ink, width: 2.4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.isDark
                ? c.shadow
                : AppColors.headerBlue.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.46,
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              return CalmSymbolIcon(
                symbol: symbol,
                size: box.maxWidth,
                color: ink,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.controller});

  final CalmMatchViewModel controller;

  @override
  Widget build(BuildContext context) {
    final int turns = controller.turns.value;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: GamesHeader(title: 'Calm match', onLeading: controller.done),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const BreathingTick(size: 190, semanticLabel: 'All matched'),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'All matched',
                      textAlign: TextAlign.center,
                      style: AppFonts.title(size: 40),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Neutral: the turns are shown, never as a result to beat.
                  Text(
                    'You found all ${controller.pairTotal} pairs in '
                    '$turns ${turns == 1 ? 'turn' : 'turns'}.',
                    textAlign: TextAlign.center,
                    style: AppFonts.body(size: 16, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            children: <Widget>[
              GradientButton(
                label: 'Play again',
                icon: Icons.replay_rounded,
                onPressed: controller.playAgain,
              ),
              const SizedBox(height: 4),
              MoodTextLink(label: 'Done', onTap: controller.done),
            ],
          ),
        ),
      ],
    );
  }
}
