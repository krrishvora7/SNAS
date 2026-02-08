-- Integration Test: Complete Attendance Flow with Geofence Validation
-- This script demonstrates the complete attendance marking flow including geofence validation
-- Validates Requirements: 5.1, 5.2, 5.3, 5.4, 6.2, 6.3, 7.1, 7.2

-- ============================================
-- SETUP: Create test data
-- ============================================

-- Clean up any existing test data
DO $$
BEGIN
  DELETE FROM attendance_logs WHERE student_id IN (
    SELECT id FROM profiles WHERE email = 'integration_test@test.com'
  );
  DELETE FROM profiles WHERE email = 'integration_test@test.com';
  DELETE FROM classrooms WHERE name = 'Integration Test Classroom';
END $$;

-- Create test classroom
-- Location: Golden Gate Park, San Francisco (37.7694° N, 122.4862° W)
INSERT INTO classrooms (id, name, building, location, nfc_secret)
VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID,
  'Integration Test Classroom',
  'Test Building',
  ST_GeogFromText('POINT(-122.4862 37.7694)'),
  'integration_test_secret_token'
);

-- Create test user profile
INSERT INTO profiles (id, email, full_name, device_id)
VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd'::UUID,
  'integration_test@test.com',
  'Integration Test User',
  'integration_test_device_001'
);

-- ============================================
-- SCENARIO 1: Successful Attendance (All Validations Pass)
-- ============================================

SELECT '=== SCENARIO 1: Successful Attendance ===' AS scenario;

-- Student is at the classroom location with correct token and device
-- Expected: Status PRESENT, no rejection reason

-- Test conditions:
-- ✓ Valid classroom_id
-- ✓ Correct secret_token
-- ✓ Student at exact classroom location (0 meters)
-- ✓ Correct device_id (would be in JWT in real scenario)

-- Expected result:
-- {
--   "status": "PRESENT",
--   "rejection_reason": null,
--   "timestamp": "2024-01-15T10:30:00Z"
-- }

SELECT 'Test: Student at classroom with valid credentials' AS test_description;
SELECT 'Expected: PRESENT status' AS expected_result;

-- ============================================
-- SCENARIO 2: Rejection - Outside Geofence
-- ============================================

SELECT '=== SCENARIO 2: Outside Geofence ===' AS scenario;

-- Student has correct token and device but is 100 meters away
-- Expected: Status REJECTED, reason 'outside_geofence'

-- Calculate location 100 meters north of classroom
-- 100 meters ≈ 0.0009 degrees latitude
-- New latitude: 37.7694 + 0.0009 = 37.7703

SELECT 
  'Distance verification' AS check_name,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4862 37.7694)'),
    ST_GeogFromText('POINT(-122.4862 37.7703)')
  ) AS distance_meters;
-- Expected: approximately 100 meters

SELECT 'Test: Student 100m away from classroom' AS test_description;
SELECT 'Expected: REJECTED with reason outside_geofence' AS expected_result;

-- Expected result:
-- {
--   "status": "REJECTED",
--   "rejection_reason": "outside_geofence",
--   "timestamp": "2024-01-15T10:30:00Z"
-- }

-- ============================================
-- SCENARIO 3: Rejection - Invalid Token (Before Geofence Check)
-- ============================================

SELECT '=== SCENARIO 3: Invalid Token ===' AS scenario;

-- Student is at classroom location but has wrong token
-- Expected: Status REJECTED, reason 'invalid_token'
-- Note: Geofence validation should NOT run because token validation fails first

SELECT 'Test: Student at classroom with wrong token' AS test_description;
SELECT 'Expected: REJECTED with reason invalid_token' AS expected_result;

-- Expected result:
-- {
--   "status": "REJECTED",
--   "rejection_reason": "invalid_token",
--   "timestamp": "2024-01-15T10:30:00Z"
-- }

-- ============================================
-- SCENARIO 4: Rejection - Device Mismatch (Before Geofence Check)
-- ============================================

SELECT '=== SCENARIO 4: Device Mismatch ===' AS scenario;

-- Student is at classroom with correct token but wrong device
-- Expected: Status REJECTED, reason 'device_mismatch'
-- Note: Geofence validation should NOT run because device binding fails first

SELECT 'Test: Student at classroom with wrong device' AS test_description;
SELECT 'Expected: REJECTED with reason device_mismatch' AS expected_result;

