import '../../Models/gratitude_entry.dart';
import '../../services/gratitude_service.dart';

/// The gratitude garden's entries.
class GratitudeRepository {
  GratitudeRepository(this._service);

  final GratitudeService _service;

  /// Newest first.
  Future<List<GratitudeEntry>> getEntries() => _service.getEntries();

  Future<void> plant(GratitudeEntry entry) => _service.create(entry);

  Future<void> editText(GratitudeEntry entry) => _service.updateText(entry);

  Future<void> delete(String dateKey) => _service.delete(dateKey);
}
