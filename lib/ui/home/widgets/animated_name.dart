import 'package:flutter/material.dart';

import '../../shared/mindmate_theme.dart';

/// The user's first name in Lobster Two. With [animate] the letters appear one
/// at a time, about [letterGap] apart, and the whole name never takes longer
/// than [maxTotal]. Without it the name is simply there.
class AnimatedName extends StatefulWidget {
  const AnimatedName({
    super.key,
    required this.name,
    required this.animate,
    this.size = 42,
    this.letterGap = const Duration(milliseconds: 250),
    this.fade = const Duration(milliseconds: 250),
    this.maxTotal = const Duration(milliseconds: 1200),
    this.delay = Duration.zero,
  });

  final String name;
  final bool animate;
  final double size;
  final Duration letterGap;

  /// How long one letter takes to fade in.
  final Duration fade;
  final Duration maxTotal;

  /// Wait before the first letter, so the greeting line can come in first.
  final Duration delay;

  /// When letter [index] of [count] starts, in milliseconds. The last letter
  /// has finished fading by [maxTotal].
  static int startMillis({
    required int index,
    required int count,
    required Duration letterGap,
    required Duration fade,
    required Duration maxTotal,
  }) {
    if (count <= 1) {
      return 0;
    }
    final double room = (maxTotal - fade).inMilliseconds / (count - 1);
    final double gap = room < letterGap.inMilliseconds
        ? room
        : letterGap.inMilliseconds.toDouble();
    return (index * (gap < 0 ? 0 : gap)).round();
  }

  @override
  State<AnimatedName> createState() => _AnimatedNameState();
}

class _AnimatedNameState extends State<AnimatedName>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  List<String> get _letters =>
      widget.name.runes.map(String.fromCharCode).toList(growable: false);

  @override
  void initState() {
    super.initState();
    final int count = _letters.length;
    final int lastStart = AnimatedName.startMillis(
      index: count - 1,
      count: count,
      letterGap: widget.letterGap,
      fade: widget.fade,
      maxTotal: widget.maxTotal,
    );
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            widget.delay.inMilliseconds +
            lastStart +
            widget.fade.inMilliseconds,
      ),
    );
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> letters = _letters;
    final Color ink = context.mm.textPrimary;
    final TextStyle style = AppFonts.title(
      size: widget.size,
      color: ink,
      height: 1.1,
    );

    return Semantics(
      container: true,
      header: true,
      label: widget.name,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double elapsed =
              _controller.value *
              _controller.duration!.inMilliseconds.toDouble();

          return RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: style,
              children: <InlineSpan>[
                for (int i = 0; i < letters.length; i += 1)
                  TextSpan(
                    text: letters[i],
                    style: style.copyWith(
                      color: ink.withValues(
                        alpha: _alpha(elapsed, i, letters.length),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _alpha(double elapsed, int index, int count) {
    final int start = AnimatedName.startMillis(
      index: index,
      count: count,
      letterGap: widget.letterGap,
      fade: widget.fade,
      maxTotal: widget.maxTotal,
    );
    final double t =
        (elapsed - widget.delay.inMilliseconds - start) /
        widget.fade.inMilliseconds;
    return Curves.easeOut.transform(t.clamp(0.0, 1.0));
  }
}
