import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/meditation_audio.dart';

import '../../Models/meditation_models.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/blended_background.dart';
import '../shared/mindmate_theme.dart';
import 'meditation_player_viewmodel.dart';
import 'widgets/background_sound_sheet.dart';
import 'widgets/meditation_widgets.dart';

/// The guided player: time left, the current step, and the controls.
class MeditationPlayerView extends GetView<MeditationPlayerViewModel> {
  const MeditationPlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    return PracticeLoader(
      controller: controller,
      builder: (BuildContext context, MeditationSession session) =>
          _PlayerBody(controller: controller, session: session),
    );
  }
}

class _PlayerBody extends StatefulWidget {
  const _PlayerBody({required this.controller, required this.session});

  final MeditationPlayerViewModel controller;
  final MeditationSession session;

  @override
  State<_PlayerBody> createState() => _PlayerBodyState();
}

class _PlayerBodyState extends State<_PlayerBody>
    with SingleTickerProviderStateMixin {
  /// One full breath (in and out) every 10 seconds.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  Worker? _playingWorker;

  MeditationPlayerViewModel get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _playingWorker = ever<bool>(_controller.isPlaying, (_) => _syncBreath());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreath();
  }

  /// The rings move only while the practice is playing, and stay still when
  /// the phone's reduce-motion setting is on.
  void _syncBreath() {
    if (!mounted) {
      return;
    }
    if (AppMotion.reduced(context)) {
      _breath.stop();
      _breath.value = 0.5;
    } else if (_controller.isPlaying.value) {
      if (!_breath.isAnimating) {
        _breath.repeat();
      }
    } else {
      _breath.stop();
    }
  }

  @override
  void dispose() {
    _playingWorker?.dispose();
    _breath.dispose();
    super.dispose();
  }

  Future<void> _confirmEnd() async {
    _controller.pauseForDialog();
    final bool? end = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'End this practice?',
          style: AppFonts.body(
            size: 20,
            weight: FontWeight.w600,
            color: dialogContext.mm.textPrimary,
          ),
        ),
        content: Text(
          'The time you have practised so far will still be saved.',
          style: AppFonts.body(size: 15.5, height: 1.45),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Keep going',
              style: AppFonts.body(
                size: 16,
                weight: FontWeight.w700,
                color: dialogContext.mm.accentText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'End',
              style: AppFonts.body(
                size: 16,
                weight: FontWeight.w700,
                color: dialogContext.mm.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    if (end == true) {
      _controller.endEarly();
    } else {
      _controller.resumeAfterDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MeditationSession session = widget.session;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _confirmEnd();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlendedBackground(
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: <Widget>[
                      CircleIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'End practice',
                        onPressed: _confirmEnd,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            session.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.body(
                              size: 17,
                              weight: FontWeight.w600,
                              color: context.mm.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      if (session.hasVoice) ...<Widget>[
                        const _VoiceButton(),
                        const SizedBox(width: 8),
                      ],
                      const _SoundButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SegmentedProgress(controller: _controller),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          // Leave room for the caption and a few lines of text.
                          final double largest = math.min(
                            300,
                            constraints.maxWidth - 40,
                          );
                          // Very short screens get a smaller ring, to leave
                          // more room for the text.
                          final double reserve = constraints.maxHeight < 420
                              ? 235
                              : 220;
                          final double ring = math.max(
                            110,
                            math.min(largest, constraints.maxHeight - reserve),
                          );

                          return Column(
                            children: <Widget>[
                              const SizedBox(height: 8),
                              _BreathingRings(
                                size: ring,
                                breath: _breath,
                                controller: _controller,
                              ),
                              const SizedBox(height: 16),
                              _Caption(
                                breath: _breath,
                                controller: _controller,
                                isBreathing: session.isBreathing,
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: _StepText(
                                  controller: _controller,
                                  // A little smaller on very short screens,
                                  // so long steps still fit.
                                  scale: constraints.maxHeight < 420 ? 0.88 : 1,
                                ),
                              ),
                            ],
                          );
                        },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _Controls(controller: _controller),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Text(
                    'Eyes open or closed. Stop any time.',
                    textAlign: TextAlign.center,
                    style: AppFonts.label(size: 13.5),
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

/// The voice on/off button. It only changes the current practice.
class _VoiceButton extends GetView<MeditationPlayerViewModel> {
  const _VoiceButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool available = controller.voiceAvailable.value;
      final bool on = controller.voiceEnabled.value && available;
      final MindMateColors c = context.mm;
      // Navy on the gold blend; the title colour on the surface circle.
      final Color ink = on ? AppColors.headerBlue : c.textPrimary;
      final String label = !available
          ? 'Voice is not available'
          : on
          ? 'Turn voice off'
          : 'Turn voice on';

      return Semantics(
        button: true,
        enabled: available,
        label: label,
        onTap: available ? controller.toggleVoice : null,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: InkResponse(
            onTap: available ? controller.toggleVoice : null,
            radius: 28,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: on ? AppBlends.gold : null,
                color: on ? null : c.surface,
                border: on || c.surfaceBorder == null
                    ? null
                    : Border.all(color: c.surfaceBorder!),
              ),
              child: Icon(
                on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                size: 22,
                color: ink.withValues(alpha: available ? 1 : 0.4),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// The background sound button: a surface circle, with a small gold dot when
/// a sound is on. It opens the "Background sound" sheet.
class _SoundButton extends GetView<MeditationPlayerViewModel> {
  const _SoundButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool on = controller.ambient.value != AmbientChoice.off;
      final MindMateColors c = context.mm;
      final String label = on
          ? 'Background sound: ${controller.ambient.value.label}'
          : 'Background sound: off';
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: 'Background sound',
          child: InkResponse(
            onTap: () => showBackgroundSoundSheet(
              context,
              selected: () => controller.ambient.value,
              volume: () => controller.ambientVolume.value,
              onSelect: controller.selectAmbient,
              onVolume: controller.setAmbientVolume,
              onVolumeEnd: controller.saveAmbientVolume,
            ),
            radius: 28,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface,
                      border: c.surfaceBorder == null
                          ? null
                          : Border.all(color: c.surfaceBorder!),
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 22,
                      color: c.textPrimary,
                    ),
                  ),
                  if (on)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppBlends.gold,
                          border: Border.all(color: c.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// One segment per step: finished steps navy, the current one filling in gold.
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({required this.controller});

  final MeditationPlayerViewModel controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int count = controller.stepCount;
      final int current = controller.stepIndex.value;
      final double progress = controller.stepProgress.value;
      final double gap = count > 14 ? 2 : 5;

      return Semantics(
        label: 'Step ${current + 1} of $count',
        excludeSemantics: true,
        child: Row(
          children: List<Widget>.generate(count, (int index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == count - 1 ? 0 : gap),
                child: _Segment(
                  done: index < current,
                  fill: index == current ? progress : 0,
                ),
              ),
            );
          }),
        ),
      );
    });
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.done, required this.fill});

  final bool done;
  final double fill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 5,
        decoration: BoxDecoration(
          color: done ? null : AppColors.secondary.withValues(alpha: 0.35),
          gradient: done ? AppBlends.blueHorizontal : null,
        ),
        alignment: Alignment.centerLeft,
        child: fill > 0
            ? FractionallySizedBox(
                widthFactor: fill.clamp(0.0, 1.0).toDouble(),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[AppColors.softSurface, AppColors.accent],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
              )
            : null,
      ),
    );
  }
}

