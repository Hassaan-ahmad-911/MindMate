import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../Models/mood_catalog.dart';
import '../../Models/mood_model.dart';
import '../../Models/mood_stats.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/mindmate_theme.dart';
import 'mood_history_viewmodel.dart';
import 'widgets/mood_visuals.dart';
import 'widgets/mood_widgets.dart';

/// History: month calendar and every entry, grouped by day.
class MoodHistoryView extends GetView<MoodHistoryViewModel> {
  const MoodHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Scaffold(
      backgroundColor: c.background,
      body: BlendedBackground(
        child: SafeArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification.metrics.extentAfter < 400) {
                controller.loadMore();
              }
              return false;
            },
            child: RefreshIndicator(
              color: c.accentText,
              onRefresh: controller.refreshAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: <Widget>[
                  MoodPageHeader(
                    title: 'History',
                    onBack: Get.back,
                    trailing: Obx(
                      () => Badge(
                        isLabelVisible: controller.filter.value != null,
                        backgroundColor: AppColors.accent,
                        smallSize: 10,
                        child: CircleIconButton(
                          icon: Icons.filter_list_rounded,
                          tooltip: 'Filter',
                          onPressed: () => _showFilterSheet(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _MoodCalendar(),
                  const SizedBox(height: 22),
                  const _EntryList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final MindMateColors c = context.mm;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) {
        Widget option(String label, MoodGroup? group) {
          final bool selected = controller.filter.value == group;
          return ListTile(
            leading: group == null
                ? Icon(Icons.all_inclusive_rounded, color: c.accentText)
                : Icon(
                    Icons.circle,
                    size: 14,
                    color: MoodVisuals.dotColorFor(group),
                  ),
            title: Text(
              label,
              style: AppFonts.body(
                size: 16,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
            trailing: selected
                ? Icon(Icons.check_rounded, color: c.accentText)
                : null,
            onTap: () {
              controller.setFilter(group);
              Navigator.of(sheetContext).pop();
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Show entries',
                      style: AppFonts.body(
                        size: 18,
                        weight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
                option('All entries', null),
                for (final MoodGroup group in MoodGroup.values)
                  option(group.shortLabel, group),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MoodCalendar extends GetView<MoodHistoryViewModel> {
  const _MoodCalendar();

  static const List<String> _weekdayLetters = <String>[
    'M', 'T', 'W', 'T', 'F', 'S', 'S', //
  ];

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Obx(() {
        final DateTime month = controller.visibleMonth.value;
        final DateTime start = controller.gridStart;
        final int rows = controller.gridRows;
        final Map<DateTime, MoodGroup> groups = controller.calendarDayGroups;
        final DateTime? selected = controller.selectedDay.value;
        final DateTime now = DateTime.now();

        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: controller.previousMonth,
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: c.textPrimary,
                ),
                Expanded(
                  child: Text(
                    MoodFormat.monthYear(month),
                    textAlign: TextAlign.center,
                    style: AppFonts.body(
                      size: 18,
                      weight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.canGoToNextMonth
                      ? controller.nextMonth
                      : null,
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: c.textPrimary,
                  disabledColor: AppColors.secondary.withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: _weekdayLetters
                  .map(
                    (String letter) => Expanded(
                      child: Text(
                        letter,
                        textAlign: TextAlign.center,
                        style: AppFonts.label(size: 12),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 6),
            for (int row = 0; row < rows; row += 1)
              Row(
                children: List<Widget>.generate(7, (int column) {
                  final DateTime day = MoodStats.addDays(
                    start,
                    row * 7 + column,
                  );
                  return Expanded(
                    child: _CalendarDay(
                      day: day,
                      inMonth: day.month == month.month,
                      isToday: MoodStats.isSameDay(day, now),
                      isFuture: day.isAfter(now),
                      isSelected:
                          selected != null &&
                          MoodStats.isSameDay(selected, day),
                      group: groups[day],
                      onTap: () => controller.selectDay(day),
                    ),
                  );
                }),
              ),
            const SizedBox(height: 10),
            Divider(color: c.divider),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (final MoodGroup group in MoodGroup.values) ...<Widget>[
                  Icon(
                    Icons.circle,
                    size: 9,
                    color: MoodVisuals.dotColorFor(group),
                  ),
                  const SizedBox(width: 5),
                  Text(group.shortLabel, style: AppFonts.label(size: 13)),
                  if (group != MoodGroup.hard) const SizedBox(width: 16),
                ],
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isFuture,
    required this.isSelected,
    required this.group,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isFuture;
  final bool isSelected;
  final MoodGroup? group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final Color textColor = isToday
        ? Colors.white
        : (inMonth && !isFuture)
        ? c.textPrimary
        : AppColors.secondary;

    return Semantics(
      button: !isFuture,
      selected: isSelected,
      label:
          '${MoodFormat.longDate(day)}'
          '${group == null ? '' : ', ${group!.shortLabel}'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: isFuture ? null : onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isToday ? c.blueBlend : null,
                  border: Border.all(
                    color: isSelected && !isToday
                        ? c.selectedRing
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  '${day.day}',
                  style: AppFonts.body(
                    size: 15,
                    weight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: group == null
                      ? Colors.transparent
                      : MoodVisuals.dotColorFor(group!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryList extends GetView<MoodHistoryViewModel> {
  const _EntryList();

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Obx(() {
      final DateTime now = DateTime.now();
      final DateTime? selectedDay = controller.selectedDay.value;
      final List<MoodDayEntries> groups = controller.groupedEntries;
      final MoodGroup? filter = controller.filter.value;

      final List<Widget> children = <Widget>[];

      if (selectedDay != null || filter != null) {
        children.add(
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  <String>[
                    if (selectedDay != null)
                      MoodFormat.dayHeader(selectedDay, now: now),
                    if (filter != null) '${filter.shortLabel} entries',
                  ].join(' · '),
                  style: AppFonts.label(size: 14, color: c.textBody),
                ),
              ),
              MoodTextLink(
                label: 'Show all',
                onTap: () {
                  controller.clearSelectedDay();
                  controller.setFilter(null);
                },
              ),
            ],
          ),
        );
      }

      if (controller.isLoading.value && controller.entries.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: c.accentText),
            ),
          ),
        );
      } else if (controller.hasLoadError.value && controller.entries.isEmpty) {
        children.add(
          MoodMessageCard(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load your history',
            message: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: controller.refreshAll,
          ),
        );
      } else if (groups.isEmpty) {
        children.add(
          MoodMessageCard(
            icon: Icons.event_note_rounded,
            title: selectedDay != null
                ? 'Nothing logged this day'
                : 'No entries to show',
            message: selectedDay != null || filter != null
                ? 'Try another day or show all entries.'
                : 'Your mood entries will appear here.',
          ),
        );
      }

      for (final MoodDayEntries group in groups) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Text(
              MoodFormat.dayHeader(group.day, now: now),
              style: AppFonts.body(
                size: 15,
                weight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
        );
        for (final MoodModel entry in group.entries) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MoodEntryCard(
                entry: entry,
                timeLabel: MoodFormat.time(entry.date),
                showNote: true,
                onTap: () => _showEntrySheet(context, entry),
              ),
            ),
          );
        }
      }

      if (selectedDay == null && controller.isLoadingMore.value) {
        children.add(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: c.accentText),
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    });
  }

  void _showEntrySheet(BuildContext context, MoodModel entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.mm.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) =>
          _EntrySheet(entry: entry, controller: controller),
    );
  }
}

/// Read the note, edit it, or delete the entry.
class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.entry, required this.controller});

  final MoodModel entry;
  final MoodHistoryViewModel controller;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late final TextEditingController _noteController = TextEditingController(
    text: widget.entry.note,
  );
  bool _editing = false;
  bool _busy = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    setState(() => _busy = true);
    final bool saved = await widget.controller.updateNote(
      widget.entry,
      _noteController.text,
    );
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: dialogContext.mm.background,
        title: Text(
          'Delete this entry?',
          style: AppFonts.body(
            size: 19,
            weight: FontWeight.w600,
            color: dialogContext.mm.textPrimary,
          ),
        ),
        content: Text(
          'This mood entry and its note will be removed. '
          'This cannot be undone.',
          style: AppFonts.body(size: 15),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _busy = true);
    final bool deleted = await widget.controller.deleteEntry(widget.entry);
    if (!mounted) {
      return;
    }
    if (deleted) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final MoodModel entry = widget.entry;
    final String note = entry.note.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  MoodAvatar(mood: entry.mood, group: entry.group, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.mood,
                          style: AppFonts.body(
                            size: 20,
                            weight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          '${MoodFormat.longDate(entry.date)} · '
                          '${MoodFormat.time(entry.date)}',
                          style: AppFonts.label(),
                        ),
                        Text(entry.detailLabel, style: AppFonts.label()),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _editing
                    ? TextField(
                        controller: _noteController,
                        autofocus: true,
                        minLines: 4,
                        maxLines: 10,
                        maxLength: MoodCatalog.noteMaxLength,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        textCapitalization: TextCapitalization.sentences,
                        style: AppFonts.body(size: 16, color: c.textBody),
                        decoration: InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Write a note',
                          hintStyle: AppFonts.body(
                            size: 16,
                            color: c.textMuted,
                          ),
                        ),
                      )
                    : Text(
                        note.isEmpty ? 'No note added.' : note,
                        style: AppFonts.body(
                          size: 16,
                          color: note.isEmpty ? c.textMuted : c.textBody,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              if (_editing)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _editing = false;
                                _noteController.text = entry.note;
                              }),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _saveNote,
                        child: const Text('Save note'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _editing = true),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(note.isEmpty ? 'Add note' : 'Edit note'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _confirmDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
