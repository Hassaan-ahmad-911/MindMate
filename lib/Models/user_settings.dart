/// One reminder: on or off, and its time ("HH:mm") if it has one.
class ReminderSlot {
  const ReminderSlot({required this.on, this.time});

  final bool on;
  final String? time;

  ReminderSlot copyWith({bool? on, String? time}) =>
      ReminderSlot(on: on ?? this.on, time: time ?? this.time);

  Map<String, dynamic> toMap() => <String, dynamic>{'on': on, 'time': ?time};

  static ReminderSlot fromMap(Object? value, ReminderSlot fallback) {
    if (value is! Map) {
      return fallback;
    }
    final Object? time = value['time'];
    return ReminderSlot(
      on: value['on'] is bool ? value['on'] as bool : fallback.on,
      time: time is String && SettingsTime.isValid(time) ? time : fallback.time,
    );
  }
}

/// "No reminders while I sleep". The window may cross midnight.
class QuietHours {
  const QuietHours({required this.on, required this.start, required this.end});

  final bool on;
  final String start;
  final String end;

  QuietHours copyWith({bool? on, String? start, String? end}) => QuietHours(
    on: on ?? this.on,
    start: start ?? this.start,
    end: end ?? this.end,
  );

  /// Whether [time] ("HH:mm") falls in the quiet window: from [start] up to,
  /// not including, [end]. 23:00 to 07:00 covers 23:30 and 06:59.
  bool covers(String time) {
    if (!on) {
      return false;
    }
    final int t = SettingsTime.minutes(time);
    final int s = SettingsTime.minutes(start);
    final int e = SettingsTime.minutes(end);
    if (s == e) {
      return false;
    }
    return s < e ? (t >= s && t < e) : (t >= s || t < e);
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'on': on,
    'start': start,
    'end': end,
  };

  static QuietHours fromMap(Object? value, QuietHours fallback) {
    if (value is! Map) {
      return fallback;
    }
    String time(String key, String other) {
      final Object? v = value[key];
      return v is String && SettingsTime.isValid(v) ? v : other;
    }

    return QuietHours(
      on: value['on'] is bool ? value['on'] as bool : fallback.on,
      start: time('start', fallback.start),
      end: time('end', fallback.end),
    );
  }
}

/// The reminder choices. Only stored here: the Notifications module reads
/// them and schedules the reminders.
class ReminderSettings {
  const ReminderSettings({
    required this.mood,
    required this.journal,
    required this.practice,
    required this.checkinsDue,
    required this.days,
    required this.quietHours,
  });

  final ReminderSlot mood;
  final ReminderSlot journal;
  final ReminderSlot practice;
  final ReminderSlot checkinsDue;

  /// ISO weekdays, Monday = 1. Never empty.
  final List<int> days;
  final QuietHours quietHours;

  static const List<int> allDays = <int>[1, 2, 3, 4, 5, 6, 7];

