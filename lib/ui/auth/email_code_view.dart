import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../Models/email_code_rules.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'email_code_viewmodel.dart';
import 'widgets/auth_widgets.dart';

/// "Check your email" (new account) and "Confirm your email" (an existing
/// account): the six code boxes, the resend line, and the button.
class EmailCodeView extends GetView<EmailCodeViewModel> {
  const EmailCodeView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Obx(() {
      final bool busy = controller.isBusy;
      return AuthPage(
        onBack: controller.isNewAccount ? controller.back : null,
        shapeTop: -250,
        topGap: 28,
        footer: GradientButton(
          label: controller.buttonLabel,
          isLoading: controller.status.value == EmailCodeStatus.submitting,
          onPressed: controller.canSubmit ? controller.submit : null,
        ),
        children: <Widget>[
          const _EnvelopeTile(),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              controller.title,
              style: AppFonts.title(size: 40, height: 1.1),
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: 'We sent a 6-digit code to\n'),
                TextSpan(
                  text: controller.email,
                  style: AppFonts.body(
                    size: 16,
                    weight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
            style: AppFonts.body(size: 16, height: 1.45),
          ),
          const SizedBox(height: 26),
          CodeBoxes(
            controller: controller.codeController,
            focusNode: controller.codeFocus,
            shown: controller.shownCode,
            rejected: controller.isRejected,
            enabled: controller.status.value != EmailCodeStatus.submitting,
            onChanged: controller.onCodeChanged,
          ),
          if (controller.message.value != null) ...<Widget>[
            const SizedBox(height: 12),
            _CodeMessage(text: controller.message.value!),
          ],
          if (controller.showNewCodePill.value) ...<Widget>[
            const SizedBox(height: 12),
            _NewCodePill(
              seconds: controller.resendSeconds.value,
              onPressed: busy ? null : controller.resend,
            ),
          ],
          const SizedBox(height: 14),
          _ResendRow(
            seconds: controller.resendSeconds.value,
            sending: controller.status.value == EmailCodeStatus.sending,
            onResend: busy ? null : controller.resend,
            isNewAccount: controller.isNewAccount,
            onChangeEmail: controller.back,
            onSignOut: controller.signOut,
          ),
          const SizedBox(height: 14),
          _InfoCard(minutes: controller.expiresMinutes.value),
          const SizedBox(height: 8),
        ],
      );
    });
  }
}

class _EnvelopeTile extends StatelessWidget {
  const _EnvelopeTile();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: context.mm.blueBlend,
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: context.mm.shadow,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          Icons.mark_email_unread_outlined,
          color: context.mm.onBlue,
          size: 30,
        ),
      ),
    );
  }
}

/// Six boxes drawn over one hidden number field, so typing, backspace,
/// pasting and the keyboard's code suggestion all work as one field.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.shown,
    required this.onChanged,
    this.rejected = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The digits in the boxes (a turned-down code stays visible).
  final String shown;
  final bool rejected;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
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
    final int active = widget.shown.length;

    return SizedBox(
      height: 62,
      child: Stack(
        children: <Widget>[
          ExcludeSemantics(
            child: Row(
              children: <Widget>[
                for (int i = 0; i < CodeInput.length; i += 1) ...<Widget>[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _Box(
                      digit: i < widget.shown.length ? widget.shown[i] : '',
                      border: widget.rejected
                          ? c.textPrimary
                          : focused && i == active
                          ? AppColors.primary
                          : AppColors.secondary.withValues(alpha: 0.55),
                      thick: widget.rejected || (focused && i == active),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // The real field: invisible, over the boxes, so a tap focuses it
          // and a long press offers Paste.
          Positioned.fill(
            child: Semantics(
              label: CodeInput.semanticsLabel(widget.shown.length),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: const <TextInputFormatter>[
                  CodeInputFormatter(),
                ],
                onChanged: widget.onChanged,
                showCursor: false,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.transparent, fontSize: 1),
                cursorColor: Colors.transparent,
                scrollPadding: const EdgeInsets.only(bottom: 200),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.border, required this.thick});

  final String digit;
  final Color border;
  final bool thick;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return AnimatedContainer(
      duration: AppMotion.of(context, const Duration(milliseconds: 140)),
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: thick ? 2 : 1),
      ),
      child: Text(
        digit,
        style: AppFonts.body(
          size: 26,
          weight: FontWeight.w600,
          color: c.textPrimary,
          height: 1,
        ),
      ),
    );
  }
}

/// Navy text with an info icon. Never red.
class _CodeMessage extends StatelessWidget {
  const _CodeMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.mm.textPrimary;
    return Semantics(
      liveRegion: true,
      container: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, size: 19, color: ink),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppFonts.body(
                size: 14.5,
                weight: FontWeight.w600,
                color: ink,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The white "Send a new code" pill shown after a code is turned down.
class _NewCodePill extends StatelessWidget {
  const _NewCodePill({required this.seconds, required this.onPressed});

  final int seconds;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final bool waiting = seconds > 0;
    final String label = waiting
        ? 'New code in ${ResendCountdown.format(seconds)}'
        : 'Send a new code';
    return Material(
      color: c.surface,
      shape: StadiumBorder(
        side: BorderSide(color: c.surfaceBorder ?? c.divider),
      ),
      shadowColor: c.shadow,
      elevation: 2,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: waiting ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.refresh_rounded, size: 19, color: c.textPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppFonts.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: waiting ? c.textMuted : c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Didn't get it? Resend in 0:42" (or the link) and "Change email" or
/// "Not you? Sign out".
class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.seconds,
    required this.sending,
    required this.onResend,
    required this.isNewAccount,
    required this.onChangeEmail,
    required this.onSignOut,
  });

  final int seconds;
  final bool sending;
  final VoidCallback? onResend;
  final bool isNewAccount;
  final VoidCallback onChangeEmail;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final TextStyle plain = AppFonts.body(size: 15);
    final Widget resend;
    if (sending) {
      resend = Text('Sending a code…', style: plain);
    } else if (seconds > 0) {
      resend = Semantics(
        label: 'Resend available in $seconds seconds',
        excludeSemantics: true,
        child: Text(
          "Didn't get it? Resend in ${ResendCountdown.format(seconds)}",
          style: plain,
        ),
      );
    } else {
      resend = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text("Didn't get it?", style: plain),
          MoodTextLink(label: 'Send a new code', onTap: onResend ?? () {}),
        ],
      );
    }

    final Widget other = isNewAccount
        ? MoodTextLink(label: 'Change email', onTap: onChangeEmail)
        : Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('Not you?', style: plain),
              MoodTextLink(label: 'Sign out', onTap: onSignOut),
            ],
          );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      spacing: 8,
      children: <Widget>[resend, other],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: c.isDark ? 0.16 : 0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.schedule_rounded, size: 20, color: c.accentText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The code works for $minutes minutes. Check your spam folder '
              "if you can't see it.",
              style: AppFonts.body(size: 14.5, color: c.textBody, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
