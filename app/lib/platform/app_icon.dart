import 'package:flutter/services.dart';

/// Tells the Android side which launcher icon to show - a lit or an unlit
/// bulb - and when to flip it next (see AppIcon.kt). A no-op on platforms
/// without the native handler.
class AppIcon {
  static const _channel = MethodChannel('mw.escom/app_icon');

  /// [lit] is the status right now; [transitions] are the upcoming changes
  /// in time order, each the moment the icon should switch and the state it
  /// switches to.
  static Future<void> update({
    required bool lit,
    required List<(DateTime, bool)> transitions,
  }) async {
    try {
      await _channel.invokeMethod('update', {
        'lit': lit,
        'times': [for (final t in transitions) t.$1.millisecondsSinceEpoch],
        'states': [for (final t in transitions) t.$2],
      });
    } on MissingPluginException {
      // Not Android.
    } on PlatformException {
      // The icon is decorative - never let it break the app.
    }
  }
}
