import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/user_settings.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/mindmate_theme.dart';
import 'settings_viewmodel.dart';
import 'widgets/reminders_widgets.dart';
import 'widgets/settings_widgets.dart';

/// Reminders. Every change saves at once; the reminders are then planned
/// again on the phone. The top card shows the next reminder, or that the
/// phone blocks them.
class RemindersView extends StatefulWidget {
  const RemindersView({super.key});

  @override
  State<RemindersView> createState() => _RemindersViewState();
}

class _RemindersViewState extends State<RemindersView> {
  late final SettingsViewModel controller = Get.find<SettingsViewModel>();

  static const List<String> _letters = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];
  static const List<String> _dayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<String?> _pickTime(BuildContext context, String current) async {
    final int m = SettingsTime.minutes(current);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return picked == null
        ? null
        : SettingsTime.format(picked.hour, picked.minute);
  }

  @override
  void initState() {
    super.initState();
    // The phone's setting may have changed since last time.
    controller.refreshReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final UserSettings? s = controller.settings.value;
      return SettingsPage(
        title: 'Reminders',
        children: s == null
            ? <Widget>[
                controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : MoodMessageCard(
                        icon: Icons.cloud_off_rounded,
                        title: 'Your reminders did not load',
                        message: 'Check your connection and try again.',
                        actionLabel: 'Try again',
                        onAction: controller.load,
                      ),
              ]
            : _content(context, s.reminders),
      );
    });
  }

  List<Widget> _content(BuildContext context, ReminderSettings r) {
    final MindMateColors c = context.mm;
    Widget slot({
      required String kind,
      required IconData icon,
      required TileStyle style,
      required String title,
      required String line,
      required ReminderSlot value,
      bool hasTime = true,
    }) {
      final String? time = value.time;
      return SettingsRow(
        icon: icon,
        style: style,
        title: title,
        line: line,
        chevron: false,
        trailing: Switch(
          value: value.on,
          onChanged: (bool on) => controller.setReminderOn(kind, on),
        ),
        below: hasTime && value.on && time != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TimePill(
                    label: title,
                    time: time,
                    onTap: () async {
                      final String? t = await _pickTime(context, time);
                      if (t != null) {
                        await controller.setReminderTime(kind, t);
                      }
                    },
                  ),
                  if (r.quietHours.covers(time)) const QuietHoursNote(),
                ],
              )
            : null,
      );
    }

    final bool inProgramme = controller.hospital != null;
    final bool blocked = controller.remindersBlocked;
    final bool notAsked = controller.remindersNotAsked;
    final String? next = controller.nextReminderLine;
    return <Widget>[
      if (blocked || notAsked)
        RemindersOffCard(
          blocked: blocked,
          onAction: blocked
              ? controller.openPhoneSettings
              : controller.turnOnReminders,
        )
      else if (next != null)
        NextReminderCard(line: next),
      const SizedBox(height: 14),
      Opacity(
        // Still usable; the choices apply once the phone allows reminders.
        opacity: blocked ? 0.5 : 1,
        child: SettingsGroup(
          children: <Widget>[
            slot(
              kind: 'mood',
              icon: Icons.sentiment_satisfied_alt_outlined,
              style: TileStyle.gold,
              title: 'Mood check-in',
              line: inProgramme
                  ? 'Your hospital asks for one a day'
                  : 'A quick "How are you feeling?"',
              value: r.mood,
            ),
            slot(
              kind: 'journal',
              icon: Icons.menu_book_outlined,
              style: TileStyle.lightBlue,
              title: 'Journal prompt',
              line: "Tonight's writing prompt",
              value: r.journal,
            ),
            slot(
              kind: 'practice',
              icon: Icons.spa_outlined,
              style: TileStyle.lightBlue,
              title: 'Practice',
              line: 'A short calm practice',
              value: r.practice,
            ),
            slot(
              kind: 'checkinsDue',
              icon: Icons.shield_outlined,
              style: TileStyle.blue,
              title: 'Check-ins due',
              line: inProgramme
                  ? 'At your mood time when one is due'
                  : 'When a questionnaire is due again',
              value: r.checkinsDue,
              hasTime: false,
            ),
          ],
        ),
      ),
      if (r.quietHours.on)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
            'Quiet hours ${r.quietHours.start} to ${r.quietHours.end} · '
            'Days and quiet hours are further down.',
            style: AppFonts.label(size: 13.5, color: c.textBody),
          ),
        ),
      const SizedBox(height: 14),
      AppCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SettingsRow(
          icon: Icons.near_me_outlined,
          style: TileStyle.lightBlue,
          title: 'Send a test reminder',
          line: 'See how reminders will look',
          onTap: controller.sendTestReminder,
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 20, 0, 10),
        child: MoodSectionLabel('On these days'),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          for (int d = 1; d <= 7; d += 1)
            _DayButton(
              letter: _letters[d - 1],
              name: _dayNames[d - 1],
              selected: r.days.contains(d),
              onTap: () => controller.toggleDay(d),
            ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 20, 0, 10),
        child: MoodSectionLabel('Quiet hours'),
      ),
      AppCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SettingsRow(
          icon: Icons.bedtime_outlined,
          style: TileStyle.blue,
          title: 'No reminders while I sleep',
          line: 'Useful after night shifts',
          chevron: false,
          trailing: Switch(
            value: r.quietHours.on,
            onChanged: controller.setQuietHoursOn,
          ),
          below: r.quietHours.on
              ? Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    TimePill(
                      label: 'Quiet from',
                      time: r.quietHours.start,
                      onTap: () async {
                        final String? t = await _pickTime(
                          context,
                          r.quietHours.start,
                        );
                        if (t != null) {
                          await controller.setQuietHoursStart(t);
                        }
                      },
                    ),
                    Text('to', style: AppFonts.label(color: c.textMuted)),
                    TimePill(
                      label: 'Quiet until',
                      time: r.quietHours.end,
                      onTap: () async {
                        final String? t = await _pickTime(
                          context,
                          r.quietHours.end,
                        );
                        if (t != null) {
                          await controller.setQuietHoursEnd(t);
                        }
                      },
                    ),
                  ],
                )
              : null,
        ),
      ),
    ];
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.letter,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected ? c.blueBlend : null,
            color: selected ? null : c.surface,
            border: selected
                ? null
                : Border.all(color: c.surfaceBorder ?? c.divider),
          ),
          child: Text(
            letter,
            style: AppFonts.body(
              size: 15,
              weight: FontWeight.w700,
              color: selected ? Colors.white : c.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
