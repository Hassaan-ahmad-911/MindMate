import 'package:cloud_firestore/cloud_firestore.dart';

/// One good thing from one day: `users/{uid}/gratitude/{yyyy-MM-dd}`. The date
/// is the document id, which keeps it to one entry per day.
class GratitudeEntry {
  const GratitudeEntry({
    required this.dateKey,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  /// `yyyy-MM-dd`, in the phone's local time.
  final String dateKey;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get date => GratitudeRules.dateFromKey(dateKey) ?? createdAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Null when the document is not a usable entry.
  static GratitudeEntry? fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final Object? text = map['text'];
    if (text is! String || GratitudeRules.dateFromKey(id) == null) {
      return null;
    }
    final DateTime? created = _readDate(map['createdAt']);
    final DateTime? updated = _readDate(map['updatedAt']);
    final DateTime fallback = GratitudeRules.dateFromKey(id) ?? DateTime.now();
    return GratitudeEntry(
      dateKey: id,
      text: text,
      createdAt: created ?? updated ?? fallback,
      updatedAt: updated ?? created ?? fallback,
    );
  }

  GratitudeEntry copyWith({String? text, DateTime? updatedAt}) {
    return GratitudeEntry(
      dateKey: dateKey,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}

/// How a flower looks. It comes only from the entry's date, so a flower never
/// changes.
class FlowerStyle {
  const FlowerStyle({required this.heightFraction, required this.colour});

  /// How tall the stem is, from [minHeight] to [maxHeight] of the garden.
  final double heightFraction;
  final FlowerColour colour;

  static const double minHeight = 0.34;
  static const double maxHeight = 0.7;

  factory FlowerStyle.forDateKey(String dateKey) {
    final int hash = _fnv1a(dateKey);
    final double height =
        minHeight + ((hash >> 4) % 1000) / 999 * (maxHeight - minHeight);
    final FlowerColour colour =
        FlowerColour.values[(hash >> 16) % FlowerColour.values.length];
    return FlowerStyle(heightFraction: height, colour: colour);
  }

  /// A hash that is the same on every phone and every run (unlike
  /// `String.hashCode`).
  static int _fnv1a(String text) {
    int hash = 0x811c9dc5;
    for (final int unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}

enum FlowerColour { gold, blue, white }

/// The one-entry-per-day rules and the date wording.
class GratitudeRules {
  const GratitudeRules._();

  static const int maxLength = 200;

  /// `2026-10-07`.
  static String dateKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static DateTime? dateFromKey(String key) {
    final RegExpMatch? match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(key);
    if (match == null) {
      return null;
    }
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final DateTime date = DateTime(year, month, day);
    // Rejects dates like 2026-02-31, which DateTime would roll over.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  /// The text to save: trimmed, 1 to [maxLength] characters. Null if it
  /// cannot be saved.
  static String? cleanText(String? text) {
    final String trimmed = (text ?? '').trim();
    if (trimmed.isEmpty || trimmed.length > maxLength) {
      return null;
    }
    return trimmed;
  }

  static bool canSave(String? text) => cleanText(text) != null;

  /// Today's entry, if one was planted.
  static GratitudeEntry? entryFor(
    Iterable<GratitudeEntry> entries,
    DateTime day,
  ) {
    final String key = dateKey(day);
    for (final GratitudeEntry entry in entries) {
      if (entry.dateKey == key) {
        return entry;
      }
    }
    return null;
  }

  /// Another flower can be planted only if none was planted that day.
  static bool canPlant(Iterable<GratitudeEntry> entries, DateTime now) {
    return entryFor(entries, now) == null;
  }

  /// An entry can be edited only on the day it belongs to.
  static bool canEdit(GratitudeEntry entry, DateTime now) {
    return entry.dateKey == dateKey(now);
  }

  /// The most recent entry before today.
  static GratitudeEntry? previousEntry(
    Iterable<GratitudeEntry> entries,
    DateTime now,
  ) {
    final String today = dateKey(now);
    GratitudeEntry? best;
    for (final GratitudeEntry entry in entries) {
      if (entry.dateKey.compareTo(today) >= 0) {
        continue;
      }
      if (best == null || entry.dateKey.compareTo(best.dateKey) > 0) {
        best = entry;
      }
    }
    return best;
  }

  /// "Yesterday", or the date such as "3 Oct" (with the year if it is not
  /// this year).
  static String dayLabel(String key, DateTime now) {
    final DateTime? date = dateFromKey(key);
    if (date == null) {
      return key;
    }
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
    if (date == yesterday) {
      return 'Yesterday';
    }
    if (date == today) {
      return 'Today';
    }
    return longDate(date, now);
  }

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String longDate(DateTime date, DateTime now) {
    final String base = '${date.day} ${_months[date.month - 1]}';
    return date.year == now.year ? base : '$base ${date.year}';
  }

  /// The entries in date order, oldest first.
  static List<GratitudeEntry> sorted(Iterable<GratitudeEntry> entries) {
    final List<GratitudeEntry> list = entries.toList();
    list.sort((GratitudeEntry a, GratitudeEntry b) {
      return a.dateKey.compareTo(b.dateKey);
    });
    return list;
  }
}
