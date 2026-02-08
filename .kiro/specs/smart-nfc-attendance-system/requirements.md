# Requirements Document: Smart NFC Attendance System (SNAS)

## Introduction

The Smart NFC Attendance System (SNAS) is a mobile-first attendance tracking solution that leverages NFC technology and GPS verification to ensure accurate, tamper-resistant attendance recording for educational institutions. Students use a mobile app to scan NFC tags placed in classrooms, with server-side validation ensuring they are physically present within the designated geofence. The system provides real-time monitoring capabilities for administrators through a dashboard with map visualization.

## Glossary

- **SNAS**: Smart NFC Attendance System
- **Mobile_App**: Flutter-based cross-platform mobile application for students
- **Backend**: Supabase backend system including PostgreSQL database with PostGIS extension
- **NFC_Tag**: NTAG213 NFC sticker containing classroom identification and security token
- **Geofence**: Geographic boundary defined as a 50-meter radius around a classroom location
- **Admin_Dashboard**: Web-based interface for real-time attendance monitoring and visualization
- **RPC_Function**: Remote Procedure Call function (mark_attendance) for server-side validation
- **Device_Binding**: Security mechanism linking a student profile to a single mobile device
- **RLS**: Row Level Security policies enforcing data access control in PostgreSQL

## Requirements

### Requirement 1: User Authentication

**User Story:** As a student, I want to authenticate using my university email, so that I can securely access the attendance system.

#### Acceptance Criteria

1. WHEN a student provides valid university email credentials, THE Backend SHALL authenticate the user via Supabase Auth
2. WHEN authentication succeeds, THE Backend SHALL create or retrieve the student's profile record
3. IF authentication fails, THEN THE Mobile_App SHALL display an error message and prevent access
4. THE Backend SHALL enforce email verification before allowing attendance marking

### Requirement 2: Device Binding

**User Story:** As a system administrator, I want each student account bound to a single device, so that attendance cannot be marked from multiple devices simultaneously.

#### Acceptance Criteria

1. WHEN a student first logs in from a device, THE Backend SHALL bind that device_id to the student's profile
2. WHEN a student attempts to log in from a different device, THE Backend SHALL reject the login and maintain the existing device binding
3. THE Backend SHALL store the device_id in the profiles table
4. WHERE an administrator manually resets device binding, THE Backend SHALL allow the student to bind a new device

### Requirement 3: NFC Tag Reading

**User Story:** As a student, I want to scan an NFC tag in the classroom, so that I can mark my attendance.

#### Acceptance Criteria

1. WHEN a student taps their device on an NFC_Tag, THE Mobile_App SHALL read the tag's NDEF payload
2. THE Mobile_App SHALL parse the JSON payload containing classroom_id and secret_token
3. IF the NFC_Tag is unreadable or malformed, THEN THE Mobile_App SHALL display an error message
4. THE Mobile_App SHALL extract classroom_id and secret_token from the payload for validation

### Requirement 4: GPS Location Capture

**User Story:** As a student, I want my location captured during attendance marking, so that the system can verify I am physically present in the classroom.

#### Acceptance Criteria

1. WHEN a student scans an NFC_Tag, THE Mobile_App SHALL capture the device's current GPS coordinates
2. THE Mobile_App SHALL obtain latitude and longitude with the highest available accuracy
3. IF GPS is disabled or unavailable, THEN THE Mobile_App SHALL prevent attendance marking and display an error
4. THE Mobile_App SHALL send the captured coordinates to the Backend for validation

### Requirement 5: Server-Side Attendance Validation

**User Story:** As a system administrator, I want attendance validated on the server, so that students cannot bypass security checks through client-side manipulation.

#### Acceptance Criteria

1. WHEN the Mobile_App submits attendance data, THE Backend SHALL invoke the mark_attendance RPC_Function
2. THE RPC_Function SHALL validate the secret_token against the classroom's stored nfc_secret
3. THE RPC_Function SHALL verify the student's device_id matches their profile
4. THE RPC_Function SHALL calculate the distance between student location and classroom location using PostGIS
5. THE RPC_Function SHALL execute within 200 milliseconds
6. IF any validation fails, THEN THE RPC_Function SHALL return a rejection status with reason

### Requirement 6: Geofence Enforcement

**User Story:** As a system administrator, I want attendance only marked when students are within 50 meters of the classroom, so that remote attendance marking is prevented.

#### Acceptance Criteria

1. WHEN validating attendance, THE Backend SHALL calculate the distance between student GPS coordinates and classroom location
2. IF the distance exceeds 50 meters, THEN THE Backend SHALL reject the attendance with status REJECTED
3. IF the distance is within 50 meters, THEN THE Backend SHALL accept the attendance with status PRESENT
4. THE Backend SHALL use PostGIS ST_Distance function for accurate geospatial calculation

### Requirement 7: Attendance Logging

**User Story:** As a system administrator, I want all attendance attempts logged, so that I can audit attendance patterns and detect anomalies.

