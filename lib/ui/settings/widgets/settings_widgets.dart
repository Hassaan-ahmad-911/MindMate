import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../mood_tracking/widgets/mood_widgets.dart';
import '../../shared/app_card.dart';
import '../../shared/blended_background.dart';
import '../../shared/blob_shape.dart';
import '../../shared/mindmate_theme.dart';

/// The look of a row's icon tile.
enum TileStyle { gold, lightBlue, blue, pale }

/// A 38 px rounded icon tile.
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile({
    super.key,
    required this.icon,
    this.style = TileStyle.lightBlue,
    this.size = 38,
  });

  final IconData icon;
  final TileStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final Gradient? gradient = switch (style) {
      TileStyle.gold => AppBlends.gold,
      TileStyle.lightBlue => AppBlends.lightBlue,
      TileStyle.blue => c.blueBlend,
      TileStyle.pale => null,
    };
    final Color iconColor = switch (style) {
      TileStyle.blue => AppColors.accent,
      TileStyle.pale => c.textPrimary,
      _ => AppColors.headerBlue,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? c.divider : null,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.5, color: iconColor),
    );
  }
}

/// A Lobster title page with a back button, the theme background and the
/// blob in the top-right corner.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.onBack,
    this.leadingIcon = Icons.chevron_left_rounded,
    this.bottom,
    this.titleBelow = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;
  final IconData leadingIcon;

  /// Pinned under the list, e.g. a main button.
  final Widget? bottom;

  /// The title on its own line under the button (Delete account, Theme).
  final bool titleBelow;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final Widget titleText = Semantics(
      header: true,
      child: Text(title, style: AppFonts.title(size: 36, color: c.textPrimary)),
    );
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          if (!c.isDark)
            const Positioned(
              right: -130,
              top: -170,
              child: BlobShape(size: 300, gradient: AppBlends.blueShape),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: <Widget>[
                      if (titleBelow) ...<Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: CircleIconButton(
                            icon: leadingIcon,
                            tooltip: leadingIcon == Icons.close_rounded
                                ? 'Close'
                                : 'Back',
                            onPressed: onBack ?? () => Get.back<void>(),
                          ),
                        ),
                        const SizedBox(height: 22),
                        titleText,
                      ] else
                        Row(
                          children: <Widget>[
                            CircleIconButton(
                              icon: leadingIcon,
                              tooltip: 'Back',
                              onPressed: onBack ?? () => Get.back<void>(),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: titleText),
                          ],
                        ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style: AppFonts.body(size: 15.5, color: c.textBody),
                        ),
                      ],
                      const SizedBox(height: 18),
                      ...children,
                    ],
                  ),
                ),
                ?bottom,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A section label and a card holding rows split by thin lines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.label, required this.children});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i += 1) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 64,
            endIndent: 16,
            color: context.mm.divider,
          ),
        );
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
            child: MoodSectionLabel(label!),
          ),
        AppCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// One row: icon tile, title (and an optional line), an optional value,
/// and a chevron or a custom trailing widget.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.style = TileStyle.lightBlue,
    this.line,
    this.value,
    this.onTap,
    this.trailing,
    this.chevron = true,
    this.below,
  });

  final IconData icon;
  final TileStyle style;
  final String title;
  final String? line;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool chevron;

  /// Shown under the title, e.g. a time pill.
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      button: onTap != null,
      label: <String>[title, ?line, ?value].join('. '),
      excludeSemantics: trailing == null && below == null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              crossAxisAlignment: below == null
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: <Widget>[
                SettingsIconTile(icon: icon, style: style),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppFonts.body(
                          size: 16,
                          weight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      if (line != null)
                        Text(
                          line!,
                          style: AppFonts.label(size: 13, color: c.textMuted),
                        ),
                      if (below != null) ...<Widget>[
                        const SizedBox(height: 8),
                        below!,
                      ],
                    ],
                  ),
                ),
                if (value != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppFonts.body(
                        size: 14,
                        weight: FontWeight.w600,
                        color: c.accentText,
                      ),
                    ),
                  ),
                ],
                ?trailing,
                if (trailing == null && chevron && onTap != null)
                  Icon(Icons.chevron_right_rounded, color: c.textPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A light-blue pill with a clock and a time; tapping it opens the picker.
class TimePill extends StatelessWidget {
  const TimePill({
    super.key,
    required this.time,
    required this.onTap,
    this.label,
  });

  final String time;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${label ?? 'Time'}: $time. Change',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppBlends.lightBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: AppColors.headerBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: AppFonts.body(
                        size: 15.5,
                        weight: FontWeight.w700,
                        color: AppColors.headerBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The profile photo, or initials on the gold blend, with a white ring.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    this.size = 58,
  });

  final String name;
  final String imageUrl;
  final double size;

  static String initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = imageUrl.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.05),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initials(),
              )
            : _initials(),
      ),
    );
  }

  Widget _initials() {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppBlends.gold),
      child: Center(
        child: Text(
          initials(name),
          style: AppFonts.body(
            size: size * 0.34,
            weight: FontWeight.w700,
            color: AppColors.headerBlue,
          ),
        ),
      ),
    );
  }
}

/// "ayesha.k@…", or the middle shortened for long addresses.
String middleTruncate(String text, {int max = 22}) {
  if (text.length <= max) {
    return text;
  }
  final int keep = max - 1;
  final int head = (keep / 2).ceil();
  return '${text.substring(0, head)}…${text.substring(text.length - (keep - head))}';
}
