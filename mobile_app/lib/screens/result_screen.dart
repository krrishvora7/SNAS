import 'package:flutter/material.dart';
import '../models/attendance_result.dart';
import 'package:intl/intl.dart';

/// Result screen for attendance marking success or failure
/// Displays green checkmark for PRESENT status
/// Displays red X and rejection reason for REJECTED status
class ResultScreen extends StatelessWidget {
  final AttendanceResult result;

  const ResultScreen({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = result.isPresent;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Result'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success or failure icon with animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isSuccess ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check : Icons.close,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Success or failure message
              Text(
                isSuccess ? 'Attendance Marked!' : 'Attendance Rejected',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? Colors.green : Colors.red,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Timestamp
              Text(
                '${dateFormat.format(result.timestamp)} at ${timeFormat.format(result.timestamp)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Rejection reason (if rejected)
              if (result.isRejected && result.rejectionReason != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reason',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRejectionReason(result.rejectionReason!),
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              // Success message (if present)
              if (result.isPresent)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Your attendance has been recorded',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Return to home button
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  backgroundColor: isSuccess ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Return to Home',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format rejection reason to user-friendly message
  String _formatRejectionReason(String reason) {
    switch (reason) {
      case 'outside_geofence':
        return 'You are outside the classroom area. Please move closer to the classroom and try again.';
      case 'invalid_token':
        return 'The NFC tag is invalid or has been deactivated. Please contact your administrator.';
      case 'device_mismatch':
        return 'This account is bound to a different device. Please use your registered device.';
      case 'email_not_verified':
        return 'Your email address has not been verified. Please check your email and verify your account.';
      case 'rate_limit_exceeded':
        return 'You are attempting to mark attendance too frequently. Please wait a minute before trying again.';
      default:
        return reason;
    }
  }
}
