import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_log.dart';

/// Cache service for storing data locally
/// Provides caching for classroom data and offline support for attendance history
class CacheService {
  static const String _classroomCacheKey = 'classroom_cache';
  static const String _attendanceHistoryCacheKey = 'attendance_history_cache';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const Duration _cacheExpiration = Duration(hours: 24);

  /// Cache classroom data
  /// 
  /// Parameters:
  /// - classroomId: UUID of the classroom
  /// - data: Classroom data to cache (name, building, etc.)
  Future<void> cacheClassroom(String classroomId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_classroomCacheKey:$classroomId';
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(cacheKey, jsonEncode(cacheData));
    } catch (e) {
      // Silently fail - caching is not critical
      print('Failed to cache classroom data: $e');
    }
  }

  /// Get cached classroom data
  /// 
  /// Returns cached data if available and not expired, null otherwise
  Future<Map<String, dynamic>?> getCachedClassroom(String classroomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_classroomCacheKey:$classroomId';
      final cachedString = prefs.getString(cacheKey);
      
      if (cachedString == null) {
        return null;
      }

      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);
      
      // Check if cache is expired
      if (DateTime.now().difference(timestamp) > _cacheExpiration) {
        // Cache expired, remove it
        await prefs.remove(cacheKey);
        return null;
      }

      return cacheData['data'] as Map<String, dynamic>;
    } catch (e) {
      print('Failed to get cached classroom data: $e');
      return null;
    }
  }

  /// Cache attendance history for offline access
  /// 
  /// Parameters:
  /// - attendanceLogs: List of attendance logs to cache
  Future<void> cacheAttendanceHistory(List<AttendanceLog> attendanceLogs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': attendanceLogs.map((log) => log.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_attendanceHistoryCacheKey, jsonEncode(cacheData));
    } catch (e) {
      print('Failed to cache attendance history: $e');
    }
  }

  /// Get cached attendance history
  /// 
  /// Returns cached attendance logs if available, empty list otherwise
  Future<List<AttendanceLog>> getCachedAttendanceHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_attendanceHistoryCacheKey);
      
      if (cachedString == null) {
        return [];
      }

      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final List<dynamic> data = cacheData['data'] as List<dynamic>;
      
      return data.map((json) => AttendanceLog.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Failed to get cached attendance history: $e');
      return [];
    }
  }

  /// Check if cached attendance history exists
  Future<bool> hasCachedAttendanceHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_attendanceHistoryCacheKey);
    } catch (e) {
      return false;
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_classroomCacheKey) || 
            key == _attendanceHistoryCacheKey ||
            key == _cacheTimestampKey) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('Failed to clear cache: $e');
    }
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_classroomCacheKey)) {
          final cachedString = prefs.getString(key);
          if (cachedString != null) {
            try {
              final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
              final timestamp = DateTime.parse(cacheData['timestamp'] as String);
              
              if (DateTime.now().difference(timestamp) > _cacheExpiration) {
                await prefs.remove(key);
              }
            } catch (e) {
              // Invalid cache entry, remove it
              await prefs.remove(key);
            }
          }
        }
      }
    } catch (e) {
      print('Failed to clear expired cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int classroomCacheCount = 0;
      bool hasAttendanceCache = false;
      
      for (final key in keys) {
        if (key.startsWith(_classroomCacheKey)) {
          classroomCacheCount++;
        } else if (key == _attendanceHistoryCacheKey) {
          hasAttendanceCache = true;
        }
      }
      
      return {
        'classroom_cache_count': classroomCacheCount,
        'has_attendance_cache': hasAttendanceCache,
      };
    } catch (e) {
      return {
        'classroom_cache_count': 0,
        'has_attendance_cache': false,
      };
    }
  }
}

