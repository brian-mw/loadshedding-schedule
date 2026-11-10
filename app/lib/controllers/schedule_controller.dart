import 'dart:async';
import 'package:get/get.dart';

import '../data/api_repository.dart';
import '../data/device_id_store.dart';
import '../data/notification_prefs_store.dart';
import '../data/saved_locations_store.dart';
import '../data/schedule_cache_store.dart';
import '../data/self_report_store.dart';
import '../models/power_window.dart';
import '../notifications/notification_scheduler.dart';
import '../platform/app_icon.dart';

class ScheduleController extends GetxController {
  final ApiRepository _api = ApiRepository();
  final NotificationScheduler _notifications = NotificationScheduler();
  final NotificationPrefsStore _notificationPrefs = NotificationPrefsStore();
  final DeviceIdStore _deviceIdStore = DeviceIdStore();
  final SelfReportStore _selfReportStore = SelfReportStore();
  final ScheduleCacheStore _scheduleCache = ScheduleCacheStore();

  /// How long a cached schedule is trusted before fetching a fresh one -
  /// ESCOM's published programme doesn't change more often than this.
  static const _scheduleFreshFor = Duration(days: 1);

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
  final RxInt transitionLeadMinutes =
      NotificationPrefsStore.defaultLeadMinutes.obs;
  // Tracks each location's last-notified on/off state, so the status
  // notification only re-posts when the status actually changes, not on
  // every 30s tick/data refresh.
  final Map<String, bool> _lastNotifiedOn = {};
  List<SavedLocation> _knownLocations = [];

  int _ticksSincePoll = 0;

