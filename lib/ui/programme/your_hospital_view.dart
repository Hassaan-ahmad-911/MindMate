import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/hospital_programme.dart';
import '../../Models/programme_schedule.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../settings/widgets/settings_widgets.dart';
import '../shared/app_card.dart';
import '../shared/mindmate_theme.dart';
import 'widgets/programme_widgets.dart';
import 'your_hospital_viewmodel.dart';

/// "Your hospital" (Settings).
class YourHospitalView extends GetView<YourHospitalViewModel> {
  const YourHospitalView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Obx(() {
      final HospitalMembership? m = controller.membership.value;
      final bool loading = controller.isLoading.value;
      return SettingsPage(
        title: 'Your hospital',
        children: <Widget>[
          if (loading && m == null)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (m == null)
            MoodMessageCard(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your hospital',
              message: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: controller.load,
            )
          else ...<Widget>[
            HospitalCard(
              name: m.name.isEmpty ? 'Your hospital' : m.name,
              line: controller.joinedLine(m),
            ),
            if (m.officerName.isNotEmpty) ...<Widget>[
              const _Label('Your wellbeing officer'),
              AppCard(child: _Officer(membership: m)),
            ],
            if (controller.rows.isNotEmpty) ...<Widget>[
              const _Label('Required check-ins'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    for (
                      int i = 0;
                      i < controller.rows.length;
                      i += 1
                    ) ...<Widget>[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: c.divider,
                        ),
                      _ScheduleLine(
                        row: controller.rows[i],
                        due: ProgrammeSchedule.dueLabel(
                          controller.rows[i],
                          controller.now,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const _Label('What your hospital can see'),
            const AppCard(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: <Widget>[
                  InfoLine(
                    icon: Icons.check_rounded,
                    text:
                        'Only a request to reach out to you, when your '
                        'check-ins suggest you may need support.',
                  ),
                  InfoLine(
                    icon: Icons.close_rounded,
                    tone: InfoTone.navy,
                    text: 'Never your moods, scores, answers or journal.',
                  ),
                ],
              ),
            ),
            if (controller.alerts.isNotEmpty) ...<Widget>[
              const _Label('Past alerts'),
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: <Widget>[
                    for (final WellbeingAlert a in controller.alerts)
                      InfoLine(
                        icon: Icons.favorite_border_rounded,
                        tone: InfoTone.gold,
                        text: controller.alertLine(a),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'To leave the programme, speak to your hospital.',
              textAlign: TextAlign.center,
              style: AppFonts.label(size: 14),
            ),
          ],
        ],
      );
    });
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
      child: MoodSectionLabel(text),
    );
  }
}

class _Officer extends StatelessWidget {
  const _Officer({required this.membership});

  final HospitalMembership membership;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppBlends.lightBlue,
          ),
          child: Text(
            membership.officerInitials,
            style: AppFonts.body(
              size: 16,
              weight: FontWeight.w700,
              color: AppColors.headerBlue,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                membership.officerName,
                style: AppFonts.body(
                  size: 16.5,
                  weight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              if (membership.officerRole.isNotEmpty)
                Text(membership.officerRole, style: AppFonts.label(size: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleLine extends StatelessWidget {
  const _ScheduleLine({required this.row, required this.due});

  final ScheduleOverviewRow row;
  final String due;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final String every = ProgrammeSchedule.frequency(row.everyDays);
    return Semantics(
      label: '${row.label}. $every. $due',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    row.label,
                    style: AppFonts.body(
                      size: 16,
                      weight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(every, style: AppFonts.label(size: 13.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              due,
              style: AppFonts.body(
                size: 15,
                weight: FontWeight.w600,
                color: c.accentText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
