/// Attendance log record matching database schema
/// Represents a single attendance attempt (successful or rejected)
class AttendanceLog {
  final String id;
  final String studentId;
  final String classroomId;
  final DateTime timestamp;
  final String status; // "PRESENT" or "REJECTED"
  final double studentLatitude;
  final double studentLongitude;
  final String? rejectionReason;
  
  // Optional fields for joined data from dashboard queries
  final String? studentName;
  final String? classroomName;
  final String? building;

  AttendanceLog({
    required this.id,
    required this.studentId,
    required this.classroomId,
    required this.timestamp,
    required this.status,
    required this.studentLatitude,
    required this.studentLongitude,
    this.rejectionReason,
    this.studentName,
    this.classroomName,
    this.building,
  });

  /// Create AttendanceLog from JSON response
  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    // Handle student_location as either a geography object or separate lat/lng fields
    double latitude;
    double longitude;
    
    if (json['student_location'] != null) {
      // PostGIS geography format: {"type": "Point", "coordinates": [lng, lat]}
      final location = json['student_location'];
      if (location is Map && location['coordinates'] != null) {
        final coords = location['coordinates'] as List;
        longitude = (coords[0] as num).toDouble();
        latitude = (coords[1] as num).toDouble();
      } else {
        // Fallback to separate fields
        latitude = (json['student_lat'] as num?)?.toDouble() ?? 0.0;
        longitude = (json['student_lng'] as num?)?.toDouble() ?? 0.0;
      }
    } else {
      // Use separate lat/lng fields
      latitude = (json['student_lat'] as num?)?.toDouble() ?? 0.0;
      longitude = (json['student_lng'] as num?)?.toDouble() ?? 0.0;
    }

    return AttendanceLog(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      classroomId: json['classroom_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: json['status'] as String,
      studentLatitude: latitude,
      studentLongitude: longitude,
      rejectionReason: json['rejection_reason'] as String?,
      studentName: json['student_name'] as String?,
      classroomName: json['classroom_name'] as String?,
      building: json['building'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'classroom_id': classroomId,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'student_lat': studentLatitude,
      'student_lng': studentLongitude,
      'rejection_reason': rejectionReason,
      'student_name': studentName,
      'classroom_name': classroomName,
      'building': building,
    };
  }

  /// Check if attendance was successful
  bool get isPresent => status == 'PRESENT';

  /// Check if attendance was rejected
  bool get isRejected => status == 'REJECTED';
}
