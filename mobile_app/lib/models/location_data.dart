/// Model representing GPS location data with validation
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  }) {
    _validate();
  }

  /// Validate coordinate ranges
  void _validate() {
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError('Latitude must be between -90 and 90 degrees');
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError('Longitude must be between -180 and 180 degrees');
    }
    if (accuracy < 0) {
      throw ArgumentError('Accuracy must be non-negative');
    }
  }

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, accuracy: ${accuracy}m)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationData &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.accuracy == accuracy;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracy);
}
