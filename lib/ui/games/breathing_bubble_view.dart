import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../Models/breath_round.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/blended_background.dart';
import '../shared/breathing_tick.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'breathing_bubble_viewmodel.dart';
import 'widgets/games_widgets.dart';

/// Press and hold to breathe in, let go to breathe out. Eight breaths.
class BreathingBubbleView extends StatefulWidget {
  const BreathingBubbleView({super.key});

  @override
  State<BreathingBubbleView> createState() => _BreathingBubbleViewState();
}

class _BreathingBubbleViewState extends State<BreathingBubbleView>
    with SingleTickerProviderStateMixin {
  late final BreathingBubbleViewModel _vm =
      Get.find<BreathingBubbleViewModel>();

  /// 0 to 1. While breathing in it is how full the bubble is; while breathing
  /// out it is how far the bubble has floated away.
  late final AnimationController _anim = AnimationController(vsync: this);

  int? _pointer;

  /// A breath started by a screen reader's double tap, which cannot hold.
  bool _assisted = false;

  static const double _smallScale = 0.2;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _press() {
    if (!_vm.press()) {
      return;
    }
    _anim.duration = BreathTiming.inhale;
    _anim.value = 0;
    _anim.forward().whenComplete(() {
      if (_vm.phase.value == BreathPhase.inhaling) {
        _vm.reachedFull();
        HapticFeedback.selectionClick();
        if (_assisted) {
          _release();
        }
      }
    });
  }

  void _release() {
    _assisted = false;
    final BreathRelease result = _vm.release();
    switch (result) {
      case BreathRelease.ignored:
        return;
      case BreathRelease.early:
        _anim.duration = BreathTiming.shrinkBack;
        _anim.reverse().whenComplete(() {
          if (_vm.phase.value == BreathPhase.shrinking) {
            _vm.shrinkFinished();
          }
        });
      case BreathRelease.exhale:
        _anim.duration = BreathTiming.exhale;
        _anim.forward(from: 0).whenComplete(() {
          if (_vm.phase.value == BreathPhase.exhaling) {
            _vm.exhaleFinished();
            _anim.value = 0;
          }
        });
    }
  }

  void _again() {
    _anim.value = 0;
    _vm.again();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          SafeArea(
            child: Obx(
              () => _vm.isFinished ? _finished() : _breathing(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final MindMateColors c = context.mm;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: <Widget>[
          CircleIconButton(
            icon: Icons.close_rounded,
            onPressed: _vm.done,
            tooltip: 'Close',
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Breathing bubble',
                textAlign: TextAlign.center,
                style: AppFonts.body(
                  size: 17,
                  weight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 46),
        ],
      ),
    );
  }

  Widget _breathing(BuildContext context) {
    return Column(
      children: <Widget>[
        _header(),
        Expanded(
          // Anywhere below the header is the "button": press to breathe in,
          // let go to breathe out.
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (PointerDownEvent event) {
              if (_pointer != null) {
                return;
              }
              _pointer = event.pointer;
              _assisted = false;
              _press();
            },
            onPointerUp: (PointerUpEvent event) {
              if (event.pointer == _pointer) {
                _pointer = null;
                _release();
              }
            },
            onPointerCancel: (PointerCancelEvent event) {
              if (event.pointer == _pointer) {
                _pointer = null;
                _release();
              }
            },
            child: Semantics(
              container: true,
              label: 'Take one slow breath',
              hint: 'Double tap to breathe in, hold, and let go.',
              button: true,
              onTap: () {
                if (_vm.phase.value == BreathPhase.ready) {
                  _assisted = true;
                  _press();
                }
              },
              excludeSemantics: true,
              child: _stage(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stage(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 18),
        Obx(() => _dots()),
        const SizedBox(height: 8),
        Obx(
          () => Text(
            _vm.progressLabel.toUpperCase(),
            style: AppFonts.label(
              size: 13,
              weight: FontWeight.w600,
              letterSpacing: 1.8,
              color: context.mm.textBody,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double ring = (box.biggest.shortestSide - 24).clamp(
                120.0,
                340.0,
              );
              // A bubble that floats up is cut off at the top of this area,
              // so it never drifts over the dots and the label above.
              return ClipRect(child: Center(child: _bubbleArea(context, ring)));
            },
          ),
        ),
        Obx(
          () => Semantics(
            liveRegion: true,
            header: true,
            child: Text(_vm.title, style: AppFonts.title(size: 42)),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Obx(
            () => Text(
              _vm.instruction,
              textAlign: TextAlign.center,
              style: AppFonts.body(size: 16, height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _HoldPill(),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _dots() {
    final int done = _vm.completed.value;
    final MindMateColors c = context.mm;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < _vm.total; i += 1)
          Container(
            width: 11,
            height: 11,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done
                  ? c.textPrimary
                  : i == done
                  ? AppColors.accent
                  : AppColors.secondary.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }

  Widget _bubbleArea(BuildContext context, double ring) {
    final bool reduced = AppMotion.reduced(context);

    return SizedBox(
      width: ring,
      height: ring,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          ExcludeSemantics(
            child: CustomPaint(
              size: Size.square(ring),
              painter: const DashedCirclePainter(color: AppColors.secondary),
            ),
          ),
          for (final Offset spot in const <Offset>[
            Offset(-0.46, -0.28),
            Offset(0.5, 0.0),
            Offset(-0.5, 0.44),
          ])
            Positioned(
              left: ring / 2 + spot.dx * ring - 9,
              top: ring / 2 + spot.dy * ring - 9,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 0.55,
                  child: BubbleSphere(size: spot.dx == 0.5 ? 26 : 18),
                ),
              ),
            ),
          AnimatedBuilder(
            animation: _anim,
            builder: (BuildContext context, Widget? child) {
              return Obx(() => _bubble(ring, reduced));
            },
          ),
        ],
      ),
    );
  }

  Widget _bubble(double ring, bool reduced) {
    final BreathPhase phase = _vm.phase.value;
    final double full = ring * 0.92;
    final double t = Curves.easeInOut.transform(_anim.value.clamp(0.0, 1.0));

    // Breathing out: floats up and fades (only fades with reduce-motion).
    if (phase == BreathPhase.exhaling) {
      final double lift = reduced ? 0 : -t * ring * 0.55;
      return Transform.translate(
        offset: Offset(0, lift),
        child: Opacity(
          opacity: 1 - t,
          child: BubbleSphere(size: full),
        ),
      );
    }

    final bool growing =
        phase == BreathPhase.inhaling ||
        phase == BreathPhase.full ||
        phase == BreathPhase.shrinking;
    final double fill = growing ? t : 0;

    // Reduce-motion: the bubble fades between a small and a big one instead of
    // growing.
    if (reduced) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Opacity(
            opacity: 1 - fill,
            child: BubbleSphere(size: full * _smallScale * 1.6),
          ),
          Opacity(
            opacity: fill,
            child: BubbleSphere(size: full),
          ),
        ],
      );
    }

    final double scale = _smallScale + (1 - _smallScale) * fill;
    return BubbleSphere(size: full * scale);
  }

  Widget _finished() {
    return Column(
      children: <Widget>[
        _header(),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const BreathingTick(size: 200, semanticLabel: 'All done'),
                  const SizedBox(height: 18),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      'Nicely done',
                      textAlign: TextAlign.center,
                      style: AppFonts.title(size: 44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You took ${_vm.total} slow breaths. Come back whenever '
                    'you want a short break.',
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
                label: 'Again',
                icon: Icons.replay_rounded,
                onPressed: _again,
              ),
              const SizedBox(height: 4),
              MoodTextLink(label: 'Done', onTap: _vm.done),
            ],
          ),
        ),
      ],
    );
  }
}

class _HoldPill extends StatelessWidget {
  const _HoldPill();

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 22, 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(30),
          border: c.surfaceBorder == null
              ? null
              : Border.all(color: c.surfaceBorder!),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.shadow,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppBlends.gold,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Press and hold anywhere',
              style: AppFonts.body(
                size: 16,
                weight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
