import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../Models/profile_options.dart';
import '../../Models/user_profile.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../shared/blended_background.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'widgets/setup_widgets.dart';

/// Profile setup, step 1 of 3: photo, name, age and gender.
class ProfileAboutView extends GetView<ProfileViewModel> {
  const ProfileAboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: BlendedBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: SetupTopBar(step: 1),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  children: <Widget>[
                    const SetupTitle(
                      title: 'About you',
                      subtitle: 'So MindMate knows what to call you.',
                    ),
                    const SizedBox(height: 24),
                    const _PhotoPicker(),
                    const SizedBox(height: 24),
                    SetupTextField(
                      label: 'Your name',
                      controller: controller.nameController,
                      hint: 'Your name',
                      textCapitalization: TextCapitalization.words,
                      maxLength: 60,
                    ),
                    const SizedBox(height: 18),
                    Obx(
                      () => SetupTextField(
                        label: 'Age',
                        controller: controller.ageController,
                        hint: 'For example 29',
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        errorText: controller.ageError,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SetupLabel('Gender'),
                    const SizedBox(height: 10),
                    const _GenderChips(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Obx(
                  () => GradientButton(
                    label: 'Continue',
                    onPressed: controller.canContinueFromAbout
                        ? controller.continueFromAbout
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

/// The round photo with a camera button. The photo is optional.
class _PhotoPicker extends GetView<ProfileViewModel> {
  const _PhotoPicker();

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Column(
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Add a photo',
          onTap: controller.pickImage,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: controller.pickImage,
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 150,
                    height: 150,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface.withValues(alpha: 0.7),
                    ),
                    child: ClipOval(child: Obx(() => _avatar())),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 6,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppBlends.gold,
                        border: Border.all(color: c.background, width: 3),
                      ),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        size: 20,
                        color: AppColors.headerBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('Photo is optional', style: AppFonts.label(size: 14)),
      ],
    );
  }

  Widget _avatar() {
    final file = controller.selectedImageFile.value;
    final UserProfile? profile = controller.profile.value;

    if (file != null) {
      return Image.file(file, fit: BoxFit.cover);
    }
    if (profile != null && profile.hasImage) {
      return Image.network(
        profile.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? trace) =>
            _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(gradient: AppBlends.lightBlue),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline_rounded,
        size: 64,
        color: AppColors.headerBlue,
      ),
    );
  }
}

class _GenderChips extends GetView<ProfileViewModel> {
  const _GenderChips();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String? selected = controller.selectedGender.value;
      return Wrap(
        spacing: 8,
        runSpacing: 10,
        children: ProfileOptions.setupGenders
            .map(
              (String gender) => SetupChip(
                label: gender,
                selected: selected == gender,
                onTap: () => controller.toggleSetupGender(gender),
              ),
            )
            .toList(growable: false),
      );
    });
  }
}
