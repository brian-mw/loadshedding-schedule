import 'package:shared_preferences/shared_preferences.dart';

/// shared_preferences-backed storage for the always-visible status
/// notification's two settings: whether it's shown at all, and whether it's
/// persistent (can't be swiped away) or an ordinary dismissable notification.
class NotificationPrefsStore {
  static const _enabledKey = 'status_notification_enabled_v1';
  static const _persistentKey = 'status_notification_persistent_v1';
  static const _leadTimeKey = 'transition_lead_minutes_v1';
  static const defaultLeadMinutes = 60;
  /// Sentinel value meaning "transition alerts are off".
  static const offLeadMinutes = -1;

  Future<int> loadLeadMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_leadTimeKey) ?? defaultLeadMinutes;
  }

  Future<void> saveLeadMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_leadTimeKey, minutes);
  }

  Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> saveEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<bool> loadPersistent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_persistentKey) ?? false;
  }

  Future<void> savePersistent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_persistentKey, value);
  }
}
