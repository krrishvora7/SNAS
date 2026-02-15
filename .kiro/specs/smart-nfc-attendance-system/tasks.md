# Implementation Plan: Smart NFC Attendance System (SNAS)

## Overview

This implementation plan breaks down the SNAS into discrete coding tasks across three main components: the Flutter mobile app, the Supabase backend (PostgreSQL + RPC functions), and the web-based admin dashboard. The plan follows an incremental approach, building core functionality first, then adding validation and security layers, and finally implementing the admin dashboard.

The implementation prioritizes server-side validation and security, ensuring that all critical business logic runs on the backend where it cannot be tampered with. Each task builds on previous work, with checkpoints to validate progress.

## Tasks

- [-] 1. Set up project structure and dependencies
  - Create Flutter project with required packages (supabase_flutter, nfc_manager, geolocator, device_info_plus)
  - Initialize Supabase project and enable PostGIS extension
  - Set up project directory structure for mobile app
  - Configure environment variables for Supabase URL and anon key
  - _Requirements: 15.1_

- [ ] 2. Implement database schema and migrations
  - [x] 2.1 Create profiles table with RLS policies
    - Write SQL migration for profiles table with columns: id, email, full_name, device_id, created_at
    - Create RLS policy: "Users can view own profile"
    - Create RLS policy: "Users can update own profile"
    - Add unique constraints on email and device_id
    - _Requirements: 9.1, 10.1, 10.2_
  
  - [x] 2.2 Create classrooms table with PostGIS geography
    - Write SQL migration for classrooms table with columns: id, name, building, location (geography), nfc_secret, created_at
    - Create spatial index on location column
    - Add unique constraint on nfc_secret
    - Create RLS policy: "Anyone can view classrooms"
    - _Requirements: 9.2, 10.1_
  
  - [x] 2.3 Create attendance_logs table with constraints
    - Write SQL migration for attendance_logs table with all required columns
    - Add CHECK constraint for status IN ('PRESENT', 'REJECTED')
    - Add CHECK constraint for rejection_reason logic (REJECTED requires reason, PRESENT requires null)
    - Create indexes on student_id, classroom_id, and timestamp
    - Create RLS policy: "Users can view own attendance"
    - Create RLS policy: "Only system can insert attendance" (WITH CHECK false)
    - _Requirements: 9.3, 10.1, 10.3_
  
  - [ ]* 2.4 Write property test for foreign key integrity
    - **Property 21: Foreign Key Integrity**
    - **Validates: Requirements 9.5**
  
  - [ ]* 2.5 Write property test for secret token uniqueness
    - **Property 24: Secret Token Uniqueness**
    - **Validates: Requirements 11.4**

- [ ] 3. Implement mark_attendance RPC function
  - [x] 3.1 Create mark_attendance function with input validation
    - Write PostgreSQL function signature with parameters: p_classroom_id, p_secret_token, p_latitude, p_longitude
    - Implement input parameter validation (null checks, type validation, coordinate range validation)
    - Return structured JSON response with status, rejection_reason, timestamp
    - Set function as SECURITY DEFINER to bypass RLS
    - _Requirements: 5.1, 14.2_
  
  - [x] 3.2 Implement device binding verification
    - Query profiles table to get user's stored device_id
    - Extract device_id from JWT claims (auth.jwt())
    - Compare device_ids and reject if mismatch
    - _Requirements: 2.2, 5.3_
  
  - [x] 3.3 Implement secret token validation
    - Query classrooms table for p_classroom_id
    - Compare p_secret_token with stored nfc_secret
    - Reject if token doesn't match
    - _Requirements: 5.2_
  
  - [x] 3.4 Implement geofence validation with PostGIS
    - Create geography point from p_latitude and p_longitude
    - Use ST_Distance to calculate distance to classroom location
    - Reject if distance > 50 meters
    - _Requirements: 5.4, 6.2, 6.3_
  
  - [x] 3.5 Implement attendance logging
    - Insert record into attendance_logs with all required fields
    - Set status to PRESENT or REJECTED based on validation results
    - Include rejection_reason for rejected attempts
    - Use single transaction for atomicity
    - _Requirements: 7.1, 7.2, 7.3_
  
  - [ ]* 3.6 Write property test for device ID verification
    - **Property 11: Device ID Verification**
    - **Validates: Requirements 5.3**
  
  - [ ]* 3.7 Write property test for secret token validation
    - **Property 10: Secret Token Validation**
    - **Validates: Requirements 5.2**
  
  - [ ]* 3.8 Write property test for distance calculation accuracy
    - **Property 12: Distance Calculation Accuracy**
    - **Validates: Requirements 5.4**
  
  - [ ]* 3.9 Write property test for geofence boundary enforcement
    - **Property 15: Geofence Boundary Enforcement**
    - **Validates: Requirements 6.2, 6.3**
  
  - [ ]* 3.10 Write property test for validation failure responses
    - **Property 14: Validation Failure Returns Rejection**
    - **Validates: Requirements 5.6**
  
  - [ ]* 3.11 Write property test for all attempts logged
    - **Property 16: All Attempts Logged**
    - **Validates: Requirements 7.1**
  
  - [ ]* 3.12 Write property test for log data model invariants
    - **Property 17: Attendance Log Data Model Invariants**
    - **Validates: Requirements 7.2, 7.3**
  
  - [ ]* 3.13 Write property test for RPC performance
    - **Property 13: RPC Performance Requirement**
    - **Validates: Requirements 5.5**
  
  - [ ]* 3.14 Write property test for input parameter validation
    - **Property 27: Input Parameter Validation**
    - **Validates: Requirements 14.2**

