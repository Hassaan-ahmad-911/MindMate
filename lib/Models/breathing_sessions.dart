import 'meditation_models.dart';

/// The original timer-only breathing practices, kept as they were: each one
/// is a single timed step, with the same title, length and description. They
/// appear in the library under the "Breathing" group.
class BreathingLibrary {
  const BreathingLibrary._();

  static const MeditationGroup group = MeditationGroup.breathing;

  static final List<MeditationSession>
  sessions = List<MeditationSession>.unmodifiable(<MeditationSession>[
    _breathing(
      id: 'breathing_gentle_reset',
      title: 'Gentle Reset',
      technique: 'Relaxation',
      minutes: 5,
      description:
          'A soft pause to release tension and settle into the moment.',
    ),
    _breathing(
      id: 'breathing_quiet_night',
      title: 'Quiet Night',
      technique: 'Sleep',
      minutes: 10,
      description:
          'A calm wind-down to help the body and mind drift toward rest.',
    ),
    _breathing(
      id: 'breathing_let_it_ease',
      title: 'Let It Ease',
      technique: 'Stress Relief',
      minutes: 7,
      description: 'A grounding practice for the moments that feel too full.',
    ),
    _breathing(
      id: 'breathing_focused_flow',
      title: 'Focused Flow',
      technique: 'Focus',
      minutes: 8,
      description: 'A steady reset to help your attention return with ease.',
    ),
    _breathing(
      id: 'breathing_safe_grounding',
      title: 'Safe Grounding',
      technique: 'Anxiety',
      minutes: 6,
      description:
          'A soothing practice to soften anxious energy and reconnect.',
    ),
    _breathing(
      id: 'breathing_soft_release',
      title: 'Soft Release',
      technique: 'Relaxation',
      minutes: 12,
      description: 'An easy, slow practice to unwind from the day.',
    ),
    _breathing(
      id: 'breathing_restful_drift',
      title: 'Restful Drift',
      technique: 'Sleep',
      minutes: 15,
      description: 'A longer bedtime practice to guide the mind toward sleep.',
    ),
    _breathing(
      id: 'breathing_calm_the_pressure',
      title: 'Calm the Pressure',
      technique: 'Stress Relief',
      minutes: 9,
      description:
          'A reassuring breath practice when everything feels a little tight.',
    ),
    _breathing(
      id: 'breathing_clear_attention',
      title: 'Clear Attention',
      technique: 'Focus',
      minutes: 10,
      description:
          'A clear, steady practice to sharpen attention without force.',
    ),
    _breathing(
      id: 'breathing_soft_breathing',
      title: 'Soft Breathing',
      technique: 'Anxiety',
      minutes: 8,
      description:
          'A gentle breath practice to bring the nervous system back to calm.',
    ),
  ]);
}

/// A breathing practice: one step as long as the whole practice. [technique]
/// holds the old category (Relaxation, Sleep, Stress Relief, Focus, Anxiety).
MeditationSession _breathing({
  required String id,
  required String title,
  required String technique,
  required int minutes,
  required String description,
}) {
  return MeditationSession(
    id: id,
    title: title,
    groupId: MeditationGroup.breathingId,
    technique: technique,
    basedOn: '',
    minutes: minutes,
    posture: '',
    goodFor: '',
    about: description,
    safetyNote: '',
    steps: <MeditationStep>[
      MeditationStep(
        phase: 'practice',
        seconds: minutes * 60,
        text: description,
      ),
    ],
  );
}
