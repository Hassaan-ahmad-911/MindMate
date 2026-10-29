# Notifications: check-in reminders

For the Notifications build. Users in a hospital wellbeing programme have
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

No questionnaire names (PHQ-9, GAD-7, ...), no scores, no ranges, never
"you seem low". One reminder per day at most for check-ins: if several are
due on the same day, use the combined line.

| Due | Reminder text |
|---|---|
| 3-day check (PHQ-4) | Your 3-day check is ready |
| Wellbeing (WHO-5) | A short wellbeing check is ready |
| Low mood and worry (PHQ-9 + GAD-7) | Two short check-ins are ready when you have a few minutes |
| Burnout and stress (CBI + PSS-10) | Your monthly check-in is ready |
| Only one of a pair | A short check-in is ready |
| More than one of the above on one day | You have {n} check-ins ready today |
| Mood (existing mood reminder) | How are you feeling today? |

Tapping a reminder opens Home, where "Today's check-ins" lists them with
"Start".

## Settings that apply

The same rules as the other reminders, from `users/{uid}.settings`
(`lib/Models/user_settings.dart`):

- **On or off:** the `checkinsDue` reminder slot. When it is off, no check-in
  reminders.
- **Days:** only on the chosen `days`.
- **Quiet hours:** never inside `quietHours`; a reminder that would land
  there is skipped (not moved into the night).
- **Hide reminder text** (`hideReminderText`): when on, every reminder shows
  only a neutral line such as "MindMate has a reminder for you", never the
  text above.
- Inexact alarms, merged with other reminders within 60 minutes, and a
  rolling 14-day plan, as designed for the Notifications module.
