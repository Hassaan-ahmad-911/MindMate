import 'package:flutter/material.dart';

import 'mindmate_theme.dart';

/// The main MindMate button: 58 high, fully rounded, blue blend, white label
/// and a gold circle on the right holding [icon]. Pass a null [onPressed] to
/// disable it, and a null [icon] to hide the circle.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  static const double height = 58;
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(29));

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onPressed : null,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: enabled || isLoading ? 1 : 0.45,
        duration: AppMotion.of(context, const Duration(milliseconds: 200)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: context.mm.blueBlendHorizontal,
            borderRadius: _radius,
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: context.mm.isDark
                          ? context.mm.shadow
                          : const Color(0x571F3550),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: _radius,
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      if (isLoading)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.white,
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: icon == null ? 16 : 52,
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.button(),
                          ),
                        ),
                      if (icon != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: _GoldCircle(icon: icon!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldCircle extends StatelessWidget {
  const _GoldCircle({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        gradient: AppBlends.gold,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x8CE4B266),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 22, color: AppColors.headerBlue),
    );
  }
}
