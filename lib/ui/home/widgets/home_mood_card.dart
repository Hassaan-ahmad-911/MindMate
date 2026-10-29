import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../Models/home_dashboard.dart';
import '../../shared/mindmate_theme.dart';
import 'home_skeleton.dart';

/// The big card at the top of the dashboard. Its colours and its sky change
/// with the time of day, a soft ring breathes behind the robot, and a speech
/// bubble can pop in over it.
///
/// "Log mood" can be tapped from the first frame: nothing here waits for data.
class HomeMoodCard extends StatefulWidget {
  const HomeMoodCard({
    super.key,
    required this.dayPart,
    required this.title,
    required this.buttonLabel,
    required this.onLog,
    required this.isLoadingTitle,
    required this.bubble,
    required this.playIntro,
  });

  final DayPart dayPart;
  final String title;
  final String buttonLabel;
  final VoidCallback onLog;

  /// Shows grey bars where the title goes while the moods load.
  final bool isLoadingTitle;

  /// The speech bubble's line, or null for none.
  final String? bubble;

  /// Plays the sun or moon rising. False shows the final picture.
  final bool playIntro;

  static const String robotAsset = 'assets/images/robot_hello.png';
  static const String robotFallbackAsset =
      'assets/images/welcome_robot_fixed.png';

  @override
  State<HomeMoodCard> createState() => _HomeMoodCardState();
}

class _Look {
  const _Look({
    required this.gradient,
    required this.text,
    required this.button,
    required this.buttonText,
  });

  final Gradient gradient;
  final Color text;
  final Gradient button;
  final Color buttonText;

  static const _Look morning = _Look(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        AppColors.softSurface,
        AppColors.secondary,
        AppColors.primary,
      ],
    ),
    text: AppColors.headerBlue,
    button: LinearGradient(
      colors: <Color>[AppColors.headerBlue, AppColors.headerBlue],
    ),
    buttonText: Colors.white,
  );

  // The blue blend follows the theme, so this one is built each time.
  static _Look get afternoon => _Look(
    gradient: AppBlends.blue,
    text: Colors.white,
    button: AppBlends.gold,
    buttonText: AppColors.headerBlue,
  );

  static const _Look evening = _Look(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[AppColors.headerBlue, AppColors.textDark],
    ),
    text: Colors.white,
    button: AppBlends.gold,
    buttonText: AppColors.headerBlue,
  );

  static _Look of(DayPart part) {
    switch (part) {
      case DayPart.morning:
        return morning;
      case DayPart.afternoon:
        return afternoon;
      case DayPart.evening:
        return evening;
    }
  }
}

class _HomeMoodCardState extends State<HomeMoodCard>
    with TickerProviderStateMixin {
  /// The sun or moon rising, once.
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  /// One 10-second loop: the breathing ring goes round twice in it, and each
  /// star twinkles once, a third of a loop apart.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playIntro) {
      _rise.forward();
    } else {
      _rise.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _rise.value = 1;
      _loop.stop();
      _loop.value = 0.25;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _Look look = _Look.of(widget.dayPart);
    final bool reduced = AppMotion.reduced(context);
    final MindMateColors c = context.mm;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: look.gradient,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.isDark ? c.shadow : const Color(0x401F3550),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double width = box.maxWidth;
            final double robot = (width * 0.38).clamp(108.0, 150.0);
            const double height = 224;

            return SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  ..._sky(width, height),
                  Positioned(
                    left: 22,
                    top: 22,
                    right: robot + 36,
                    bottom: 20,
                    child: _text(look),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 22,
                    child: _robot(robot, reduced),
                  ),
                  if (widget.bubble != null)
                    Positioned(
                      right: 12,
                      top: 8,
                      child: _Bubble(text: widget.bubble!, animate: !reduced),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Text and button.
  // ---------------------------------------------------------------------------

  Widget _text(_Look look) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        if (widget.isLoadingTitle)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBar(width: 150, height: 20, onDark: true),
                SizedBox(height: 10),
                SkeletonBar(width: 110, height: 20, onDark: true),
              ],
            ),
          )
        else
          Semantics(
            header: true,
            child: Text(
              widget.title,
              style: AppFonts.body(
                size: 25,
                weight: FontWeight.w700,
                color: look.text,
                height: 1.18,
              ),
            ),
          ),
        // Scales down on a narrow phone instead of running out of the card.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _LogButton(
            label: widget.buttonLabel,
            look: look,
            onPressed: widget.onLog,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Robot, glow and speech bubble.
  // ---------------------------------------------------------------------------

  Widget _robot(double size, bool reduced) {
    final MindMateColors c = context.mm;
    return SizedBox(
      width: size * 1.3,
      height: size * 1.3,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _loop,
              builder: (BuildContext context, Widget? child) {
                // Two breaths in one 10-second loop: a 5-second cycle.
                final double breath =
                    0.5 - 0.5 * math.cos(2 * math.pi * 2 * _loop.value);
                final double scale = reduced ? 1.06 : 1.0 + 0.12 * breath;
                return Container(
                  width: size * 1.12 * scale,
                  height: size * 1.12 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: reduced ? 0.2 : 0.14 + 0.1 * breath,
                    ),
                  ),
                );
              },
            ),
          ),
          Semantics(
            label: 'MindMate robot waving',
            image: true,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.background,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  HomeMoodCard.robotAsset,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) {
                        return Image.asset(
                          HomeMoodCard.robotFallbackAsset,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stack,
                              ) => Icon(
                                Icons.smart_toy_rounded,
                                color: c.accentText,
                                size: 56,
                              ),
                        );
                      },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // The sky: a sun that rises, a high sun, or a moon with stars.
  // ---------------------------------------------------------------------------

  List<Widget> _sky(double width, double height) {
    switch (widget.dayPart) {
      case DayPart.morning:
        return <Widget>[
          AnimatedBuilder(
            animation: _rise,
            builder: (BuildContext context, Widget? child) {
              final double t = Curves.easeOutCubic.transform(_rise.value);
              return Positioned(
                left: width * 0.12,
                top: _lerp(height + 10, height * 0.5, t),
                child: ExcludeSemantics(child: _PaleSun(size: width * 0.34)),
              );
            },
          ),
        ];
      case DayPart.afternoon:
        return <Widget>[
          Positioned(
            left: width * 0.44,
            top: 10,
            child: const ExcludeSemantics(child: _HighSun()),
          ),
        ];
      case DayPart.evening:
        return <Widget>[
          AnimatedBuilder(
            animation: _rise,
            builder: (BuildContext context, Widget? child) {
              final double t = Curves.easeOutCubic.transform(_rise.value);
              // Rises into the gap under the title, above the button.
              return Positioned(
                left: width * 0.3,
                top: _lerp(height, height * 0.4, t),
                child: const ExcludeSemantics(child: _Moon(size: 46)),
              );
            },
          ),
          for (final _StarSpec star in _stars)
            AnimatedBuilder(
              animation: _loop,
              builder: (BuildContext context, Widget? child) {
                final double wave =
                    0.5 +
                    0.5 * math.sin(2 * math.pi * (_loop.value + star.phase));
                final double alpha = AppMotion.reduced(context)
                    ? 0.85
                    : 0.3 + 0.7 * wave;
                return Positioned(
                  left: width * star.x,
                  top: height * star.y,
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: alpha,
                      child: _Star(size: star.size),
                    ),
                  ),
                );
              },
            ),
        ];
    }
  }

  static const List<_StarSpec> _stars = <_StarSpec>[
    _StarSpec(x: 0.08, y: 0.5, size: 11, phase: 0),
    _StarSpec(x: 0.46, y: 0.44, size: 8, phase: 0.33),
    _StarSpec(x: 0.44, y: 0.7, size: 9, phase: 0.66),
  ];

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _StarSpec {
  const _StarSpec({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
  });

  final double x;
  final double y;
  final double size;
  final double phase;
}

