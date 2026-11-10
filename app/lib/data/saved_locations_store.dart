import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedLocation {
  final String label;
  final String groupCode;
  final String region;
  // ESCOM's own location names are technical categorisations (e.g. "Area
  // 48") - an optional personal nickname shown in its place when set.
  final String? customName;

  SavedLocation({
    required this.label,
    required this.groupCode,
    required this.region,
    this.customName,
  });

  String get displayName => customName?.trim().isNotEmpty == true
      ? customName!.trim()
      : label;

  Map<String, dynamic> toJson() => {
    'label': label,
    'groupCode': groupCode,
    'region': region,
    'customName': customName,
  };

  factory SavedLocation.fromJson(Map<String, dynamic> json) => SavedLocation(
    label: json['label'] as String,
    groupCode: json['groupCode'] as String,
    region: json['region'] as String,
    customName: json['customName'] as String?,
  );
}

enum SaveResult { added, alreadySaved, limitReached }

class SaveOutcome {
  final SaveResult result;
  final List<SavedLocation> locations;
  SaveOutcome(this.result, this.locations);
}

/// shared_preferences-backed CRUD for the user's saved locations. No user
/// accounts needed for v1 - this is purely on-device state.
///
/// Capped at 2: the first saved location is "primary", the second
/// "secondary" (list order IS the primary/secondary distinction - no
/// separate flag needed). Other locations can still be searched and viewed
/// ad hoc; only saving/tracking is capped, to keep the home screen and
/// notification volume to what a personal-use app actually needs.
class SavedLocationsStore {
  static const _key = 'saved_locations_v1';
  static const maxSaved = 2;

  Future<List<SavedLocation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SavedLocation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<SavedLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(locations.map((l) => l.toJson()).toList()),
    );
  }

  Future<SaveOutcome> add(SavedLocation location) async {
    final current = await load();
    final exists = current.any(
      (l) => l.label == location.label && l.groupCode == location.groupCode,
    );
    if (exists) {
      return SaveOutcome(SaveResult.alreadySaved, current);
    }
    if (current.length >= maxSaved) {
      return SaveOutcome(SaveResult.limitReached, current);
    }
    current.add(location);
    await _save(current);
    return SaveOutcome(SaveResult.added, current);
  }

  Future<List<SavedLocation>> remove(SavedLocation location) async {
    final current = await load();
    current.removeWhere(
      (l) => l.label == location.label && l.groupCode == location.groupCode,
    );
    await _save(current);
    return current;
  }
}
