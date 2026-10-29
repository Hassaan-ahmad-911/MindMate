import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/hospital_programme.dart';
import '../app/app_routes.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/blob_shape.dart';
import '../shared/gradient_button.dart';
import '../shared/mindmate_theme.dart';
import 'widgets/programme_widgets.dart';

/// "Someone will reach out": the user is told, once per alert, that their
/// wellbeing officer was asked to contact them. Opened with the
/// [WellbeingAlert] as the argument.
class WellbeingAlertView extends StatelessWidget {
  const WellbeingAlertView({super.key, this.alert});

  /// For tests; otherwise read from the route.
  final WellbeingAlert? alert;

  static const String title = 'Someone will reach out';

  /// The main line, with [officer] shown in bold by the view.
  static String message(WellbeingAlert alert) {
    final String officer = officerOf(alert);
    return alert.urgent
        ? 'Your answers suggest you may need support today. We have asked '
              '$officer to contact you today.'
        : 'Your check-ins over the last two weeks suggest things have been '
              'hard. We have asked $officer, your wellbeing officer, to get '
              'in touch and support you.';
  }

  static String officerOf(WellbeingAlert alert) =>
      alert.officerName.isEmpty ? 'your wellbeing officer' : alert.officerName;

  @override
  Widget build(BuildContext context) {
    final Object? argument = Get.arguments;
    final WellbeingAlert? shown =
        alert ?? (argument is WellbeingAlert ? argument : null);
    final MindMateColors c = context.mm;

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          if (!c.isDark)
            const Positioned(
              right: -110,
              top: -150,
              child: BlobShape(size: 280, gradient: AppBlends.blueShape),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CircleIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onPressed: () => Get.back<void>(),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppBlends.gold,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 4,
                            ),
                          ),
                          child: const Icon(
                            Icons.favorite_border_rounded,
                            color: AppColors.headerBlue,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Semantics(
                        header: true,
                        child: Text(title, style: AppFonts.title(size: 36)),
                      ),
                      const SizedBox(height: 12),
                      if (shown != null) _Message(alert: shown),
                      const SizedBox(height: 18),
                      const AppCard(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Column(
                          children: <Widget>[
                            InfoLine(
                              icon: Icons.close_rounded,
                              tone: InfoTone.navy,
                              text:
                                  'They were not sent your moods, scores, '
                                  'answers or journal.',
                            ),
                            InfoLine(
                              icon: Icons.shield_outlined,
                              text:
                                  'This is for support, not a performance '
                                  'review.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _TalkSoonerCard(
                        onTap: () => Get.offNamed<void>(AppRoutes.support),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    children: <Widget>[
                      GradientButton(
                        label: 'Okay',
                        icon: Icons.check_rounded,
                        onPressed: () => Get.back<void>(),
                      ),
                      MoodTextLink(
                        label: 'Try a calm practice',
                        onTap: () => Get.offNamed<void>(AppRoutes.meditation),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.alert});

  final WellbeingAlert alert;

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    final String text = WellbeingAlertView.message(alert);
    final String officer = WellbeingAlertView.officerOf(alert);
    final int at = text.indexOf(officer);
    final TextStyle style = AppFonts.body(size: 17, color: c.textBody);
    return Text.rich(
      TextSpan(
        style: style,
        children: <InlineSpan>[
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: officer,
            style: AppFonts.body(
              size: 17,
              weight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          TextSpan(text: text.substring(at + officer.length)),
        ],
      ),
    );
  }
}

/// "Need to talk sooner?": the blue card to the support page.
class _TalkSoonerCard extends StatelessWidget {
  const _TalkSoonerCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Need to talk sooner? Support and helplines',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppBlends.blue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppBlends.gold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.call_outlined,
                      color: AppColors.headerBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Need to talk sooner?',
                          style: AppFonts.body(
                            size: 17,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Support and helplines',
                          style: AppFonts.body(
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
