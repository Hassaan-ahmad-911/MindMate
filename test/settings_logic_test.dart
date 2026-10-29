import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Data/repositories/settings_repository.dart';
import 'package:mindmate/Models/theme_preferences.dart';
import 'package:mindmate/Models/user_settings.dart';
import 'package:mindmate/services/account_data_service.dart';
import 'package:mindmate/services/account_deletion_service.dart';
import 'package:mindmate/services/data_export_service.dart';
import 'package:mindmate/ui/app/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/settings_fakes.dart';

void main() {
  group('Default settings', () {
    test('the mood reminder follows the first check-in answer', () {
      ReminderSlot mood(String? pref) =>
          UserSettings.defaults(reminderPreference: pref).reminders.mood;
      expect(mood('before_shift').on, isTrue);
      expect(mood('before_shift').time, '07:00');
      expect(mood('after_shift').time, '19:30');
      expect(mood('evening').time, '20:00');
      expect(mood('evening').on, isTrue);
      expect(mood('none').on, isFalse);
      expect(mood(null).on, isTrue);
    });

    test('everything else starts from the defaults', () {
      final UserSettings s = UserSettings.defaults();
      expect(s.reminders.journal.on, isFalse);
      expect(s.reminders.journal.time, '21:00');
      expect(s.reminders.practice.time, '07:30');
      expect(s.reminders.checkinsDue.on, isTrue);
      expect(s.reminders.days, <int>[1, 2, 3, 4, 5, 6, 7]);
      expect(s.reminders.quietHours.on, isFalse);
      expect(s.hideReminderText, isFalse);
      expect(s.meditationSound, 'off');
      expect(s.meditationSoundVolume, 0.25);
      final Map<String, dynamic> map = s.toMap();
      expect(
        (map['reminders'] as Map<String, dynamic>)['checkinsDue'],
        <String, dynamic>{'on': true},
      );
      expect(UserSettings.fromMap(map, UserSettings.defaults()).toMap(), map);
    });
  });

  group('Reminders', () {
    test('at least one day must remain', () {
      final ReminderSettings r = UserSettings.defaults().reminders.copyWith(
        days: <int>[3],
      );
      expect(r.toggleDay(3), isNull);
      expect(r.toggleDay(5), <int>[3, 5]);
      expect(UserSettings.defaults().reminders.toggleDay(1), <int>[
        2,
        3,
        4,
        5,
        6,
        7,
      ]);
    });

    test('quiet hours can cross midnight', () {
      const QuietHours night = QuietHours(
        on: true,
        start: '23:00',
        end: '07:00',
      );
      expect(night.covers('23:00'), isTrue);
      expect(night.covers('02:30'), isTrue);
      expect(night.covers('06:59'), isTrue);
      expect(night.covers('07:00'), isFalse);
      expect(night.covers('22:59'), isFalse);
      const QuietHours day = QuietHours(on: true, start: '13:00', end: '15:00');
      expect(day.covers('14:00'), isTrue);
      expect(day.covers('15:00'), isFalse);
      expect(night.copyWith(on: false).covers('02:30'), isFalse);
    });

    test('the summary on the Settings row', () {
      UserSettings s = UserSettings.defaults();
      expect(s.remindersSummary, 'Mood at 20:00');
      final ReminderSettings r = s.reminders;
      s = s.copyWith(
        reminders: r.copyWith(
          mood: r.mood.copyWith(on: false),
          journal: r.journal.copyWith(on: true),
        ),
      );
      expect(s.remindersSummary, 'Journal at 21:00');
      s = s.copyWith(
        reminders: s.reminders.copyWith(
          journal: r.journal.copyWith(on: false),
          checkinsDue: const ReminderSlot(on: false),
        ),
      );
      expect(s.remindersSummary, 'Off');
    });
  });

  group('Settings repository', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('first load creates the settings from the defaults', () async {
      final FakeSettingsService service = FakeSettingsService(
        userDoc: <String, dynamic>{'reminderPreference': 'after_shift'},
      );
      final UserSettings s = await SettingsRepository(service).load();
      expect(service.creates, 1);
      expect(s.reminders.mood.time, '19:30');
      expect(
        ((service.userDoc['settings'] as Map)['reminders'] as Map)['mood'],
        <String, dynamic>{'on': true, 'time': '19:30'},
      );
    });

    test('a sound saved on the phone moves into the settings map', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'meditation_ambient_uid-1': 'soft_rain',
        'meditation_ambient_volume_uid-1': 0.4,
      });
      final FakeSettingsService service = FakeSettingsService();
      final UserSettings s = await SettingsRepository(service).load();
      expect(s.meditationSound, 'soft_rain');
      expect(s.meditationSoundVolume, 0.4);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('meditation_ambient_uid-1'), isNull);
    });

    test('each change writes one field with update', () async {
      final FakeSettingsService service = FakeSettingsService(
        userDoc: <String, dynamic>{'settings': UserSettings.defaults().toMap()},
      );
      final SettingsRepository repo = SettingsRepository(service);
      await repo.setReminderTime('mood', '21:15');
      await repo.setReminderOn('journal', true);
      await repo.setQuietHoursStart('22:30');
      await repo.setHideReminderText(true);
      await repo.setMeditationSound('warm_tones');
      expect(service.creates, 0);
      expect(
        service.updates.map((MapEntry<String, Object?> e) => e.key),
        <String>[
          'reminders.mood.time',
          'reminders.journal.on',
          'reminders.quietHours.start',
          'hideReminderText',
          'meditationSound',
        ],
      );
      final UserSettings s = await repo.load();
      expect(s.reminders.mood.time, '21:15');
      expect(s.reminders.journal.on, isTrue);
      expect(s.meditationSound, 'warm_tones');
    });

    test('removing the last day saves nothing', () async {
      final Map<String, dynamic> map = UserSettings.defaults().toMap();
      (map['reminders'] as Map<String, dynamic>)['days'] = <int>[2];
      final FakeSettingsService service = FakeSettingsService(
        userDoc: <String, dynamic>{'settings': map},
      );
      final SettingsRepository repo = SettingsRepository(service);
      expect(await repo.toggleDay(2), isNull);
      expect(service.updates, isEmpty);
      expect((await repo.toggleDay(4))!.reminders.days, <int>[2, 4]);
    });
  });

  group('Theme mode', () {
    final DateTime noon = DateTime(2026, 10, 10, 12);
    Brightness resolve(
      AppThemeMode mode, {
      Brightness phone = Brightness.light,
      bool sunset = false,
      DateTime? at,
    }) => ThemeResolver.resolve(
      mode,
      darkAfterSunset: sunset,
      platform: phone,
      now: at ?? noon,
    );

    test('light, dark and system with the phone in each mode', () {
      expect(
        resolve(AppThemeMode.light, phone: Brightness.dark),
        Brightness.light,
      );
      expect(resolve(AppThemeMode.dark), Brightness.dark);
      expect(resolve(AppThemeMode.system), Brightness.light);
      expect(
        resolve(AppThemeMode.system, phone: Brightness.dark),
        Brightness.dark,
      );
    });

    test('dark after sunset at 18:59, 19:00, 06:59 and 07:00', () {
      DateTime at(int h, int m) => DateTime(2026, 10, 10, h, m);
      expect(
        resolve(AppThemeMode.light, sunset: true, at: at(18, 59)),
        Brightness.light,
      );
      expect(
        resolve(AppThemeMode.light, sunset: true, at: at(19, 0)),
        Brightness.dark,
      );
      expect(
        resolve(AppThemeMode.light, sunset: true, at: at(6, 59)),
        Brightness.dark,
      );
      expect(
        resolve(AppThemeMode.light, sunset: true, at: at(7, 0)),
        Brightness.light,
      );
      expect(
        resolve(
          AppThemeMode.system,
          phone: Brightness.light,
          sunset: true,
          at: at(23, 0),
        ),
        Brightness.dark,
      );
    });

    test('the next switch time and the footer', () {
      expect(
        ThemeResolver.nextBoundary(DateTime(2026, 10, 10, 12)),
        DateTime(2026, 10, 10, 19),
      );
      expect(
        ThemeResolver.nextBoundary(DateTime(2026, 10, 10, 20)),
        DateTime(2026, 10, 11, 7),
      );
      expect(
        ThemeResolver.footer(
          AppThemeMode.system,
          darkAfterSunset: false,
          platform: Brightness.dark,
          now: noon,
        ),
        'Your phone is in dark mode, so MindMate is dark too.',
      );
      expect(AppThemeMode.fromId('nonsense'), AppThemeMode.system);
    });
  });

  group('Download my data', () {
    test('has every collection and no Firestore types', () async {
      final FakeAccountData data = FakeAccountData();
      data.user = <String, dynamic>{
        'name': 'Ayesha',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1, 8)),
        'settings': <String, dynamic>{'hideReminderText': true},
      };
      data.collections['moods'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'm1',
          'mood': 'Calm',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
          'where': const GeoPoint(1, 2),
        },
      ];
      data.legacy = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'old', 'content': 'Old entry'},
      ];
      final Map<String, dynamic> out = await DataExportService(
        data,
        clock: () => DateTime(2026, 10, 10, 9),
      ).collect();

      for (final String name in AccountDataBackend.subcollections) {
        expect(out.containsKey(name), isTrue, reason: name);
      }
      expect(out['settings'], <String, dynamic>{'hideReminderText': true});
      expect((out['profile'] as Map).containsKey('settings'), isFalse);
      expect(
        (out['moods'] as List).single['createdAt'],
        '2026-10-01T00:00:00.000Z',
      );
      expect((out['journals'] as List).single['id'], 'old');
      // Plain JSON all the way down.
      expect(() => jsonEncode(out), returnsNormally);
      expect(jsonEncode(out).contains('Timestamp'), isFalse);
      expect(
        DataExportService.fileName(DateTime(2026, 10, 10)),
        'MindMate-data-2026-10-10.json',
      );
    });
  });

  group('Deleting an account', () {
    AccountDeletionService build(FakeAccountData data, List<String> log) =>
        AccountDeletionService(
          data: data,
          deleteAuthUser: () async => log.add('deleteAuthUser'),
          signOutGoogle: () async => log.add('signOutGoogle'),
          clearLocalSettings: (String uid) async => log.add('clearLocal:$uid'),
        );

    test('runs every step in order', () async {
      final FakeAccountData data = FakeAccountData();
      final List<String> log = <String>[];
      await build(data, log).deleteAccount();
      expect(data.calls, <String>[
        for (final String n in AccountDataBackend.subcollections)
          'deleteSubcollection:$n',
        'deleteLegacyJournals',
        'deleteProfilePhoto',
        'deleteUserDocument',
      ]);
      expect(log, <String>[
        'deleteAuthUser',
        'signOutGoogle',
        'clearLocal:uid-1',
      ]);
    });

    test('stops at a failed step, and running again finishes it', () async {
      final FakeAccountData data = FakeAccountData()
        ..failOn = 'deleteProfilePhoto';
      data.collections['moods'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'a'},
      ];
      final List<String> log = <String>[];

      await expectLater(
        build(data, log).deleteAccount(),
        throwsA(
          isA<AccountDeletionException>().having(
            (AccountDeletionException e) => e.step,
            'step',
            DeletionStep.profilePhoto,
          ),
        ),
      );
      expect(data.user, isNotNull, reason: 'the profile is kept');
      expect(log, isEmpty, reason: 'still signed in');

      await build(data, log).deleteAccount();
      expect(data.user, isNull);
      expect(log.first, 'deleteAuthUser');
    });
  });

  test('the version shown matches pubspec.yaml', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String version = RegExp(
      r'^version:\s*([0-9.]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    expect(AppInfo.version, version);
  });
}
