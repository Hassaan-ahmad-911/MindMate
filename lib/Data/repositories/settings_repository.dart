import 'package:shared_preferences/shared_preferences.dart';

import '../../Models/user_settings.dart';
import '../../services/settings_firestore_service.dart';

/// The user's settings (`users/{uid}.settings`). Loads them once per user,
/// creates them from the defaults on first load, and writes one field at a
/// time.
class SettingsRepository {
  SettingsRepository(
    this._service, {
    Future<SharedPreferences> Function()? prefs,
  }) : _prefs = prefs ?? SharedPreferences.getInstance;

  final SettingsFirestoreService _service;
  final Future<SharedPreferences> Function() _prefs;

  String? _uid;
  UserSettings? _cache;
  Future<UserSettings>? _loading;

  /// Where the meditation player kept the background sound before it moved
  /// into the settings map.
  static String legacySoundKey(String uid) => 'meditation_ambient_$uid';
  static String legacyVolumeKey(String uid) => 'meditation_ambient_volume_$uid';

  String get uid => _service.currentUid();

  /// The settings, loaded once per signed-in user.
  Future<UserSettings> load() {
    final String current = uid;
    if (_uid == current && _cache != null) {
      return Future<UserSettings>.value(_cache);
    }
    if (_uid != current) {
      _cache = null;
      _loading = null;
      _uid = current;
    }
    return _loading ??= _read(current).whenComplete(() => _loading = null);
  }

  Future<UserSettings> _read(String uid) async {
    final Map<String, dynamic> doc =
        await _service.readUserDocument() ?? <String, dynamic>{};
    final Object? stored = doc['settings'];
    final UserSettings defaults = UserSettings.defaults(
      reminderPreference: doc['reminderPreference'] as String?,
    );

    // A sound chosen in the player before this map existed moves in here.
    SharedPreferences? prefs;
    try {
      prefs = await _prefs();
    } catch (_) {
      prefs = null;
    }
    final String? legacySound = prefs?.getString(legacySoundKey(uid));
    final double? legacyVolume = prefs?.getDouble(legacyVolumeKey(uid));

    UserSettings settings;
    if (stored is Map) {
      settings = UserSettings.fromMap(stored, defaults);
      if (stored['meditationSound'] == null && legacySound != null) {
        settings = settings.copyWith(
          meditationSound: legacySound,
          meditationSoundVolume: legacyVolume,
        );
        await _service.updateField('meditationSound', settings.meditationSound);
        await _service.updateField(
          'meditationSoundVolume',
          settings.meditationSoundVolume,
        );
      }
    } else {
      settings = defaults.copyWith(
        meditationSound: legacySound,
        meditationSoundVolume: legacyVolume,
      );
      await _service.createSettings(settings.toMap());
    }
    await prefs?.remove(legacySoundKey(uid));
    await prefs?.remove(legacyVolumeKey(uid));

    if (_uid == uid) {
      _cache = settings;
    }
    return settings;
  }

  /// Saves one field and the new settings in memory.
  Future<UserSettings> _write(
    String path,
    Object? value,
    UserSettings Function(UserSettings) apply,
  ) async {
    final UserSettings next = apply(await load());
    await _service.updateField(path, value);
    _cache = next;
    return next;
  }

  /// [kind] is `mood`, `journal`, `practice` or `checkinsDue`.
  Future<UserSettings> setReminderOn(String kind, bool on) => _write(
    'reminders.$kind.on',
    on,
    (UserSettings s) => s.copyWith(
      reminders: _withSlot(
        s.reminders,
        kind,
        (ReminderSlot r) => r.copyWith(on: on),
      ),
    ),
  );

  Future<UserSettings> setReminderTime(String kind, String time) => _write(
    'reminders.$kind.time',
    time,
    (UserSettings s) => s.copyWith(
      reminders: _withSlot(
        s.reminders,
        kind,
        (ReminderSlot r) => r.copyWith(time: time),
      ),
    ),
  );

  /// Null (and nothing saved) when it would leave no day.
  Future<UserSettings?> toggleDay(int day) async {
    final UserSettings s = await load();
    final List<int>? days = s.reminders.toggleDay(day);
    if (days == null) {
      return null;
    }
    return _write(
      'reminders.days',
      days,
      (UserSettings x) =>
          x.copyWith(reminders: x.reminders.copyWith(days: days)),
    );
  }

  Future<UserSettings> setQuietHoursOn(bool on) => _write(
    'reminders.quietHours.on',
    on,
    (UserSettings s) => s.copyWith(
      reminders: s.reminders.copyWith(
        quietHours: s.reminders.quietHours.copyWith(on: on),
      ),
    ),
  );

  Future<UserSettings> setQuietHoursStart(String time) => _write(
    'reminders.quietHours.start',
    time,
    (UserSettings s) => s.copyWith(
      reminders: s.reminders.copyWith(
        quietHours: s.reminders.quietHours.copyWith(start: time),
      ),
    ),
  );

  Future<UserSettings> setQuietHoursEnd(String time) => _write(
    'reminders.quietHours.end',
    time,
    (UserSettings s) => s.copyWith(
      reminders: s.reminders.copyWith(
        quietHours: s.reminders.quietHours.copyWith(end: time),
      ),
    ),
  );

  Future<UserSettings> setHideReminderText(bool hide) => _write(
    'hideReminderText',
    hide,
    (UserSettings s) => s.copyWith(hideReminderText: hide),
  );

  Future<UserSettings> setMeditationSound(String id) => _write(
    'meditationSound',
    id,
    (UserSettings s) => s.copyWith(meditationSound: id),
  );

  Future<UserSettings> setMeditationSoundVolume(double volume) => _write(
    'meditationSoundVolume',
    volume,
    (UserSettings s) => s.copyWith(meditationSoundVolume: volume),
  );

  /// Forgets the settings kept in memory (after sign-out or deletion).
  void clear() {
    _uid = null;
    _cache = null;
    _loading = null;
  }

  static ReminderSettings _withSlot(
    ReminderSettings r,
    String kind,
    ReminderSlot Function(ReminderSlot) change,
  ) {
    switch (kind) {
      case 'mood':
        return r.copyWith(mood: change(r.mood));
      case 'journal':
        return r.copyWith(journal: change(r.journal));
      case 'practice':
        return r.copyWith(practice: change(r.practice));
      case 'checkinsDue':
        return r.copyWith(checkinsDue: change(r.checkinsDue));
    }
    throw ArgumentError('Unknown reminder "$kind".');
  }
}