  ReminderSettings copyWith({
    ReminderSlot? mood,
    ReminderSlot? journal,
    ReminderSlot? practice,
    ReminderSlot? checkinsDue,
    List<int>? days,
    QuietHours? quietHours,
  }) {
    return ReminderSettings(
      mood: mood ?? this.mood,
      journal: journal ?? this.journal,
      practice: practice ?? this.practice,
      checkinsDue: checkinsDue ?? this.checkinsDue,
      days: days ?? this.days,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  /// [day] switched on or off, or null when that would leave no day.
  List<int>? toggleDay(int day) {
    final Set<int> next = days.toSet();
    if (next.contains(day)) {
      if (next.length == 1) {
        return null;
      }
      next.remove(day);
    } else {
      next.add(day);
    }
    return next.toList()..sort();
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'mood': mood.toMap(),
    'journal': journal.toMap(),
    'practice': practice.toMap(),
    'checkinsDue': <String, dynamic>{'on': checkinsDue.on},
    'days': days,
    'quietHours': quietHours.toMap(),
  };

  static ReminderSettings fromMap(Object? value, ReminderSettings fallback) {
    if (value is! Map) {
      return fallback;
    }
    final Object? days = value['days'];
    final List<int> parsed = days is List
        ? (days
              .whereType<num>()
              .map((num d) => d.toInt())
              .where((int d) => d >= 1 && d <= 7)
              .toSet()
              .toList()
            ..sort())
        : fallback.days;
    return ReminderSettings(
      mood: ReminderSlot.fromMap(value['mood'], fallback.mood),
      journal: ReminderSlot.fromMap(value['journal'], fallback.journal),
      practice: ReminderSlot.fromMap(value['practice'], fallback.practice),
      checkinsDue: ReminderSlot.fromMap(
        value['checkinsDue'],
        fallback.checkinsDue,
      ),
      days: parsed.isEmpty ? fallback.days : parsed,
      quietHours: QuietHours.fromMap(value['quietHours'], fallback.quietHours),
    );
  }
}

/// `settings` on the user document.
class UserSettings {
  const UserSettings({
    required this.reminders,
    required this.hideReminderText,
    required this.meditationSound,
    required this.meditationSoundVolume,
  });

  final ReminderSettings reminders;
  final bool hideReminderText;

  /// "off", "soft_rain" or "warm_tones".
  final String meditationSound;
  final double meditationSoundVolume;

  static const double defaultVolume = 0.25;

  /// The defaults, with the mood reminder taken from the first check-in's
  /// answer: before_shift 07:00, after_shift 19:30, evening 20:00, none off.
  factory UserSettings.defaults({String? reminderPreference}) {
    final ReminderSlot mood = switch (reminderPreference) {
      'before_shift' => const ReminderSlot(on: true, time: '07:00'),
      'after_shift' => const ReminderSlot(on: true, time: '19:30'),
      'evening' => const ReminderSlot(on: true, time: '20:00'),
      'none' => const ReminderSlot(on: false, time: '20:00'),
      _ => const ReminderSlot(on: true, time: '20:00'),
    };
    return UserSettings(
      reminders: ReminderSettings(
        mood: mood,
        journal: const ReminderSlot(on: false, time: '21:00'),
        practice: const ReminderSlot(on: false, time: '07:30'),
        checkinsDue: const ReminderSlot(on: true),
        days: ReminderSettings.allDays,
        quietHours: const QuietHours(on: false, start: '23:00', end: '07:00'),
      ),
      hideReminderText: false,
      meditationSound: 'off',
      meditationSoundVolume: defaultVolume,
    );
  }

  UserSettings copyWith({
    ReminderSettings? reminders,
    bool? hideReminderText,
    String? meditationSound,
    double? meditationSoundVolume,
  }) {
    return UserSettings(
      reminders: reminders ?? this.reminders,
      hideReminderText: hideReminderText ?? this.hideReminderText,
      meditationSound: meditationSound ?? this.meditationSound,
      meditationSoundVolume:
          meditationSoundVolume ?? this.meditationSoundVolume,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'reminders': reminders.toMap(),
    'hideReminderText': hideReminderText,
    'meditationSound': meditationSound,
    'meditationSoundVolume': meditationSoundVolume,
  };

  /// Missing or broken fields fall back to [fallback]'s.
  static UserSettings fromMap(Object? value, UserSettings fallback) {
    if (value is! Map) {
      return fallback;
    }
    final Object? sound = value['meditationSound'];
    final Object? volume = value['meditationSoundVolume'];
    return UserSettings(
      reminders: ReminderSettings.fromMap(
        value['reminders'],
        fallback.reminders,
      ),
      hideReminderText: value['hideReminderText'] is bool
          ? value['hideReminderText'] as bool
          : fallback.hideReminderText,
      meditationSound: sound is String && sound.isNotEmpty
          ? sound
          : fallback.meditationSound,
      meditationSoundVolume: volume is num
          ? volume.toDouble()
          : fallback.meditationSoundVolume,
    );
  }

  /// The value on the Settings row: "Mood at 20:00", or the first reminder
  /// that is on, or "Off".
  String get remindersSummary {
    final ReminderSettings r = reminders;
    if (r.mood.on) {
      return 'Mood at ${r.mood.time}';
    }
    if (r.journal.on) {
      return 'Journal at ${r.journal.time}';
    }
    if (r.practice.on) {
      return 'Practice at ${r.practice.time}';
    }
    if (r.checkinsDue.on) {
      return 'Check-ins due';
    }
    return 'Off';
  }
}

/// "HH:mm" helpers.
class SettingsTime {
  const SettingsTime._();

  static bool isValid(String value) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

  static int minutes(String value) {
    final List<String> parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String format(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
