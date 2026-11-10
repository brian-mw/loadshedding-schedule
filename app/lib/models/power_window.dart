class PowerWindow {
  final DateTime date;
  final String subgroup;
  final int slotIndex;
  final String startTime; // "HH:MM:SS"
  final String endTime;
  final String status; // 'ON' | 'OFF'

  PowerWindow({
    required this.date,
    required this.subgroup,
    required this.slotIndex,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  bool get isOn => status == 'ON';

  factory PowerWindow.fromJson(Map<String, dynamic> json) {
    return PowerWindow(
      date: DateTime.parse(json['date'] as String),
      subgroup: json['subgroup'] as String,
      slotIndex: json['slotIndex'] as int,
      startTime: (json['startTime'] as String),
      endTime: (json['endTime'] as String),
      status: json['status'] as String,
    );
  }

  /// Combine [date] with [startTime]/[endTime] into real DateTimes, handling
  /// the overnight slot (end time earlier than start time means it rolls into
  /// the next day).
  DateTime get startDateTime => _combine(date, startTime);
  DateTime get endDateTime {
    final start = _combine(date, startTime);
    var end = _combine(date, endTime);
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  static DateTime _combine(DateTime date, String hhmmss) {
    final parts = hhmmss.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}
