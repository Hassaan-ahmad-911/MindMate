import 'package:flutter/material.dart';

class MeditationCategory {
  const MeditationCategory({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.gradient,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradient;
}

class MeditationSession {
  const MeditationSession({
    required this.title,
    required this.category,
    required this.duration,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.gradient,
  });

  final String title;
  final String category;
  final Duration duration;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradient;

  String get durationLabel => _formatDuration(duration);

  static MeditationSession sample() => MeditationLibrary.sessions.first;
}

class MeditationLibrary {
  static const List<MeditationCategory> categories = <MeditationCategory>[
    MeditationCategory(
      label: 'Relaxation',
      icon: Icons.self_improvement_rounded,
      accentColor: Color(0xFF6A9F8D),
      gradient: <Color>[Color(0xFFDDF1E8), Color(0xFF7FB8A6)],
    ),
    MeditationCategory(
      label: 'Sleep',
      icon: Icons.bedtime_rounded,
      accentColor: Color(0xFF6D8FB5),
      gradient: <Color>[Color(0xFFDCE8F7), Color(0xFF8FA9CF)],
    ),
    MeditationCategory(
      label: 'Stress Relief',
      icon: Icons.air_rounded,
      accentColor: Color(0xFFE09B67),
      gradient: <Color>[Color(0xFFF7E1C9), Color(0xFFE9B58E)],
    ),
    MeditationCategory(
      label: 'Focus',
      icon: Icons.center_focus_strong_rounded,
      accentColor: Color(0xFF5C86A2),
      gradient: <Color>[Color(0xFFDCECF6), Color(0xFF83A9C2)],
    ),
    MeditationCategory(
      label: 'Anxiety',
      icon: Icons.healing_rounded,
      accentColor: Color(0xFF8D7BBE),
      gradient: <Color>[Color(0xFFE9E1FA), Color(0xFFB7A8D9)],
    ),
  ];

  static const List<MeditationSession> sessions = <MeditationSession>[
    MeditationSession(
      title: 'Gentle Reset',
      category: 'Relaxation',
      duration: Duration(minutes: 5),
      description:
          'A soft pause to release tension and settle into the moment.',
      icon: Icons.self_improvement_rounded,
      accentColor: Color(0xFF6A9F8D),
      gradient: <Color>[Color(0xFFDDF1E8), Color(0xFF7FB8A6)],
    ),
    MeditationSession(
      title: 'Quiet Night',
      category: 'Sleep',
      duration: Duration(minutes: 10),
      description:
          'A calm wind-down to help the body and mind drift toward rest.',
      icon: Icons.bedtime_rounded,
      accentColor: Color(0xFF6D8FB5),
      gradient: <Color>[Color(0xFFDCE8F7), Color(0xFF8FA9CF)],
    ),
    MeditationSession(
      title: 'Let It Ease',
      category: 'Stress Relief',
      duration: Duration(minutes: 7),
      description: 'A grounding practice for the moments that feel too full.',
      icon: Icons.air_rounded,
      accentColor: Color(0xFFE09B67),
      gradient: <Color>[Color(0xFFF7E1C9), Color(0xFFE9B58E)],
    ),
    MeditationSession(
      title: 'Focused Flow',
      category: 'Focus',
      duration: Duration(minutes: 8),
      description: 'A steady reset to help your attention return with ease.',
      icon: Icons.center_focus_strong_rounded,
      accentColor: Color(0xFF5C86A2),
      gradient: <Color>[Color(0xFFDCECF6), Color(0xFF83A9C2)],
    ),
    MeditationSession(
      title: 'Safe Grounding',
      category: 'Anxiety',
      duration: Duration(minutes: 6),
      description:
          'A soothing practice to soften anxious energy and reconnect.',
      icon: Icons.healing_rounded,
      accentColor: Color(0xFF8D7BBE),
      gradient: <Color>[Color(0xFFE9E1FA), Color(0xFFB7A8D9)],
    ),
    MeditationSession(
      title: 'Soft Release',
      category: 'Relaxation',
      duration: Duration(minutes: 12),
      description: 'An easy, slow practice to unwind from the day.',
      icon: Icons.spa_rounded,
      accentColor: Color(0xFF7EA68D),
      gradient: <Color>[Color(0xFFE4F4E9), Color(0xFF92C3A3)],
    ),
    MeditationSession(
      title: 'Restful Drift',
      category: 'Sleep',
      duration: Duration(minutes: 15),
      description: 'A longer bedtime practice to guide the mind toward sleep.',
      icon: Icons.nightlight_round,
      accentColor: Color(0xFF7A96C8),
      gradient: <Color>[Color(0xFFD9E5FA), Color(0xFF9BB5DF)],
    ),
    MeditationSession(
      title: 'Calm the Pressure',
      category: 'Stress Relief',
      duration: Duration(minutes: 9),
      description:
          'A reassuring breath practice when everything feels a little tight.',
      icon: Icons.volunteer_activism_rounded,
      accentColor: Color(0xFFE08A67),
      gradient: <Color>[Color(0xFFF8E2D8), Color(0xFFE8A484)],
    ),
    MeditationSession(
      title: 'Clear Attention',
      category: 'Focus',
      duration: Duration(minutes: 10),
      description:
          'A clear, steady practice to sharpen attention without force.',
      icon: Icons.visibility_rounded,
      accentColor: Color(0xFF4F90A8),
      gradient: <Color>[Color(0xFFD8EEF1), Color(0xFF8CC3CE)],
    ),
    MeditationSession(
      title: 'Soft Breathing',
      category: 'Anxiety',
      duration: Duration(minutes: 8),
      description:
          'A gentle breath practice to bring the nervous system back to calm.',
      icon: Icons.favorite_rounded,
      accentColor: Color(0xFF9A7DBA),
      gradient: <Color>[Color(0xFFF0E7FB), Color(0xFFC7B4E5)],
    ),
  ];
}

String _formatDuration(Duration duration) {
  final int minutes = duration.inMinutes;
  final int seconds = duration.inSeconds.remainder(60);
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
