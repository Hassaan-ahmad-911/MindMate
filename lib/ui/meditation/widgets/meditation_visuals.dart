import 'package:flutter/material.dart';

import '../../../Models/meditation_models.dart';
import '../../shared/mindmate_theme.dart';

/// The colour of a practice's icon tile, taken from the shared blends.
enum MeditationTone { blue, gold, lightBlue }

extension MeditationToneStyle on MeditationTone {
  Gradient get gradient {
    switch (this) {
      case MeditationTone.blue:
        return AppBlends.blue;
      case MeditationTone.gold:
        return AppBlends.gold;
      case MeditationTone.lightBlue:
        return AppBlends.lightBlue;
    }
  }

  /// Icon and text colour on top of [gradient].
  Color get foreground =>
      this == MeditationTone.blue ? Colors.white : AppColors.headerBlue;
}

/// Which icon and colour each practice uses. The content file has neither, so
/// they are chosen here.
class MeditationVisuals {
  const MeditationVisuals._();

  static MeditationTone toneFor(MeditationSession session) {
    switch (session.groupId) {
      case 'before_shift':
      case 'after_shift':
        return MeditationTone.gold;
      case 'overwhelmed':
      case 'after_event':
      case 'sleep':
        return MeditationTone.blue;
      default:
        return MeditationTone.lightBlue;
    }
  }

  static IconData iconFor(MeditationSession session) {
    switch (session.id) {
      case 'arriving':
        return Icons.wb_twilight_rounded;
      case 'three_step_pause':
        return Icons.pause_circle_outline_rounded;
      case 'mindful_hand_washing':
        return Icons.water_drop_outlined;
      case 'senses_54321':
        return Icons.visibility_outlined;
      case 'stop':
        return Icons.front_hand_outlined;
      case 'self_compassion_break':
        return Icons.favorite_border_rounded;
      case 'leaving_work':
        return Icons.exit_to_app_rounded;
      case 'release_the_tension':
        return Icons.waves_rounded;
      case 'sleep_wind_down':
        return Icons.bedtime_outlined;
      case 'kindness_for_carers':
        return Icons.volunteer_activism_outlined;
      case 'calm_place':
        return Icons.landscape_outlined;
      case 'full_body_scan':
        return Icons.accessibility_new_rounded;
      // The original breathing practices keep their old icons.
      case 'breathing_gentle_reset':
        return Icons.self_improvement_rounded;
      case 'breathing_quiet_night':
        return Icons.bedtime_rounded;
      case 'breathing_let_it_ease':
        return Icons.air_rounded;
      case 'breathing_focused_flow':
        return Icons.center_focus_strong_rounded;
      case 'breathing_safe_grounding':
        return Icons.healing_rounded;
      case 'breathing_soft_release':
        return Icons.spa_rounded;
      case 'breathing_restful_drift':
        return Icons.nightlight_round;
      case 'breathing_calm_the_pressure':
        return Icons.volunteer_activism_rounded;
      case 'breathing_clear_attention':
        return Icons.visibility_rounded;
      case 'breathing_soft_breathing':
        return Icons.favorite_rounded;
      default:
        return Icons.self_improvement_rounded;
    }
  }
}
