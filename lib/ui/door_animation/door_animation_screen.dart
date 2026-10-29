import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/app_routes.dart';
import '../shared/mindmate_theme.dart';

class DoorAnimationScreen extends StatefulWidget {
  const DoorAnimationScreen({super.key});

  @override
  State<DoorAnimationScreen> createState() => _DoorAnimationScreenState();
}

class _DoorAnimationScreenState extends State<DoorAnimationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.forward();

    _navigationTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) {
        return;
      }
      Get.offNamed(AppRoutes.robot);
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindMateColors c = context.mm;

    return Scaffold(
      backgroundColor: c.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.15,
            colors: <Color>[
              c.background,
              AppColors.softSurface.withValues(alpha: 0.20),
              AppColors.primary.withValues(alpha: 0.16),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Center(
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.surface.withValues(alpha: 0.58),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                        color: c.shadow,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.smart_toy_rounded,
                    color: c.accentText,
                    size: 74,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  final double progress = Curves.easeInOutCubic.transform(
                    _controller.value,
                  );
                  final double screenWidth = MediaQuery.sizeOf(context).width;
                  final double shift = screenWidth * 0.54 * progress;

                  return Row(
                    children: <Widget>[
                      Transform.translate(
                        offset: Offset(-shift, 0),
                        child: _DoorPanel(isLeft: true, progress: progress),
                      ),
                      Transform.translate(
                        offset: Offset(shift, 0),
                        child: _DoorPanel(isLeft: false, progress: progress),
                      ),
                    ],
                  );
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Opening your safe space...',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A gentle space for calm conversation is opening now.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoorPanel extends StatelessWidget {
  const _DoorPanel({required this.isLeft, required this.progress});

  final bool isLeft;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.5,
      height: double.infinity,
      child: Container(
        margin: EdgeInsets.only(
          top: 40,
          bottom: 60,
          left: isLeft ? 20 : 8,
          right: isLeft ? 8 : 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xFFF6E2B6),
              const Color(0xFFE8BD78).withValues(alpha: 0.98),
            ],
          ),
          borderRadius: BorderRadius.only(
            topLeft: isLeft
                ? const Radius.circular(28)
                : const Radius.circular(8),
            bottomLeft: isLeft
                ? const Radius.circular(28)
                : const Radius.circular(8),
            topRight: isLeft
                ? const Radius.circular(8)
                : const Radius.circular(28),
            bottomRight: isLeft
                ? const Radius.circular(8)
                : const Radius.circular(28),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              blurRadius: 20,
              offset: const Offset(0, 8),
              color: context.mm.shadow,
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              bottom: 0,
              left: isLeft ? null : 0,
              right: isLeft ? 0 : null,
              child: Container(
                width: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(isLeft ? 0 : 999),
                    right: Radius.circular(isLeft ? 999 : 0),
                  ),
                ),
              ),
            ),
            Center(
              child: AnimatedOpacity(
                opacity: 1 - progress,
                duration: const Duration(milliseconds: 80),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.32),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLeft
                        ? Icons.meeting_room_rounded
                        : Icons.door_back_door_rounded,
                    // On the gold door: the same in both themes.
                    color: AppColors.textDark.withValues(alpha: 0.70),
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
