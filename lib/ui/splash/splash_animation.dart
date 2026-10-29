// MindMate animated splash: a brain that draws itself, breathing rings,
// and the name "MindMate" appearing letter by letter in Lobster Two.
//
// This file is UI only. SplashView shows it as the screen's body and
// SplashViewModel decides where to go once onFinished fires.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/mindmate_theme.dart';

class MindMateSplashAnimation extends StatefulWidget {
  const MindMateSplashAnimation({
    super.key,
    this.onFinished,
    this.duration = const Duration(milliseconds: 4200),
  });

  /// Called once, when the intro has finished playing.
  final VoidCallback? onFinished;

  /// Length of the intro (brain drawing + name). The breathing keeps looping.
  final Duration duration;

  @override
  State<MindMateSplashAnimation> createState() =>
      _MindMateSplashAnimationState();
}

class _MindMateSplashAnimationState extends State<MindMateSplashAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _breath;
  late final AnimationController _drift;

  bool _started = false;
  bool _static = false; // true when the phone has animations turned off
  bool _finished = false;
  Timer? _staticTimer;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (AppMotion.reduced(context)) {
      // Show the finished picture, hold briefly, then continue.
      _static = true;
      _staticTimer = Timer(const Duration(milliseconds: 1500), _finish);
    } else {
      _intro.forward();
      _breath.repeat();
      _drift.repeat(reverse: true);
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _staticTimer?.cancel();
    _intro.dispose();
    _breath.dispose();
    _drift.dispose();
    super.dispose();
  }

  /// Progress (0..1) of one step that runs between [start] and [end] of the
  /// intro, where the whole intro is 0..1.
  double _step(double intro, double start, double end) {
    final t = ((intro - start) / (end - start)).clamp(0.0, 1.0).toDouble();
    return Curves.easeOut.transform(t);
  }

  double _captionOpacity(double v) {
    if (v < 0.08) return v / 0.08;
    if (v < 0.42) return 1;
    if (v < 0.50) return (0.50 - v) / 0.08;
    return 0;
  }

  // The splash keeps its light look in both themes: fixed colours only, and
  // the Light theme's colours for the shared widgets (the background).
  static const MindMateColors _look = MindMateColors.light;

  @override
  Widget build(BuildContext context) {
    final Widget splash = AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: MindMateColors.cream,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Material(
        color: MindMateColors.cream,
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _breath, _drift]),
          builder: (context, _) {
            final intro = _static ? 1.0 : _intro.value;
            final breathRaw = _static ? 0.25 : _breath.value;
            final drift = _static
                ? 0.0
                : Curves.easeInOut.transform(_drift.value);

            // 0 = fully breathed out, 1 = fully breathed in.
            final breath = Curves.easeInOut.transform(
              breathRaw < 0.5 ? breathRaw * 2 : (1 - breathRaw) * 2,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                // Soft blue glow top-right, peach glow bottom-left.
                const BlendedBackground(),

                // Background shapes, drifting slowly.
                Positioned(
                  right: -120,
                  top: -130,
                  child: Transform.translate(
                    offset: Offset(-16 * drift, 14 * drift),
                    child: Transform.rotate(
                      angle: 0.17 * drift,
                      child: const BlobShape(
                        size: 330,
                        gradient: AppBlends.blueShape,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -170,
                  bottom: -170,
                  child: Transform.translate(
                    offset: Offset(14 * drift, -12 * drift),
                    child: Transform.rotate(
                      angle: -0.16 * drift,
                      child: const BlobShape(
                        size: 360,
                        gradient: AppBlends.gold,
                        points: blobShapeB,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 46,
                  top: 132 - 14 * drift,
                  child: const GlowDot(
                    size: 44,
                    gradient: AppBlends.gold,
                    glowColor: Color(0x99E4B266),
                  ),
                ),
                Positioned(
                  right: 50,
                  top: 238 + 14 * drift,
                  child: const GlowDot(size: 18, color: AppColors.secondary),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 44,
                  height: 160,
                  child: CustomPaint(
                    painter: _WavePainter(_step(intro, 0.10, 0.80)),
                  ),
                ),

                // Brain, name and breathing caption.
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBrain(intro, breath, breathRaw),
                      const SizedBox(height: 24),
                      _buildName(intro),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: _step(intro, 0.86, 0.96),
                        child: Container(
                          width: 56,
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, AppColors.softSurface],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildCaption(breathRaw),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    return Theme(
      data: Theme.of(
        context,
      ).copyWith(extensions: const <ThemeExtension<dynamic>>[_look]),
      child: splash,
    );
  }

  Widget _buildBrain(double intro, double breath, double breathRaw) {
    Widget ring(double size, double minScale, double opacity) {
      return Transform.scale(
        scale: minScale + (1 - minScale) * breath,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondary.withValues(alpha: opacity),
          ),
        ),
      );
    }

    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(300, 0.70, 0.16),
          ring(232, 0.80, 0.24),
          ring(192, 0.88, 0.40),
          Transform.scale(
            scale: 0.96 + 0.08 * breath,
            child: Container(
              width: 150,
              height: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _look.blueBlend,
                boxShadow: const [
                  // Soft white ring around the circle.
                  BoxShadow(color: Color(0xB3FFFFFF), spreadRadius: 6),
                  BoxShadow(
                    color: Color(0x611F3550),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: CustomPaint(
                size: const Size(110, 110),
                painter: _BrainPainter(
                  outline: _step(intro, 0.00, 0.45),
                  folds: _step(intro, 0.30, 0.62),
                  sparks: _step(intro, 0.58, 0.70),
                  sparkPhase: breathRaw,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Mind" then "Mate", one letter at a time.
  Widget _buildName(double intro) {
    const letters = 'MindMate';
    const starts = [0.30, 0.36, 0.42, 0.48, 0.60, 0.66, 0.72, 0.78];

    final style = AppFonts.title(
      size: 58,
      color: MindMateColors.navy,
      height: 1.15,
    );

    return Semantics(
      label: 'MindMate',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            for (var i = 0; i < letters.length; i++)
              TextSpan(
                text: letters[i],
                style: style.copyWith(
                  color: (i < 4 ? AppColors.headerBlue : AppColors.primary)
                      .withValues(
                        alpha: _step(intro, starts[i], starts[i] + 0.10),
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaption(double breathRaw) {
    final style = AppFonts.body(
      size: 15,
      height: 1.6,
      weight: FontWeight.w500,
      letterSpacing: 2.4,
      color: AppColors.textDark.withValues(alpha: 0.84),
    );

    return SizedBox(
      width: 240,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: _captionOpacity(breathRaw),
            child: Text('BREATHE IN', style: style),
          ),
          Opacity(
            opacity: _captionOpacity((breathRaw + 0.5) % 1.0),
            child: Text('BREATHE OUT', style: style),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brain, drawn on a 120 x 120 grid. Only the left half is listed; the right
// half is the same shape mirrored. Each list is: start x, start y, then groups
// of six numbers (control 1, control 2, end point) for cubic curves.
// ---------------------------------------------------------------------------

const List<double> _brainOutline = [
  60,
  24,
  52,
  16,
  40,
  18,
  37,
  27,
  28,
  26,
  20,
  34,
  23,
  44,
  14,
  48,
  12,
  60,
  20,
  66,
  15,
  74,
  20,
  85,
  30,
  86,
  33,
  95,
  46,
  99,
  53,
  93,
  57,
  96,
  60,
  94,
  60,
  90,
];

const List<List<double>> _brainFolds = [
  [37, 27, 40, 34, 47, 36, 51, 32],
  [23, 44, 30, 44, 34, 49, 33, 55],
  [20, 66, 28, 64, 34, 68, 36, 74],
  [30, 86, 32, 80, 38, 77, 44, 79],
];

const List<double> _brainBranchLeft = [60, 56, 52, 54, 46, 58, 45, 65];
const List<double> _brainBranchRight = [60, 44, 68, 42, 74, 46, 75, 53];

Path _cubicPath(
  List<double> d,
  double scale, {
  bool mirror = false,
  double mirrorWidth = 120,
}) {
  double x(double v) => (mirror ? mirrorWidth - v : v) * scale;

  final path = Path()..moveTo(x(d[0]), d[1] * scale);
  for (var i = 2; i + 5 < d.length; i += 6) {
    path.cubicTo(
      x(d[i]),
      d[i + 1] * scale,
      x(d[i + 2]),
      d[i + 3] * scale,
      x(d[i + 4]),
      d[i + 5] * scale,
    );
  }
  return path;
}

class _WavePainter extends CustomPainter {
  const _WavePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final sx = size.width / 390;
    final path = Path()
      ..moveTo(-10 * sx, 62)
      ..cubicTo(70 * sx, 20, 140 * sx, 120, 230 * sx, 90)
      ..cubicTo(320 * sx, 60, 350 * sx, 36, 400 * sx, 68);

    final paint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BrainPainter extends CustomPainter {
  const _BrainPainter({
    required this.outline,
    required this.folds,
    required this.sparks,
    required this.sparkPhase,
  });

  final double outline; // 0..1, how much of the outline is drawn
  final double folds; // 0..1, how much of the inner folds is drawn
  final double sparks; // 0..1, opacity of the gold points
  final double sparkPhase; // 0..1, loops, drives the pulsing

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;

    // The brain sits on a dark blue circle, so it is drawn in light colours.
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final foldPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void draw(Path path, Paint paint, double t) {
      if (t <= 0) return;
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
      }
    }

    // Outline: left half, right half, centre line.
    draw(_cubicPath(_brainOutline, s), outlinePaint, outline);
    draw(_cubicPath(_brainOutline, s, mirror: true), outlinePaint, outline);
    draw(
      Path()
        ..moveTo(60 * s, 24 * s)
        ..lineTo(60 * s, 90 * s),
      outlinePaint,
      outline,
    );

    // Inner folds.
    for (final fold in _brainFolds) {
      draw(_cubicPath(fold, s), foldPaint, folds);
      draw(_cubicPath(fold, s, mirror: true), foldPaint, folds);
    }
    draw(_cubicPath(_brainBranchLeft, s), foldPaint, folds);
    draw(_cubicPath(_brainBranchRight, s), foldPaint, folds);

    // Gold points that pulse one after another.
    if (sparks > 0) {
      const points = [
        Offset(37, 27),
        Offset(97, 44),
        Offset(20, 66),
        Offset(90, 86),
      ];
      for (var i = 0; i < points.length; i++) {
        final pulse =
            0.5 + 0.5 * math.sin(2 * math.pi * (sparkPhase * 3 + i / 4));
        final paint = Paint()
          ..color = AppColors.accent.withValues(
            alpha: sparks * (0.35 + 0.65 * pulse),
          );
        canvas.drawCircle(points[i] * s, 4 * s * (0.55 + 0.75 * pulse), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BrainPainter oldDelegate) =>
      oldDelegate.outline != outline ||
      oldDelegate.folds != folds ||
      oldDelegate.sparks != sparks ||
      oldDelegate.sparkPhase != sparkPhase;
}
