import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../mood_tracking/widgets/mood_widgets.dart';
import '../programme/widgets/programme_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'reminder_permission_viewmodel.dart';

/// "Gentle reminders": after "All set" for new users, once over Home for
/// existing ones.
class ReminderPermissionView extends GetView<ReminderPermissionViewModel> {
  const ReminderPermissionView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return PopScope(
      canPop: controller.fromHome,
      child: Scaffold(
        backgroundColor: c.background,
        body: Stack(
          children: <Widget>[
            const Positioned.fill(child: BlendedBackground()),
            if (!c.isDark) ...const <Widget>[
              Positioned(
                right: -120,
                top: -150,
                child: BlobShape(size: 280, gradient: AppBlends.blueShape),
              ),
              Positioned(
                left: -110,
                top: 330,
                child: BlobShape(size: 200, gradient: AppBlends.gold),
              ),
            ],
            SafeArea(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                      children: <Widget>[
                        const Center(child: _BellRings()),
                        const SizedBox(height: 26),
                        Semantics(
                          header: true,
                          child: Text(
                            'Gentle reminders',
                            textAlign: TextAlign.center,
                            style: AppFonts.title(size: 38),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A small nudge at the times you chose, so check-ins '
                          'fit around your shifts.',
                          textAlign: TextAlign.center,
                          style: AppFonts.body(size: 16, color: c.textBody),
                        ),
                        const SizedBox(height: 22),
                        const AppCard(
                          padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Column(
                            children: <Widget>[
                              InfoLine(
                                icon: Icons.schedule_rounded,
                                tone: InfoTone.gold,
                                text:
                                    'Only at your chosen times, never in '
                                    'quiet hours',
                              ),
                              InfoLine(
                                icon: Icons.check_rounded,
                                text: 'Skipped when you have already done it',
                              ),
                              InfoLine(
                                icon: Icons.shield_outlined,
                                tone: InfoTone.navy,
                                text: 'Never shows your moods or answers',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Column(
                      children: <Widget>[
                        Obx(
                          () => GradientButton(
                            label: 'Turn on reminders',
                            icon: Icons.notifications_none_rounded,
                            isLoading: controller.isAsking.value,
                            onPressed: controller.turnOn,
                          ),
                        ),
                        MoodTextLink(
                          label: 'Not now',
                          onTap: controller.notNow,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bell in a blue-blend circle inside two soft rings.
class _BellRings extends StatelessWidget {
  const _BellRings();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 180,
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.secondary.withValues(alpha: 0.18),
        ),
        child: Container(
          width: 130,
          height: 130,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondary.withValues(alpha: 0.28),
          ),
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppBlends.blue,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.accent,
              size: 38,
            ),
          ),
        ),
      ),
    );
  }
}
