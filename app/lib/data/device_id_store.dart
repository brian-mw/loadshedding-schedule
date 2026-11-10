import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A random, anonymous per-install identifier, used only to count distinct
/// reporters for crowd-sourced status reports - no accounts, no PII.
class DeviceIdStore {
  static const _key = 'device_id_v1';

  Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null) return existing;
    final id = _generate();
    await prefs.setString(_key, id);
    return id;
  }

  String _generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
