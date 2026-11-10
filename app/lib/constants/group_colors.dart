import 'package:flutter/material.dart';

/// Static mapping of base group letter -> colour, matching the scheme ESCOM
/// itself uses on the published loadshedding-programme PDF (see the
/// pipeline's README). This is domain knowledge, not weekly data, so it
/// lives here rather than coming from the API.
// Deliberately muted/desaturated rather than saturated "flat UI kit" primaries
// - reads as a calmer dashboard palette instead of bright AI-generated-looking
// colours.
const Map<String, Color> kGroupColors = {
  'A': Color(0xFFB2524A), // muted brick red
  'B': Color(0xFFC08A42), // muted amber
  'C': Color(0xFF5E8C6A), // muted forest green
  'D': Color(0xFF4F7CA3), // muted steel blue
  'E': Color(0xFF8C9A6B), // muted sage
  'F': Color(0xFF7D7D7D), // neutral gray
};

Color colorForSubgroup(String subgroup) {
  final base = subgroup.substring(0, 1);
  return kGroupColors[base] ?? Colors.grey;
}
