import '../../Models/mood_model.dart';
import '../../Models/mood_stats.dart';
import '../../services/mood_firestore_service.dart';

class MoodRepository {
  MoodRepository(this._service);

  final MoodFirestoreService _service;

  Future<MoodModel> saveMood(MoodModel mood) {
    return _service.saveMood(mood);
  }

  Future<List<MoodModel>> getMoodHistory() {
    return _service.getMoodHistory();
  }

  Future<List<MoodModel>> getRecentMoods() {
    return _service.getRecentMoods();
  }

  Future<List<MoodModel>> getWeeklyMoods() {
    return _service.getWeeklyMoods();
  }

  /// Entries with [start] <= date < [end], newest first.
  Future<List<MoodModel>> getMoodsBetween(DateTime start, DateTime end) {
    return _service.getMoodsBetween(start, end);
  }

  /// Entries from the last [MoodStats.historyWindowDays] days, newest first.
  Future<List<MoodModel>> getRecentWindow({DateTime? now}) {
    final DateTime today = MoodStats.dayOf(now ?? DateTime.now());
    return _service.getMoodsBetween(
      MoodStats.addDays(today, 1 - MoodStats.historyWindowDays),
      MoodStats.addDays(today, 1),
    );
  }

  Future<List<MoodModel>> getMoodPage({DateTime? before, int limit = 30}) {
    return _service.getMoodPage(before: before, limit: limit);
  }

  Future<void> updateMoodNote(String moodId, String note) {
    return _service.updateMoodNote(moodId, note);
  }

  Future<void> deleteMood(String moodId) {
    return _service.deleteMood(moodId);
  }
}
