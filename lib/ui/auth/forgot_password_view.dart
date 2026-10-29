import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/breathing_tick.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'forgot_password_viewmodel.dart';
import 'widgets/auth_widgets.dart';

/// Reset password: asks for an email and says the same thing whether or not
/// it has an account.
class ForgotPasswordView extends GetView<ForgotPasswordViewModel> {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool sent = controller.sent.value;

      return AuthPage(
        onBack: controller.back,
        showShape: false,
        topGap: 4,
        bottom: sent
            ? null
            : AuthSwitchLine(
                prompt: 'Remembered it?',
                action: 'Back to log in',
                onTap: controller.back,
              ),
        children: <Widget>[
          const Center(
            child: BreathingTick(
              size: 210,
              icon: Icons.key_rounded,
              semanticLabel: 'Reset password',
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Semantics(
              header: true,
              child: Text(
                'Reset password',
                textAlign: TextAlign.center,
                style: AppFonts.title(size: 42, height: 1.1),
              ),
            ),
          ),
          if (!sent) ...<Widget>[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Enter your email and we will send you a link to choose a new '
                'password.',
                textAlign: TextAlign.center,
                style: AppFonts.body(size: 16, height: 1.45),
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (sent) _sent() else _form(),
        ],
      );
    });
  }

  Widget _form() {
    final bool busy = controller.isLoading.value;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AuthTextField(
            label: 'Email',
            controller: controller.emailController,
            focusNode: controller.emailFocus,
            icon: Icons.mail_outline_rounded,
            hint: 'you@example.com',
            errorText: controller.emailError.value,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.email],
            onChanged: controller.onEmailChanged,
            onSubmitted: (_) => controller.send(),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Send reset link',
            isLoading: busy,
            onPressed: busy ? null : controller.send,
          ),
          const SizedBox(height: 16),
          const _NoteCard(
            text:
                'The email can take a few minutes. Check your spam folder too.',
          ),
        ],
      ),
    );
  }

  Widget _sent() {
    final bool busy = controller.isLoading.value;
    final int left = controller.secondsUntilResend.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          child: const _NoteCard(
            icon: Icons.mark_email_read_outlined,
            text: ForgotPasswordViewModel.confirmation,
          ),
        ),
        const SizedBox(height: 10),
        const _NoteCard(
          text: 'The email can take a few minutes. Check your spam folder too.',
        ),
        const SizedBox(height: 20),
        GradientButton(label: 'Back to log in', onPressed: controller.back),
        const SizedBox(height: 4),
        Center(
          child: Opacity(
            opacity: left > 0 ? 0.5 : 1,
            child: MoodTextLink(
              label: left > 0 ? 'Send again in ${left}s' : 'Send again',
              onTap: busy || left > 0 ? () {} : controller.send,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: context.mm.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppFonts.body(
                size: 15,
                weight: FontWeight.w500,
                color: context.mm.textBody,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
