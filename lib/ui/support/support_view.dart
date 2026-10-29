import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Models/support_contacts.dart';
import '../mood_tracking/widgets/mood_widgets.dart';
import '../shared/app_card.dart';
import '../shared/blended_background.dart';
import '../shared/mindmate_theme.dart';

/// Support and helplines. The list is a placeholder, filled in with local
/// numbers before release (see [SupportContacts]).
class SupportView extends StatelessWidget {
  const SupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mm.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: BlendedBackground()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: <Widget>[
                MoodPageHeader(
                  title: 'Support',
                  onBack: () => Get.back<void>(),
                ),
                const SizedBox(height: 10),
                Text(
                  'You do not have to carry a hard shift alone. These are '
                  'people you can reach.',
                  style: AppFonts.body(size: 16, height: 1.45),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    // Opaque in Dark so the navy text keeps its contrast.
                    color: AppColors.softSurface.withValues(
                      alpha: context.mm.isDark ? 1 : 0.7,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.headerBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${SupportContacts.urgentLine} '
                          '${SupportContacts.notEmergencyLine}',
                          style: AppFonts.body(
                            size: 15,
                            weight: FontWeight.w600,
                            color: AppColors.textDark,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final SupportContact contact in SupportContacts.all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ContactCard(contact: contact),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final SupportContact contact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${contact.name}. ${contact.detail} ${contact.howToReach}',
      excludeSemantics: true,
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              contact.name,
              style: AppFonts.body(
                size: 17.5,
                weight: FontWeight.w700,
                color: context.mm.textPrimary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(contact.detail, style: AppFonts.body(size: 14.5)),
            const SizedBox(height: 8),
            Text(
              contact.howToReach,
              style: AppFonts.body(
                size: 16,
                weight: FontWeight.w600,
                color: context.mm.accentText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
