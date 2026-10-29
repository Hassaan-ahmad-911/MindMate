import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../Models/profile_options.dart';
import '../../Models/profile_validation.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'edit_profile_viewmodel.dart';
import 'widgets/settings_widgets.dart';

/// Edit profile.
class EditProfileView extends GetView<EditProfileViewModel> {
  const EditProfileView({super.key});

  Future<void> _leave(BuildContext context) async {
    if (!controller.hasChanges) {
      Get.back<void>();
      return;
    }
    final MindMateColors c = context.mm;
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(
          'Discard changes?',
          style: AppFonts.body(
            size: 19,
            weight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text('Keep editing', style: TextStyle(color: c.accentText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text('Discard', style: TextStyle(color: c.textPrimary)),
          ),
        ],
      ),
    );
    if (discard == true) {
      Get.back<void>();
    }
  }

  Future<void> _photoOptions(BuildContext context) async {
    final MindMateColors c = context.mm;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SettingsRow(
                icon: Icons.photo_camera_outlined,
                title: 'Take photo',
                chevron: false,
                onTap: () {
                  Navigator.of(s).pop();
                  controller.pickPhoto(ImageSource.camera);
                },
              ),
              SettingsRow(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                chevron: false,
                onTap: () {
                  Navigator.of(s).pop();
                  controller.pickPhoto(ImageSource.gallery);
                },
              ),
              if (controller.hasPhoto)
                SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  style: TileStyle.pale,
                  title: 'Remove photo',
                  chevron: false,
                  onTap: () {
                    Navigator.of(s).pop();
                    controller.clearPhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Obx(() {
      final bool canSave = controller.canSave;
      return PopScope(
        canPop: !controller.hasChanges,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (!didPop) {
            _leave(context);
          }
        },
        child: SettingsPage(
          title: 'Edit profile',
          onBack: () => _leave(context),
          bottom: controller.isLoading.value || controller.hasError.value
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: GradientButton(
                    label: 'Save changes',
                    icon: Icons.check_rounded,
                    isLoading: controller.isSaving.value,
                    onPressed: canSave
                        ? () async {
                            if (await controller.save()) {
                              Get.back<void>();
                            }
                          }
                        : null,
                  ),
                ),
          children: controller.isLoading.value
              ? const <Widget>[Center(child: CircularProgressIndicator())]
              : controller.hasError.value
              ? <Widget>[
                  Text(
                    'Your profile did not load.',
                    style: AppFonts.body(color: c.textBody),
                  ),
                  TextButton(
                    onPressed: controller.load,
                    child: const Text('Try again'),
                  ),
                ]
              : _form(context, c),
        ),
      );
    });
  }

  List<Widget> _form(BuildContext context, MindMateColors c) {
    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 0, 8),
      child: Text(
        text,
        style: AppFonts.body(
          size: 14,
          weight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
    );

    Widget field(
      TextEditingController ctrl, {
      String? error,
      TextInputType? keyboard,
      int? maxLength,
    }) {
      return TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLength: maxLength,
        style: AppFonts.body(size: 16, color: c.textBody),
        decoration: InputDecoration(errorText: error, counterText: ''),
      );
    }

    return <Widget>[
      Center(
        child: _Photo(
          controller: controller,
          onTap: () => _photoOptions(context),
        ),
      ),
      label('Name'),
      field(
        controller.nameController,
        error: controller.nameController.text.isEmpty
            ? null
            : controller.nameError,
        maxLength: ProfileValidation.maxNameLength,
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                label('Age'),
                field(
                  controller.ageController,
                  error: controller.ageError,
                  keyboard: TextInputType.number,
                  maxLength: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                label('Gender'),
                DropdownButtonFormField<String>(
                  initialValue:
                      ProfileOptions.setupGenders.contains(
                        controller.gender.value,
                      )
                      ? controller.gender.value
                      : null,
                  isExpanded: true,
                  dropdownColor: c.surface,
                  style: AppFonts.body(size: 16, color: c.textBody),
                  items: <DropdownMenuItem<String>>[
                    for (final String g in ProfileOptions.setupGenders)
                      DropdownMenuItem<String>(value: g, child: Text(g)),
                  ],
                  onChanged: (String? v) {
                    if (v != null) {
                      controller.setGender(v);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      label('Role'),
      _Chips(
        options: <MapEntry<String, String>>[
          for (final String r in ProfileOptions.roles)
            MapEntry<String, String>(r, r),
        ],
        selected: controller.role.value,
        onTap: controller.setRole,
      ),
      label('Shifts'),
      _Chips(
        options: <MapEntry<String, String>>[
          for (final ProfileOption s in ProfileOptions.shifts)
            MapEntry<String, String>(s.key, s.label),
        ],
        selected: controller.shift.value,
        onTap: controller.setShift,
      ),
      label('Department (optional)'),
      field(controller.departmentController, maxLength: 60),
    ];
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.controller, required this.onTap});

  final EditProfileViewModel controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name = controller.nameController.text;
    final ImageProvider? image = controller.newPhoto.value != null
        ? FileImage(controller.newPhoto.value!)
        : (controller.hasPhoto
              ? NetworkImage(controller.original.value!.imageUrl)
              : null);
    return Semantics(
      button: true,
      label: 'Change photo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 112,
          height: 112,
          child: Stack(
            children: <Widget>[
              if (image == null)
                ProfileAvatar(name: name, imageUrl: '', size: 104)
              else
                Container(
                  width: 104,
                  height: 104,
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: CircleAvatar(backgroundImage: image),
                ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: context.mm.blueBlend,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    size: 18,
                    color: Colors.white,
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

class _Chips extends StatelessWidget {
  const _Chips({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  /// Stored value -> label.
  final List<MapEntry<String, String>> options;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final MapEntry<String, String> o in options)
          Semantics(
            button: true,
            selected: o.key == selected,
            label: o.value,
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: o.key == selected ? c.blueBlend : null,
                  color: o.key == selected ? null : c.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: o.key == selected || c.surfaceBorder == null
                      ? null
                      : Border.all(color: c.surfaceBorder!),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onTap(o.key),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    child: Text(
                      o.value,
                      style: AppFonts.body(
                        size: 14.5,
                        weight: FontWeight.w600,
                        color: o.key == selected ? Colors.white : c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
