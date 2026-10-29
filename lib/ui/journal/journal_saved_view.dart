import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/journal_content.dart';
import '../../Models/journal_model.dart';
import '../../Models/meditation_models.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/breathing_tick.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'journal_saved_viewmodel.dart';
import 'widgets/journal_widgets.dart';

/// "Saved", and its support version.
class JournalSavedView extends GetView<JournalSavedViewModel> {
  const JournalSavedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          const Positioned(
            right: -110,
            top: -140,
            child: BlobShape(size: 300, gradient: AppBlends.blueShape),
          ),
          const Positioned(
            left: -130,
            top: 240,
            child: BlobShape(
              size: 230,
              gradient: AppBlends.gold,
              points: blobShapeB,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: IntrinsicHeight(
                      child: Obx(
                        () => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Spacer(),
                            const Center(
                              child: BreathingTick(
                                size: 200,
                                icon: Icons.menu_book_rounded,
                                semanticLabel: 'Entry saved',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Semantics(
                              header: true,
                              child: Text(
                                'Saved',
                                textAlign: TextAlign.center,
                                style: AppFonts.title(size: 46),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              controller.summaryLine,
                              textAlign: TextAlign.center,
                              style: AppFonts.body(size: 16),
                            ),
                            const SizedBox(height: 24),
                            if (controller.showSupport)
                              ..._supportSection()
                            else
                              ..._toneSection(context),
                            const Spacer(flex: 2),
                            const SizedBox(height: 20),
                            if (controller.showSupport)
                              GradientButton(
                                label:
                                    controller
                                        .content
                                        .value
                                        ?.supportCard
                                        .secondary ??
                                    'Breathe with me first',
                                onPressed: controller.breatheFirst,
                              )
                            else
                              GradientButton(
                                label: 'Done',
                                onPressed: controller.done,
                              ),
                            Center(
                              child: JournalTextLink(
                                label: controller.showSupport
                                    ? controller
                                              .content
                                              .value
                                              ?.supportCard
                                              .tertiary ??
                                          'Back to my journal'
                                    : 'Read my entry',
                                onTap: controller.showSupport
                                    ? controller.done
                                    : controller.readEntry,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _supportSection() {
    final JournalSupportCard? card = controller.content.value?.supportCard;
    if (card == null) {
      return const <Widget>[];
    }
    return <Widget>[
      JournalSupportCardView(card: card, onTalk: controller.talkToSomeone),
    ];
  }

  List<Widget> _toneSection(BuildContext context) {
    final JournalContent? content = controller.content.value;
    final JournalTone? tone = controller.entry.tone;
    final MeditationSession? practice = controller.practice.value;
    return <Widget>[
      AppCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(child: MoodSectionLabel('Tone of this entry')),
                if (tone != null)
                  JournalTonePill(
                    tone: tone,
                    labels: content?.tone.labels ?? const <String, String>{},
                  ),
              ],
            ),
            if (tone != null) ...<Widget>[
              const SizedBox(height: 16),
              _ToneBar(position: controller.markerPosition),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Heavy', style: AppFonts.label()),
                  Text('Light', style: AppFonts.label()),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              controller.toneLine,
              style: AppFonts.body(
                size: 16,
                weight: FontWeight.w500,
                color: context.mm.textBody,
              ),
            ),
          ],
        ),
      ),
      if (practice != null) ...<Widget>[
        const SizedBox(height: 12),
        _PracticeCard(
          label: controller.practiceLabel,
          title: practice.title,
          onTap: controller.openPractice,
        ),
      ],
    ];
  }
}

/// The Heavy-to-Light bar with a white marker. No number is shown.
class _ToneBar extends StatelessWidget {
  const _ToneBar({required this.position});

  /// 0 (Heavy) to 1 (Light).
  final double position;

  static const double _marker = 26;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: _marker,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double left =
                (constraints.maxWidth - _marker) * position.clamp(0.0, 1.0);
            return Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: <Color>[
                        AppColors.headerBlue,
                        AppColors.primary,
                        AppColors.secondary,
                        AppColors.softSurface,
                        AppColors.accent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: left,
                  child: Container(
                    width: _marker,
                    height: _marker,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: AppColors.primary, width: 3),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: context.mm.isDark
                              ? context.mm.shadow
                              : const Color(0x331F3550),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.label,
    required this.title,
    required this.onTap,
  });

  final String label;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play $title. $label',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        radius: 22,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppBlends.lightBlue,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.spa_outlined,
                color: AppColors.headerBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  MoodSectionLabel(label),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: AppFonts.body(
                      size: 17,
                      weight: FontWeight.w700,
                      color: context.mm.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppBlends.gold,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.headerBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
