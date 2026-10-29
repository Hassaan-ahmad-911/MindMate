import 'dart:async';

import 'package:mindmate/Data/repositories/auth_repository.dart';
import 'package:mindmate/Data/repositories/home_repository.dart';
import 'package:mindmate/Data/repositories/meditation_repository.dart';
import 'package:mindmate/Data/repositories/mood_repository.dart';
import 'package:mindmate/Data/repositories/profile_repository.dart';
import 'package:mindmate/Models/mood_catalog.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/services/auth_service.dart';
import 'package:mindmate/services/mood_firestore_service.dart';
import 'package:mindmate/ui/programme/wellbeing_programme_controller.dart';
import 'package:mindmate/viewmodels/home_viewmodel.dart';

import 'meditation_fakes.dart';
import 'profile_fakes.dart';

/// Keeps a list of moods in memory and answers date-range queries from it.
class FakeMoodHistoryService extends MoodFirestoreService {
  /// Newest first, like the real service.
  List<MoodModel> history = <MoodModel>[];

  bool failLoading = false;
  int loads = 0;

  /// If set, loading waits for it (a request that is still running).
  Completer<void>? gate;

  @override
  Future<List<MoodModel>> getMoodsBetween(DateTime start, DateTime end) async {
    loads += 1;
    await gate?.future;
    if (failLoading) {
      throw StateError('offline');
    }
    return history
        .where((MoodModel m) => !m.date.isBefore(start) && m.date.isBefore(end))
        .toList();
  }
}

/// A mood entry for [mood] at [date].
MoodModel moodAt(
  DateTime date,
  String mood, {
  String intensity = MoodCatalog.moderate,
}) {
  final MoodDefinition definition = MoodCatalog.find(mood)!;
  return MoodModel(
    id: 'm-${date.microsecondsSinceEpoch}',
    mood: mood,
    intensity: intensity,
    valence: definition.valence,
    factors: const <String>[],
    note: '',
    date: date,
  );
}

/// Everything [HomeViewModel] reads, as fakes.
class HomeFakes {
  HomeFakes({
    FakeMoodHistoryService? moods,
    FakeProfileService? profiles,
    FakeLogService? logs,
    AuthService? auth,
  }) : moods = moods ?? FakeMoodHistoryService(),
       profiles = profiles ?? FakeProfileService(),
       logs = logs ?? FakeLogService(),
       auth = auth ?? AuthService();

  final FakeMoodHistoryService moods;
  final FakeProfileService profiles;
  final FakeLogService logs;
  final AuthService auth;
}

HomeViewModel buildHome({
  HomeFakes? fakes,
  AuthRepository? auth,
  ProfileRepository? profileRepository,
  DateTime Function()? clock,
  bool Function(String route)? routeExists,
  Duration bubbleDelay = const Duration(seconds: 3),
  WellbeingProgrammeController? programme,
}) {
  final HomeFakes f = fakes ?? HomeFakes();
  return HomeViewModel(
    auth ?? AuthRepository(f.auth),
    MoodRepository(f.moods),
    profileRepository ?? ProfileRepository(f.profiles),
    MeditationRepository(fileContentService(), f.logs),
    HomeRepository(),
    clock: clock,
    routeExists: routeExists ?? (String route) => true,
    bubbleDelay: bubbleDelay,
    programme: programme,
  );
}
