import 'package:flutter/material.dart';

import 'mindmate_theme.dart';

/// A gold tick in a navy circle, with soft rings that slowly breathe in and
/// out. The rings stay still when the phone's reduce-motion setting is on.
class BreathingTick extends StatefulWidget {
  const BreathingTick({
    super.key,
    this.size = 230,
    this.semanticLabel = 'Done',
    this.icon = Icons.check_rounded,
  });

  final double size;
  final String semanticLabel;

  /// The gold icon in the circle. A tick unless said otherwise.
  final IconData icon;

  @override
  State<BreathingTick> createState() => _BreathingTickState();
}

class _BreathingTickState extends State<BreathingTick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _breath.stop();
      _breath.value = 0.5;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;

    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (BuildContext context, Widget? child) {
            final double t = Curves.easeInOut.transform(_breath.value);
            Widget ring(double diameter, double minScale, double opacity) {
              return Transform.scale(
                scale: minScale + (1 - minScale) * t,
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
                ring(size, 0.78, 0.18),
                ring(size * 0.75, 0.86, 0.28),
                ring(size * 0.57, 0.92, 0.45),
                child!,
              ],
            );
          },
          child: Container(
            width: size * 0.45,
            height: size * 0.45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppBlends.blue,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
                width: 5,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x4D1F3550),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              size: size * 0.23,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}