- [x] 4. Checkpoint - Verify database and RPC function
  - Test mark_attendance function manually with valid and invalid inputs
  - Verify all validation logic works correctly
  - Verify attendance_logs are created with correct status
  - Ensure all tests pass, ask the user if questions arise

- [x] 5. Implement Flutter authentication module
  - [x] 5.1 Create authentication service with Supabase Auth
    - Implement signInWithEmail function using Supabase client
    - Implement signOut function
    - Implement session management and token refresh
    - Handle authentication errors and return structured results
    - _Requirements: 1.1, 1.3_
  
  - [x] 5.2 Implement device binding logic
    - Create function to get unique device ID using device_info_plus
    - On first login, store device_id in profiles table
    - On subsequent logins, verify device_id matches stored value
    - Reject login if device_id mismatch
    - _Requirements: 2.1, 2.2, 2.3_
  
  - [x] 5.3 Create login screen UI
    - Build login form with email and password fields
    - Add sign in button with loading state
    - Display error messages for authentication failures
    - Navigate to home screen on successful login
    - _Requirements: 12.1_
  
  - [ ]* 5.4 Write property test for authentication success creates profile
    - **Property 1: Authentication Success Creates Profile**
    - **Validates: Requirements 1.1, 1.2**
  
  - [ ]* 5.5 Write property test for authentication failure prevents access
    - **Property 2: Authentication Failure Prevents Access**
    - **Validates: Requirements 1.3**
  
  - [ ]* 5.6 Write property test for first login binds device
    - **Property 4: First Login Binds Device**
    - **Validates: Requirements 2.1, 2.3**
  
  - [ ]* 5.7 Write property test for device binding enforcement
    - **Property 5: Device Binding Enforcement**
    - **Validates: Requirements 2.2**

- [x] 6. Implement Flutter NFC scanner module
  - [x] 6.1 Create NFC service for reading tags
    - Implement startNFCSession using nfc_manager package
    - Implement readTag to capture NDEF messages
    - Parse NDEF text records to extract JSON payload
    - Handle platform-specific NFC permissions
    - _Requirements: 3.1, 3.2_
  
  - [x] 6.2 Create NFCPayload model and JSON parsing
    - Define NFCPayload class with classroomId and secretToken fields
    - Implement fromJson factory constructor
    - Validate JSON structure and required fields
    - Handle parsing errors gracefully
    - _Requirements: 3.2, 11.3_
  
  - [ ]* 6.3 Write property test for JSON payload parsing
    - **Property 6: JSON Payload Parsing**
    - **Validates: Requirements 3.2**
  
  - [ ]* 6.4 Write property test for malformed payload rejection
    - **Property 7: Malformed Payload Rejection**
    - **Validates: Requirements 3.3**
  
  - [ ]* 6.5 Write property test for NFC payload structure validation
    - **Property 23: NFC Payload Structure Validation**
    - **Validates: Requirements 11.3**

- [x] 7. Implement Flutter GPS module
  - [x] 7.1 Create location service for GPS capture
    - Implement getCurrentLocation using geolocator package
    - Request high accuracy location mode
    - Implement timeout handling (10 seconds)
    - Check if location services are enabled
    - Request location permissions
    - _Requirements: 4.1, 4.2_
  
  - [x] 7.2 Create LocationData model
    - Define LocationData class with latitude, longitude, accuracy fields
    - Add validation for coordinate ranges
    - _Requirements: 4.4_
  
  - [ ]* 7.3 Write unit test for GPS unavailable error handling
    - Test that attendance is prevented when GPS is disabled
    - Verify error message is displayed
    - _Requirements: 4.3_

