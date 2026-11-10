import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/location_entry.dart';
import '../models/power_window.dart';

class CommunityStatus {
  final bool? isOn;
  final int reporterCount;
  final bool official;

  CommunityStatus({
    required this.isOn,
    required this.reporterCount,
    required this.official,
  });

  factory CommunityStatus.fromJson(Map<String, dynamic> json) =>
      CommunityStatus(
        isOn: switch (json['status']) {
          'ON' => true,
          'OFF' => false,
          _ => null,
        },
        reporterCount: json['reporterCount'] as int,
        official: json['official'] as bool,
      );
}

class ApiRepository {
  Future<List<LocationEntry>> searchLocations(String query) async {
    final uri = Uri.parse(
      '$kApiBaseUrl/locations/search',
    ).replace(queryParameters: {'q': query});
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('search failed: ${resp.statusCode}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .map((e) => LocationEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PowerWindow>> getPowerWindows({
    required String subgroup,
    required DateTime from,
    required DateTime to,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/power-windows').replace(
      queryParameters: {
        'subgroup': subgroup,
        'from': _isoDate(from),
        'to': _isoDate(to),
      },
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('power-windows failed: ${resp.statusCode}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .map((e) => PowerWindow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>?> getLatestProgramme() async {
    final uri = Uri.parse('$kApiBaseUrl/programmes/latest');
    final resp = await http.get(uri);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw Exception('programmes/latest failed: ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<CommunityStatus> getCommunityStatus({
    required String location,
    required String groupCode,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/status-reports').replace(
      queryParameters: {'location': location, 'groupCode': groupCode},
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('status-reports failed: ${resp.statusCode}');
    }
    return CommunityStatus.fromJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  Future<CommunityStatus> submitStatusReport({
    required String location,
    required String groupCode,
    required String deviceId,
    required bool isOn,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/status-reports');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'location': location,
        'groupCode': groupCode,
        'deviceId': deviceId,
        'status': isOn ? 'ON' : 'OFF',
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('status-reports post failed: ${resp.statusCode}');
    }
    return CommunityStatus.fromJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