class _LogButton extends StatelessWidget {
  const _LogButton({
    required this.label,
    required this.look,
    required this.onPressed,
  });

  final String label;
  final _Look look;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(Radius.circular(24));

    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: look.button, borderRadius: radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: AppFonts.body(
                      size: 17,
                      weight: FontWeight.w700,
                      color: look.buttonText,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: look.buttonText,
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

/// A small bubble (white in Light) that pops in over the robot and stays.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.animate});

  final String text;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: animate ? 0 : 1, end: 1),
      duration: animate ? const Duration(milliseconds: 520) : Duration.zero,
      curve: Curves.elasticOut,
      builder: (BuildContext context, double value, Widget? child) {
        return Transform.scale(
          scale: value.clamp(0.0, 1.2),
          alignment: Alignment.bottomRight,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Semantics(
        liveRegion: true,
        label: text,
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 138),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            border: c.surfaceBorder == null
                ? null
                : Border.all(color: c.surfaceBorder!),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.shadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppFonts.body(
              size: 13.5,
              weight: FontWeight.w600,
              color: c.textPrimary,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaleSun extends StatelessWidget {
  const _PaleSun({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: <Color>[Color(0xFFF7E3B8), Color(0xFFEFCD9F)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.45),
            blurRadius: 36,
            spreadRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _HighSun extends StatelessWidget {
  const _HighSun();

  @override
  Widget build(BuildContext context) {
    Widget ring(double size, double alpha) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accent.withValues(alpha: alpha),
            width: 2,
          ),
        ),
      );
    }

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ring(88, 0.18),
          ring(62, 0.3),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppBlends.gold,
              boxShadow: <BoxShadow>[
                BoxShadow(color: Color(0x80E4B266), blurRadius: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Moon extends StatelessWidget {
  const _Moon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: const _MoonPainter());
  }
}

class _MoonPainter extends CustomPainter {
  const _MoonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final Path outer = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(s * 0.5, s * 0.5), radius: s * 0.42),
      );
    final Path bite = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(s * 0.68, s * 0.4), radius: s * 0.36),
      );
    final Path crescent = Path.combine(PathOperation.difference, outer, bite);
    canvas.drawShadow(crescent, AppColors.softSurface, 8, true);
    canvas.drawPath(crescent, Paint()..color = AppColors.softSurface);
  }

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) => false;
}

class _Star extends StatelessWidget {
  const _Star({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: const _StarPainter());
  }
}

/// A four-point sparkle.
class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double c = s / 2;
    final Path star = Path()
      ..moveTo(c, 0)
      ..quadraticBezierTo(c, c, s, c)
      ..quadraticBezierTo(c, c, c, s)
      ..quadraticBezierTo(c, c, 0, c)
      ..quadraticBezierTo(c, c, c, 0)
      ..close();
    canvas.drawPath(star, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => false;
}
