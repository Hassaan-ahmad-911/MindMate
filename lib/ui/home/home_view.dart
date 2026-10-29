import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/home_dashboard.dart';
import '../../Models/meditation_suggester.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../shared/blended_background.dart';
import '../shared/mindmate_theme.dart';
import 'widgets/animated_name.dart';
import 'widgets/home_mood_card.dart';
import 'widgets/home_sections.dart';
import 'widgets/home_skeleton.dart';

/// The home dashboard: greeting, the mood card, three numbers, a suggested
/// practice, the Explore grid and the support card.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with SingleTickerProviderStateMixin {
  late final HomeViewModel _vm = Get.find<HomeViewModel>();

  /// Drives the staggered fade-in of the sections.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    // The name, the sun or moon and the bubble play once per app launch, and
    // not at all with reduce-motion on.
    final bool animate = _vm.startIntro(
      reduceMotion: AppMotion.reduced(context),
    );
    if (animate) {
      _reveal.forward();
    } else {
      _reveal.value = 1;
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Widget _section(int index, Widget child) {
    final double begin = (index * 0.07).clamp(0.0, 0.6);
    final Animation<double> curve = CurvedAnimation(
      parent: _reveal,
      curve: Interval(
        begin,
        (begin + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  Color _glowColor(DayPart part) {
    switch (part) {
      case DayPart.morning:
        return AppColors.accent;
      case DayPart.afternoon:
        return AppColors.secondary;
      case DayPart.evening:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DayPart part = _vm.dayPart;
    final MindMateColors c = context.mm;

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: BlendedBackground(
              blueGlowColor: _glowColor(part),
              blueGlowOpacity: part == DayPart.morning ? 0.4 : 0.5,
            ),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: c.accentText,
              backgroundColor: c.surface,
              onRefresh: _vm.refreshAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: <Widget>[
                  _section(0, _header()),
                  const SizedBox(height: 16),
                  _section(1, _moodCard()),
                  const SizedBox(height: 12),
                  _section(2, _stats()),
                  Obx(
                    () => _vm.showCheckInCard
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _section(
                              3,
                              FinishCheckInCard(
                                onOpen: _vm.openCheckIn,
                                onDismiss: _vm.dismissCheckIn,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Obx(_suggestion),
                  const SizedBox(height: 22),
                  _section(
                    5,
                    Semantics(
                      header: true,
                      child: Text(
                        'Explore',
                        style: AppFonts.body(
                          size: 22,
                          weight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(6, Obx(_explore)),
                  const SizedBox(height: 14),
                  _section(7, SupportCard(onTap: _vm.openSupport)),
                  // Room for the bar at the bottom of the screen.
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header.
  // ---------------------------------------------------------------------------

  Widget _header() {
    return Obx(() {
      final bool loading = _vm.profileStatus.value == SectionStatus.loading;
      final bool failed = _vm.profileStatus.value == SectionStatus.failed;
      final String name = _vm.firstName;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _vm.greetingLine,
                      style: AppFonts.body(
                        size: 17,
                        weight: FontWeight.w500,
                        color: context.mm.textBody,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 50,
                      child: loading
                          ? const Align(
                              alignment: Alignment.centerLeft,
                              child: SkeletonBar(
                                width: 130,
                                height: 30,
                                radius: 12,
                              ),
                            )
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedName(
                                key: ValueKey<String>(name),
                                name: name,
                                animate: _vm.animateIntro,
                                delay: const Duration(milliseconds: 350),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Obx(
                () => HeaderCircleButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Notifications',
                  showDot: _vm.hasUnreadNotifications,
                  onPressed: _showNotifications,
                ),
              ),
              const SizedBox(width: 10),
              ProfileAvatar(
                imageUrl: _vm.imageUrl,
                initials: _vm.initials,
                onPressed: _vm.openProfile,
              ),
            ],
          ),
          if (failed)
            Semantics(
              button: true,
              label: 'Your profile could not load. Tap to retry',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: _vm.retryProfile,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Could not load. Tap to retry',
                    style: AppFonts.body(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: context.mm.accentText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final MindMateColors c = sheetContext.mm;
        return Container(
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            28 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Notifications',
                style: AppFonts.body(
                  size: 21,
                  weight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text('You are all caught up.', style: AppFonts.body(size: 16)),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Mood card and stats.
  // ---------------------------------------------------------------------------

  Widget _moodCard() {
    return Obx(() {
      final MoodCardContent content = _vm.moodCard;
      return HomeMoodCard(
        dayPart: _vm.dayPart,
        title: content.title,
        buttonLabel: content.buttonLabel,
        onLog: _vm.logMood,
        isLoadingTitle: _vm.moodStatus.value == SectionStatus.loading,
        bubble: _vm.bubbleText.value,
        playIntro: _vm.animateIntro,
      );
    });
  }

  Widget _stats() {
    return Obx(() {
      final SectionStatus mood = _vm.moodStatus.value;
      final SectionStatus meditation = _vm.meditationStatus.value;

      return Row(
        children: <Widget>[
          Expanded(
            child: StatTile(
              value: '${_vm.moodStreak}',
              label: 'day streak',
              status: mood,
              onRetry: _vm.retryMood,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              value: '${_vm.calmMinutes}',
              label: 'calm minutes',
              status: meditation,
              onRetry: _vm.retryMeditation,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              value: _vm.weekWord.label,
              label: 'week so far',
              status: mood,
              onRetry: _vm.retryMood,
            ),
          ),
        ],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Suggestion and Explore.
  // ---------------------------------------------------------------------------

  Widget _suggestion() {
    // Read first, so this Obx always has something to watch.
    final SectionStatus status = _vm.meditationStatus.value;

    // Hidden when the meditation module is not built.
    if (!_vm.meditationAvailable) {
      return const SizedBox.shrink();
    }

    final Widget card;
    switch (status) {
      case SectionStatus.loading:
        card = const SectionPlaceholderCard.loading();
      case SectionStatus.failed:
        card = SectionPlaceholderCard.failed(onRetry: _vm.retryMeditation);
      case SectionStatus.ready:
        final MeditationSuggestion? suggestion = _vm.suggestion.value;
        if (suggestion == null) {
          return const SizedBox.shrink();
        }
        card = SuggestionCard(
          heading: _vm.suggestionHeading,
          suggestion: suggestion,
          onOpen: _vm.openSuggestion,
        );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _section(4, card),
    );
  }

  Widget _explore() {
    final List<ExploreTile> tiles = _vm.exploreTiles;

    return Column(
      children: <Widget>[
        for (int i = 0; i < tiles.length; i += 2) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ExploreTileCard(
                    tile: tiles[i],
                    onTap: () => _vm.openTile(tiles[i]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ExploreTileCard(
                    tile: tiles[i + 1],
                    onTap: () => _vm.openTile(tiles[i + 1]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
