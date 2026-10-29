import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/gradient_button.dart';
import 'login_viewmodel.dart';
import 'widgets/auth_widgets.dart';

/// Log in: email, password, Google, and a way to Create account.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final LoginViewModel _vm = Get.find<LoginViewModel>();

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
      topGap: 72,
      bottom: AuthSwitchLine(
        prompt: 'New here?',
        action: 'Create an account',
        onTap: _vm.goToSignup,
      ),
      children: <Widget>[
        const AuthHeading(
          title: 'Welcome back',
          subtitle: 'Log in to pick up where you left off.',
        ),
        const SizedBox(height: 26),
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
              AutofillHints.username,
              AutofillHints.email,
            ],
            onChanged: _vm.onEmailChanged,
            onSubmitted: (_) => _vm.passwordFocus.requestFocus(),
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
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.password],
            onChanged: _vm.onPasswordChanged,
            onSubmitted: (_) => _vm.submit(),
            trailing: PasswordToggle(
              hidden: _vm.obscurePassword.value,
              onPressed: _vm.togglePasswordVisibility,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: MoodTextLink(
              label: 'Forgot password?',
              onTap: busy ? () {} : _vm.goToForgotPassword,
            ),
          ),
          const SizedBox(height: 4),
          GradientButton(
            label: 'Log in',
            isLoading: request == AuthRequest.email,
            onPressed: busy ? null : _vm.submit,
          ),
          const SizedBox(height: 18),
          const OrDivider(),
          const SizedBox(height: 18),
          GoogleButton(
            isLoading: request == AuthRequest.google,
            onPressed: busy ? null : _vm.loginWithGoogle,
          ),
        ],
      ),
    );
  }
}
