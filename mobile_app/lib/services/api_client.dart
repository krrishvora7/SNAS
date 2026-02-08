import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_result.dart';
import '../models/attendance_log.dart';
import 'cache_service.dart';

/// API client for communicating with Supabase backend
/// Handles attendance marking and attendance history retrieval
/// Implements caching for improved performance and offline support
class ApiClient {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CacheService _cacheService = CacheService();

  /// Mark attendance by calling the mark_attendance RPC function
  /// 
  /// Parameters:
  /// - classroomId: UUID of the classroom
  /// - secretToken: Secret token from NFC tag
  /// - latitude: Student's current latitude
  /// - longitude: Student's current longitude
  /// 
  /// Returns AttendanceResult with status (PRESENT/REJECTED) and optional rejection reason
  /// 
  /// Throws:
  /// - Exception on network errors or timeouts
  Future<AttendanceResult> markAttendance({
    required String classroomId,
    required String secretToken,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Call the mark_attendance RPC function with timeout
      final response = await _supabase
          .rpc('mark_attendance', params: {
            'p_classroom_id': classroomId,
            'p_secret_token': secretToken,
            'p_latitude': latitude,
            'p_longitude': longitude,
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout. Please try again.'),
          );

      // Parse response JSON into AttendanceResult
      if (response == null) {
        throw Exception('Empty response from server');
      }

      return AttendanceResult.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      // Handle Supabase/PostgreSQL errors
      throw Exception(_handlePostgrestError(e));
    } catch (e) {
      // Handle network errors and other exceptions
      if (e.toString().contains('timeout')) {
        throw Exception('Request timeout. Please try again.');
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('NetworkException')) {
        throw Exception('No internet connection. Please check your network.');
      } else {
        throw Exception('Failed to mark attendance: ${e.toString()}');
      }
    }
  }

  /// Get attendance history for the current user
  /// 
  /// Returns list of AttendanceLog records ordered by timestamp descending
  /// Implements caching for offline support
  /// 
  /// Parameters:
  /// - forceRefresh: If true, bypass cache and fetch from server
  /// 
  /// Throws:
  /// - Exception on network errors or timeouts (returns cached data if available)
  Future<List<AttendanceLog>> getMyAttendance({bool forceRefresh = false}) async {
    try {
      // Get current user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // If not forcing refresh, try to get cached data first
      if (!forceRefresh) {
        final cachedData = await _cacheService.getCachedAttendanceHistory();
        if (cachedData.isNotEmpty) {
          // Return cached data and fetch fresh data in background
          _fetchAndCacheAttendanceHistory(userId);
          return cachedData;
        }
      }

      // Fetch from server
      final attendanceLogs = await _fetchAndCacheAttendanceHistory(userId);
      return attendanceLogs;
    } on PostgrestException catch (e) {
      // Try to return cached data on error
      final cachedData = await _cacheService.getCachedAttendanceHistory();
      if (cachedData.isNotEmpty) {
        return cachedData;
      }
      throw Exception(_handlePostgrestError(e));
    } catch (e) {
      // Try to return cached data on network error
      final cachedData = await _cacheService.getCachedAttendanceHistory();
      if (cachedData.isNotEmpty) {
        return cachedData;
      }
      
      // Handle network errors and other exceptions
      if (e.toString().contains('timeout')) {
        throw Exception('Request timeout. Please try again.');
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('NetworkException')) {
        throw Exception('No internet connection. Please check your network.');
      } else {
        throw Exception('Failed to fetch attendance history: ${e.toString()}');
      }
    }
  }

  /// Fetch attendance history from server and cache it
  /// 
  /// Internal method used by getMyAttendance
  Future<List<AttendanceLog>> _fetchAndCacheAttendanceHistory(String userId) async {
    // Query attendance_logs table with timeout
    // RLS policies ensure only user's own records are returned
    final response = await _supabase
        .from('attendance_logs')
        .select('''
          id,
          student_id,
          classroom_id,
          timestamp,
          status,
          student_location,
          rejection_reason,
          classrooms (
            name,
            building
          )
        ''')
        .eq('student_id', userId)
        .order('timestamp', ascending: false)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Request timeout. Please try again.'),
        );

    // Parse response into list of AttendanceLog objects
    final List<dynamic> data = response as List<dynamic>;
    final attendanceLogs = data.map((json) {
      // Flatten classroom data into the attendance log
      final Map<String, dynamic> flattenedJson = Map<String, dynamic>.from(json);
      if (json['classrooms'] != null) {
        final classroom = json['classrooms'];
        flattenedJson['classroom_name'] = classroom['name'];
        flattenedJson['building'] = classroom['building'];
      }
      return AttendanceLog.fromJson(flattenedJson);
    }).toList();

    // Cache the attendance history for offline access
    await _cacheService.cacheAttendanceHistory(attendanceLogs);

    return attendanceLogs;
  }

  /// Get classroom data with caching
  /// 
  /// Parameters:
  /// - classroomId: UUID of the classroom
  /// 
  /// Returns classroom data (name, building, location)
  Future<Map<String, dynamic>?> getClassroom(String classroomId) async {
    try {
      // Try to get from cache first
      final cachedData = await _cacheService.getCachedClassroom(classroomId);
      if (cachedData != null) {
        return cachedData;
      }

      // Fetch from server
      final response = await _supabase
          .from('classrooms')
          .select('id, name, building, location')
          .eq('id', classroomId)
          .single()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Request timeout'),
          );

      // Cache the classroom data
      await _cacheService.cacheClassroom(classroomId, response);

      return response;
    } catch (e) {
      print('Failed to fetch classroom data: $e');
      return null;
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await _cacheService.clearCache();
  }

  /// Handle PostgrestException and return user-friendly error messages
  String _handlePostgrestError(PostgrestException error) {
    // Check for specific error codes or messages
    if (error.code == 'PGRST301') {
      return 'Database connection error. Please try again later.';
    } else if (error.code == '42501') {
      return 'Permission denied. Please check your account.';
    } else if (error.message.contains('timeout')) {
      return 'Request timeout. Please try again.';
    } else if (error.message.contains('constraint')) {
      return 'Data validation error. Please contact support.';
    } else {
      return 'Server error: ${error.message}';
    }
  }
}