  @override
  void onInit() {
    super.onInit();
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      now.value = DateTime.now();
      // Cheap, cache-only recheck so a schedule-driven transition (the
      // moment `now` crosses a window boundary) gets its notification
      // within 30s instead of waiting for the location list to change.
      _refreshStatusNotifications();
      _syncAppIcon();
      // A slower full refetch alongside it, so a transition someone else
      // reported (community status) is also picked up without the user
      // having to add/remove a location to force a reload.
      if (++_ticksSincePoll >= 4) {
        _ticksSincePoll = 0;
        if (_knownLocations.isNotEmpty) refreshFor(_knownLocations);
      }
    });
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    statusNotificationsEnabled.value = await _notificationPrefs.loadEnabled();
    statusNotificationsPersistent.value = await _notificationPrefs
        .loadPersistent();
    transitionLeadMinutes.value = await _notificationPrefs.loadLeadMinutes();
  }

  Future<void> setTransitionLeadMinutes(int minutes) async {
    transitionLeadMinutes.value = minutes;
    await _notificationPrefs.saveLeadMinutes(minutes);
    // Re-schedule every known location's reminders at the new lead time,
    // rather than waiting for the next natural data refresh.
    for (final loc in _knownLocations) {
      final windows = windowsByGroup[loc.groupCode];
      if (windows == null) continue;
      await _notifications.rescheduleFor(
        label: loc.displayName,
        notificationIdBase: loc.groupCode.hashCode & 0x7fffffff,
        powerWindows: windows,
        leadTime: Duration(minutes: minutes),
      );
    }
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
      final isOn = effectiveIsOn(loc);
      final key = loc.groupCode;
      final previous = _lastNotifiedOn[key];
      final changed = previous != isOn;
      if (!changed && !force) continue;
      _lastNotifiedOn[key] = isOn;
      await _notifications.showStatusNotification(
        id: _statusId(loc),
        title: '${loc.displayName} · ${isOn ? 'Lights on' : 'Blackout'}',
        body: isOn ? 'All good' : 'Power is currently off',
        persistent: statusNotificationsPersistent.value,
        isOn: isOn,
      );
      // A real OFF -> ON transition earns its own alert (sound/heads-up),
      // not just a silent update to the ongoing status notification - the
      // scheduled lead-time reminder only warns ahead of the *published*
      // schedule, which this app elsewhere admits can be wrong.
      if (changed && !force && previous == false && isOn) {
        await _notifications.showTransitionAlert(
          id: _statusId(loc) + 1,
          title: '${loc.displayName} - power is back on',
          body: 'Lights are back on.',
        );
      }
    }
  }

  // What was last handed to the launcher icon, so the 30s tick only talks
  // to the platform when something actually changed.
  String? _lastIconSignature;

  /// Keeps the launcher icon (a lit or unlit bulb) in step with the primary
  /// - first saved - location, including the schedule's upcoming changes so
  /// the icon can keep flipping while the app is closed.
  Future<void> _syncAppIcon() async {
    if (_knownLocations.isEmpty) return;
    final primary = _knownLocations.first;
    final windows = windowsByGroup[primary.groupCode];
    if (windows == null) return;
    final lit = effectiveIsOn(primary);
    final t = DateTime.now();
    final upcoming = windows.where((w) => w.startDateTime.isAfter(t)).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    final transitions = <(DateTime, bool)>[];
    var state = lit;
    for (final w in upcoming) {
      if (w.isOn == state) continue;
      transitions.add((w.startDateTime, w.isOn));
      state = w.isOn;
    }
    final signature = [
      lit,
      for (final t in transitions) '${t.$1.millisecondsSinceEpoch}:${t.$2}',
    ].join('|');
    if (signature == _lastIconSignature) return;
    _lastIconSignature = signature;
    await AppIcon.update(lit: lit, transitions: transitions);
  }

  @override
  void onClose() {
    _tickTimer?.cancel();
    super.onClose();
  }

  Future<void> refreshFor(List<SavedLocation> locations) async {
    if (locations.isEmpty) {
      // Nothing to follow any more - back to the default lit bulb.
      _knownLocations = [];
      _lastIconSignature = null;
      await AppIcon.update(lit: true, transitions: const []);
      return;
    }
    _knownLocations = locations;
    isLoading.value = true;
    try {
      final from = DateTime.now().subtract(const Duration(hours: 12));
      final to = DateTime.now().add(const Duration(days: 7));
      for (final loc in locations) {
        // Serve the cached schedule immediately, before even checking
        // staleness, so a cold start never has to wait on the network for
        // data it already has.
        if (!windowsByGroup.containsKey(loc.groupCode)) {
          final cached = await _scheduleCache.load(loc.groupCode);
          if (cached != null) windowsByGroup[loc.groupCode] = cached;
        }

        final lastFetched = await _scheduleCache.fetchedAt(loc.groupCode);
        final stale =
            lastFetched == null ||
            DateTime.now().difference(lastFetched) >= _scheduleFreshFor;
        if (stale) {
          try {
            final windows = await _api.getPowerWindows(
              subgroup: loc.groupCode,
              from: from,
              to: to,
            );
            windowsByGroup[loc.groupCode] = windows;
            await _scheduleCache.save(loc.groupCode, windows);
            await _notifications.rescheduleFor(
              label: loc.displayName,
              notificationIdBase: loc.groupCode.hashCode & 0x7fffffff,
              powerWindows: windows,
              leadTime: Duration(minutes: transitionLeadMinutes.value),
            );
          } catch (_) {
            // Keep showing cached data rather than erroring the screen -
            // ESCOM's schedule rarely changes mid-week, so a failed refresh
            // here isn't urgent.
          }
        }

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
      await _syncAppIcon();
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
    await _refreshStatusNotifications();
    await _syncAppIcon();
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

  /// The next time the status will actually differ from [currentIsOn].
  /// Windows don't necessarily alternate every slot (several ON slots can
  /// run back-to-back), so this searches past same-status slots instead of
  /// just using the current window's end time.
  DateTime? nextTransitionFor(String groupCode, bool currentIsOn) {
    final windows = windowsByGroup[groupCode];
    if (windows == null) return null;
    final t = now.value;
    final upcoming = windows.where((w) => w.endDateTime.isAfter(t)).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    for (final w in upcoming) {
      if (w.isOn != currentIsOn) return w.startDateTime;
    }
    return null;
  }
}
