import 'package:supabase_flutter/supabase_flutter.dart';
import 'device_service.dart';

class DeviceBindingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DeviceService _deviceService = DeviceService();

  /// Check and enforce device binding for the current user
  /// Returns true if device binding is successful or already bound to this device
  /// Returns false if device is bound to a different device
  Future<DeviceBindingResult> checkAndBindDevice() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return DeviceBindingResult.failure('User not authenticated');
      }

      // Get current device ID
      final currentDeviceId = await _deviceService.getDeviceId();

      // Query user's profile to check existing device binding
      final response = await _supabase
          .from('profiles')
          .select('device_id')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (response == null) {
        // Profile doesn't exist yet, create it with device binding
        await _createProfileWithDeviceBinding(currentUser, currentDeviceId);
        return DeviceBindingResult.success(isFirstLogin: true);
      }

      final storedDeviceId = response['device_id'] as String?;

      if (storedDeviceId == null || storedDeviceId.isEmpty) {
        // First login - bind this device
        await _bindDevice(currentUser.id, currentDeviceId);
        return DeviceBindingResult.success(isFirstLogin: true);
      }

      if (storedDeviceId == currentDeviceId) {
        // Device already bound to this device
        return DeviceBindingResult.success(isFirstLogin: false);
      }

      // Device mismatch - reject login
      return DeviceBindingResult.failure(
        'This account is bound to another device. Please contact administrator to reset device binding.',
      );
    } catch (e) {
      return DeviceBindingResult.failure(
        'Device binding check failed: ${e.toString()}',
      );
    }
  }

  /// Create profile with device binding for new user
  Future<void> _createProfileWithDeviceBinding(
    User user,
    String deviceId,
  ) async {
    await _supabase.from('profiles').insert({
      'id': user.id,
      'email': user.email,
      'full_name': user.userMetadata?['full_name'] ?? user.email,
      'device_id': deviceId,
    });
  }

  /// Bind device to user profile
  Future<void> _bindDevice(String userId, String deviceId) async {
    await _supabase.from('profiles').update({
      'device_id': deviceId,
    }).eq('id', userId);
  }

  /// Get current device ID
  Future<String> getCurrentDeviceId() async {
    return await _deviceService.getDeviceId();
  }
}

class DeviceBindingResult {
  final bool success;
  final String? errorMessage;
  final bool isFirstLogin;

  DeviceBindingResult({
    required this.success,
    this.errorMessage,
    this.isFirstLogin = false,
  });

  factory DeviceBindingResult.success({required bool isFirstLogin}) {
    return DeviceBindingResult(
      success: true,
      isFirstLogin: isFirstLogin,
    );
  }

  factory DeviceBindingResult.failure(String errorMessage) {
    return DeviceBindingResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}
