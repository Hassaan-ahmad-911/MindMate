import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shared/app_card.dart';
import '../shared/mindmate_theme.dart';
import 'settings_viewmodel.dart';
import 'widgets/settings_widgets.dart';

/// Privacy and data.
class PrivacyView extends GetView<SettingsViewModel> {
  const PrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Obx(
      () => SettingsPage(
        title: 'Privacy and data',
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              gradient: c.blueBlend,
              borderRadius: BorderRadius.circular(24),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: c.isDark ? c.shadow : const Color(0x401F3550),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppBlends.gold,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: AppColors.headerBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your moods, journal and check-ins are stored in your own '
                    'private account. Nobody else can see them, and MindMate '
                    'never sells or shares them.',
                    style: AppFonts.body(
                      size: 15,
                      color: c.onBlue,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (controller.hasSettings)
            SettingsGroup(
              label: 'On this phone',
              children: <Widget>[
                SettingsRow(
                  icon: Icons.visibility_off_outlined,
                  title: 'Hide reminder text',
                  line: 'Show "MindMate" only on the lock screen',
                  chevron: false,
                  trailing: Switch(
                    value: controller.settings.value?.hideReminderText ?? false,
                    onChanged: controller.settings.value == null
                        ? null
                        : controller.setHideReminderText,
                  ),
                ),
              ],
            ),
          SettingsGroup(
            label: 'Your data',
            children: <Widget>[
              SettingsRow(
                icon: Icons.download_rounded,
                style: TileStyle.gold,
                title: 'Download my data',
                line: 'Everything you saved, as one file',
                onTap: controller.isExporting.value
                    ? null
                    : controller.downloadMyData,
                trailing: controller.isExporting.value
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      )
                    : null,
              ),
              // AI chat history is not stored, so there is no "Clear AI chat
              // history" row.
              SettingsRow(
                icon: Icons.description_outlined,
                title: 'Privacy policy',
                onTap: () => controller.openInfo('Privacy policy'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SettingsGroup(
            label: 'Account',
            children: <Widget>[
              SettingsRow(
                icon: Icons.delete_outline_rounded,
                style: TileStyle.pale,
                title: 'Delete my account',
                line: 'Removes your account and all your data',
                onTap: controller.openDeleteAccount,
              ),
            ],
          ),
          if (controller.isExporting.value) ...<Widget>[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Making your file… It stays on this phone until you '
                'share it.',
                style: AppFonts.body(size: 14, color: c.textBody),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