- [x] 8. Implement Flutter API client module
  - [x] 8.1 Create API client for Supabase communication
    - Implement markAttendance function calling mark_attendance RPC
    - Implement getMyAttendance function querying attendance_logs
    - Add authentication headers to all requests
    - Handle network errors and timeouts
    - Parse response JSON into Dart models
    - _Requirements: 4.4, 12.4_
  
  - [x] 8.2 Create AttendanceResult and AttendanceLog models
    - Define AttendanceResult class with status, rejectionReason, timestamp
    - Define AttendanceLog class matching database schema
    - Implement fromJson factory constructors
    - _Requirements: 7.2_
  
  - [ ]* 8.3 Write property test for coordinates transmitted to backend
    - **Property 9: Coordinates Transmitted to Backend**
    - **Validates: Requirements 4.4**
  
  - [ ]* 8.4 Write property test for attendance history retrieval
    - **Property 25: Attendance History Retrieval**
    - **Validates: Requirements 12.4**

- [x] 9. Implement Flutter UI screens
  - [x] 9.1 Create home screen with NFC ready indicator
    - Build UI with large "Tap to Scan" button
    - Display NFC ready status
    - Show recent attendance list (last 5 records)
    - Add logout button
    - _Requirements: 12.1_
  
  - [x] 9.2 Create scanning screen with loading state
    - Display loading indicator during NFC read and API call
    - Show "Processing..." message
    - Handle cancellation
    - _Requirements: 12.1_
  
  - [x] 9.3 Create result screen for success/failure
    - Display success UI with green checkmark for PRESENT status
    - Display error UI with red X and rejection reason for REJECTED status
    - Add button to return to home screen
    - _Requirements: 12.2, 12.3_
  
  - [x] 9.4 Create attendance history screen
    - Display list of all attendance records
    - Show date, classroom name, status for each record
    - Add filtering options (date range, status)
    - Implement pull-to-refresh
    - _Requirements: 12.4_
  
  - [ ]* 9.5 Write unit tests for UI state transitions
    - Test success response triggers success UI
    - Test rejection response triggers error UI with reason
    - _Requirements: 12.2, 12.3_

- [x] 10. Integrate attendance marking flow
  - [x] 10.1 Wire together NFC, GPS, and API modules
    - Implement complete flow: NFC scan → GPS capture → API call → Result display
    - Handle errors at each step with appropriate user feedback
    - Add loading states and progress indicators
    - Implement retry logic for transient failures
    - _Requirements: 3.1, 4.1, 5.1_
  
  - [x] 10.2 Implement error handling and user feedback
    - Display specific error messages for each error type
    - Handle NFC reading errors
    - Handle GPS errors (disabled, timeout, low accuracy)
    - Handle network errors (no connection, timeout, server error)
    - Handle validation errors (invalid token, device mismatch, outside geofence)
    - _Requirements: 3.3, 4.3_
  
  - [ ]* 10.3 Write integration tests for complete attendance flow
    - Test successful attendance marking end-to-end
    - Test rejection scenarios (outside geofence, invalid token)
    - _Requirements: 1.1, 3.1, 4.1, 5.1, 6.2, 7.1_

- [ ] 11. Checkpoint - Test mobile app functionality
  - Test complete attendance flow with real NFC tags
  - Verify GPS capture and geofence validation
  - Test error handling for various failure scenarios
  - Verify device binding prevents multi-device access
  - Ensure all tests pass, ask the user if questions arise

- [ ] 12. Implement admin dashboard backend queries
  - [ ] 12.1 Create SQL view for dashboard data
    - Create view joining attendance_logs, profiles, and classrooms
    - Include all required fields: student name, classroom name, building, timestamp, status, coordinates
    - Add indexes for performance
    - _Requirements: 8.2_
  
  - [ ] 12.2 Create RPC function for filtered attendance query
    - Implement function with parameters: start_date, end_date, classroom_id, status
    - Apply filters to attendance query
    - Return JSON array of attendance records
    - Enforce admin role requirement
    - _Requirements: 8.5_
  
  - [ ]* 12.3 Write property test for dashboard query completeness
    - **Property 19: Dashboard Query Completeness**
    - **Validates: Requirements 8.2**
  
  - [ ]* 12.4 Write property test for dashboard filtering
    - **Property 20: Dashboard Filtering**
    - **Validates: Requirements 8.5**

