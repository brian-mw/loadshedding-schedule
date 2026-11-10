import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists this device's own last crowd-status report per location, so a
/// report that hasn't yet reached community consensus still immediately (and
/// durably, across app restarts) updates what *this* device shows - "just
/// update their personal device" until it either expires or gets superseded
/// by an official community status.
class SelfReportStore {
  static const _key = 'self_reports_v1';
  static const freshness = Duration(hours: 2);

  Future<Map<String, _SelfReport>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map(
      (k, v) => MapEntry(k, _SelfReport.fromJson(v as Map<String, dynamic>)),
    );
  }

  Future<void> _save(Map<String, _SelfReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(reports.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  String _keyFor(String location, String groupCode) => '$location|$groupCode';

  Future<void> save({
    required String location,
    required String groupCode,
    required bool isOn,
  }) async {
    final reports = await _load();
    reports[_keyFor(location, groupCode)] = _SelfReport(
      isOn: isOn,
      reportedAt: DateTime.now(),
    );
    await _save(reports);
  }

  /// Returns this device's own report for the location if one exists and is
  /// still within the freshness window, otherwise null.
  Future<bool?> currentFor(String location, String groupCode) async {
    final reports = await _load();
    final report = reports[_keyFor(location, groupCode)];
    if (report == null) return null;
    if (DateTime.now().difference(report.reportedAt) > freshness) return null;
    return report.isOn;
  }
}

class _SelfReport {
  final bool isOn;
  final DateTime reportedAt;

  _SelfReport({required this.isOn, required this.reportedAt});

  Map<String, dynamic> toJson() => {
    'isOn': isOn,
    'reportedAt': reportedAt.toIso8601String(),
  };

  factory _SelfReport.fromJson(Map<String, dynamic> json) => _SelfReport(
    isOn: json['isOn'] as bool,
    reportedAt: DateTime.parse(json['reportedAt'] as String),
  );
}
