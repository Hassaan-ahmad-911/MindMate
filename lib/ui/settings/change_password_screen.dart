import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shared/app_card.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'change_password_viewmodel.dart';
import 'widgets/settings_widgets.dart';

/// Change password (email accounts only). The logic is unchanged; the look
/// follows the theme.
class ChangePasswordScreen extends GetView<ChangePasswordViewModel> {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsPage(
        title: 'Change password',
        subtitle: 'Enter your current password, then choose a new one.',
        onBack: controller.isLoading.value
            ? () {}
            : () {
                FocusManager.instance.primaryFocus?.unfocus();
                Get.back<void>();
              },
        bottom: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: GradientButton(
            label: 'Update password',
            icon: Icons.check_rounded,
            isLoading: controller.isLoading.value,
            onPressed: controller.isLoading.value
                ? null
                : controller.updatePassword,
          ),
        ),
        children: <Widget>[
          AppCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _PasswordField(
                  label: 'Current password',
                  controller: controller.currentPasswordController,
                  obscureText: controller.obscureCurrentPassword.value,
                  onToggleVisibility:
                      controller.toggleCurrentPasswordVisibility,
                  errorText: controller.currentPasswordError.value,
                  onChanged: (_) => controller.clearCurrentPasswordError(),
                ),
                const SizedBox(height: 14),
                _PasswordField(
                  label: 'New password',
                  controller: controller.newPasswordController,
                  obscureText: controller.obscureNewPassword.value,
                  onToggleVisibility: controller.toggleNewPasswordVisibility,
                  errorText: controller.newPasswordError.value,
                  onChanged: (_) => controller.clearNewPasswordError(),
                ),
                const SizedBox(height: 14),
                _PasswordField(
                  label: 'Confirm new password',
                  controller: controller.confirmPasswordController,
                  obscureText: controller.obscureConfirmPassword.value,
                  onToggleVisibility:
                      controller.toggleConfirmPasswordVisibility,
                  errorText: controller.confirmPasswordError.value,
                  onChanged: (_) => controller.clearConfirmPasswordError(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscureText,
    required this.onToggleVisibility,
    required this.errorText,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final String errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppFonts.body(
            size: 14,
            weight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          style: AppFonts.body(size: 16, color: c.textBody),
          decoration: InputDecoration(
            fillColor: c.isDark ? c.input : AppColors.background,
            suffixIcon: IconButton(
              onPressed: onToggleVisibility,
              tooltip: obscureText ? 'Show password' : 'Hide password',
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: c.textMuted,
              ),
            ),
          ),
        ),
        if (errorText.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: AppFonts.body(
              size: 13.5,
              weight: FontWeight.w600,
              color: c.accentText,
            ),
          ),
        ],
      ],
    );
  }
}
