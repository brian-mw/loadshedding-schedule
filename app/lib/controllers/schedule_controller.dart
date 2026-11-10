import 'dart:async';
import 'package:get/get.dart';

import '../data/api_repository.dart';
import '../data/device_id_store.dart';
import '../data/notification_prefs_store.dart';
import '../data/saved_locations_store.dart';
import '../data/self_report_store.dart';
import '../models/power_window.dart';
import '../notifications/notification_scheduler.dart';

class ScheduleController extends GetxController {
  final ApiRepository _api = ApiRepository();
  final NotificationScheduler _notifications = NotificationScheduler();
  final NotificationPrefsStore _notificationPrefs = NotificationPrefsStore();
  final DeviceIdStore _deviceIdStore = DeviceIdStore();
  final SelfReportStore _selfReportStore = SelfReportStore();

  // location|groupCode -> community-confirmed status, refreshed alongside
  // the schedule data.
  final Map<String, CommunityStatus> _communityStatus = {};
  // location|groupCode -> this device's own unexpired self-report.
  final Map<String, bool?> _selfReport = {};

  /// groupCode -> this week's windows, keyed so each saved location's detail
  /// screen can reuse data already fetched for the home screen.
  final RxMap<String, List<PowerWindow>> windowsByGroup =
      <String, List<PowerWindow>>{}.obs;
  final RxBool isLoading = false.obs;
  Timer? _tickTimer;
  final Rx<DateTime> now = DateTime.now().obs;

  final RxBool statusNotificationsEnabled = false.obs;
  final RxBool statusNotificationsPersistent = false.obs;
  // Tracks each location's last-notified on/off state, so the status
  // notification only re-posts when the status actually changes, not on
  // every 30s tick/data refresh.
  final Map<String, bool> _lastNotifiedOn = {};
  List<SavedLocation> _knownLocations = [];

  @override
  void onInit() {
    super.onInit();
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      now.value = DateTime.now();
    });
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    statusNotificationsEnabled.value = await _notificationPrefs.loadEnabled();
    statusNotificationsPersistent.value = await _notificationPrefs
        .loadPersistent();
  }

  Future<void> setStatusNotificationsEnabled(bool value) async {
    statusNotificationsEnabled.value = value;
    await _notificationPrefs.saveEnabled(value);
    if (value) {
      await _refreshStatusNotifications(force: true);
    } else {
      for (final loc in _knownLocations) {
        await _notifications.cancelStatusNotification(_statusId(loc));
      }
      _lastNotifiedOn.clear();
    }
  }

  Future<void> setStatusNotificationsPersistent(bool value) async {
    statusNotificationsPersistent.value = value;
    await _notificationPrefs.savePersistent(value);
    if (statusNotificationsEnabled.value) {
      await _refreshStatusNotifications(force: true);
    }
  }

  int _statusId(SavedLocation location) =>
      (location.groupCode.hashCode & 0x7fffffff) + 500;

  Future<void> _refreshStatusNotifications({bool force = false}) async {
    if (!statusNotificationsEnabled.value) return;
    for (final loc in _knownLocations) {
      final isOn = currentWindowFor(loc.groupCode)?.isOn ?? true;
      final key = loc.groupCode;
      final changed = _lastNotifiedOn[key] != isOn;
      if (!changed && !force) continue;
      _lastNotifiedOn[key] = isOn;
      await _notifications.showStatusNotification(
        id: _statusId(loc),
        title: '${loc.displayName} · ${isOn ? 'Lights on' : 'Blackout'}',
        body: isOn ? 'Supply normal' : 'Power is currently off',
        persistent: statusNotificationsPersistent.value,
        isOn: isOn,
      );
    }
  }

  @override
  void onClose() {
    _tickTimer?.cancel();
    super.onClose();
  }

  Future<void> refreshFor(List<SavedLocation> locations) async {
    if (locations.isEmpty) return;
    _knownLocations = locations;
    isLoading.value = true;
    try {
      final from = DateTime.now().subtract(const Duration(hours: 12));
      final to = DateTime.now().add(const Duration(days: 7));
      for (final loc in locations) {
        final windows = await _api.getPowerWindows(
          subgroup: loc.groupCode,
          from: from,
          to: to,
        );
        windowsByGroup[loc.groupCode] = windows;
        await _notifications.rescheduleFor(
          label: loc.displayName,
          notificationIdBase: loc.groupCode.hashCode & 0x7fffffff,
          powerWindows: windows,
          leadTime: const Duration(minutes: 15),
        );

        final key = _reportKey(loc);
        _selfReport[key] = await _selfReportStore.currentFor(
          loc.label,
          loc.groupCode,
        );
        try {
          final community = await _api.getCommunityStatus(
            location: loc.label,
            groupCode: loc.groupCode,
          );
          _communityStatus[key] = community;
        } catch (_) {
          // Crowd status is a nice-to-have overlay on top of the schedule -
          // if the API call fails, just fall through to the other layers.
        }
      }
      await _refreshStatusNotifications();
    } finally {
      isLoading.value = false;
    }
  }

  String _reportKey(SavedLocation loc) => '${loc.label}|${loc.groupCode}';

  /// Layers, highest priority first: an official community-confirmed status,
  /// then this device's own unexpired report, then the schedule's guess.
  bool effectiveIsOn(SavedLocation loc) {
    final community = _communityStatus[_reportKey(loc)];
    if (community != null && community.official && community.isOn != null) {
      return community.isOn!;
    }
    final selfReport = _selfReport[_reportKey(loc)];
    if (selfReport != null) return selfReport;
    return currentWindowFor(loc.groupCode)?.isOn ?? true;
  }

  Future<CommunityStatus> reportStatus(SavedLocation loc, bool isOn) async {
    final deviceId = await _deviceIdStore.load();
    final result = await _api.submitStatusReport(
      location: loc.label,
      groupCode: loc.groupCode,
      deviceId: deviceId,
      isOn: isOn,
    );
    await _selfReportStore.save(
      location: loc.label,
      groupCode: loc.groupCode,
      isOn: isOn,
    );
    final key = _reportKey(loc);
    _selfReport[key] = isOn;
    _communityStatus[key] = result;
    windowsByGroup.refresh();
    return result;
  }

  PowerWindow? currentWindowFor(String groupCode) {
    final windows = windowsByGroup[groupCode];
    if (windows == null) return null;
    final t = now.value;
    for (final w in windows) {
      if (!t.isBefore(w.startDateTime) && t.isBefore(w.endDateTime)) {
        return w;
      }
    }
    return null;
  }

  PowerWindow? nextWindowFor(String groupCode) {
    final windows = windowsByGroup[groupCode];
    if (windows == null) return null;
    final t = now.value;
    final upcoming = windows.where((w) => w.startDateTime.isAfter(t)).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }
}