- [x] 13. Implement admin dashboard web interface
  - [x] 13.1 Set up Next.js or React project for dashboard
    - Initialize project with TypeScript
    - Install Supabase client library
    - Set up authentication for admin users
    - Configure environment variables
    - _Requirements: 8.1_
  
  - [x] 13.2 Create real-time attendance feed component
    - Subscribe to attendance_logs table changes using Supabase Realtime
    - Display recent check-ins in a list
    - Color-code by status (green for PRESENT, red for REJECTED)
    - Show student name, classroom, timestamp
    - _Requirements: 8.2, 8.4_
  
  - [x] 13.3 Create map visualization component
    - Integrate Leaflet or Mapbox for map rendering
    - Display classroom locations as markers
    - Show recent student check-in points
    - Draw 50m radius circles around classrooms
    - Add tooltips with classroom and student information
    - _Requirements: 8.3_
  
  - [x] 13.4 Create filter controls and analytics
    - Add date range picker
    - Add classroom dropdown filter
    - Add status filter (PRESENT/REJECTED/ALL)
    - Display summary statistics (total attendance, rejection rate)
    - Update map and feed when filters change
    - _Requirements: 8.5_
  
  - [ ]* 13.5 Write integration tests for dashboard
    - Test real-time updates when attendance is marked
    - Test filtering functionality
    - Test map rendering with sample data
    - _Requirements: 8.2, 8.4, 8.5_

- [x] 14. Implement security enhancements
  - [x] 14.1 Add email verification enforcement
    - Modify mark_attendance RPC to check email verification status
    - Reject attendance if email not verified
    - Add email verification flow to mobile app
    - _Requirements: 1.4_
  
  - [x] 14.2 Implement rate limiting on mark_attendance
    - Add rate limiting logic to RPC function (e.g., max 1 request per minute per user)
    - Return appropriate error when rate limit exceeded
    - _Requirements: 14.5_
  
  - [x] 14.3 Add NFC secret token rotation support
    - Create admin function to update classroom nfc_secret
    - Ensure old tokens are immediately invalidated
    - Log token rotation events
    - _Requirements: 11.5_
  
  - [ ]* 14.4 Write property test for email verification requirement
    - **Property 3: Email Verification Required for Attendance**
    - **Validates: Requirements 1.4**
  
  - [ ]* 14.5 Write unit test for rate limiting
    - Test that rapid requests trigger rate limiting
    - _Requirements: 14.5_
  
  - [ ]* 14.6 Write unit test for token rotation
    - Test that updating secret invalidates old token
    - _Requirements: 11.5_

- [x] 15. Implement RLS policy testing
  - [x]* 15.1 Write property test for row level security for students
    - **Property 22: Row Level Security for Students**
    - **Validates: Requirements 10.2, 10.3**
  
  - [x]* 15.2 Write unit test for admin access to all records
    - Test that admin users can query all profiles and attendance logs
    - _Requirements: 10.4_
  
  - [x]* 15.3 Write property test for attendance log immutability
    - **Property 18: Attendance Log Immutability**
    - **Validates: Requirements 7.4**

- [x] 16. Performance optimization and testing
  - [ ]* 16.1 Write property test for concurrent request handling
    - **Property 26: Concurrent Request Handling**
    - **Validates: Requirements 13.3**
  
  - [x] 16.2 Optimize database queries and indexes
    - Analyze query performance with EXPLAIN
    - Add additional indexes if needed
    - Optimize RPC function for sub-200ms execution
    - _Requirements: 5.5, 13.1_
  
  - [x] 16.3 Implement connection pooling and caching
    - Configure Supabase connection pooling
    - Add caching for classroom data in mobile app
    - Implement offline support for attendance history
    - _Requirements: 13.3_

- [ ] 17. Final checkpoint and integration testing
  - Run all unit tests and property tests
  - Perform end-to-end testing of complete system
  - Test with multiple concurrent users
  - Verify admin dashboard real-time updates
  - Test all error scenarios and edge cases
  - Verify performance requirements are met
  - Ensure all tests pass, ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties (minimum 100 iterations each)
- Unit tests validate specific examples and edge cases
- The implementation follows a bottom-up approach: database → backend → mobile app → dashboard
- All validation logic is implemented server-side for security
- Device binding and geofencing are enforced at the database level
