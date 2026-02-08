/// Result of an attendance marking attempt
/// Contains status (PRESENT/REJECTED), optional rejection reason, and timestamp
class AttendanceResult {
  final String status; // "PRESENT" or "REJECTED"
  final String? rejectionReason;
  final DateTime timestamp;

  AttendanceResult({
    required this.status,
    this.rejectionReason,
    required this.timestamp,
  });

  /// Create AttendanceResult from JSON response
  factory AttendanceResult.fromJson(Map<String, dynamic> json) {
    return AttendanceResult(
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'rejection_reason': rejectionReason,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Check if attendance was successful
  bool get isPresent => status == 'PRESENT';

  /// Check if attendance was rejected
  bool get isRejected => status == 'REJECTED';
}
