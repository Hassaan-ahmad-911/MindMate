import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../mood_tracking/widgets/mood_widgets.dart';
import '../../shared/mindmate_theme.dart';

/// The top of a setup screen: an optional back button, a progress bar of
/// [total] segments with [step] filled, and "step of total".
class SetupTopBar extends StatelessWidget {
  const SetupTopBar({
    super.key,
    required this.step,
    this.total = 3,
    this.onBack,
  });

  final int step;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          CircleIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Back',
            onPressed: onBack,
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Semantics(
            label: 'Step $step of $total',
            excludeSemantics: true,
            child: Row(
              children: List<Widget>.generate(total, (int index) {
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: index < step ? AppBlends.blueHorizontal : null,
                      color: index < step
                          ? null
                          : AppColors.secondary.withValues(alpha: 0.35),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          '$step of $total',
          style: AppFonts.label(size: 14, color: context.mm.textBody),
        ),
      ],
    );
  }
}

/// The Lobster title with a line under it.
class SetupTitle extends StatelessWidget {
  const SetupTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: AppFonts.title(size: 40)),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: AppFonts.body(size: 15.5, height: 1.4)),
      ],
    );
  }
}

/// A small heading above a group of choices or a field.
class SetupLabel extends StatelessWidget {
  const SetupLabel(this.text, {super.key, this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: AppFonts.body(
          size: 15,
          weight: FontWeight.w600,
          color: context.mm.textPrimary,
        ),
        children: <InlineSpan>[
          if (optional)
            TextSpan(
              text: ' (optional)',
              style: AppFonts.body(
                size: 14,
                weight: FontWeight.w400,
                color: context.mm.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// A selectable pill. Chosen: blue blend with a gold tick.
class SetupChip extends StatelessWidget {
  const SetupChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final BorderRadius radius = BorderRadius.circular(24);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 160)),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: selected ? AppBlends.blue : null,
          color: selected ? null : c.surface,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.secondary.withValues(alpha: 0.55),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (selected) ...<Widget>[
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: AppFonts.body(
                      size: 15,
                      weight: FontWeight.w500,
                      color: selected ? Colors.white : c.textPrimary,
                      height: 1.1,
                    ),
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

/// A white text field with a small label above it.
class SetupTextField extends StatelessWidget {
  const SetupTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.optional = false,
    this.errorText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool optional;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SetupLabel(label, optional: optional),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          style: AppFonts.body(size: 16.5, color: c.textBody),
          decoration: InputDecoration(
            filled: true,
            fillColor: c.input,
            counterText: '',
            hintText: hint,
            hintStyle: AppFonts.body(size: 16.5, color: c.textMuted),
            errorText: errorText,
            errorStyle: AppFonts.body(
              size: 13,
              color: c.accentText,
              height: 1.3,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: border(AppColors.secondary.withValues(alpha: 0.5), 1),
            enabledBorder: border(
              AppColors.secondary.withValues(alpha: 0.5),
              1,
            ),
            focusedBorder: border(c.textPrimary, 1.8),
            errorBorder: border(AppColors.primary, 1.4),
            focusedErrorBorder: border(c.textPrimary, 1.8),
          ),
        ),
      ],
    );
  }
}

/// An answer on a check-in question: a white card with a circle on the right
/// (a tick when chosen). Chosen: blue blend with white text.
class AnswerCard extends StatelessWidget {
  const AnswerCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.multiSelect = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Shows a square tick box instead of a round one.
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final BorderRadius radius = BorderRadius.circular(18);
    final BorderRadius markRadius = BorderRadius.circular(multiSelect ? 8 : 12);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 160)),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: selected ? AppBlends.blueHorizontal : null,
          color: selected ? null : c.surface,
          border: selected || c.surfaceBorder == null
              ? null
              : Border.all(color: c.surfaceBorder!),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.isDark
                  ? c.shadow
                  : AppColors.headerBlue.withValues(
                      alpha: selected ? 0.2 : 0.06,
                    ),
              blurRadius: selected ? 14 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: AppFonts.body(
                        size: 16.5,
                        weight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? Colors.white : c.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: markRadius,
                      color: selected ? AppColors.accent : Colors.transparent,
                      border: selected
                          ? null
                          : Border.all(color: AppColors.secondary, width: 1.6),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: AppColors.headerBlue,
                          )
                        : null,
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
