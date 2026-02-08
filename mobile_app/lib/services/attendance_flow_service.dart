import 'dart:async';
import 'nfc_service.dart';
import 'location_service.dart';
import 'api_client.dart';
import '../models/nfc_payload.dart';
import '../models/location_data.dart';
import '../models/attendance_result.dart';

/// Service that orchestrates the complete attendance marking flow
/// Coordinates NFC scanning, GPS capture, and API communication
class AttendanceFlowService {
  final NFCService _nfcService;
  final LocationService _locationService;
  final ApiClient _apiClient;

  AttendanceFlowService({
    NFCService? nfcService,
    LocationService? locationService,
    ApiClient? apiClient,
  })  : _nfcService = nfcService ?? NFCService(),
        _locationService = locationService ?? LocationService(),
        _apiClient = apiClient ?? ApiClient();

  /// Execute the complete attendance marking flow
  /// 
  /// Flow: NFC scan → GPS capture → API call → Result
  /// 
  /// Returns AttendanceResult on success
  /// Throws AttendanceFlowException with specific error type on failure
  /// 
  /// Error types:
  /// - nfc_unavailable: NFC is not available on device
  /// - nfc_read_error: Failed to read NFC tag
  /// - nfc_parse_error: Failed to parse NFC payload
  /// - gps_disabled: Location services are disabled
  /// - gps_permission_denied: Location permission denied
  /// - gps_timeout: Failed to get location within timeout
  /// - gps_error: Other GPS errors
  /// - network_error: Network connection issues
  /// - api_timeout: API request timeout
  /// - api_error: Other API errors
  Future<AttendanceResult> markAttendance({
    Function(AttendanceFlowStep)? onStepChange,
    int maxRetries = 2,
  }) async {
    try {
      // Step 1: Check NFC availability
      onStepChange?.call(AttendanceFlowStep.checkingNFC);
      final isNFCAvailable = await _nfcService.isNFCAvailable();
      if (!isNFCAvailable) {
        throw AttendanceFlowException(
          type: AttendanceFlowErrorType.nfcUnavailable,
          message: 'NFC is not available on this device',
        );
      }

      // Step 2: Read NFC tag
      onStepChange?.call(AttendanceFlowStep.readingNFC);
      String nfcPayloadJson;
      try {
        nfcPayloadJson = await _nfcService.startNFCSession();
      } on NFCException catch (e) {
        throw AttendanceFlowException(
          type: AttendanceFlowErrorType.nfcReadError,
          message: e.message,
          originalError: e,
        );
      } catch (e) {
        throw AttendanceFlowException(
          type: AttendanceFlowErrorType.nfcReadError,
          message: 'Failed to read NFC tag: ${e.toString()}',
          originalError: e,
        );
      }

      // Step 3: Parse NFC payload
      onStepChange?.call(AttendanceFlowStep.parsingPayload);
      NFCPayload payload;
      try {
        payload = NFCPayload.fromJson(nfcPayloadJson);
      } on NFCPayloadException catch (e) {
        throw AttendanceFlowException(
          type: AttendanceFlowErrorType.nfcParseError,
          message: e.message,
          originalError: e,
        );
      } catch (e) {
        throw AttendanceFlowException(
          type: AttendanceFlowErrorType.nfcParseError,
          message: 'Invalid NFC tag format: ${e.toString()}',
          originalError: e,
        );
      }

      // Step 4: Get GPS location
      onStepChange?.call(AttendanceFlowStep.gettingLocation);
      LocationData location;
      try {
        location = await _locationService.getCurrentLocation();
      } catch (e) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        
        // Categorize GPS errors
        if (errorMessage.contains('disabled')) {
          throw AttendanceFlowException(
            type: AttendanceFlowErrorType.gpsDisabled,
            message: errorMessage,
            originalError: e,
          );
        } else if (errorMessage.contains('permission')) {
          throw AttendanceFlowException(
            type: AttendanceFlowErrorType.gpsPermissionDenied,
            message: errorMessage,
            originalError: e,
          );
        } else if (errorMessage.contains('timeout') || errorMessage.contains('time')) {
          throw AttendanceFlowException(
            type: AttendanceFlowErrorType.gpsTimeout,
            message: errorMessage,
            originalError: e,
          );
        } else {
          throw AttendanceFlowException(
            type: AttendanceFlowErrorType.gpsError,
            message: errorMessage,
            originalError: e,
          );
        }
      }

      // Step 5: Call API with retry logic
      onStepChange?.call(AttendanceFlowStep.submittingAttendance);
      AttendanceResult result;
      int retryCount = 0;
      
      while (true) {
        try {
          result = await _apiClient.markAttendance(
            classroomId: payload.classroomId,
            secretToken: payload.secretToken,
            latitude: location.latitude,
            longitude: location.longitude,
          );
          break; // Success, exit retry loop
        } catch (e) {
          final errorMessage = e.toString().replaceAll('Exception: ', '');
          
          // Check if this is a transient error that can be retried
          final isTransientError = errorMessage.contains('timeout') ||
              errorMessage.contains('network') ||
              errorMessage.contains('connection');
          
          if (isTransientError && retryCount < maxRetries) {
            retryCount++;
            onStepChange?.call(AttendanceFlowStep.retrying);
            
            // Exponential backoff: 1s, 2s, 4s
            await Future.delayed(Duration(seconds: 1 << (retryCount - 1)));
            continue; // Retry
          }
          
          // Non-transient error or max retries reached
          if (errorMessage.contains('timeout')) {
            throw AttendanceFlowException(
              type: AttendanceFlowErrorType.apiTimeout,
              message: errorMessage,
              originalError: e,
            );
          } else if (errorMessage.contains('network') || 
                     errorMessage.contains('connection') ||
                     errorMessage.contains('internet')) {
            throw AttendanceFlowException(
              type: AttendanceFlowErrorType.networkError,
              message: errorMessage,
              originalError: e,
            );
          } else {
            throw AttendanceFlowException(
              type: AttendanceFlowErrorType.apiError,
              message: errorMessage,
              originalError: e,
            );
          }
        }
      }

      // Step 6: Complete
      onStepChange?.call(AttendanceFlowStep.complete);
      return result;
      
    } catch (e) {
      // Re-throw AttendanceFlowException as-is
      if (e is AttendanceFlowException) {
        rethrow;
      }
      
      // Wrap unexpected errors
      throw AttendanceFlowException(
        type: AttendanceFlowErrorType.unknown,
        message: 'Unexpected error: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Cancel any ongoing NFC session
  Future<void> cancelNFCSession() async {
    try {
      await _nfcService.stopNFCSession();
    } catch (e) {
      // Ignore errors when canceling
    }
  }
}

/// Steps in the attendance marking flow
enum AttendanceFlowStep {
  checkingNFC,
  readingNFC,
  parsingPayload,
  gettingLocation,
  submittingAttendance,
  retrying,
  complete,
}

/// Types of errors that can occur during attendance flow
enum AttendanceFlowErrorType {
  nfcUnavailable,
  nfcReadError,
  nfcParseError,
  gpsDisabled,
  gpsPermissionDenied,
  gpsTimeout,
  gpsError,
  networkError,
  apiTimeout,
  apiError,
  unknown,
}

/// Exception thrown during attendance flow with specific error type
class AttendanceFlowException implements Exception {
  final AttendanceFlowErrorType type;
  final String message;
  final Object? originalError;

  AttendanceFlowException({
    required this.type,
    required this.message,
    this.originalError,
  });

  @override
  String toString() => message;

  /// Get user-friendly error message
  String getUserMessage() {
    switch (type) {
      case AttendanceFlowErrorType.nfcUnavailable:
        return 'NFC is not available on this device. Please use a device with NFC support.';
      case AttendanceFlowErrorType.nfcReadError:
        return 'Unable to read NFC tag. Please try again.';
      case AttendanceFlowErrorType.nfcParseError:
        return 'Invalid NFC tag. Please contact administrator.';
      case AttendanceFlowErrorType.gpsDisabled:
        return 'Please enable location services to mark attendance.';
      case AttendanceFlowErrorType.gpsPermissionDenied:
        return 'Location permission is required. Please grant permission in settings.';
      case AttendanceFlowErrorType.gpsTimeout:
        return 'Unable to determine location. Please try again in an open area.';
      case AttendanceFlowErrorType.gpsError:
        return 'Unable to get location. Please check your GPS settings.';
      case AttendanceFlowErrorType.networkError:
        return 'No internet connection. Please check your network.';
      case AttendanceFlowErrorType.apiTimeout:
        return 'Request timeout. Please try again.';
      case AttendanceFlowErrorType.apiError:
        return message; // Use original message for API errors
      case AttendanceFlowErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Check if this error is retryable
  bool get isRetryable {
    return type == AttendanceFlowErrorType.networkError ||
        type == AttendanceFlowErrorType.apiTimeout ||
        type == AttendanceFlowErrorType.gpsTimeout ||
        type == AttendanceFlowErrorType.nfcReadError;
  }
}
