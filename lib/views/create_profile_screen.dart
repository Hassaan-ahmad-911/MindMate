import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Models/user_profile.dart';
import '../ui/shared/mindmate_theme.dart';
import '../viewmodels/profile_viewmodel.dart';

/// The fill of fields, chips and the back button inside the profile card:
/// soft white on the peach card in Light, the input colour on the navy card
/// in Dark.
Color _fieldFill(MindMateColors c, double alpha) =>
    c.isDark ? c.input : Colors.white.withValues(alpha: alpha);

/// Thin outlines inside the profile card.
Color _outline(MindMateColors c, double alpha) =>
    c.surfaceBorder ?? AppColors.primary.withValues(alpha: alpha);

class CreateProfileScreen extends GetView<ProfileViewModel> {
  const CreateProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                c.background,
                AppColors.softSurface.withValues(alpha: 0.18),
                AppColors.primary.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: Obx(() {
            final UserProfile? currentProfile = controller.profile.value;
            final bool isEditMode = controller.isEditMode.value;
            final bool isCreating = currentProfile?.createdAt == null;
            final bool isLoading =
                controller.isLoading.value && currentProfile == null;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      // Peach in Light; a navy surface in Dark.
                      color: c.isDark ? c.surface : AppColors.softSurface,
                      borderRadius: BorderRadius.circular(28),
                      border: c.surfaceBorder == null
                          ? null
                          : Border.all(color: c.surfaceBorder!),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                          color: c.isDark
                              ? c.shadow
                              : AppColors.primary.withValues(alpha: 0.16),
                        ),
                      ],
                    ),
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _ProfileHeader(
                                onBack: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Get.back();
                                },
                                title: isEditMode
                                    ? (isCreating
                                          ? 'Create Profile'
                                          : 'Edit Profile')
                                    : 'Profile',
                                subtitle: isEditMode
                                    ? 'Update your account details and preferences.'
                                    : 'View and manage your account information.',
                              ),
                              const SizedBox(height: 22),
                              _ProfileAvatarSection(
                                profile: currentProfile,
                                selectedImageFile:
                                    controller.selectedImageFile.value,
                                isEditMode: isEditMode,
                                onTap: isEditMode ? controller.pickImage : null,
                              ),
                              const SizedBox(height: 22),
                              _SectionLabel(
                                label: 'Account Info',
                                hint: isEditMode
                                    ? 'Fill in the fields below'
                                    : 'Tap Edit Profile to make changes',
                              ),
                              const SizedBox(height: 12),
                              _ProfileTextField(
                                label: 'Name',
                                controller: controller.nameController,
                                readOnly: !isEditMode,
                                textCapitalization: TextCapitalization.words,
                                hintText: 'Enter your name',
                              ),
                              const SizedBox(height: 14),
                              _ReadOnlyField(
                                label: 'Email',
                                value: currentProfile?.email ?? '',
                              ),
                              const SizedBox(height: 14),
                              _ProfileTextField(
                                label: 'Bio',
                                controller: controller.bioController,
                                readOnly: !isEditMode,
                                hintText: 'Tell us a little about yourself',
                                maxLines: 4,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _ProfileTextField(
                                      label: 'Age',
                                      controller: controller.ageController,
                                      readOnly: !isEditMode,
                                      hintText: 'Age',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ReadOnlyField(
                                      label: 'Gender',
                                      value:
                                          controller.selectedGender.value ??
                                          'Select gender',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _GenderSelection(
                                controller: controller,
                                enabled: isEditMode,
                              ),
                              const SizedBox(height: 18),
                              if (isEditMode)
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: controller.isSaving.value
                                            ? null
                                            : controller.cancelEdit,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: c.textBody,
                                          side: BorderSide(
                                            color: c.accentText.withValues(
                                              alpha: 0.24,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Cancel Edit'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: controller.isSaving.value
                                            ? null
                                            : controller.updateProfile,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: AppColors
                                              .primary
                                              .withValues(alpha: 0.55),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                        ),
                                        child: controller.isSaving.value
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : Text(
                                                isCreating
                                                    ? 'Save Profile'
                                                    : 'Save Changes',
                                              ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: controller.isSaving.value
                                        ? null
                                        : controller.toggleEditMode,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: const Icon(Icons.edit_rounded),
                                    label: const Text('Edit Profile'),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.onBack,
    required this.title,
    required this.subtitle,
  });

  final VoidCallback onBack;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindMateColors c = context.mm;

    return Row(
      children: <Widget>[
        Material(
          color: _fieldFill(c, 0.78),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.arrow_back_rounded, color: c.textBody),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: c.textBody,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: c.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatarSection extends StatelessWidget {
  const _ProfileAvatarSection({
    required this.profile,
    required this.selectedImageFile,
    required this.isEditMode,
    required this.onTap,
  });

  final UserProfile? profile;
  final File? selectedImageFile;
  final bool isEditMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindMateColors c = context.mm;
    final String imageUrl = profile?.imageUrl.trim() ?? '';
    final bool hasNetworkImage =
        imageUrl.isNotEmpty && selectedImageFile == null;
    final String initials = profile?.initial ?? 'U';

    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: <Widget>[
              CircleAvatar(
                radius: 54,
                backgroundColor: c.background,
                backgroundImage: selectedImageFile != null
                    ? FileImage(selectedImageFile!)
                    : hasNetworkImage
                    ? NetworkImage(imageUrl)
                    : null,
                child: selectedImageFile == null && !hasNetworkImage
                    ? Text(
                        initials,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              if (isEditMode)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isEditMode ? 'Tap the avatar to change photo' : 'Profile photo',
          style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindMateColors c = context.mm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: c.textBody,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.label,
    required this.controller,
    required this.readOnly,
    required this.hintText,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final String hintText;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(color: c.textBody, height: 1.35),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: _fieldFill(c, readOnly ? 0.58 : 0.82),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _outline(c, 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c.selectedRing, width: 1.3),
        ),
        labelStyle: TextStyle(color: c.textMuted, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _fieldFill(c, 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline(c, 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.trim().isNotEmpty ? value : 'Not set',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: c.textBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderSelection extends StatelessWidget {
  const _GenderSelection({required this.controller, required this.enabled});

  final ProfileViewModel controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindMateColors c = context.mm;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ProfileViewModel.genderOptions
          .map((String gender) {
            return Obx(() {
              final bool selected = controller.selectedGender.value == gender;
              return ChoiceChip(
                label: Text(gender),
                selected: selected,
                onSelected: enabled
                    ? (_) => controller.selectGender(gender)
                    : null,
                selectedColor: AppColors.primary,
                backgroundColor: _fieldFill(c, 0.65),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : c.textBody,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected ? AppColors.primary : _outline(c, 0.12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            });
          })
          .toList(growable: false),
    );
  }
}
