import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../Models/auth_validation.dart';
import '../../mood_tracking/widgets/mood_widgets.dart';
import '../../shared/blended_background.dart';
import '../../shared/blob_shape.dart';
import '../../shared/gradient_button.dart';
import '../../shared/mindmate_theme.dart';

/// The sentence people agree to on Create account.
const String disclaimerText =
    'I understand MindMate is a self-support tool and not a substitute for '
    'professional care.';

/// A softer red for messages under a field. It is only used for problems.
const Color authErrorColor = Color(0xFFB54F43);

/// The shared page of the account screens: the glowing background, an
/// optional blue shape with a gold dot, a round back button, and content that
/// scrolls when the keyboard is open. [bottom] sits at the foot of the page
/// (or just under the content on a short screen). [footer] stays pinned
/// under the scrolling part, so it sits just above the keyboard.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.onBack,
    required this.children,
    this.bottom,
    this.footer,
    this.showShape = true,
    this.shapeTop = -170,
    this.topGap = 36,
  });

  /// Null hides the back button.
  final VoidCallback? onBack;
  final List<Widget> children;
  final Widget? bottom;
  final Widget? footer;

  /// The large blue shape in the top-right corner (Log in and Create account).
  final bool showShape;

  /// How far up the blue shape sits; lower numbers show less of it.
  final double shapeTop;

  /// Space between the back button and the first child.
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: BlendedBackground(blueGlowOpacity: showShape ? 0 : 0.6),
          ),
          if (showShape) ...<Widget>[
            Positioned(
              right: -150,
              top: shapeTop,
              child: const ExcludeSemantics(
                child: BlobShape(size: 360, gradient: AppBlends.blueShape),
              ),
            ),
            const Positioned(
              left: 150,
              top: 76,
              child: ExcludeSemantics(
                child: GlowDot(
                  size: 26,
                  gradient: AppBlends.gold,
                  glowColor: Color(0x80E4B266),
                ),
              ),
            ),
          ],
          SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: <Widget>[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                        sliver: SliverFillRemaining(
                          hasScrollBody: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (onBack != null)
                                CircleIconButton(
                                  icon: Icons.chevron_left_rounded,
                                  onPressed: onBack,
                                  tooltip: 'Back',
                                )
                              else
                                const SizedBox(height: 46),
                              SizedBox(height: topGap),
                              ...children,
                              if (bottom != null) ...<Widget>[
                                const Spacer(),
                                const SizedBox(height: 22),
                                Center(child: bottom),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: footer,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one Lobster title and the line under it.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: AppFonts.title(size: 44, height: 1.1)),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: AppFonts.body(size: 16, height: 1.4)),
      ],
    );
  }
}

