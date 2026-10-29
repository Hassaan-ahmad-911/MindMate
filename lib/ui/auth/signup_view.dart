import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/gradient_button.dart';
import 'login_viewmodel.dart' show AuthRequest;
import 'signup_viewmodel.dart';
import 'widgets/auth_widgets.dart';

/// Create account: email, a new password, the notice, and Google.
class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  late final SignupViewModel _vm = Get.find<SignupViewModel>();

  @override
  void initState() {
    super.initState();
    _vm.askGoogleConsent = () => showGoogleConsentSheet(context);
  }

  @override
  void dispose() {
    _vm.askGoogleConsent = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      onBack: _vm.back,
      shapeTop: -225,
      topGap: 36,
      bottom: AuthSwitchLine(
        prompt: 'Already have an account?',
        action: 'Log in',
        onTap: _vm.goToLogin,
      ),
      children: <Widget>[
        const AuthHeading(
          title: 'Create account',
          subtitle: 'It takes less than a minute.',
        ),
        const SizedBox(height: 24),
        Obx(_form),
      ],
    );
  }

  Widget _form() {
    final bool busy = _vm.isLoading;
    final AuthRequest request = _vm.request.value;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AuthTextField(
            label: 'Email',
            controller: _vm.emailController,
            focusNode: _vm.emailFocus,
            icon: Icons.mail_outline_rounded,
            hint: 'you@example.com',
            errorText: _vm.emailError.value,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[
              AutofillHints.newUsername,
              AutofillHints.email,
            ],
            onChanged: _vm.onEmailChanged,
            onSubmitted: (_) => _vm.passwordFocus.requestFocus(),
          ),
          if (_vm.emailInUse.value)
            Align(
              alignment: Alignment.centerLeft,
              child: MoodTextLink(label: 'Log in', onTap: _vm.goToLogin),
            ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Password',
            controller: _vm.passwordController,
            focusNode: _vm.passwordFocus,
            icon: Icons.lock_outline_rounded,
            errorText: _vm.passwordError.value,
            obscureText: _vm.obscurePassword.value,
            enabled: !busy,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.newPassword],
            onChanged: _vm.onPasswordChanged,
            onSubmitted: (_) => _vm.confirmFocus.requestFocus(),
            trailing: PasswordToggle(
              hidden: _vm.obscurePassword.value,
              onPressed: _vm.togglePasswordVisibility,
            ),
          ),
          const SizedBox(height: 10),
          PasswordStrengthBar(strength: _vm.strength),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Confirm password',
            controller: _vm.confirmPasswordController,
            focusNode: _vm.confirmFocus,
            icon: Icons.lock_outline_rounded,
            hint: 'Type it again',
            errorText: _vm.confirmError.value,
            obscureText: _vm.obscureConfirmPassword.value,
            enabled: !busy,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.newPassword],
            onChanged: _vm.onConfirmChanged,
            onSubmitted: (_) => _vm.submit(),
            trailing: PasswordToggle(
              hidden: _vm.obscureConfirmPassword.value,
              onPressed: _vm.toggleConfirmPasswordVisibility,
            ),
          ),
          const SizedBox(height: 16),
          ConsentCard(
            checked: _vm.acceptedDisclaimer.value,
            enabled: !busy,
            onChanged: _vm.setDisclaimer,
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Create account',
            isLoading: request == AuthRequest.email,
            onPressed: _vm.canSubmit ? _vm.submit : null,
          ),
          const SizedBox(height: 12),
          GoogleButton(
            isLoading: request == AuthRequest.google,
            onPressed: busy ? null : _vm.signUpWithGoogle,
          ),
        ],
      ),
    );
  }
}
