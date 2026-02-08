import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/attendance_flow_service.dart';
import '../models/attendance_log.dart';
import 'attendance_history_screen.dart';
import 'scanning_screen.dart';
import 'result_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final authService = AuthService();
  final apiClient = ApiClient();
  final attendanceFlowService = AttendanceFlowService();
  List<AttendanceLog> recentAttendance = [];
  bool isLoading = true;
  String? errorMessage;
  bool isScanning = false;
  bool isResendingVerification = false;

  @override
  void initState() {
    super.initState();
    _loadRecentAttendance();
  }

  Future<void> _loadRecentAttendance() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final logs = await apiClient.getMyAttendance();
      setState(() {
        recentAttendance = logs.take(5).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() {
      isResendingVerification = true;
    });

    try {
      final success = await authService.resendVerificationEmail();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Verification email sent! Please check your inbox.'
                  : 'Failed to send verification email. Please try again later.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isResendingVerification = false;
        });
      }
    }
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen()),
    );
  }

  Future<void> _startAttendanceFlow() async {
    if (isScanning) return; // Prevent multiple simultaneous scans

    setState(() {
      isScanning = true;
    });

    // Track current step for UI updates
    AttendanceFlowStep currentStep = AttendanceFlowStep.checkingNFC;
    
    // Navigate to scanning screen with step callback
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (context) => ScanningScreen(
          currentStep: currentStep,
          onCancel: () {
            attendanceFlowService.cancelNFCSession();
          },
        ),
      ),
    );

    try {
      // Execute attendance flow with step updates
      final result = await attendanceFlowService.markAttendance(
        onStepChange: (step) {
          currentStep = step;
          // Note: We can't easily update the scanning screen state from here
          // The scanning screen will show a generic "Processing..." message
        },
      );

      // Navigate to result screen (replace scanning screen)
      if (mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResultScreen(result: result),
          ),
        );
      }

      // Refresh attendance list after marking
      _loadRecentAttendance();
    } on AttendanceFlowException catch (e) {
      // Handle attendance flow errors
      if (mounted) {
        navigator.pop(); // Close scanning screen

        // Show error dialog with retry option
        _showErrorDialog(
          title: 'Attendance Failed',
          message: e.getUserMessage(),
          canRetry: e.isRetryable,
        );
      }
    } catch (e) {
      // Handle unexpected errors
      if (mounted) {
        navigator.pop(); // Close scanning screen

        _showErrorDialog(
          title: 'Error',
          message: 'An unexpected error occurred: ${e.toString()}',
          canRetry: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isScanning = false;
        });
      }
    }
  }

  void _showErrorDialog({
    required String title,
    required String message,
    required bool canRetry,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            _buildErrorHelp(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (canRetry)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startAttendanceFlow(); // Retry
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorHelp(String message) {
    // Provide contextual help based on error type
    String helpText = '';
    IconData helpIcon = Icons.info_outline;
    Color helpColor = Colors.blue;

    if (message.contains('NFC')) {
      helpText = 'Make sure NFC is enabled in your device settings and hold your phone close to the tag.';
      helpIcon = Icons.nfc;
      helpColor = Colors.orange;
    } else if (message.contains('location') || message.contains('GPS')) {
      helpText = 'Enable location services in your device settings and ensure you have a clear view of the sky.';
      helpIcon = Icons.location_on;
      helpColor = Colors.orange;
    } else if (message.contains('permission')) {
      helpText = 'Go to Settings > Apps > SNAS > Permissions and enable the required permissions.';
      helpIcon = Icons.settings;
      helpColor = Colors.orange;
    } else if (message.contains('network') || message.contains('internet')) {
      helpText = 'Check your WiFi or mobile data connection and try again.';
      helpIcon = Icons.wifi_off;
      helpColor = Colors.orange;
    } else if (message.contains('timeout')) {
      helpText = 'The request took too long. Check your connection and try again.';
      helpIcon = Icons.timer_off;
      helpColor = Colors.orange;
    } else if (message.contains('outside') || message.contains('geofence')) {
      helpText = 'You must be within 50 meters of the classroom to mark attendance.';
      helpIcon = Icons.location_off;
      helpColor = Colors.red;
    } else if (message.contains('invalid') || message.contains('token')) {
      helpText = 'The NFC tag may be damaged or deactivated. Contact your administrator.';
      helpIcon = Icons.warning;
      helpColor = Colors.red;
    } else if (message.contains('device')) {
      helpText = 'This account is registered to a different device. Contact support to reset device binding.';
      helpIcon = Icons.phone_android;
      helpColor = Colors.red;
    }

    if (helpText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: helpColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: helpColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(helpIcon, color: helpColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              helpText,
              style: TextStyle(
                fontSize: 13,
                color: helpColor.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SNAS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecentAttendance,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email Verification Warning Banner
                if (!authService.isEmailVerified)
                  Card(
                    color: Colors.orange.shade50,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Email Not Verified',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You cannot mark attendance until you verify your email address. Please check your inbox for the verification link.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: isResendingVerification ? null : _resendVerificationEmail,
                            icon: isResendingVerification
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.email, size: 18),
                            label: Text(
                              isResendingVerification ? 'Sending...' : 'Resend Verification Email',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // NFC Ready Indicator and Tap to Scan Button
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.nfc,
                          size: 80,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'NFC Ready',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isScanning ? null : _startAttendanceFlow,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 20,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: const Text('Tap to Scan'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Recent Attendance Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Attendance',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton(
                      onPressed: _navigateToHistory,
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Loading, Error, or List
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (errorMessage != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadRecentAttendance,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (recentAttendance.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No attendance records yet',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...recentAttendance.map((log) => _buildAttendanceCard(log)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceLog log) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final isPresent = log.isPresent;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPresent ? Colors.green : Colors.red,
          child: Icon(
            isPresent ? Icons.check : Icons.close,
            color: Colors.white,
          ),
        ),
        title: Text(
          log.classroomName ?? 'Unknown Classroom',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (log.building != null) Text(log.building!),
            Text('${dateFormat.format(log.timestamp)} at ${timeFormat.format(log.timestamp)}'),
            if (log.isRejected && log.rejectionReason != null)
              Text(
                _formatRejectionReason(log.rejectionReason!),
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        trailing: Chip(
          label: Text(
            log.status,
            style: TextStyle(
              color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          backgroundColor: isPresent ? Colors.green.shade50 : Colors.red.shade50,
        ),
      ),
    );
  }

  String _formatRejectionReason(String reason) {
    switch (reason) {
      case 'outside_geofence':
        return 'Outside classroom area';
      case 'invalid_token':
        return 'Invalid NFC tag';
      case 'device_mismatch':
        return 'Wrong device';
      case 'email_not_verified':
        return 'Email not verified';
      case 'rate_limit_exceeded':
        return 'Too many attempts';
      default:
        return reason;
    }
  }
}
