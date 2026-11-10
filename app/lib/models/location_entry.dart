class LocationEntry {
  final String groupCode;
  final String region;
  final String location;
  final String affectedAreas;

  LocationEntry({
    required this.groupCode,
    required this.region,
    required this.location,
    required this.affectedAreas,
  });

  factory LocationEntry.fromJson(Map<String, dynamic> json) {
    return LocationEntry(
      groupCode: json['groupCode'] as String,
      region: json['region'] as String,
      location: json['location'] as String,
      affectedAreas: json['affectedAreas'] as String,
    );
  }
}
