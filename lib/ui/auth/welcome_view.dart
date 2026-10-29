// MindMate welcome screen (final design: theme shapes + Lobster Two).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'welcome_viewmodel.dart';

// Robot image, listed under `assets:` in pubspec.yaml. It is shown inside a
// cream circle, so its cream square background blends in.
const String _robotAsset = 'assets/images/robot_hello.png';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _float;

  late final CurvedAnimation _heroIn;
  late final CurvedAnimation _textIn;
  late final CurvedAnimation _buttonsIn;
  late final CurvedAnimation _floatCurve;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _heroIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _textIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.25, 0.8, curve: Curves.easeOutCubic),
    );
    _buttonsIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    );
    _floatCurve = CurvedAnimation(parent: _float, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Respect the phone's "remove animations" accessibility setting.
    if (AppMotion.reduced(context)) {
      _float.stop();
      _intro.value = 1;
    } else {
      if (!_intro.isCompleted && !_intro.isAnimating) _intro.forward();
      if (!_float.isAnimating) _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _heroIn.dispose();
    _textIn.dispose();
    _buttonsIn.dispose();
    _floatCurve.dispose();
    _intro.dispose();
    _float.dispose();
    super.dispose();
  }

  Widget _reveal(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.10),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // A navigation bar in the page colour, instead of the black bar.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: c.background,
        systemNavigationBarIconBrightness: c.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        // No SafeArea at the top: the blue shape runs under the status bar.
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Peach glow bottom-left and a blue glow on the right.
            const BlendedBackground(
              blueGlowCenter: Alignment(1, 0.2),
              blueGlowRadius: 0.95,
              blueGlowOpacity: 0.45,
            ),
            SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: FadeTransition(
                      opacity: _heroIn,
                      child: _Hero(float: _floatCurve),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _reveal(_textIn, const _Headline()),
                        const SizedBox(height: 40),
                        _reveal(_buttonsIn, const _Actions()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Robot in a cream circle on a large blue shape, with peach and gold accents.
class _Hero extends StatelessWidget {
  const _Hero({required this.float});

  final Animation<double> float;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final s = width / 390; // the design was drawn 390 wide

        // Robot circle.
        final disc = math.min(286 * s, height * 0.62);
        final discLeft = width - 24 * s - disc;
        final discTop = height * 0.16;
        final discCx = discLeft + disc / 2;
        final discCy = discTop + disc / 2;

        // Blue shape, sized and placed around the robot circle.
        final blob = disc * 1.96;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: discCx - blob * 0.416,
              top: discCy - blob * 0.605,
              child: BlobShape(size: blob, gradient: AppBlends.blueShape),
            ),
            Positioned(
              left: -130 * s,
              top: discTop + disc * 0.61,
              child: BlobShape(
                size: 220 * s,
                gradient: AppBlends.gold,
                points: blobShapeB,
              ),
            ),
            Positioned(
              left: 14 * s,
              top: discTop + disc * 0.07,
              child: GlowDot(
                size: 52 * s,
                gradient: AppBlends.gold,
                glowColor: const Color(0x99E4B266),
              ),
            ),
            Positioned(
              left: 22 * s,
              top: discTop + disc * 0.42,
              child: GlowDot(size: 16 * s, color: AppColors.secondary),
            ),
            Positioned(
              left: discLeft,
              top: discTop,
              child: AnimatedBuilder(
                animation: float,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, -5 + 10 * float.value),
                  child: child,
                ),
                child: Container(
                  width: disc,
                  height: disc,
                  // Cream in both themes: the robot image has a cream square
                  // background that must blend into the circle.
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MindMateColors.cream,
                    boxShadow: [
                      // Soft ring around the circle.
                      const BoxShadow(
                        color: Color(0x47FDF7EE),
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: c.isDark ? c.shadow : const Color(0x3D1F3550),
                        blurRadius: 38,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      _robotAsset,
                      width: disc,
                      height: disc,
                      fit: BoxFit.cover,
                      semanticLabel: 'MindMate robot companion waving hello',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final nameStyle = AppFonts.title(size: 66, height: 1.08);
    final Color accentText = context.mm.accentText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          label: 'Welcome to MindMate',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to',
                style: AppFonts.title(
                  size: 30,
                  height: 1.2,
                  color: accentText,
                ).copyWith(fontWeight: FontWeight.w400),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Mind', style: nameStyle),
                      TextSpan(
                        text: 'Mate',
                        style: nameStyle.copyWith(color: accentText),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 56,
          height: 4,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.softSurface],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your wellness companion',
          style: AppFonts.body(size: 18, height: 1.5),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    final WelcomeViewModel controller = Get.find<WelcomeViewModel>();
    final Color ink = context.mm.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main button: blue-to-navy blend with a glowing gold arrow.
        GradientButton(label: 'Get started', onPressed: controller.goToSignup),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: controller.goToLogin,
            style: TextButton.styleFrom(
              foregroundColor: ink,
              minimumSize: const Size(96, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: Text(
              'Log in',
              style: AppFonts.body(
                size: 17,
                weight: FontWeight.w700,
                color: ink,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
