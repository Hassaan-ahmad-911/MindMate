import 'package:flutter/material.dart';

import '../../../Models/programme_schedule.dart';
import '../../shared/app_card.dart';
import '../../shared/mindmate_theme.dart';

/// The white card under the check-ins card (hospital staff): Mood and every
/// check-in due today, each with "Done" or "Start".
class TodayCheckInsCard extends StatelessWidget {
  const TodayCheckInsCard({
    super.key,
    required this.rows,
    required this.subtitle,
    required this.onStart,
  });

  final List<ScheduleRow> rows;
  final String Function(ScheduleRow row) subtitle;
  final void Function(ScheduleRow row) onStart;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i += 1) ...<Widget>[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: c.divider,
              ),
            _Row(
              row: rows[i],
              subtitle: subtitle(rows[i]),
              onStart: () => onStart(rows[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.subtitle,
    required this.onStart,
  });

  final ScheduleRow row;
  final String subtitle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: row.isMood ? AppBlends.gold : AppBlends.blue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              row.isMood
                  ? Icons.sentiment_satisfied_rounded
                  : Icons.assignment_outlined,
              color: row.isMood ? AppColors.headerBlue : AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.label,
                  style: AppFonts.body(
                    size: 16.5,
                    weight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.25,
                  ),
                ),
                Text(subtitle, style: AppFonts.label(size: 13.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (row.done)
            Semantics(
              label: '${row.label} done',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
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
            )
          else
            Semantics(
              button: true,
              label: 'Start ${row.label}',
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
                    onTap: onStart,
                    child: ConstrainedBox(
                      // At least 44 px to tap.
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: 72,
                      ),
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
            ),
        ],
      ),
    );
  }
}
