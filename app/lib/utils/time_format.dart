/// "HH:mm" clock time.
String formatClock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Whether the sun is roughly up (06:00-18:00); Malawi's day length barely
/// varies through the year, so fixed hours are close enough for scenery.
bool isDaytime(DateTime d) => d.hour >= 6 && d.hour < 18;

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Formats a transition time, adding a day qualifier whenever it isn't
/// today - otherwise "08:00" tomorrow reads identically to "08:00" later
/// today, which is exactly the confusion this was built to avoid.
String transitionLabel(DateTime at, DateTime from) {
  final time = formatClock(at);
  final atDay = DateTime(at.year, at.month, at.day);
  final fromDay = DateTime(from.year, from.month, from.day);
  final dayDiff = atDay.difference(fromDay).inDays;
  if (dayDiff == 0) return time;
  if (dayDiff == 1) return 'Tomorrow $time';
  return '${_weekdayNames[at.weekday - 1]} $time';
}
