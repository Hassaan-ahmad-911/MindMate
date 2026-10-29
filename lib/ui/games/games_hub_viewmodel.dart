import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/break_repository.dart';
import '../../Data/repositories/gratitude_repository.dart';
import '../../Models/gratitude_entry.dart';

/// "Take a break": opens the three activities and shows two small facts, how
/// many breaks were taken this week and whether today's flower is planted.
class GamesHubViewModel extends GetxController {
  GamesHubViewModel(this._breaks, this._gratitude, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final BreakRepository _breaks;
  final GratitudeRepository _gratitude;
  final DateTime Function() _clock;

  /// Null until the count is known (or if it could not be loaded).
  final RxnInt breaksThisWeek = RxnInt();

  /// Null until known (or if it could not be loaded).
  final RxnBool plantedToday = RxnBool();

  @override
  void onInit() {
    super.onInit();
    unawaited(reload());
  }

  Future<void> reload() async {
    await Future.wait(<Future<void>>[_loadBreaks(), _loadGarden()]);
  }

  Future<void> _loadBreaks() async {
    try {
      breaksThisWeek.value = await _breaks.countThisWeek(now: _clock());
    } catch (_) {
      breaksThisWeek.value = null;
    }
  }

  Future<void> _loadGarden() async {
    try {
      final List<GratitudeEntry> entries = await _gratitude.getEntries();
      plantedToday.value = GratitudeRules.entryFor(entries, _clock()) != null;
    } catch (_) {
      plantedToday.value = null;
    }
  }

  /// The chip on the Gratitude garden card.
  String get gardenChip {
    switch (plantedToday.value) {
      case true:
        return 'Planted today';
      case false:
        return 'Today\'s flower is waiting';
      case null:
        return 'One good thing a day';
    }
  }

  /// Opens an activity, and refreshes the facts when the user comes back.
  void open(String route) {
    final Future<dynamic>? result = Get.toNamed<dynamic>(route);
    result?.then((_) => reload());
  }

  void back() => Get.back<void>();
}
