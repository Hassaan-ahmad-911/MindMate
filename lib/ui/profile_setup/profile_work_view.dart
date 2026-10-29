import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/profile_options.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../shared/blended_background.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'widgets/setup_widgets.dart';

/// Profile setup, step 3 of 3: role, usual shifts, years in healthcare and an
/// optional department. "Continue" saves the profile.
class ProfileWorkView extends GetView<ProfileViewModel> {
  const ProfileWorkView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: BlendedBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SetupTopBar(step: 3, onBack: Get.back),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                  children: <Widget>[
                    const SetupTitle(
                      title: 'Your work',
                      subtitle: 'This helps MindMate fit around your shifts.',
                    ),
                    const SizedBox(height: 22),
                    const SetupLabel('Your role'),
                    const SizedBox(height: 10),
                    const _RoleChips(),
                    const SizedBox(height: 22),
                    const SetupLabel('Your usual shifts'),
                    const SizedBox(height: 10),
                    const _ShiftCards(),
                    const SizedBox(height: 22),
                    const SetupLabel('Years in healthcare'),
                    const SizedBox(height: 10),
                    const _YearsSwitch(),
                    const SizedBox(height: 22),
                    SetupTextField(
                      label: 'Department',
                      optional: true,
                      controller: controller.departmentController,
                      hint: 'For example Emergency',
                      textCapitalization: TextCapitalization.words,
                      maxLength: 60,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Obx(
                  () => GradientButton(
                    label: 'Continue',
                    isLoading: controller.isSaving.value,
                    onPressed: controller.canContinueFromWork
                        ? controller.finishSetup
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChips extends GetView<ProfileViewModel> {
  const _RoleChips();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String? selected = controller.selectedRole.value;
      return Wrap(
        spacing: 8,
        runSpacing: 10,
        children: ProfileOptions.roles
            .map(
              (String role) => SetupChip(
                label: role,
                selected: selected == role,
                onTap: () => controller.selectRole(role),
              ),
            )
            .toList(growable: false),
      );
    });
  }
}

class _ShiftCards extends GetView<ProfileViewModel> {
  const _ShiftCards();

  static const Map<String, IconData> _icons = <String, IconData>{
    'day': Icons.wb_sunny_outlined,
    'night': Icons.dark_mode_rounded,
    'rotating': Icons.autorenew_rounded,
    'on_call': Icons.notifications_none_rounded,
  };

  // Read on each build: the blue blend follows the theme.
  static Gradient _tile(String key) {
    switch (key) {
      case 'day':
        return AppBlends.gold;
      case 'night':
        return AppBlends.blue;
      default:
        return AppBlends.lightBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String? selected = controller.selectedShift.value;

      Widget card(ProfileOption option) {
        return Expanded(
          child: _ShiftCard(
            label: option.label,
            icon: _icons[option.key] ?? Icons.schedule_rounded,
            tile: _tile(option.key),
            selected: selected == option.key,
            onTap: () => controller.selectShift(option.key),
          ),
        );
      }

      const List<ProfileOption> shifts = ProfileOptions.shifts;
      return Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              card(shifts[0]),
              const SizedBox(width: 10),
              card(shifts[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              card(shifts[2]),
              const SizedBox(width: 10),
              card(shifts[3]),
            ],
          ),
        ],
      );
    });
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.label,
    required this.icon,
    required this.tile,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Gradient tile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final BorderRadius radius = BorderRadius.circular(18);
    final bool dark = tile == AppBlends.blue;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 160)),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected
                ? c.selectedRing
                : c.surfaceBorder ?? Colors.transparent,
            width: 2.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.shadow,
              blurRadius: 12,
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
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: tile,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: dark ? Colors.white : AppColors.headerBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(
                        size: 16,
                        weight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
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

/// A four-way switch: Under 2, 2 to 5, 6 to 10, Over 10.
class _YearsSwitch extends GetView<ProfileViewModel> {
  const _YearsSwitch();

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(26),
        border: c.surfaceBorder == null
            ? null
            : Border.all(color: c.surfaceBorder!),
      ),
      child: Obx(() {
        final String? selected = controller.selectedYears.value;
        return Row(
          children: ProfileOptions.years
              .map((ProfileOption option) {
                final bool isSelected = selected == option.key;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: option.label,
                    onTap: () => controller.selectYears(option.key),
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.selectYears(option.key),
                      child: AnimatedContainer(
                        duration: AppMotion.of(
                          context,
                          const Duration(milliseconds: 180),
                        ),
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppBlends.blue : null,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            option.label,
                            maxLines: 1,
                            style: AppFonts.body(
                              size: 15,
                              weight: FontWeight.w600,
                              color: isSelected ? Colors.white : c.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      }),
    );
  }
}