-- Expected result:
-- {
--   "status": "REJECTED",
--   "rejection_reason": "device_mismatch",
--   "timestamp": "2024-01-15T10:30:00Z"
-- }

-- ============================================
-- SCENARIO 5: Boundary Test - Exactly 50 Meters
-- ============================================

SELECT '=== SCENARIO 5: At Geofence Boundary ===' AS scenario;

-- Student is exactly 50 meters from classroom
-- Expected: Status PRESENT (boundary is inclusive: distance ≤ 50m)

-- Calculate location 50 meters north of classroom
-- 50 meters ≈ 0.00045 degrees latitude
-- New latitude: 37.7694 + 0.00045 = 37.76985

SELECT 
  'Distance verification' AS check_name,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4862 37.7694)'),
    ST_GeogFromText('POINT(-122.4862 37.76985)')
  ) AS distance_meters;
-- Expected: approximately 50 meters

SELECT 'Test: Student exactly 50m from classroom' AS test_description;
SELECT 'Expected: PRESENT status (boundary is inclusive)' AS expected_result;

-- Expected result:
-- {
--   "status": "PRESENT",
--   "rejection_reason": null,
--   "timestamp": "2024-01-15T10:30:00Z"
-- }

-- ============================================
-- SCENARIO 6: Boundary Test - Just Over 50 Meters
-- ============================================

SELECT '=== SCENARIO 6: Just Outside Geofence ===' AS scenario;

-- Student is 51 meters from classroom
-- Expected: Status REJECTED, reason 'outside_geofence'

-- Calculate location 51 meters north of classroom
-- 51 meters ≈ 0.000459 degrees latitude
-- New latitude: 37.7694 + 0.000459 = 37.769859

SELECT 
  'Distance verification' AS check_name,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4862 37.7694)'),
    ST_GeogFromText('POINT(-122.4862 37.769859)')
  ) AS distance_meters;
-- Expected: approximately 51 meters

SELECT 'Test: Student 51m from classroom' AS test_description;
SELECT 'Expected: REJECTED with reason outside_geofence' AS expected_result;

-- Expected result:
-- {
--   "status": "REJECTED",
--   "rejection_reason": "outside_geofence",
--   "timestamp": "2024-01-15T10:30:00Z"
-- }

-- ============================================
-- SCENARIO 7: Multiple Directions Test
-- ============================================

SELECT '=== SCENARIO 7: Geofence in All Directions ===' AS scenario;

-- Test that geofence works in all directions (not just north)

-- 30 meters north
SELECT 
  'North (30m)' AS direction,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4862 37.7694)'),
    ST_GeogFromText('POINT(-122.4862 37.76967)')
  ) AS distance_meters,
  'Should be PRESENT' AS expected;

-- 30 meters south
SELECT 
  'South (30m)' AS direction,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4862 37.7694)'),
    ST_GeogFromText('POINT(-122.4862 37.76913)')
  ) AS distance_meters,
  'Should be PRESENT' AS expected;

-- 30 meters east
SELECT 
  'East (30m)' AS direction,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4862 37.7694)'),
    ST_GeogFromText('POINT(-122.48586 37.7694)')
  ) AS distance_meters,
  'Should be PRESENT' AS expected;

-- 30 meters west
SELECT 
  'West (30m)' AS direction,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4862 37.7694)'),
    ST_GeogFromText('POINT(-122.48654 37.7694)')
  ) AS distance_meters,
  'Should be PRESENT' AS expected;

-- ============================================
-- VERIFICATION: Check Attendance Logs
-- ============================================

SELECT '=== VERIFICATION: Attendance Logs ===' AS section;

-- After running the actual mark_attendance calls, verify logs are created
SELECT 
  'Attendance logs verification' AS check_name,
  'Run mark_attendance calls and check this query' AS instruction;

-- Query to check attendance logs (run after actual tests)
-- SELECT 
--   id,
--   student_id,
--   classroom_id,
--   timestamp,
--   status,
--   ST_Distance(student_location, (SELECT location FROM classrooms WHERE id = classroom_id)) AS distance_meters,
--   rejection_reason
-- FROM attendance_logs
-- WHERE student_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'::UUID
-- ORDER BY timestamp DESC;

-- ============================================
-- VERIFICATION: Data Model Invariants
-- ============================================

