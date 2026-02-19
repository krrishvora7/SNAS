import 'package:flutter/material.dart';
import '../services/attendance_flow_service.dart';

/// Scanning screen displayed during NFC read and API call
/// Shows loading indicator and processing message
class ScanningScreen extends StatefulWidget {
  final VoidCallback? onCancel;
  final AttendanceFlowStep? currentStep;

  const ScanningScreen({
    super.key,
    this.onCancel,
    this.currentStep,
  });

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  AttendanceFlowStep _currentStep = AttendanceFlowStep.checkingNFC;

  @override
  void initState() {
    super.initState();
    if (widget.currentStep != null) {
      _currentStep = widget.currentStep!;
    }
  }

  @override
  void didUpdateWidget(ScanningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStep != null && widget.currentStep != _currentStep) {
      setState(() {
        _currentStep = widget.currentStep!;
      });
    }
  }

  /// Update the current step from external caller
  void updateStep(AttendanceFlowStep step) {
    if (mounted) {
      setState(() {
        _currentStep = step;
      });
    }
  }

  String _getStepMessage(AttendanceFlowStep step) {
    switch (step) {
      case AttendanceFlowStep.checkingNFC:
        return 'Checking NFC availability...';
      case AttendanceFlowStep.readingNFC:
        return 'Reading NFC tag...';
      case AttendanceFlowStep.parsingPayload:
        return 'Validating tag data...';
      case AttendanceFlowStep.gettingLocation:
        return 'Getting your location...';
      case AttendanceFlowStep.submittingAttendance:
        return 'Submitting attendance...';
      case AttendanceFlowStep.retrying:
        return 'Retrying...';
      case AttendanceFlowStep.complete:
        return 'Complete!';
    }
  }

  IconData _getStepIcon(AttendanceFlowStep step) {
    switch (step) {
      case AttendanceFlowStep.checkingNFC:
      case AttendanceFlowStep.readingNFC:
      case AttendanceFlowStep.parsingPayload:
        return Icons.nfc;
      case AttendanceFlowStep.gettingLocation:
        return Icons.location_on;
      case AttendanceFlowStep.submittingAttendance:
      case AttendanceFlowStep.retrying:
        return Icons.cloud_upload;
      case AttendanceFlowStep.complete:
        return Icons.check_circle;
    }
  }

@override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 1. CRITICAL: Prevents the automatic double-pop!
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // User pressed hardware back button, trigger cancel to let HomeScreen pop it
        if (widget.onCancel != null) {
          widget.onCancel!();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scanning'),
          leading: widget.onCancel != null
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel, // Let HomeScreen handle the pop
                  tooltip: 'Cancel',
                )
              : null,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey(_currentStep),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (value * 0.2),
                      child: Opacity(
                        opacity: 0.3 + (value * 0.7),
                        child: Icon(
                          _getStepIcon(_currentStep),
                          size: 120,
                          color: Colors.blue,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(strokeWidth: 3),
                const SizedBox(height: 24),
                Text(
                  _getStepMessage(_currentStep),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _currentStep == AttendanceFlowStep.retrying
                      ? 'Connection issue detected, retrying...'
                      : 'Please wait while we verify your attendance',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Cancel button
                if (widget.onCancel != null)
                  OutlinedButton(
                    onPressed: widget.onCancel, // Let HomeScreen handle the pop
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
