import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/gratitude_entry.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'gratitude_garden_viewmodel.dart';
import 'widgets/games_widgets.dart';
import 'widgets/garden_painter.dart';

/// Gratitude garden: one good thing a day, each one a flower.
class GratitudeGardenView extends StatefulWidget {
  const GratitudeGardenView({super.key});

  @override
  State<GratitudeGardenView> createState() => _GratitudeGardenViewState();
}

class _GratitudeGardenViewState extends State<GratitudeGardenView>
    with SingleTickerProviderStateMixin {
  late final GratitudeGardenViewModel _vm =
      Get.find<GratitudeGardenViewModel>();

  /// How far the newest flower has grown.
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );

  Worker? _plantedWorker;

  /// Flowers that fit side by side before the garden scrolls.
  static const int _visibleFlowers = 11;

  @override
  void initState() {
    super.initState();
    _plantedWorker = ever<String?>(_vm.justPlantedKey, (String? key) {
      if (key == null || !mounted) {
        return;
      }
      if (AppMotion.reduced(context)) {
        _grow.value = 1;
      } else {
        _grow.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _plantedWorker?.dispose();
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: <Widget>[
                MoodPageHeader(title: 'Gratitude garden', onBack: _vm.back),
                const SizedBox(height: 16),
                _garden(context),
                const SizedBox(height: 14),
                Obx(() => _card(context)),
                Obx(() => _previous(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // The garden.
  // ---------------------------------------------------------------------------

  Widget _garden(BuildContext context) {
    final double height = (MediaQuery.sizeOf(context).height * 0.25).clamp(
      150.0,
      230.0,
    );

    // A day sky on the cream page; a calm night sky in Dark, so the box
    // does not glow against the dark page.
    final List<Color> sky = context.mm.isDark
        ? const <Color>[Color(0xFF1A2C40), Color(0xFF22384F), Color(0xFF2C4A66)]
        : const <Color>[
            Color(0xFFC9DAE3),
            MindMateColors.cream,
            AppColors.softSurface,
          ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: height,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: sky,
                    stops: const <double>[0, 0.62, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 24,
              top: 22,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppBlends.gold,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: Color(0x66E4B266), blurRadius: 22),
                  ],
                ),
              ),
            ),
            Obx(() => _flowers(context, height)),
            Positioned(
              left: 14,
              top: 14,
              child: Obx(() {
                final int count = _vm.entries.length;
                if (count == 0) {
                  return const SizedBox.shrink();
                }
                return GamesChip(
                  '$count ${count == 1 ? 'flower' : 'flowers'}',
                  white: true,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowers(BuildContext context, double height) {
    final List<GratitudeEntry> entries = _vm.entries.toList(growable: false);
    final DateTime now = _vm.now;
    final TextDirection direction = Directionality.of(context);
    // Read here, not inside the builders below, so the Obx notices changes.
    final bool loading = _vm.isLoading.value;
    final String? growingKey = _vm.justPlantedKey.value;
    final MindMateColors c = context.mm;
    final Color stemColor = c.isDark
        ? AppColors.secondary
        : AppColors.headerBlue;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double viewport = box.maxWidth;
        final double slot =
            (viewport - GardenPainter.sidePadding * 2) / _visibleFlowers;
        final double content =
            (slot * entries.length + GardenPainter.sidePadding * 2).clamp(
              viewport,
              double.infinity,
            );

        return Stack(
          children: <Widget>[
            // Reversed, so the newest flowers are in view and older ones are
            // reached by scrolling sideways.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: SizedBox(
                width: content,
                height: height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails details) {
                    final GratitudeEntry? entry = GardenPainter(
                      entries: entries,
                      slotWidth: slot,
                      now: now,
                      onSelect: (_) {},
                      textDirection: direction,
                    ).entryAt(details.localPosition.dx);
                    if (entry != null) {
                      _showFlower(entry);
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _grow,
                    builder: (BuildContext context, Widget? child) {
                      return CustomPaint(
                        painter: GardenPainter(
                          entries: entries,
                          slotWidth: slot,
                          now: now,
                          onSelect: _showFlower,
                          textDirection: direction,
                          growingKey: growingKey,
                          growth: Curves.easeOutCubic.transform(_grow.value),
                          stemColor: stemColor,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (entries.isEmpty && !loading)
              Positioned(
                left: 24,
                right: 24,
                bottom: height * 0.3,
                child: Text(
                  'Plant your first flower today.',
                  textAlign: TextAlign.center,
                  style: AppFonts.body(
                    size: 17,
                    weight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Today's card.
  // ---------------------------------------------------------------------------

  Widget _card(BuildContext context) {
    if (_vm.isLoading.value) {
      return AppCard(
        radius: 26,
        child: SizedBox(
          height: 110,
          child: Center(
            child: CircularProgressIndicator(color: context.mm.accentText),
          ),
        ),
      );
    }
    if (_vm.loadFailed.value) {
      return MoodMessageCard(
        icon: Icons.cloud_off_rounded,
        title: 'Could not open your garden',
        message: 'Check your connection and try again.',
        actionLabel: 'Try again',
        onAction: _vm.load,
      );
    }
    return _vm.isWriting ? _composer() : _planted();
  }

  Widget _composer() {
    final bool editing = _vm.isEditing.value;
    final MindMateColors c = context.mm;

    return AppCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              'What is one good thing from today?',
              style: AppFonts.body(
                size: 19,
                weight: FontWeight.w700,
                color: c.textPrimary,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vm.textController,
            enabled: !_vm.isSaving.value,
            minLines: 2,
            maxLines: 4,
            maxLength: GratitudeRules.maxLength,
            textCapitalization: TextCapitalization.sentences,
            enableIMEPersonalizedLearning: false,
            style: AppFonts.body(size: 16, color: c.textBody),
            cursorColor: c.accentText,
            decoration: InputDecoration(
              hintText: 'A small thing is enough.',
              hintStyle: AppFonts.body(size: 16, color: c.textMuted),
              counterStyle: AppFonts.label(size: 12.5),
              filled: true,
              // Cream inside the white card (Light); the input colour (Dark).
              fillColor: c.isDark ? c.input : c.background,
              contentPadding: const EdgeInsets.all(14),
              border: _fieldBorder(AppColors.secondary),
              enabledBorder: _fieldBorder(AppColors.secondary),
              focusedBorder: _fieldBorder(c.selectedRing),
              disabledBorder: _fieldBorder(AppColors.secondary),
            ),
          ),
          if (_vm.saveFailed.value) ...<Widget>[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text(
                'We could not save that. Your words are still here.',
                style: AppFonts.body(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: MoodTextLink(label: 'Try again', onTap: _vm.submit),
            ),
          ],
          const SizedBox(height: 10),
          GradientButton(
            label: editing ? 'Save changes' : 'Plant today\'s flower',
            icon: null,
            isLoading: _vm.isSaving.value,
            onPressed: _vm.canSubmit ? _vm.submit : null,
          ),
          if (editing)
            Align(
              alignment: Alignment.center,
              child: MoodTextLink(label: 'Cancel', onTap: _vm.cancelEdit),
            ),
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: 2),
    );
  }

  Widget _planted() {
    final GratitudeEntry? entry = _vm.todayEntry;
    if (entry == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const GamesChip('Planted today', gold: true),
          const SizedBox(height: 12),
          Text(
            entry.text,
            style: AppFonts.body(
              size: 17,
              color: context.mm.textBody,
              height: 1.45,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: MoodTextLink(label: 'Edit', onTap: _vm.startEdit),
          ),
        ],
      ),
    );
  }

  Widget _previous(BuildContext context) {
    final GratitudeEntry? entry = _vm.previousEntry;
    if (entry == null || _vm.isLoading.value || _vm.loadFailed.value) {
      return const SizedBox.shrink();
    }
    final FlowerStyle style = FlowerStyle.forDateKey(entry.dateKey);

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MoodSectionLabel(GratitudeRules.dayLabel(entry.dateKey, _vm.now)),
          const SizedBox(height: 8),
          AppCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            onTap: () => _showFlower(entry),
            child: Row(
              children: <Widget>[
                ExcludeSemantics(
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _headColour(style.colour),
                      border: Border.all(
                        color: AppColors.headerBlue,
                        width: 2.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.headerBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.body(
                      size: 16,
                      color: context.mm.textBody,
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

  Color _headColour(FlowerColour colour) {
    switch (colour) {
      case FlowerColour.gold:
        return AppColors.accent;
      case FlowerColour.blue:
        return AppColors.secondary;
      case FlowerColour.white:
        return Colors.white;
    }
  }

  // ---------------------------------------------------------------------------
  // One flower.
  // ---------------------------------------------------------------------------

  Future<void> _showFlower(GratitudeEntry entry) {
    final DateTime now = _vm.now;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final MindMateColors c = sheetContext.mm;
        return Container(
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            22,
            20,
            22,
            20 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MoodSectionLabel(GratitudeRules.longDate(entry.date, now)),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    entry.text,
                    style: AppFonts.body(
                      size: 18,
                      color: c.textBody,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  TextButton(
                    onPressed: () async {
                      final bool? confirmed = await _confirmDelete(
                        sheetContext,
                      );
                      if (confirmed == true && sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                        await _vm.delete(entry);
                      }
                    },
                    child: Text(
                      'Delete',
                      style: AppFonts.body(
                        size: 16,
                        weight: FontWeight.w700,
                        color: c.accentText,
                      ),
                    ),
                  ),
                  MoodTextLink(
                    label: 'Close',
                    onTap: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDelete(BuildContext sheetContext) {
    return showDialog<bool>(
      context: sheetContext,
      builder: (BuildContext dialogContext) {
        final MindMateColors c = dialogContext.mm;
        return AlertDialog(
          backgroundColor: c.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Remove this flower?',
            style: AppFonts.body(
              size: 20,
              weight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          content: Text(
            'The flower and what you wrote will be removed.',
            style: AppFonts.body(size: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Keep it',
                style: AppFonts.body(
                  size: 16,
                  weight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Remove',
                style: AppFonts.body(
                  size: 16,
                  weight: FontWeight.w700,
                  color: c.accentText,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
