import 'package:flutter/material.dart';

import '../../shared/mindmate_theme.dart';

/// A soft grey-blue bar that pulses gently while something loads. It stays
/// still when the phone's reduce-motion setting is on.
class SkeletonBar extends StatefulWidget {
  const SkeletonBar({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.onDark = false,
  });

  final double? width;
  final double height;
  final double radius;

  /// For use on the blue mood card: a light bar instead of a blue one.
  final bool onDark;

  @override
  State<SkeletonBar> createState() => _SkeletonBarState();
}

class _SkeletonBarState extends State<SkeletonBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = widget.onDark ? Colors.white : AppColors.secondary;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext context, Widget? child) {
          final double alpha = 0.22 + 0.18 * _pulse.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: base.withValues(alpha: alpha),
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          );
        },
      ),
    );
  }
}