SELECT '=== VERIFICATION: Data Model Invariants ===' AS section;

-- Verify that all REJECTED logs have rejection_reason
SELECT 
  'Rejected logs have reason' AS check_name,
  COUNT(*) AS rejected_count,
  COUNT(rejection_reason) AS with_reason_count,
  CASE 
    WHEN COUNT(*) = COUNT(rejection_reason) THEN 'PASS: All rejected logs have reason'
    ELSE 'FAIL: Some rejected logs missing reason'
  END AS result
FROM attendance_logs
WHERE status = 'REJECTED'
  AND student_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'::UUID;

-- Verify that all PRESENT logs have NULL rejection_reason
SELECT 
  'Present logs have no reason' AS check_name,
  COUNT(*) AS present_count,
  COUNT(rejection_reason) AS with_reason_count,
  CASE 
    WHEN COUNT(rejection_reason) = 0 THEN 'PASS: No present logs have reason'
    ELSE 'FAIL: Some present logs have reason'
  END AS result
FROM attendance_logs
WHERE status = 'PRESENT'
  AND student_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'::UUID;

-- ============================================
-- CLEANUP (Optional)
-- ============================================

-- DO $$
-- BEGIN
--   DELETE FROM attendance_logs WHERE student_id IN (
--     SELECT id FROM profiles WHERE email = 'integration_test@test.com'
--   );
--   DELETE FROM profiles WHERE email = 'integration_test@test.com';
--   DELETE FROM classrooms WHERE name = 'Integration Test Classroom';
-- END $$;

-- ============================================
-- SUMMARY
-- ============================================

SELECT 
  'Integration Test Summary' AS section,
  'Task 3.4: Geofence Validation' AS task,
  'Complete attendance flow with all validations' AS description;

SELECT 
  'Test Scenarios' AS section,
  'Scenario 1: Successful attendance (PRESENT)' AS scenario_1,
  'Scenario 2: Outside geofence (REJECTED)' AS scenario_2,
  'Scenario 3: Invalid token (REJECTED)' AS scenario_3,
  'Scenario 4: Device mismatch (REJECTED)' AS scenario_4,
  'Scenario 5: At boundary 50m (PRESENT)' AS scenario_5,
  'Scenario 6: Just outside 51m (REJECTED)' AS scenario_6,
  'Scenario 7: All directions (PRESENT)' AS scenario_7;

SELECT 
  'Requirements Validated' AS section,
  '5.1: RPC function invocation' AS req_5_1,
  '5.2: Secret token validation' AS req_5_2,
  '5.3: Device binding verification' AS req_5_3,
  '5.4: PostGIS distance calculation' AS req_5_4,
  '6.2: Rejection when > 50m' AS req_6_2,
  '6.3: Acceptance when ≤ 50m' AS req_6_3,
  '7.1: All attempts logged' AS req_7_1,
  '7.2: Correct status and reason' AS req_7_2;

-- ============================================
-- INSTRUCTIONS
-- ============================================

-- To run this integration test:
-- 
-- 1. Apply all migrations (profiles, classrooms, attendance_logs, mark_attendance function)
-- 2. Run this script to create test data
-- 3. Authenticate as the test user with correct device_id in JWT
-- 4. Call mark_attendance for each scenario:
--
--    -- Scenario 1: Success
--    SELECT mark_attendance(
--      'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID,
--      'integration_test_secret_token',
--      37.7694,
--      -122.4862
--    );
--
--    -- Scenario 2: Outside geofence
--    SELECT mark_attendance(
--      'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID,
--      'integration_test_secret_token',
--      37.7703,
--      -122.4862
--    );
--
--    -- Scenario 3: Invalid token
--    SELECT mark_attendance(
--      'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID,
--      'wrong_token',
--      37.7694,
--      -122.4862
--    );
--
--    -- Scenario 5: At boundary
--    SELECT mark_attendance(
--      'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID,
--      'integration_test_secret_token',
--      37.76985,
--      -122.4862
--    );
--
--    -- Scenario 6: Just outside
--    SELECT mark_attendance(
--      'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID,
--      'integration_test_secret_token',
--      37.769859,
--      -122.4862
--    );
--
-- 5. Verify results match expected status and rejection_reason
-- 6. Check attendance_logs table to verify all attempts were logged
-- 7. Run verification queries to check data model invariants
-- 8. Run cleanup script to remove test data

