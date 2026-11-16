import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/power_window.dart';

/// Schedules local notifications for upcoming ON/OFF transitions. Entirely
/// client-side: no push/FCM backend needed, since the app re-schedules
/// notifications for the known-ahead windows whenever it refreshes data from
/// the API.
class NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (kIsWeb) return;
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // Status-bar icon must be a plain white silhouette, not the full-colour
    // launcher icon - Android renders the latter muddy there.
    const androidInit = AndroidInitializationSettings('ic_stat_notify');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );
    // Deliberately does NOT request the exact-alarm permission here: that
    // request always force-navigates the user to a system Settings screen
    // (there's no in-app dialog for it), which would happen on every single
    // cold start as long as it's ungranted - a bad first-run experience.
    // rescheduleFor() below checks current permission state and falls back
    // to inexact scheduling when it isn't granted; a future "enable precise
    // alerts" toggle in Settings is the right place to call
    // requestExactAlarmsPermission() explicitly, as a deliberate user action.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  /// Cancels this location's previously-scheduled notifications and schedules
  /// new ones for its next upcoming transitions within [powerWindows].
  Future<void> rescheduleFor({
    required String label,
    required int notificationIdBase,
    required List<PowerWindow> powerWindows,
    required Duration leadTime,
  }) async {
    if (kIsWeb) return;
    await init();
    // Cancel this location's slice of the id space (10 slots reserved/location).
    for (var i = 0; i < 10; i++) {
      await _plugin.cancel(id: notificationIdBase + i);
    }
    // A negative lead time is the sentinel for "alerts off" - leave the
    // slots cancelled above and schedule nothing new.
    if (leadTime.isNegative) return;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final now = DateTime.now();
    final sorted = [...powerWindows]
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    var slot = 0;
    for (final window in sorted) {
      if (slot >= 10) break;
      final fireAt = window.startDateTime.subtract(leadTime);
      if (fireAt.isBefore(now)) continue;

      final verb = window.isOn ? 'back on' : 'going off';
      await _plugin.zonedSchedule(
        id: notificationIdBase + slot,
        title: 'Power $verb soon - $label',
        body:
            'Expected ${window.isOn ? "ON" : "OFF"} at '
            '${window.startDateTime.hour.toString().padLeft(2, '0')}:'
            '${window.startDateTime.minute.toString().padLeft(2, '0')}',
        scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'power_transitions',
            'Power transitions',
            channelDescription: 'Upcoming ON/OFF schedule reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: scheduleMode,
      );
      slot++;
    }
  }

  /// Shows (or, called again with the same [id], updates in place) the
  /// always-visible current-status notification. `onlyAlertOnce` so
  /// refreshing it on every status change doesn't re-alert like a new
  /// notification each time - it's a status display, not an interrupt.
  /// [persistent] controls whether the user can swipe it away; [isOn] drives
  /// the colourised accent (amber for on, red for a blackout) and large icon
  /// so it reads at a glance instead of blending into the rest of the shade.
  Future<void> showStatusNotification({
    required int id,
    required String title,
    required String body,
    required bool persistent,
    required bool isOn,
  }) async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'power_status',
          'Power status',
          channelDescription: 'Always-visible current power status',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: persistent,
          autoCancel: !persistent,
          onlyAlertOnce: true,
          category: AndroidNotificationCategory.status,
          visibility: NotificationVisibility.public,
          color: isOn ? const Color(0xFFD98A1C) : const Color(0xFFB3261E),
          colorized: true,
          largeIcon: const DrawableResourceAndroidBitmap(
            'ic_launcher_foreground',
          ),
          styleInformation: BigTextStyleInformation(body, contentTitle: title),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: false),
      ),
    );
  }

  /// Fires a one-off alert (sound/heads-up) the moment a location's status
  /// actually flips - distinct from [showStatusNotification]'s silent,
  /// `onlyAlertOnce` update to the ongoing status entry.
  Future<void> showTransitionAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'power_transitions',
          'Power transitions',
          channelDescription: 'Upcoming ON/OFF schedule reminders',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelStatusNotification(int id) => _plugin.cancel(id: id);
}
