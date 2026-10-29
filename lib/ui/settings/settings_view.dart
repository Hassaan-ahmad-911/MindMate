import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/user_profile.dart';
import '../meditation/widgets/background_sound_sheet.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/mindmate_theme.dart';
import 'settings_viewmodel.dart';
import 'widgets/settings_widgets.dart';

/// Settings. The bottom-nav tab, and the pushed `/settings` route.
class SettingsView extends GetView<SettingsViewModel> {
  const SettingsView({super.key, this.showBack = false});

  /// True when opened as a page rather than the tab.
  final bool showBack;

  Future<void> _confirmSignOut(BuildContext context) async {
    final MindMateColors c = context.mm;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(
          'Sign out of MindMate?',
          style: AppFonts.body(
            size: 19,
            weight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text(
              'Cancel',
              style: AppFonts.body(
                size: 15,
                weight: FontWeight.w600,
                color: c.accentText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(
              'Sign out',
              style: AppFonts.body(
                size: 15,
                weight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    if (yes == true) {
      await controller.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    // Kept here so a rebuild while signing out does not look it up again
    // after it has been removed.
    final SettingsViewModel vm = controller;
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          if (!c.isDark)
            const Positioned(
              right: -120,
              top: -160,
              child: BlobShape(size: 300, gradient: AppBlends.blueShape),
            ),
          SafeArea(
            bottom: false,
            child: Obx(
              () => ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (showBack) ...<Widget>[
                        CircleIconButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Back',
                          onPressed: () => Get.back<void>(),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                            header: true,
                            child: Text(
                              'Settings',
                              style: AppFonts.title(
                                size: 40,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ProfileCard(controller: vm),
                  SettingsGroup(
                    label: 'Your app',
                    children: <Widget>[
                      if (vm.hasTheme)
                        SettingsRow(
                          icon: Icons.contrast_rounded,
                          style: TileStyle.blue,
                          title: 'Theme',
                          value: vm.themeLabel,
                          onTap: vm.openTheme,
                        ),
                      if (vm.hasSettings) ...<Widget>[
                        SettingsRow(
                          icon: Icons.notifications_none_rounded,
                          style: TileStyle.gold,
                          title: 'Reminders',
                          value: vm.remindersLabel,
                          onTap: vm.openReminders,
                        ),
                        SettingsRow(
                          icon: Icons.music_note_rounded,
                          style: TileStyle.lightBlue,
                          title: 'Meditation sound',
                          value: vm.sound.label,
                          onTap: () => showBackgroundSoundSheet(
                            context,
                            selected: () => vm.sound,
                            volume: () => vm.soundVolume,
                            onSelect: vm.selectSound,
                            onVolume: vm.previewVolume,
                            onVolumeEnd: vm.saveVolume,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SettingsGroup(
                    label: 'Privacy and data',
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.shield_outlined,
                        title: 'Privacy and data',
                        line: 'Download or delete your data',
                        onTap: vm.openPrivacy,
                      ),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Account',
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.mail_outline_rounded,
                        title: 'Email',
                        value: middleTruncate(vm.email),
                        chevron: false,
                      ),
                      if (vm.canChangePassword)
                        SettingsRow(
                          icon: Icons.key_rounded,
                          title: 'Change password',
                          onTap: vm.changePassword,
                        ),
                      SettingsRow(
                        icon: Icons.logout_rounded,
                        style: TileStyle.gold,
                        title: 'Sign out',
                        chevron: false,
                        onTap: vm.isLoggingOut.value
                            ? null
                            : () => _confirmSignOut(context),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Help',
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.support_outlined,
                        style: TileStyle.blue,
                        title: 'Support and helplines',
                        onTap: vm.openSupport,
                      ),
                      SettingsRow(
                        icon: Icons.help_outline_rounded,
                        title: 'Questions and answers',
                        onTap: () => vm.openInfo('Questions and answers'),
                      ),
                      SettingsRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Contact us',
                        onTap: () => vm.openInfo('Contact us'),
                      ),
                      SettingsRow(
                        icon: Icons.info_outline_rounded,
                        title: 'About MindMate',
                        value: 'Version ${vm.version}',
                        onTap: () => vm.openInfo('About MindMate'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.controller});

  final SettingsViewModel controller;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final UserProfile? p = controller.profile.value;
    final String name = p?.name ?? '';
    final String line = controller.profileLine;
    final BorderRadius radius = BorderRadius.circular(24);
    return Semantics(
      button: true,
      label: '$name. $line. Edit profile',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: c.blueBlend,
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.isDark ? c.shadow : const Color(0x401F3550),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: controller.openEditProfile,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: <Widget>[
                  ProfileAvatar(name: name, imageUrl: p?.imageUrl ?? ''),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name.isEmpty ? 'Your profile' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.body(
                            size: 19,
                            weight: FontWeight.w700,
                            color: c.onBlue,
                          ),
                        ),
                        if (line.isNotEmpty)
                          Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.body(
                              size: 14,
                              color: c.onBlueMuted,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          'Edit profile',
                          style: AppFonts.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: AppColors.softSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.onBlue),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
