import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// One notification to schedule or show. [text] is already worded (or
/// hidden); nothing here is ever logged.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
    this.hidden = false,
    this.replacedAfter,
  });

  final int id;

  /// Local time.
  final DateTime at;
  final String title;
  final String body;
  final String payload;
  final bool hidden;

  /// When the next reminder is due: this one is taken off the screen then,
  /// so only one MindMate reminder shows at a time (Android).
  final Duration? replacedAfter;
}

/// Whether the phone lets MindMate show notifications.
enum ReminderPermission { enabled, blocked, notAsked }

/// The only class that talks to the notification plugin.
abstract class ReminderScheduler {
  /// Sets up the plugin and the time zone. [onTap] gets a tapped
  /// reminder's payload while the app runs.
  Future<void> init({required void Function(String? payload) onTap});

  /// The payload of the reminder that opened the app, if any.
  Future<String?> launchPayload();

  /// Cancels every pending and shown MindMate reminder and schedules these.
  Future<void> replaceAll(List<ScheduledReminder> reminders);

  Future<void> cancelAll();

  /// Shows [reminder] at once (the test reminder).
  Future<void> showNow(ScheduledReminder reminder);

  /// Whether notifications are allowed. Null when it cannot be told.
  Future<bool?> notificationsEnabled();

  /// Asks the phone; true when allowed.
  Future<bool> requestPermission();

  Future<void> openSettings();
}

/// [ReminderScheduler] with `flutter_local_notifications`.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  String? _zone;

  static const String channelId = 'gentle_reminders';
  static const String channelName = 'Gentle reminders';
  static const String channelDescription =
      'Reminders at the times you chose in MindMate.';

  /// The same tag and thread for every reminder, so they replace and stack
  /// as one.
  static const String tag = 'mindmate_reminder';
  static const String thread = 'mindmate_reminders';
  static const String smallIcon = 'ic_stat_mindmate';

  @override
  Future<void> init({required void Function(String? payload) onTap}) async {
    if (_ready || kIsWeb) {
      return;
    }
    await _setZone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(smallIcon),
        // Permission is asked only on the "Gentle reminders" page.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse r) =>
          onTap(r.payload),
    );
    _ready = true;
  }

  /// The phone's time zone, again each time (it may have changed).
  Future<void> _setZone() async {
    tz_data.initializeTimeZones();
    try {
      final String zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      if (zone != _zone) {
        tz.setLocalLocation(tz.getLocation(zone));
        _zone = zone;
      }
    } catch (_) {
      // Unknown zone name: the plugin's default (UTC) is used.
    }
  }

  @override
  Future<String?> launchPayload() async {
    if (kIsWeb) {
      return null;
    }
    final NotificationAppLaunchDetails? details = await _plugin
        .getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) {
      return null;
    }
    return details?.notificationResponse?.payload;
  }

  NotificationDetails _details(ScheduledReminder r) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        icon: smallIcon,
        tag: tag,
        groupKey: thread,
        onlyAlertOnce: true,
        // With "Hide reminder text" on, the words are already the neutral
        // public version, so the lock screen may show them.
        visibility: r.hidden
            ? NotificationVisibility.public
            : NotificationVisibility.private,
        timeoutAfter: r.replacedAfter?.inMilliseconds,
      ),
      iOS: const DarwinNotificationDetails(threadIdentifier: thread),
    );
  }

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {
    await _setZone();
    await _plugin.cancelAll();
    for (final ScheduledReminder r in reminders) {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: _details(r),
        // A few minutes late is fine; no exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.payload,
      );
    }
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> showNow(ScheduledReminder reminder) async {
    // Only one MindMate reminder on screen.
    final List<ActiveNotification> shown = await _plugin
        .getActiveNotifications();
    for (final ActiveNotification n in shown) {
      final int? id = n.id;
      if (id != null) {
        await _plugin.cancel(id: id, tag: n.tag);
      }
    }
    await _plugin.show(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      notificationDetails: _details(reminder),
      payload: reminder.payload,
    );
  }

  @override
  Future<bool?> notificationsEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final NotificationsEnabledOptions? options = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return options?.isEnabled;
    }
    return null;
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> openSettings() async {
    await _plugin.openAppNotificationSettings();
  }
}
