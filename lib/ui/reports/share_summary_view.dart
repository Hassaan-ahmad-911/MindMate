import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'share_summary_viewmodel.dart';

/// "Share a summary".
class ShareSummaryView extends GetView<ShareSummaryViewModel> {
  const ShareSummaryView({super.key});

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          const Positioned(
            right: -120,
            top: -150,
            child: BlobShape(size: 300, gradient: AppBlends.blueShape),
          ),
          SafeArea(
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      children: <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: CircleIconButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'Back',
                            onPressed: controller.back,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Semantics(
                          header: true,
                          child: Text(
                            'Share a summary',
                            style: AppFonts.title(size: 36),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Make a PDF to show a doctor or counsellor.',
                          style: AppFonts.body(size: 15.5),
                        ),
                        const SizedBox(height: 18),
                        const MoodSectionLabel('Period'),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            for (final int days in ShareSummaryViewModel.spans)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: _SpanChip(
                                    label: ShareSummaryViewModel.spanLabel(
                                      days,
                                    ),
                                    selected: controller.span.value == days,
                                    onTap: () => controller.span.value = days,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AppCard(
                          radius: 22,
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'What to include',
                                style: AppFonts.body(
                                  size: 17,
                                  weight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                              if (controller.hasMood)
                                _SwitchRow(
                                  title: 'Mood summary',
                                  line:
                                      'Days logged, good and hard days, common '
                                      'factors',
                                  value: controller.includeMood.value,
                                  onChanged: (bool v) =>
                                      controller.includeMood.value = v,
                                ),
                              if (controller.hasCheckIns)
                                _SwitchRow(
                                  title: 'Check-in results',
                                  line: 'Scores and ranges, with dates',
                                  value: controller.includeCheckIns.value,
                                  onChanged: (bool v) =>
                                      controller.includeCheckIns.value = v,
                                ),
                              if (controller.hasPractice)
                                _SwitchRow(
                                  title: 'Practice and activity',
                                  line:
                                      'Calm minutes, breaks, before and after',
                                  value: controller.includePractice.value,
                                  onChanged: (bool v) =>
                                      controller.includePractice.value = v,
                                ),
                              const _LockedRow(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _PageThumb(),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                '1 page · ${controller.rangeLabel}\n'
                                'MindMate does not send it anywhere. You '
                                'choose who to share it with.',
                                style: AppFonts.body(size: 14, height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: GradientButton(
                      label: 'Create PDF',
                      icon: Icons.ios_share_rounded,
                      isLoading: controller.isBuilding.value,
                      onPressed: controller.canCreate
                          ? controller.createPdf
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpanChip extends StatelessWidget {
  const _SpanChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? c.blueBlend : null,
            color: selected ? null : c.surface,
            borderRadius: BorderRadius.circular(22),
            border: selected || c.surfaceBorder == null
                ? null
                : Border.all(color: c.surfaceBorder!),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppFonts.body(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: selected ? Colors.white : c.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.line,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String line;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppFonts.body(
                      size: 15.5,
                      weight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(line, style: AppFonts.label(size: 12.5)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.accent,
              // A navy track would vanish on the navy card in Dark.
              activeTrackColor: c.isDark
                  ? AppColors.primary
                  : AppColors.headerBlue,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppColors.secondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow();

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Semantics(
      label: 'Journal. Never included. Your writing stays private.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Journal',
                    style: AppFonts.body(
                      size: 15.5,
                      weight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    'Never included. Your writing stays private.',
                    style: AppFonts.label(size: 12.5),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.25),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 17,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny picture of the PDF page. The PDF is always light, so the picture
/// keeps the light colours in both themes.
class _PageThumb extends StatelessWidget {
  const _PageThumb();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, Color c, {double h = 4}) => Container(
      width: w,
      height: h,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 72,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: context.mm.isDark
                  ? context.mm.shadow
                  : AppColors.headerBlue.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            bar(30, AppColors.headerBlue, h: 5),
            Container(
              height: 12,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                gradient: MindMateColors.light.blueBlendHorizontal,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            bar(36, AppColors.secondary),
            bar(28, AppColors.secondary),
            bar(34, AppColors.softSurface),
          ],
        ),
      ),
    );
  }
}