/// A white, 16 px rounded field with a label above, a leading icon and a 2 px
/// blue border with a soft glow while it has focus. The message for a problem
/// sits under it.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.icon,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.trailing,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final IconData icon;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final Widget? trailing;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(AuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final bool focused = widget.focusNode.hasFocus;
    final bool hasError = widget.errorText != null;
    final Color border = hasError
        ? authErrorColor
        : focused
        ? AppColors.primary
        : AppColors.secondary.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: AppFonts.body(
              size: 15,
              weight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: AppMotion.of(context, const Duration(milliseconds: 160)),
          decoration: BoxDecoration(
            color: widget.enabled
                ? c.input
                : c.isDark
                ? c.background
                : const Color(0xFFF3EFE8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: border,
              width: focused || hasError ? 2 : 1,
            ),
            boxShadow: focused && !hasError
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Semantics(
            label: widget.label,
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              enabled: widget.enabled,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              autocorrect: false,
              enableSuggestions: !widget.obscureText,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              scrollPadding: const EdgeInsets.only(bottom: 120),
              style: AppFonts.body(size: 17, color: c.textBody),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                filled: false,
                hintText: widget.hint,
                hintStyle: AppFonts.body(size: 17, color: c.textMuted),
                prefixIcon: Icon(widget.icon, size: 22, color: c.textPrimary),
                suffixIcon: widget.trailing,
                contentPadding: const EdgeInsets.symmetric(vertical: 17),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                widget.errorText!,
                style: AppFonts.body(
                  size: 14,
                  weight: FontWeight.w500,
                  color: authErrorColor,
                  height: 1.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The eye button at the end of a password field.
class PasswordToggle extends StatelessWidget {
  const PasswordToggle({
    super.key,
    required this.hidden,
    required this.onPressed,
  });

  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: hidden ? 'Show password' : 'Hide password',
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 22,
        color: context.mm.textPrimary,
      ),
    );
  }
}

/// Four segments and a word, under the new-password field.
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      container: true,
      liveRegion: true,
      label: strength.level == 0
          ? 'Password strength: not started'
          : 'Password strength: ${strength.label}',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          for (int i = 1; i <= 4; i += 1)
            Container(
              width: 30,
              height: 5,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i <= strength.level
                    ? c.textPrimary
                    : AppColors.secondary.withValues(alpha: 0.45),
              ),
            ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              AuthValidation.strengthLine(strength),
              textAlign: TextAlign.right,
              maxLines: 2,
              style: AppFonts.body(
                size: 13.5,
                weight: FontWeight.w600,
                color: c.textPrimary,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The peach card with the tick box for the self-support notice.
class ConsentCard extends StatelessWidget {
  const ConsentCard({
    super.key,
    required this.checked,
    required this.onChanged,
    this.enabled = true,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    void toggle() {
      if (enabled) {
        onChanged(!checked);
      }
    }

    return Semantics(
      container: true,
      checked: checked,
      enabled: enabled,
      label: disclaimerText,
      onTap: enabled ? toggle : null,
      excludeSemantics: true,
      child: Material(
        // Opaque in Dark so the navy-ish text keeps its contrast.
        color: AppColors.softSurface.withValues(
          alpha: context.mm.isDark ? 1 : 0.7,
        ),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? toggle : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(width: 2),
                _Box(checked: checked),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    disclaimerText,
                    style: AppFonts.body(
                      size: 15.5,
                      weight: FontWeight.w500,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.of(context, const Duration(milliseconds: 140)),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: checked ? AppColors.headerBlue : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked ? AppColors.headerBlue : AppColors.secondary,
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 18, color: AppColors.accent)
          : null,
    );
  }
}

/// "or", between two lines.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final Widget line = Expanded(
      child: Container(height: 1, color: context.mm.divider),
    );
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('or', style: AppFonts.label(size: 14)),
          ),
          line,
        ],
      ),
    );
  }
}

/// "Continue with Google", following Google's guidelines for the light
/// button: white, a thin grey outline, the four-colour G (the project's
/// `google icon.png`) and the words in Roboto.
class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  static const String asset = 'assets/images/google icon.png';

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;
    const BorderRadius radius = BorderRadius.all(Radius.circular(29));
    // Google's light and dark button colours.
    final bool dark = context.mm.isDark;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onPressed : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null && !isLoading ? 0.5 : 1,
        child: Material(
          color: dark ? const Color(0xFF131314) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: dark ? const Color(0xFF8E918F) : const Color(0xFF747775),
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 56,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.primary,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const _GoogleG(),
                          const SizedBox(width: 12),
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: dark
                                  ? const Color(0xFFE3E3E3)
                                  : const Color(0xFF1F1F1F),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The G from the (wide, padded) icon file, cropped to its own square.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: 22,
        height: 22,
        child: OverflowBox(
          maxWidth: 44,
          maxHeight: 22,
          child: Image(
            image: AssetImage(GoogleButton.asset),
            width: 44,
            height: 22,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// "New here? Create an account" and the like: a plain line and a link.
class AuthSwitchLine extends StatelessWidget {
  const AuthSwitchLine({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(prompt, style: AppFonts.body(size: 16)),
        const SizedBox(width: 6),
        MoodTextLink(label: action, onTap: onTap ?? () {}),
      ],
    );
  }
}

/// Asks someone signing in with Google for the first time to agree to the
/// self-support notice. Resolves to true only if they tick it and continue.
Future<bool> showGoogleConsentSheet(BuildContext context) async {
  final bool? agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => const _ConsentSheet(),
  );
  return agreed ?? false;
}

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet();

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.mm.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              'One thing before you start',
              style: AppFonts.body(
                size: 21,
                weight: FontWeight.w700,
                color: context.mm.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConsentCard(
            checked: _checked,
            onChanged: (bool value) => setState(() => _checked = value),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Continue',
            onPressed: _checked
                ? () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop(true);
                  }
                : null,
          ),
          Center(
            child: MoodTextLink(
              label: 'Cancel',
              onTap: () => Navigator.of(context).pop(false),
            ),
          ),
        ],
      ),
    );
  }
}