/// Breathing rings around a navy circle with the time left.
class _BreathingRings extends StatelessWidget {
  const _BreathingRings({
    required this.size,
    required this.breath,
    required this.controller,
  });

  final double size;
  final Animation<double> breath;
  final MeditationPlayerViewModel controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: breath,
        builder: (BuildContext context, Widget? child) {
          final double t = breath.value;
          // 0 = fully breathed out, 1 = fully breathed in.
          final double b = Curves.easeInOut.transform(
            t < 0.5 ? t * 2 : (1 - t) * 2,
          );

          Widget ring(double diameter, double minScale, double opacity) {
            return Transform.scale(
              scale: minScale + (1 - minScale) * b,
              child: Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: opacity),
                ),
              ),
            );
          }

          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ring(size, 0.82, 0.15),
              ring(size * 0.84, 0.87, 0.24),
              ring(size * 0.69, 0.91, 0.36),
              Transform.scale(scale: 0.97 + 0.06 * b, child: child),
            ],
          );
        },
        child: _TimeCircle(diameter: size * 0.54, controller: controller),
      ),
    );
  }
}

class _TimeCircle extends StatelessWidget {
  const _TimeCircle({required this.diameter, required this.controller});

  final double diameter;
  final MeditationPlayerViewModel controller;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppBlends.blue,
        border: Border.all(color: c.surface.withValues(alpha: 0.8), width: 6),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.isDark ? c.shadow : const Color(0x4D1F3550),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Obx(
        () => Semantics(
          label: 'Time left ${controller.timeLeftLabel}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    controller.timeLeftLabel,
                    style: AppFonts.body(
                      size: 46,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                ),
                Text(
                  'LEFT',
                  style: AppFonts.label(
                    size: 13,
                    weight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Colors.white.withValues(alpha: 0.88),
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

/// "STEP 4 OF 6", or "BREATHE IN" / "BREATHE OUT" for a breathing practice.
class _Caption extends StatelessWidget {
  const _Caption({
    required this.breath,
    required this.controller,
    required this.isBreathing,
  });

  final Animation<double> breath;
  final MeditationPlayerViewModel controller;
  final bool isBreathing;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppFonts.label(
      size: 13.5,
      weight: FontWeight.w600,
      letterSpacing: 2,
      color: context.mm.textBody,
    );

    if (!isBreathing) {
      return Obx(
        () => Text(
          'STEP ${controller.stepIndex.value + 1} OF ${controller.stepCount}',
          style: style,
        ),
      );
    }

    // The rings do not move with reduce-motion on, so no in/out to follow.
    if (AppMotion.reduced(context)) {
      return Text('BREATHE SLOWLY', style: style);
    }
    return AnimatedBuilder(
      animation: breath,
      builder: (BuildContext context, Widget? child) =>
          Text(breath.value < 0.5 ? 'BREATHE IN' : 'BREATHE OUT', style: style),
    );
  }
}

/// The text of the current step, large and centred. It starts at the same
/// place for every step, just under the caption.
class _StepText extends StatelessWidget {
  const _StepText({required this.controller, this.scale = 1});

  final MeditationPlayerViewModel controller;

  /// Multiplies the text size.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 8, 26, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 8),
            child: Align(
              alignment: Alignment.topCenter,
              child: Obx(() {
                final String text = controller.stepText;
                final double size =
                    (text.length > 150
                        ? 19
                        : text.length > 100
                        ? 20.5
                        : 22) *
                    scale;
                return AnimatedSwitcher(
                  duration: AppMotion.of(
                    context,
                    const Duration(milliseconds: 350),
                  ),
                  layoutBuilder: (Widget? current, List<Widget> previous) =>
                      Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[...previous, ?current],
                      ),
                  child: Text(
                    text,
                    key: ValueKey<int>(controller.stepIndex.value),
                    textAlign: TextAlign.center,
                    style: AppFonts.body(
                      size: size,
                      color: context.mm.textBody,
                      height: 1.42,
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

/// Previous step, play or pause, next step.
class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final MeditationPlayerViewModel controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool playing = controller.isPlaying.value;
      final bool hasSteps = controller.stepCount > 1;

      final Widget playPause = _PlayPauseButton(
        playing: playing,
        onPressed: controller.togglePlayPause,
      );
      if (!hasSteps) {
        return Center(child: playPause);
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _TransportButton(
            icon: Icons.skip_previous_rounded,
            tooltip: 'Previous step',
            onPressed: controller.previous,
          ),
          const SizedBox(width: 26),
          playPause,
          const SizedBox(width: 26),
          _TransportButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Next step',
            onPressed: controller.isLastStep ? null : controller.next,
          ),
        ],
      );
    });
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final MindMateColors c = context.mm;

    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Material(
            color: c.surface,
            shape: CircleBorder(
              side: c.surfaceBorder == null
                  ? BorderSide.none
                  : BorderSide(color: c.surfaceBorder!),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(icon, size: 26, color: c.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String label = playing ? 'Pause' : 'Play';
    final MindMateColors c = context.mm;

    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: c.blueBlend,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.isDark ? c.shadow : const Color(0x591F3550),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 72,
                height: 72,
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
