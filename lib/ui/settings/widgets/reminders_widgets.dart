import 'package:flutter/material.dart';

import '../../shared/mindmate_theme.dart';

/// "NEXT REMINDER · Today 20:00 · Mood check-in": blue blend, gold bell.
class NextReminderCard extends StatelessWidget {
  const NextReminderCard({super.key, required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      container: true,
      label: 'Next reminder. $line',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppBlends.blue,
          borderRadius: BorderRadius.circular(22),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.isDark ? c.shadow : const Color(0x331F3550),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            const _Tile(
              icon: Icons.notifications_none_rounded,
              gradient: AppBlends.gold,
              color: AppColors.headerBlue,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'NEXT REMINDER',
                    style: AppFonts.label(
                      size: 12.5,
                      weight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.softSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: AppFonts.body(
                      size: 16.5,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
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

/// When the phone blocks MindMate's notifications ([blocked]), or MindMate
/// has not asked yet: a white card with a navy outline and a crossed-out
/// bell, and a gold button.
class RemindersOffCard extends StatelessWidget {
  const RemindersOffCard({
    super.key,
    required this.blocked,
    required this.onAction,
  });

  final bool blocked;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final String title = blocked
        ? 'Notifications are off'
        : 'Reminders are not turned on yet';
    final String text = blocked
        ? 'Your phone is blocking MindMate, so no reminders will arrive.'
        : 'Turn them on to get a gentle nudge at the times below.';
    final String action = blocked ? 'Open phone settings' : 'Turn on reminders';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: c.isDark ? AppColors.secondary : AppColors.headerBlue,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Tile(
                icon: Icons.notifications_off_outlined,
                color: c.textPrimary,
                background: c.input,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: AppFonts.body(
                          size: 17,
                          weight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(text, style: AppFonts.body(size: 14.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: action,
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppBlends.gold,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          blocked
                              ? Icons.settings_outlined
                              : Icons.notifications_none_rounded,
                          size: 19,
                          color: AppColors.headerBlue,
                        ),
                        const SizedBox(width: 8),
                        // Scales down on a narrow phone.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              action,
                              style: AppFonts.body(
                                size: 16,
                                weight: FontWeight.w700,
                                color: AppColors.headerBlue,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Under a reminder time that falls in quiet hours.
class QuietHoursNote extends StatelessWidget {
  const QuietHoursNote({super.key});

  static const String text = "In your quiet hours, so it won't be sent";

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, size: 16, color: c.accentText),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: AppFonts.label(
                size: 13.5,
                weight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    this.gradient,
    this.background,
  });

  final IconData icon;
  final Color color;
  final Gradient? gradient;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: gradient,
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
