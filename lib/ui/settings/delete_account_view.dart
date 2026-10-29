import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/mindmate_theme.dart';
import 'delete_account_viewmodel.dart';
import 'widgets/settings_widgets.dart';

/// "Delete your account?". No red: an outlined navy button.
class DeleteAccountView extends GetView<DeleteAccountViewModel> {
  const DeleteAccountView({super.key});

  static const List<String> _removed = <String>[
    'Profile and photo',
    'Mood entries',
    'Journal',
    'Check-in results',
    'Practices, breaks',
    'AI chat history',
  ];

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Obx(() {
      if (controller.isDeleting.value) {
        return Scaffold(
          backgroundColor: c.background,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  'Deleting your data…',
                  style: AppFonts.body(size: 17, color: c.textPrimary),
                ),
              ],
            ),
          ),
        );
      }
      return SettingsPage(
        title: 'Delete your account?',
        subtitle:
            'This cannot be undone. Everything below will be removed for '
            'good.',
        titleBelow: true,
        leadingIcon: Icons.close_rounded,
        bottom: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: controller.canDelete
                      ? controller.deleteAccount
                      : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: c.surface,
                    foregroundColor: c.textPrimary,
                    side: BorderSide(
                      color: controller.canDelete
                          ? c.textPrimary
                          : c.textPrimary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Delete my account',
                    style: AppFonts.body(
                      size: 17,
                      weight: FontWeight.w700,
                      color: controller.canDelete
                          ? c.textPrimary
                          : c.textPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              MoodTextLink(
                label: 'Keep my account',
                onTap: () => Get.back<void>(),
              ),
            ],
          ),
        ),
        children: <Widget>[
          AppCard(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Wrap(
              runSpacing: 8,
              children: <Widget>[
                for (final String item in _removed)
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.accentText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: AppFonts.body(size: 14.5, color: c.textBody),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            radius: 18,
            onTap: controller.isExporting.value
                ? null
                : controller.downloadMyData,
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: <Widget>[
                Icon(Icons.download_rounded, size: 20, color: c.accentText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppFonts.body(size: 14.5, color: c.textBody),
                      children: <InlineSpan>[
                        const TextSpan(text: 'Want a copy first? '),
                        TextSpan(
                          text: 'Download my data',
                          style: AppFonts.body(
                            size: 14.5,
                            weight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (controller.isExporting.value)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: c.textPrimary),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (controller.isGoogleOnly) ...<Widget>[
            Text(
              'Confirm with Google to continue',
              style: AppFonts.body(
                size: 14,
                weight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.googleConfirmed.value
                  ? null
                  : controller.confirmWithGoogle,
              icon: Icon(
                controller.googleConfirmed.value
                    ? Icons.check_rounded
                    : Icons.verified_user_outlined,
                color: c.textPrimary,
              ),
              label: Text(
                controller.googleConfirmed.value
                    ? 'Confirmed with Google'
                    : 'Confirm with Google',
                style: AppFonts.body(
                  size: 15,
                  weight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: c.surface,
                side: BorderSide(color: c.divider),
                shape: const StadiumBorder(),
              ),
            ),
          ] else ...<Widget>[
            Text(
              'Enter your password to confirm',
              style: AppFonts.body(
                size: 14,
                weight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.password,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.password],
              style: AppFonts.body(size: 16, color: c.textBody),
              decoration: const InputDecoration(hintText: 'Password'),
            ),
          ],
          if (controller.error.value != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              controller.error.value!,
              style: AppFonts.body(
                size: 14.5,
                weight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
        ],
      );
    });
  }
}
