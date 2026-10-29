import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shared/app_card.dart';
import '../shared/mindmate_theme.dart';
import 'widgets/settings_widgets.dart';

/// A help page that is not written yet: its title and "Coming soon". The
/// title is the route argument.
class InfoPageView extends StatelessWidget {
  const InfoPageView({super.key});

  @override
  Widget build(BuildContext context) {
    final Object? arg = Get.arguments;
    final String title = arg is String && arg.isNotEmpty ? arg : 'MindMate';
    final MindMateColors c = context.mm;
    return SettingsPage(
      title: title,
      children: <Widget>[
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, size: 32, color: c.accentText),
              const SizedBox(height: 10),
              Text(
                'Coming soon',
                style: AppFonts.body(
                  size: 18,
                  weight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This page is being written.',
                textAlign: TextAlign.center,
                style: AppFonts.body(size: 15, color: c.textBody),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
