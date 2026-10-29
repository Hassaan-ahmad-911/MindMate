import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/assessment_definition.dart';
import '../../Models/assessment_rules.dart';
import '../home/widgets/home_skeleton.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/mindmate_theme.dart';
import 'assessments_hub_viewmodel.dart';
import 'widgets/assessment_widgets.dart';

/// "Check-ins": every questionnaire with its latest range.
class AssessmentsHubView extends GetView<AssessmentsHubViewModel> {
  const AssessmentsHubView({super.key});

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
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => controller.load(quiet: true),
              child: Obx(
                () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleIconButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Back',
                          onPressed: controller.back,
                        ),
                        const Spacer(),
                        CircleIconButton(
                          icon: Icons.bar_chart_rounded,
                          tooltip: 'Over time',
                          onPressed: controller.openHistory,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      child: Text('Check-ins', style: AppFonts.title(size: 40)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Short questionnaires to notice how you are doing. '
                      'Not a diagnosis.',
                      style: AppFonts.body(size: 15.5),
                    ),
                    const SizedBox(height: 18),
                    ..._body(),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: c.textBody,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your answers are private. Results help you spot '
                            'changes over time.',
                            style: AppFonts.label(size: 13, color: c.textBody),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body() {
    final AssessmentContent? content = controller.content.value;
    if (controller.hasError.value && content == null) {
      return <Widget>[
        MoodMessageCard(
          icon: Icons.cloud_off_rounded,
          title: 'Check-ins did not load',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: controller.load,
        ),
      ];
    }
    if (controller.isLoading.value || content == null) {
      return const <Widget>[
        SkeletonBar(height: 110, radius: 24),
        SizedBox(height: 18),
        SkeletonBar(height: 72, radius: 20),
        SizedBox(height: 10),
        SkeletonBar(height: 72, radius: 20),
        SizedBox(height: 10),
        SkeletonBar(height: 72, radius: 20),
      ];
    }

    final AssessmentSuggestion? suggestion = controller.suggestion.value;
    return <Widget>[
      if (controller.showSupportBanner.value) ...<Widget>[
        _SupportBanner(
          text: content.item9.hubBanner,
          onTap: controller.openSupport,
        ),
        const SizedBox(height: 14),
      ],
      if (controller.hasError.value) ...<Widget>[
        Text(
          'Your latest results could not be loaded. Pull down to try again.',
          style: AppFonts.label(size: 13.5, color: AppColors.bodyText),
        ),
        const SizedBox(height: 12),
      ],
      if (suggestion != null) ...<Widget>[
        _SuggestedCard(
          suggestion: suggestion,
          onTap: () => controller.openCheckIn(suggestion.def.id),
        ),
        const SizedBox(height: 8),
      ],
      for (final AssessmentHubGroup group in content.hubGroups) ...<Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 0, 10),
          child: MoodSectionLabel(group.label),
        ),
        for (final AssessmentDefinition def in content.inGroup(group.id))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CheckInCard(
              def: def,
              band: controller.latestBand(def),
              onTap: () => controller.openCheckIn(def.id),
            ),
          ),
      ],
    ];
  }
}

class _SuggestedCard extends StatelessWidget {
  const _SuggestedCard({required this.suggestion, required this.onTap});

  final AssessmentSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final BorderRadius radius = BorderRadius.circular(24);
    final String line = AssessmentsHubViewModel.suggestionLine(suggestion);
    return Semantics(
      button: true,
      label: 'Suggested: ${suggestion.def.checkTitle}. $line',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppBlends.blue,
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.isDark ? c.shadow : const Color(0x401F3550),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'SUGGESTED THIS WEEK',
                          style: AppFonts.label(
                            size: 12,
                            weight: FontWeight.w600,
                            letterSpacing: 1.4,
                            color: AppColors.softSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          suggestion.def.checkTitle,
                          style: AppFonts.body(
                            size: 20,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          line,
                          style: AppFonts.body(
                            size: 13.5,
                            color: c.onBlueMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppBlends.gold,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.headerBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.def,
    required this.band,
    required this.onTap,
  });

  final AssessmentDefinition def;
  final AssessmentBand? band;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final AssessmentBand? b = band;
    final String status = b == null ? 'Not taken' : '${b.label} range';
    return Semantics(
      button: true,
      label: '${def.name}. ${AssessmentsHubViewModel.cardLine(def)}. $status',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: <Widget>[
            AssessmentIconTile(icon: def.icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    def.name,
                    style: AppFonts.body(
                      size: 16.5,
                      weight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    AssessmentsHubViewModel.cardLine(def),
                    style: AppFonts.label(size: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (b == null)
              Text(
                'Not taken',
                style: AppFonts.label(
                  size: 13,
                  weight: FontWeight.w600,
                  color: c.accentText,
                ),
              )
            else
              Flexible(
                child: RangePill(
                  label: b.label,
                  tone: AssessmentMath.toneFor(def, b.id),
                ),
              ),
            Icon(Icons.chevron_right_rounded, color: c.textPrimary),
          ],
        ),
      ),
    );
  }
}

class _SupportBanner extends StatelessWidget {
  const _SupportBanner({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return AppCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.favorite_border_rounded,
            color: AppColors.accent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppFonts.body(
                size: 14.5,
                weight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          Text(
            'Support',
            style: AppFonts.body(
              size: 14,
              weight: FontWeight.w700,
              color: c.textPrimary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent,
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textPrimary),
        ],
      ),
    );
  }
}
