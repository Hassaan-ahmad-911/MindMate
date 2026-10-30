# Notifications: check-in reminders

Built in the Notifications module (`lib/ui/reminders/`). Users in a hospital wellbeing programme have
check-ins that fall due on a schedule; the Notifications module turns those
due dates into gentle local reminders. Nothing here is sent to a server and
nothing is written to Firestore.

## What to read

All dates are local calendar days.

- **The schedule:** `ProgrammeSchedule` in `lib/Models/programme_schedule.dart`.
  - `ProgrammeSchedule.today(...)`: today's rows (Mood plus every check-in due
    today or overdue, pairs merged), each with `done`.
  - `ProgrammeSchedule.overview(...)`: every required check-in with its
    `nextDue` day. Use this to plan reminders for the coming days.
  - `ProgrammeSchedule.dueDay(...)`: the next due day of one check-in, if a
    plan needs it per check-in.
- **Their inputs:** `WellbeingProgrammeController.loadStatus()` returns a
  `ProgrammeStatus` (membership with `joinedAt`, the `ProgrammeConfig` from
  `assessments_content.json`, and `lastDone` per check-in). The last mood
  date comes from `MoodRepository`.
- **Only for users in a hospital.** `loadStatus()` returns null for everyone
  else: they get no check-in reminders (their mood reminder is unchanged).
- **Re-plan after every save** (mood, check-in, journal) and on app open, as
  a check-in taken early moves its own next date.
- **Skip if already done:** a row with `done == true` today needs no reminder.
- The optional workplace questionnaire never gets a reminder.

## What each reminder says

Built in `lib/Models/reminder_plan.dart` (`ReminderPlanner`, `ReminderWording`),
tested in `test/reminder_planner_test.dart`. No questionnaire names, scores or
health words; no "!".

| Due | Title | Body |
|---|---|---|
| Programme: 3-day check only | Your 3-day check is ready | 4 questions, about 30 seconds. |
| Programme: wellbeing check only | A short wellbeing check is ready | 5 questions, about a minute. |
| Programme: any other, or several | Your check-in is ready | A few minutes, whenever suits you. |
| Not in a programme | A short check-in is ready | A few minutes, whenever suits you. |

Programme reminders come on the due day and once more the next day;
outside a programme, on the retake day and once more 7 days later. Several on
one day are one reminder, at the mood time (19:00 when the mood reminder is
off). The single 3-day or wellbeing check opens that check-in; the rest open
the Today page (programme) or the check-ins hub.

## Settings that apply

The same rules as the other reminders, from `users/{uid}.settings`
(`lib/Models/user_settings.dart`):

- **On or off:** the `checkinsDue` reminder slot. When it is off, no check-in
  reminders.
- **Days:** only on the chosen `days`.
- **Quiet hours:** never inside `quietHours`; a reminder that would land
  there is skipped (not moved into the night).
- **Hide reminder text** (`hideReminderText`): when on, every reminder shows
  "MindMate" and "You have a gentle reminder.", never the
  text above.
- Inexact alarms, merged with other reminders less than 60 minutes apart,
  and a rolling 14-day plan of at most 60 reminders.