#### Acceptance Criteria

1. WHEN attendance validation completes, THE Backend SHALL create a record in the attendance_logs table
2. THE Backend SHALL store student_id, classroom_id, timestamp, status (PRESENT/REJECTED), and GPS coordinates
3. THE Backend SHALL record rejection_reason for REJECTED attempts
4. THE Backend SHALL ensure attendance_logs are immutable after creation

### Requirement 8: Real-Time Admin Dashboard

**User Story:** As an administrator, I want to view attendance in real-time on a dashboard, so that I can monitor classroom occupancy and attendance patterns.

#### Acceptance Criteria

1. WHEN an administrator accesses the Admin_Dashboard, THE Backend SHALL provide real-time attendance data
2. THE Admin_Dashboard SHALL display attendance logs with student names, classrooms, timestamps, and status
3. THE Admin_Dashboard SHALL show a map visualization with classroom locations and student check-in points
4. THE Admin_Dashboard SHALL update automatically when new attendance is marked
5. THE Admin_Dashboard SHALL allow filtering by date, classroom, and status

### Requirement 9: Database Schema and Storage

**User Story:** As a system architect, I want a well-structured database schema, so that data integrity and performance are maintained.

#### Acceptance Criteria

1. THE Backend SHALL maintain a profiles table with columns: id, email, full_name, device_id, created_at
2. THE Backend SHALL maintain a classrooms table with columns: id, name, building, location (geography), nfc_secret, created_at
3. THE Backend SHALL maintain an attendance_logs table with columns: id, student_id, classroom_id, timestamp, status, student_location (geography), rejection_reason
4. THE Backend SHALL use PostgreSQL 15 or higher with PostGIS extension enabled
5. THE Backend SHALL enforce foreign key constraints between tables

### Requirement 10: Row Level Security

**User Story:** As a security architect, I want row-level security policies enforced, so that users can only access data they are authorized to view.

#### Acceptance Criteria

1. THE Backend SHALL enable RLS on profiles, classrooms, and attendance_logs tables
2. WHEN a student queries their profile, THE Backend SHALL only return their own profile data
3. WHEN a student queries attendance_logs, THE Backend SHALL only return their own attendance records
4. WHERE a user has admin role, THE Backend SHALL allow access to all records
5. THE Backend SHALL enforce RLS policies at the database level

### Requirement 11: NFC Tag Configuration

**User Story:** As a system administrator, I want NFC tags properly configured with classroom data, so that students can scan them for attendance.

#### Acceptance Criteria

1. THE NFC_Tag SHALL be NTAG213 format with 144 bytes of memory
2. THE NFC_Tag SHALL store an NDEF message containing JSON payload
3. THE JSON payload SHALL include classroom_id and secret_token fields
4. THE secret_token SHALL be unique per classroom and stored in the classrooms table
5. WHERE a tag is compromised, THE Backend SHALL support secret_token rotation

### Requirement 12: Mobile App User Interface

**User Story:** As a student, I want a simple and modern user interface, so that I can quickly mark attendance without confusion.

#### Acceptance Criteria

1. THE Mobile_App SHALL display a clear scan button or NFC ready indicator
2. WHEN attendance is successfully marked, THE Mobile_App SHALL display a success confirmation
3. WHEN attendance is rejected, THE Mobile_App SHALL display the rejection reason clearly
4. THE Mobile_App SHALL show the student's attendance history
5. THE Mobile_App SHALL use a modern, clean design with intuitive navigation

### Requirement 13: Performance Requirements

**User Story:** As a student, I want attendance marking to be fast, so that I don't waste time during class transitions.

#### Acceptance Criteria

1. THE RPC_Function SHALL complete attendance validation within 200 milliseconds
2. THE Mobile_App SHALL display feedback within 1 second of NFC tag scan
3. THE Backend SHALL handle concurrent attendance marking from multiple students
4. THE Admin_Dashboard SHALL load initial data within 2 seconds

### Requirement 14: Security Requirements

**User Story:** As a security architect, I want the system to be secure against common attacks, so that attendance data integrity is maintained.

#### Acceptance Criteria

1. THE Backend SHALL store nfc_secret values encrypted or hashed
2. THE Backend SHALL validate all input parameters in the RPC_Function
3. THE Backend SHALL prevent SQL injection through parameterized queries
4. THE Mobile_App SHALL communicate with the Backend over HTTPS only
5. THE Backend SHALL implement rate limiting on the mark_attendance endpoint

### Requirement 15: Cross-Platform Support

**User Story:** As a student, I want to use the app on both Android and iOS devices, so that I can mark attendance regardless of my device choice.

#### Acceptance Criteria

1. THE Mobile_App SHALL be built using Flutter framework
2. THE Mobile_App SHALL support Android 8.0 (API level 26) and higher
3. THE Mobile_App SHALL support iOS 12.0 and higher
4. THE Mobile_App SHALL provide consistent functionality across both platforms
5. THE Mobile_App SHALL handle platform-specific NFC APIs appropriately
