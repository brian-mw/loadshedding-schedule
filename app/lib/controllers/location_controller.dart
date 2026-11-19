import 'dart:math';

import 'package:get/get.dart';

import '../data/api_repository.dart';
import '../data/saved_locations_store.dart';
import '../models/location_entry.dart';
import '../models/power_card_style.dart';

class LocationController extends GetxController {
  final ApiRepository _api = ApiRepository();
  final SavedLocationsStore _store = SavedLocationsStore();
  final _random = Random();
  // Picked fresh per app session (not persisted) the first time each saved
  // location is drawn, then kept stable for the rest of the session - varied
  // across app opens without the jarring flicker of changing mid-session.
  final Map<String, PowerCardStyle> _cardStyles = {};
  final Map<String, String> _statusPhrases = {};

  static const _onPhrases = [
    'Lights are on',
    'Power is on',
    "We've got power",
    'Electricity is on',
    'Magetsi akuyaka',
    'Akuyaka',
  ];
  static const _offPhrases = [
    'Blackout',
    'Power is off',
    'Lights are off',
    'Load shedding',
    'No power right now',
    'Magetsi Kulibe',
    'Azima Konse',
  ];

  final RxList<SavedLocation> savedLocations = <SavedLocation>[].obs;
  final RxList<LocationEntry> searchResults = <LocationEntry>[].obs;
  final RxBool isSearching = false.obs;
  final RxBool searchFailed = false.obs;
  // Bumped per search so a slow response to an older query can't overwrite
  // the results of a newer one.
  int _searchToken = 0;
  final RxBool isLoaded = false.obs;

  PowerCardStyle cardStyleFor(SavedLocation location) {
    final key = '${location.groupCode}-${location.label}';
    final cached = _cardStyles[key];
    if (cached != null) return cached;

    // Independent random picks can coincidentally collide (25% chance with
    // only 2 saved locations and 4 styles), making both cards look like the
    // same scene - so prefer a style not already taken by another saved
    // location this session.
    final taken = savedLocations
        .where((other) => '${other.groupCode}-${other.label}' != key)
        .map((other) => _cardStyles['${other.groupCode}-${other.label}'])
        .whereType<PowerCardStyle>()
        .toSet();
    final pool = PowerCardStyle.values
        .where((s) => !taken.contains(s))
        .toList();
    final choices = pool.isNotEmpty ? pool : PowerCardStyle.values;
    final style = choices[_random.nextInt(choices.length)];
    _cardStyles[key] = style;
    return style;
  }

  /// A randomly-picked phrase for the big status line, stable for as long as
  /// [isOn] doesn't change this session (so it doesn't flicker between
  /// wordings every 30s tick), re-rolled whenever the status actually flips.
  String statusTextFor(SavedLocation location, bool isOn) {
    final key = '${location.groupCode}-${location.label}-$isOn';
    final pool = isOn ? _onPhrases : _offPhrases;
    return _statusPhrases.putIfAbsent(
      key,
      () => pool[_random.nextInt(pool.length)],
    );
  }

  @override
  void onInit() {
    super.onInit();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    savedLocations.value = await _store.load();
    isLoaded.value = true;
  }

  Future<void> search(String query) async {
    final token = ++_searchToken;
    searchFailed.value = false;
    if (query.trim().length < 2) {
      searchResults.clear();
      isSearching.value = false;
      return;
    }
    isSearching.value = true;
    try {
      final results = await _api.searchLocations(query.trim());
      if (token != _searchToken) return;
      searchResults.value = results;
    } catch (_) {
      if (token != _searchToken) return;
      searchResults.clear();
      searchFailed.value = true;
    } finally {
      if (token == _searchToken) isSearching.value = false;
    }
  }

  Future<SaveResult> saveLocation(
    LocationEntry entry, {
    String? customName,
  }) async {
    final saved = SavedLocation(
      label: entry.location,
      groupCode: entry.groupCode,
      region: entry.region,
      customName: customName,
    );
    final outcome = await _store.add(saved);
    savedLocations.value = outcome.locations;
    return outcome.result;
  }

  Future<void> makePrimary(SavedLocation location) async {
    savedLocations.value = await _store.makePrimary(location);
  }

  Future<void> removeLocation(SavedLocation location) async {
    savedLocations.value = await _store.remove(location);
  }
}
