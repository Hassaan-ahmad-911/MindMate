import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/mindmate_theme.dart';

/// The blue card with the hospital's name: on "Join your hospital" after
/// joining, and at the top of "Your hospital".
class HospitalCard extends StatelessWidget {
  const HospitalCard({super.key, required this.name, required this.line});

  final String name;
  final String line;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      container: true,
      label: '$name. $line',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppBlends.blue,
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.isDark ? c.shadow : const Color(0x331F3550),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppBlends.gold,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: AppColors.headerBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: AppFonts.body(
                      size: 17,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: AppFonts.body(
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.3,
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

/// The look of the small round icon in front of an [InfoLine].
enum InfoTone { lightBlue, gold, navy }

/// One line with a small round icon, as on "How your wellbeing is looked
/// after" and "What your hospital can see".
class InfoLine extends StatelessWidget {
  const InfoLine({
    super.key,
    required this.icon,
    required this.text,
    this.tone = InfoTone.lightBlue,
    this.bold,
  });

  final IconData icon;
  final String text;
  final InfoTone tone;

  /// A part of [text] to show in bold (the first time it appears).
  final String? bold;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final Gradient? gradient;
    final Color? color;
    final Color iconColor;
    switch (tone) {
      case InfoTone.lightBlue:
        gradient = AppBlends.lightBlue;
        color = null;
        iconColor = AppColors.headerBlue;
      case InfoTone.gold:
        gradient = AppBlends.gold;
        color = null;
        iconColor = AppColors.headerBlue;
      case InfoTone.navy:
        gradient = null;
        color = AppColors.headerBlue;
        iconColor = Colors.white;
    }

    final TextStyle style = AppFonts.body(
      size: 15,
      color: c.textBody,
      height: 1.4,
    );
    final String? strong = bold;
    final int at = strong == null ? -1 : text.indexOf(strong);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              color: color,
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: at < 0
                ? Text(text, style: style)
                : Text.rich(
                    TextSpan(
                      style: style,
                      children: <InlineSpan>[
                        TextSpan(text: text.substring(0, at)),
                        TextSpan(
                          text: strong,
                          style: AppFonts.body(
                            size: 15,
                            weight: FontWeight.w700,
                            color: c.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        TextSpan(text: text.substring(at + strong!.length)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The hospital code field: a hospital icon, capital letters, and a tick
/// once the code looks right.
class HospitalCodeField extends StatelessWidget {
  const HospitalCodeField({
    super.key,
    required this.controller,
    required this.looksRight,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool looksRight;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmitted(),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
        LengthLimitingTextInputFormatter(20),
        TextInputFormatter.withFunction(
          (TextEditingValue oldValue, TextEditingValue newValue) =>
              newValue.copyWith(text: newValue.text.toUpperCase()),
        ),
      ],
      style: AppFonts.body(
        size: 19,
        weight: FontWeight.w700,
        color: c.textPrimary,
        letterSpacing: 2,
      ),
      decoration: InputDecoration(
        hintText: 'For example CGH-2026',
        hintStyle: AppFonts.body(size: 16, color: c.textMuted),
        semanticCounterText: '',
        filled: true,
        fillColor: c.input,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        prefixIcon: Icon(Icons.apartment_rounded, color: c.accentText),
        suffixIcon: looksRight
            ? Icon(Icons.check_rounded, color: c.accentText)
            : null,
        enabledBorder: border(
          looksRight ? AppColors.primary : AppColors.secondary,
          looksRight ? 2 : 1.2,
        ),
        focusedBorder: border(AppColors.primary, 2),
        disabledBorder: border(AppColors.secondary, 1.2),
      ),
    );
  }
}
