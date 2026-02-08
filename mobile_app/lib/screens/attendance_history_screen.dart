import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/attendance_log.dart';
import 'package:intl/intl.dart';

/// Attendance history screen displaying all attendance records
/// Includes filtering by date range and status
/// Supports pull-to-refresh
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final apiClient = ApiClient();
  List<AttendanceLog> allLogs = [];
  List<AttendanceLog> filteredLogs = [];
  bool isLoading = true;
  String? errorMessage;

  // Filter state
  String statusFilter = 'ALL'; // ALL, PRESENT, REJECTED
  DateTimeRange? dateRangeFilter;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final logs = await apiClient.getMyAttendance(forceRefresh: forceRefresh);
      setState(() {
        allLogs = logs;
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    filteredLogs = allLogs.where((log) {
      // Status filter
      if (statusFilter != 'ALL' && log.status != statusFilter) {
        return false;
      }

      // Date range filter
      if (dateRangeFilter != null) {
        final logDate = log.timestamp;
        if (logDate.isBefore(dateRangeFilter!.start) ||
            logDate.isAfter(dateRangeFilter!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: dateRangeFilter,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        dateRangeFilter = picked;
        _applyFilters();
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      dateRangeFilter = null;
      _applyFilters();
    });
  }

  void _changeStatusFilter(String? value) {
    if (value != null) {
      setState(() {
        statusFilter = value;
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
      ),
      body: Column(
        children: [
          // Filter controls
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Status filter
                Row(
                  children: [
                    const Icon(Icons.filter_list, size: 20),
                    const SizedBox(width: 8),
                    const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'ALL', label: Text('All')),
                          ButtonSegment(value: 'PRESENT', label: Text('Present')),
                          ButtonSegment(value: 'REJECTED', label: Text('Rejected')),
                        ],
                        selected: {statusFilter},
                        onSelectionChanged: (Set<String> selected) {
                          _changeStatusFilter(selected.first);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date range filter
                Row(
                  children: [
                    const Icon(Icons.date_range, size: 20),
                    const SizedBox(width: 8),
                    const Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: dateRangeFilter == null
                          ? OutlinedButton(
                              onPressed: _selectDateRange,
                              child: const Text('Select Date Range'),
                            )
                          : Chip(
                              label: Text(
                                '${DateFormat('MMM dd').format(dateRangeFilter!.start)} - ${DateFormat('MMM dd, yyyy').format(dateRangeFilter!.end)}',
                              ),
                              onDeleted: _clearDateRange,
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results count
          if (!isLoading && errorMessage == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredLogs.length} record${filteredLogs.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (statusFilter != 'ALL' || dateRangeFilter != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          statusFilter = 'ALL';
                          dateRangeFilter = null;
                          _applyFilters();
                        });
                      },
                      child: const Text('Clear Filters'),
                    ),
                ],
              ),
            ),

          // List content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadAttendance(forceRefresh: true),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAttendance,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                allLogs.isEmpty
                    ? 'No attendance records yet'
                    : 'No records match your filters',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
              if (allLogs.isNotEmpty) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      statusFilter = 'ALL';
                      dateRangeFilter = null;
                      _applyFilters();
                    });
                  },
                  child: const Text('Clear Filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        return _buildAttendanceCard(filteredLogs[index]);
      },
    );
  }

  Widget _buildAttendanceCard(AttendanceLog log) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final isPresent = log.isPresent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPresent ? Colors.green : Colors.red,
                  radius: 20,
                  child: Icon(
                    isPresent ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.classroomName ?? 'Unknown Classroom',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (log.building != null)
                        Text(
                          log.building!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    log.status,
                    style: TextStyle(
                      color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date and time
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  dateFormat.format(log.timestamp),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  timeFormat.format(log.timestamp),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),

            // Rejection reason (if rejected)
            if (log.isRejected && log.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatRejectionReason(log.rejectionReason!),
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
      default:
        return reason;
    }
  }
}
