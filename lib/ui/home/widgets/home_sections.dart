import 'package:flutter/material.dart';

import '../../../Models/home_dashboard.dart';
import '../../../Models/meditation_suggester.dart';
import '../../../viewmodels/home_viewmodel.dart';
import '../../meditation/widgets/meditation_widgets.dart';
import '../../shared/app_card.dart';
import '../../shared/mindmate_theme.dart';
import 'home_skeleton.dart';

/// A round surface-coloured button in the header (the bell), with an optional gold dot.
class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.showDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      button: true,
      label: showDot ? '$tooltip, new' : tooltip,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        shape: c.surfaceBorder == null
            ? const CircleBorder()
            : CircleBorder(side: BorderSide(color: c.surfaceBorder!)),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(icon, size: 24, color: c.textPrimary),
                if (showDot)
                  Positioned(
                    right: 12,
                    top: 11,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppBlends.gold,
                        border: Border.all(color: c.surface, width: 1.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The profile photo in a circle, or the initials on the gold blend.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    required this.initials,
    required this.onPressed,
  });

  final String imageUrl;
  final String initials;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl.trim();
    final MindMateColors c = context.mm;

    return Semantics(
      button: true,
      label: 'Your profile',
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surface.withValues(alpha: 0.9),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.shadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: AppBlends.gold),
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: <Widget>[
                  Center(
                    child: Text(
                      initials,
                      style: AppFonts.body(
                        size: 18,
                        weight: FontWeight.w700,
                        color: AppColors.headerBlue,
                        height: 1,
                      ),
                    ),
                  ),
                  // Covers the initials once the photo has loaded; if it
                  // cannot load, the initials stay.
                  if (url.isNotEmpty)
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stack,
                          ) => const SizedBox.shrink(),
                      frameBuilder:
                          (
                            BuildContext context,
                            Widget child,
                            int? frame,
                            bool wasSynchronouslyLoaded,
                          ) => frame == null && !wasSynchronouslyLoaded
                          ? const SizedBox.shrink()
                          : child,
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

/// One of the three small numbers under the mood card.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.status,
    required this.onRetry,
  });

  final String value;
  final String label;
  final SectionStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final Widget content;
    switch (status) {
      case SectionStatus.loading:
        content = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SkeletonBar(width: 44, height: 26),
            SizedBox(height: 10),
            SkeletonBar(width: 70, height: 12),
          ],
        );
      case SectionStatus.failed:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.refresh_rounded, size: 20, color: c.accentText),
            const SizedBox(height: 4),
            Text(
              'Could not load. Tap to retry',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.label(size: 12.5),
            ),
          ],
        );
      case SectionStatus.ready:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Scaled down rather than wrapped, so the three tiles keep one
            // height whatever the text size.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppFonts.body(
                  size: 30,
                  weight: FontWeight.w700,
                  color: c.textPrimary,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: AppFonts.label(size: 14.5),
              ),
            ),
          ],
        );
    }

    final bool failed = status == SectionStatus.failed;
    return Semantics(
      container: true,
      button: failed,
      label: switch (status) {
        SectionStatus.loading => 'Loading $label',
        SectionStatus.failed => '$label could not load. Tap to retry',
        SectionStatus.ready => '$value $label',
      },
      onTap: failed ? onRetry : null,
      excludeSemantics: true,
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: failed ? onRetry : null,
        child: SizedBox(height: 62, width: double.infinity, child: content),
      ),
    );
  }
}

