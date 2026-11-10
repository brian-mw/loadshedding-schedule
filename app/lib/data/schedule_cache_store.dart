import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/power_window.dart';

/// Caches each group's fetched schedule windows locally, so the app can show
/// the last-known schedule instantly on cold start instead of a blank or
/// skeleton state, and so the API is only actually hit roughly once a day
/// (ESCOM's published programme doesn't change more often than that) rather
/// than on every app open or periodic poll.
class ScheduleCacheStore {
  static const _windowsPrefix = 'schedule_cache_windows_v1_';
  static const _fetchedAtPrefix = 'schedule_cache_fetched_at_v1_';

  Future<List<PowerWindow>?> load(String groupCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_windowsPrefix$groupCode');
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PowerWindow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DateTime?> fetchedAt(String groupCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_fetchedAtPrefix$groupCode');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> save(String groupCode, List<PowerWindow> windows) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(windows.map((w) => w.toJson()).toList());
    await prefs.setString('$_windowsPrefix$groupCode', raw);
    await prefs.setString(
      '$_fetchedAtPrefix$groupCode',
      DateTime.now().toIso8601String(),
    );
  }
}
