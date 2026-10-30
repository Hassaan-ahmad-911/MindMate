import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/today_items.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/mindmate_theme.dart';
import 'today_viewmodel.dart';

/// "Today": ready now, later today and done.
class TodayView extends GetView<TodayViewModel> {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Scaffold(
      backgroundColor: c.background,
      body: BlendedBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Obx(() {
                  final TodaySections s = controller.sections;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleIconButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'Back',
                            onPressed: () => Get.back<void>(),
                          ),
                          const SizedBox(width: 14),
                          Semantics(
                            header: true,
                            child: Text(
                              'Today',
                              style: AppFonts.title(size: 40),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.dateLine,
                        style: AppFonts.body(size: 16, color: c.textBody),
                      ),
                      if (controller.isLoading.value &&
                          s.ready.isEmpty &&
                          s.later.isEmpty &&
                          s.done.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...<Widget>[
                        if (s.nothingWaiting) ...<Widget>[
                          const SizedBox(height: 20),
                          MoodMessageCard(
                            icon: Icons.spa_outlined,
                            title: 'Nothing waiting right now.',
                            message: 'Take a breath.',
                            actionLabel: 'Open the meditation library',
                            onAction: controller.openMeditation,
                          ),
                        ],
                        if (s.ready.isNotEmpty)
                          _Section(
                            label: 'Ready now',
                            items: s.ready,
                            trailing: (TodayItem item) => _StartButton(
                              label: item.title,
                              onTap: () => controller.start(item),
                            ),
                          ),
                        if (s.later.isNotEmpty)
                          _Section(
                            label: 'Later today',
                            items: s.later,
                            trailing: (TodayItem item) => Text(
                              item.time ?? '',
                              style: AppFonts.body(
                                size: 15.5,
                                weight: FontWeight.w700,
                                color: c.accentText,
                              ),
                            ),
                          ),
                        if (s.done.isNotEmpty)
                          _Section(
                            label: 'Done',
                            items: s.done,
                            trailing: (TodayItem item) =>
                                _DonePill(label: item.title),
                          ),
                      ],
                    ],
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Center(
                  child: TextButton.icon(
                    onPressed: controller.openReminders,
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      size: 18,
                      color: c.textBody,
                    ),
                    label: Text(
                      'Change times in Settings · Reminders',
                      style: AppFonts.body(size: 14.5, color: c.textBody),
                    ),
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

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.items,
    required this.trailing,
  });

  final String label;
  final List<TodayItem> items;
  final Widget Function(TodayItem item) trailing;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 0, 8),
          child: MoodSectionLabel(label),
        ),
        AppCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < items.length; i += 1) ...<Widget>[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: c.divider,
                  ),
                _Row(item: items[i], trailing: trailing(items[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.trailing});

  final TodayItem item;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final (
      IconData icon,
      Gradient gradient,
      Color iconColor,
    ) = switch (item.kind) {
      TodayKind.mood => (
        Icons.sentiment_satisfied_rounded,
        AppBlends.gold,
        AppColors.headerBlue,
      ),
      TodayKind.journal => (
        Icons.menu_book_outlined,
        AppBlends.lightBlue,
        AppColors.headerBlue,
      ),
      TodayKind.practice => (
        Icons.spa_outlined,
        AppBlends.lightBlue,
        AppColors.headerBlue,
      ),
      TodayKind.checkIn => (
        Icons.assignment_outlined,
        AppBlends.blue,
        AppColors.accent,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: AppFonts.body(
                    size: 16.5,
                    weight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.25,
                  ),
                ),
                Text(item.line, style: AppFonts.label(size: 13.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start $label',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppBlends.gold,
            borderRadius: BorderRadius.circular(22),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 72),
              child: Center(
                widthFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Start',
                    style: AppFonts.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: AppColors.headerBlue,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonePill extends StatelessWidget {
  const _DonePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label done',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: AppBlends.lightBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppColors.headerBlue,
            ),
            const SizedBox(width: 4),
            Text(
              'Done',
              style: AppFonts.body(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.headerBlue,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