/// "Suggested for tonight": one practice and a play button.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    super.key,
    required this.heading,
    required this.suggestion,
    required this.onOpen,
  });

  final String heading;
  final MeditationSuggestion suggestion;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final String length = '${suggestion.session.lengthLabel} guided practice';

    return Semantics(
      button: true,
      label: '$heading: ${suggestion.session.title}, $length. Play',
      onTap: onOpen,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppBlends.gold,
            borderRadius: BorderRadius.circular(26),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: <Widget>[
                  SessionIconTile(session: suggestion.session, size: 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          heading.toUpperCase(),
                          style: AppFonts.label(
                            size: 12.5,
                            weight: FontWeight.w700,
                            letterSpacing: 1.6,
                            color: AppColors.headerBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          suggestion.session.title,
                          style: AppFonts.body(
                            size: 21,
                            weight: FontWeight.w700,
                            color: AppColors.headerBlue,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          length,
                          style: AppFonts.body(
                            size: 14.5,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.headerBlue,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 28,
                      color: Colors.white,
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

/// A slim card standing in for a section that is loading or failed.
class SectionPlaceholderCard extends StatelessWidget {
  const SectionPlaceholderCard.loading({super.key})
    : failed = false,
      onRetry = null;

  const SectionPlaceholderCard.failed({super.key, required this.onRetry})
    : failed = true;

  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!failed) {
      return AppCard(
        radius: 26,
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: <Widget>[
            SkeletonBar(width: 58, height: 58, radius: 18),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SkeletonBar(width: 120, height: 12),
                  SizedBox(height: 10),
                  SkeletonBar(width: 170, height: 18),
                  SizedBox(height: 10),
                  SkeletonBar(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Could not load. Tap to retry',
      onTap: onRetry,
      excludeSemantics: true,
      child: AppCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        onTap: onRetry,
        child: Row(
          children: <Widget>[
            Icon(Icons.refresh_rounded, color: context.mm.accentText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Could not load. Tap to retry',
                style: AppFonts.body(
                  size: 15,
                  weight: FontWeight.w600,
                  color: context.mm.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offered until the first check-in is finished or dismissed.
class FinishCheckInCard extends StatelessWidget {
  const FinishCheckInCard({
    super.key,
    required this.onOpen,
    required this.onDismiss,
  });

  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return AppCard(
      onTap: onOpen,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppBlends.gold,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 21,
              color: AppColors.headerBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Finish your check-in',
                  style: AppFonts.body(
                    size: 16.5,
                    weight: FontWeight.w600,
                    color: c.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'About 2 minutes. Skip anything you like.',
                  style: AppFonts.label(size: 13.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss',
            icon: Icon(Icons.close_rounded, size: 20, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// One tile of the Explore grid. A tile whose module is not built yet is
/// faded, says "Coming soon" and does nothing.
class ExploreTileCard extends StatelessWidget {
  const ExploreTileCard({super.key, required this.tile, required this.onTap});

  final ExploreTile tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _TileStyle style = _TileStyle.of(tile.id);

    return Semantics(
      button: true,
      enabled: tile.isLive,
      label: '${tile.title}, ${tile.line}',
      onTap: tile.isLive ? onTap : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: tile.isLive ? 1 : 0.55,
        child: AppCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          onTap: tile.isLive ? onTap : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: style.gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(style.icon, size: 26, color: style.foreground),
              ),
              const SizedBox(height: 14),
              // One line, shrunk to fit if needed. The row's height is measured
              // before the downloaded font arrives, so a title that wraps only
              // in the final font would overflow the card.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  tile.title,
                  maxLines: 1,
                  softWrap: false,
                  style: AppFonts.body(
                    size: 20,
                    weight: FontWeight.w700,
                    color: context.mm.textPrimary,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tile.line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.body(size: 14.5, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileStyle {
  const _TileStyle(this.icon, this.gradient, this.foreground);

  final IconData icon;
  final Gradient gradient;
  final Color foreground;

  static _TileStyle of(ExploreId id) {
    switch (id) {
      case ExploreId.mood:
        return const _TileStyle(
          Icons.sentiment_satisfied_alt_outlined,
          AppBlends.gold,
          AppColors.headerBlue,
        );
      case ExploreId.journal:
        return const _TileStyle(
          Icons.menu_book_outlined,
          AppBlends.lightBlue,
          AppColors.headerBlue,
        );
      case ExploreId.meditation:
        return _TileStyle(
          Icons.self_improvement_rounded,
          AppBlends.blue,
          Colors.white,
        );
      case ExploreId.aiChat:
        return const _TileStyle(
          Icons.chat_bubble_outline_rounded,
          AppBlends.gold,
          AppColors.headerBlue,
        );
      case ExploreId.checkIns:
        return const _TileStyle(
          Icons.assignment_turned_in_outlined,
          AppBlends.lightBlue,
          AppColors.headerBlue,
        );
      case ExploreId.reports:
        return _TileStyle(
          Icons.bar_chart_rounded,
          AppBlends.blue,
          Colors.white,
        );
      case ExploreId.takeABreak:
        return const _TileStyle(
          Icons.bubble_chart_outlined,
          AppBlends.gold,
          AppColors.headerBlue,
        );
      case ExploreId.emotionCheck:
        return const _TileStyle(
          Icons.face_unlock_outlined,
          AppBlends.lightBlue,
          AppColors.headerBlue,
        );
    }
  }
}

/// "Need to talk to someone now?"
class SupportCard extends StatelessWidget {
  const SupportCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      button: true,
      label: 'Need to talk to someone now? Support and helplines',
      onTap: onTap,
      excludeSemantics: true,
      child: AppCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: c.blueBlend,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Need to talk to someone now?',
                    style: AppFonts.body(
                      size: 18.5,
                      weight: FontWeight.w700,
                      color: c.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Support and helplines',
                    style: AppFonts.body(size: 14.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 26, color: c.textPrimary),
          ],
        ),
      ),
    );
  }
}
