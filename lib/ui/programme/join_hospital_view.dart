import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/hospital_programme.dart';
import '../auth/widgets/auth_widgets.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../profile_setup/widgets/setup_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'join_hospital_viewmodel.dart';
import 'widgets/programme_widgets.dart';

/// "Join your hospital", step 1 of 3 of the setup.
class JoinHospitalView extends GetView<JoinHospitalViewModel> {
  const JoinHospitalView({super.key});

  static const String agreement =
      "I understand and agree to take part in my hospital's wellbeing "
      'programme.';

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Scaffold(
      backgroundColor: c.background,
      body: BlendedBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: SetupTopBar(step: 1),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  children: <Widget>[
                    const SetupTitle(
                      title: 'Join your hospital',
                      subtitle: 'Enter the code your hospital gave you.',
                    ),
                    const SizedBox(height: 20),
                    Obx(
                      () => HospitalCodeField(
                        controller: controller.codeController,
                        looksRight: controller.codeLooksRight,
                        enabled:
                            !controller.isJoining.value &&
                            controller.joined.value == null,
                        onSubmitted: controller.join,
                      ),
                    ),
                    Obx(() {
                      final JoinedHospital? hospital = controller.joined.value;
                      return AnimatedSwitcher(
                        duration: AppMotion.of(
                          context,
                          const Duration(milliseconds: 260),
                        ),
                        child: hospital == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: HospitalCard(
                                  name: hospital.name,
                                  line: hospital.officerName.isEmpty
                                      ? 'Joined'
                                      : 'Wellbeing officer: '
                                            '${hospital.officerName}',
                                ),
                              ),
                      );
                    }),
                    const SizedBox(height: 22),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: MoodSectionLabel(
                        'How your wellbeing is looked after',
                      ),
                    ),
                    const AppCard(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Column(
                        children: <Widget>[
                          InfoLine(
                            icon: Icons.event_note_rounded,
                            text:
                                'A daily mood check and short check-ins on a '
                                "set schedule are part of your hospital's "
                                'programme.',
                          ),
                          InfoLine(
                            icon: Icons.person_outline_rounded,
                            tone: InfoTone.gold,
                            bold: 'wellbeing officer',
                            text:
                                'If your check-ins show you may be '
                                'struggling, your wellbeing officer is asked '
                                'to reach out and support you.',
                          ),
                          InfoLine(
                            icon: Icons.close_rounded,
                            tone: InfoTone.navy,
                            text:
                                'They never see your moods, scores, answers '
                                'or journal. Only that you may need support.',
                          ),
                          InfoLine(
                            icon: Icons.check_rounded,
                            text:
                                'You will always be told in the app when '
                                'they have been asked to contact you.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Obx(
                      () => ConsentCard(
                        text: agreement,
                        checked: controller.agreed.value,
                        enabled:
                            !controller.isJoining.value &&
                            controller.joined.value == null,
                        onChanged: controller.setAgreed,
                      ),
                    ),
                    Obx(() {
                      final String? error = controller.error.value;
                      if (error == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            style: AppFonts.body(
                              size: 15,
                              weight: FontWeight.w600,
                              color: c.accentText,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  children: <Widget>[
                    Obx(
                      () => GradientButton(
                        label: 'Join and continue',
                        isLoading:
                            controller.isJoining.value ||
                            controller.joined.value != null,
                        onPressed: controller.canJoin ? controller.join : null,
                      ),
                    ),
                    MoodTextLink(
                      label: 'Not now, log out',
                      onTap: controller.logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
