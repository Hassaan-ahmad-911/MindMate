import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/journal_draft.dart';
import '../../Models/journal_model.dart';
import '../../Models/journal_rules.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/mindmate_theme.dart';
import 'journal_viewmodel.dart';
import 'widgets/journal_widgets.dart';

/// Journal home. A bottom-nav tab, and also a pushed screen (with a back
/// button) when opened from the Home dashboard.
class JournalView extends StatefulWidget {
  const JournalView({super.key, this.showBack = false});

  final bool showBack;

  @override
  State<JournalView> createState() => _JournalViewState();
}

class _JournalViewState extends State<JournalView> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  JournalViewModel get controller => Get.find<JournalViewModel>();

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _startWriting({required bool fromPrompt}) async {
    final JournalDraft? draft = await controller.pendingDraft();
    if (draft != null) {
      if (!mounted) {
        return;
      }
      final bool? carryOn = await showJournalChoice(
        context,
        title: 'Continue your draft?',
        message: 'You have an entry you did not finish.',
        confirm: 'Continue',
        cancel: 'Start fresh',
      );
      if (carryOn == null) {
        return;
      }
      if (carryOn) {
        controller.continueDraft(draft);
        return;
      }
    }
    await controller.startFresh(fromPrompt: fromPrompt);
  }

  void _openSearch() {
    controller.openSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _search.clear();
    _searchFocus.unfocus();
    controller.closeSearch();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 400) {
      controller.loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      floatingActionButton: _WriteFab(
        onPressed: () => _startWriting(fromPrompt: false),
      ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: JournalBackground(blob: false)),
          SafeArea(
            bottom: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: controller.refreshEntries,
                child: Obx(() {
                  final bool searching = controller.isSearching.value;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                    children: <Widget>[
                      if (searching)
                        _SearchBar(
                          controller: _search,
                          focusNode: _searchFocus,
                          onChanged: controller.setQuery,
                          onClose: _closeSearch,
                        )
                      else
                        _Header(
                          showBack: widget.showBack,
                          onSearch: _openSearch,
                          onInsights: controller.openInsights,
                        ),
                      const SizedBox(height: 18),
                      if (!searching) ...<Widget>[
                        _PromptSection(
                          controller: controller,
                          onStart: () => _startWriting(fromPrompt: true),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ..._body(context),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (controller.isLoading.value && controller.entries.isEmpty) {
      return const <Widget>[SizedBox(height: 60), JournalListSkeleton()];
    }
    if (controller.hasError.value) {
      return <Widget>[
        MoodMessageCard(
          icon: Icons.cloud_off_rounded,
          title: 'Your journal did not load',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: controller.refreshEntries,
        ),
      ];
    }
    if (controller.isEmpty) {
      return <Widget>[
        _EmptyState(onStart: () => _startWriting(fromPrompt: false)),
      ];
    }

    final List<JournalDayGroup> groups = controller.groups;
    return <Widget>[
      _FilterChips(controller: controller),
      const SizedBox(height: 8),
      if (groups.isEmpty && !controller.isLoadingMore.value)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text(
            controller.query.value.trim().isNotEmpty
                ? 'No entries match "${controller.query.value.trim()}".'
                : 'No entries of this kind yet.',
            textAlign: TextAlign.center,
            style: AppFonts.body(size: 15),
          ),
        ),
      for (final JournalDayGroup group in groups) ...<Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 0, 10),
          child: MoodSectionLabel(group.label),
        ),
        for (final JournalModel entry in group.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: JournalEntryCard(
              entry: entry,
              onTap: () => controller.openEntry(entry),
            ),
          ),
      ],
      if (controller.isLoadingMore.value)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.showBack,
    required this.onSearch,
    required this.onInsights,
  });

  final bool showBack;
  final VoidCallback onSearch;
  final VoidCallback onInsights;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showBack) ...<Widget>[
          JournalRoundButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Back',
            onPressed: () => Get.back<void>(),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text('Journal', style: AppFonts.title(size: 40)),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: context.mm.textBody,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Private. Only you can see it.',
                      style: AppFonts.label(
                        size: 13.5,
                        color: context.mm.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        JournalRoundButton(
          icon: Icons.search_rounded,
          tooltip: 'Search',
          onPressed: onSearch,
        ),
        const SizedBox(width: 10),
        JournalRoundButton(
          icon: Icons.bar_chart_rounded,
          tooltip: 'Your writing',
          onPressed: onInsights,
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: c.input,
              border: c.surfaceBorder == null
                  ? null
                  : Border.all(color: c.surfaceBorder!),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.search_rounded, color: c.accentText),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: AppFonts.body(size: 16, color: c.textBody),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search your entries',
                      hintStyle: AppFonts.body(size: 16, color: c.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        JournalRoundButton(
          icon: Icons.close_rounded,
          tooltip: 'Close search',
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _PromptSection extends StatelessWidget {
  const _PromptSection({required this.controller, required this.onStart});

  final JournalViewModel controller;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String? prompt = controller.prompt.value?.text;
      if (prompt == null) {
        return Container(
          height: 190,
          decoration: BoxDecoration(
            gradient: AppBlends.blue,
            borderRadius: BorderRadius.circular(24),
          ),
        );
      }
      return JournalPromptCard(
        label: controller.promptLabel.value,
        prompt: prompt,
        onStart: onStart,
        onShuffle: controller.shufflePrompt,
      );
    });
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.controller});

  final JournalViewModel controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Let the chips run to the screen edges.
        clipBehavior: Clip.none,
        itemCount: JournalViewModel.filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String filter = JournalViewModel.filters[index];
          return Obx(
            () => JournalChip(
              label: JournalViewModel.filterLabel(filter),
              selected: controller.filter.value == filter,
              onTap: () => controller.setFilter(filter),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: <Widget>[
          const JournalMoodTile(moodLabel: null, size: 60),
          const SizedBox(height: 14),
          Text(
            'Your journal is empty.\nWrite your first entry tonight.',
            textAlign: TextAlign.center,
            style: AppFonts.body(
              size: 17,
              weight: FontWeight.w600,
              color: context.mm.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GoldPillButton(label: 'Start writing', onPressed: onStart),
        ],
      ),
    );
  }
}

class _WriteFab extends StatelessWidget {
  const _WriteFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Write a new entry',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppBlends.blue,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: context.mm.isDark
                    ? context.mm.shadow
                    : const Color(0x571F3550),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: const Icon(
              Icons.edit_rounded,
              color: AppColors.accent,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
