import 'dart:convert';

/// Model representing the NFC tag payload containing classroom information
class NFCPayload {
  /// UUID of the classroom
  final String classroomId;
  
  /// Secret token for validation
  final String secretToken;

  NFCPayload({
    required this.classroomId,
    required this.secretToken,
  });

  /// Creates an NFCPayload from a JSON string
  /// Throws [NFCPayloadException] if the JSON is invalid or missing required fields
  factory NFCPayload.fromJson(String jsonString) {
    try {
      // Parse JSON string
      final Map<String, dynamic> json = jsonDecode(jsonString);
      
      // Validate required fields exist
      if (!json.containsKey('classroom_id')) {
        throw NFCPayloadException('Missing required field: classroom_id');
      }
      
      if (!json.containsKey('secret_token')) {
        throw NFCPayloadException('Missing required field: secret_token');
      }
      
      // Extract values
      final classroomId = json['classroom_id'];
      final secretToken = json['secret_token'];
      
      // Validate field types and values
      if (classroomId == null || classroomId.toString().trim().isEmpty) {
        throw NFCPayloadException('classroom_id cannot be null or empty');
      }
      
      if (secretToken == null || secretToken.toString().trim().isEmpty) {
        throw NFCPayloadException('secret_token cannot be null or empty');
      }
      
      // Validate UUID format for classroom_id (basic validation)
      final classroomIdStr = classroomId.toString();
      final uuidPattern = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      );
      
      if (!uuidPattern.hasMatch(classroomIdStr)) {
        throw NFCPayloadException('classroom_id must be a valid UUID format');
      }
      
      return NFCPayload(
        classroomId: classroomIdStr,
        secretToken: secretToken.toString(),
      );
    } on FormatException catch (e) {
      throw NFCPayloadException('Invalid JSON format: ${e.message}');
    } on NFCPayloadException {
      rethrow;
    } catch (e) {
      throw NFCPayloadException('Failed to parse NFC payload: $e');
    }
  }

  /// Creates an NFCPayload from a Map
  factory NFCPayload.fromMap(Map<String, dynamic> map) {
    return NFCPayload.fromJson(jsonEncode(map));
  }

  /// Converts the NFCPayload to a Map
  Map<String, dynamic> toMap() {
    return {
      'classroom_id': classroomId,
      'secret_token': secretToken,
    };
  }

  /// Converts the NFCPayload to a JSON string
  String toJson() {
    return jsonEncode(toMap());
  }

  @override
  String toString() {
    return 'NFCPayload(classroomId: $classroomId, secretToken: ${secretToken.substring(0, 4)}***)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is NFCPayload &&
        other.classroomId == classroomId &&
        other.secretToken == secretToken;
  }

  @override
  int get hashCode => classroomId.hashCode ^ secretToken.hashCode;
}

/// Custom exception for NFC payload parsing errors
class NFCPayloadException implements Exception {
  final String message;
  
  NFCPayloadException(this.message);
  
  @override
  String toString() => 'NFCPayloadException: $message';
}
