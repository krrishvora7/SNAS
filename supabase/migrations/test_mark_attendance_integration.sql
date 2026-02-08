-- Integration test for mark_attendance function
-- This test verifies the function can be called and returns the expected structure
-- Note: This test requires proper authentication context to run successfully

-- ============================================
-- Setup Test Data
-- ============================================

-- Note: In a real test environment, you would:
-- 1. Create a test user in auth.users
-- 2. Create a test profile
-- 3. Create a test classroom
-- 4. Authenticate as the test user
-- 5. Call mark_attendance
-- 6. Verify the response and database state

-- ============================================
-- Example Test Flow (Pseudo-code)
-- ============================================

-- Step 1: Create test user (via Supabase Auth API)
-- POST /auth/v1/signup
-- { "email": "test@university.edu", "password": "testpass123" }

-- Step 2: Create test profile
-- INSERT INTO profiles (id, email, full_name, device_id)
-- VALUES (
--   'test-user-uuid',
--   'test@university.edu',
--   'Test Student',
--   'test-device-id'
-- );

-- Step 3: Create test classroom
-- INSERT INTO classrooms (id, name, building, location, nfc_secret)
-- VALUES (
--   'test-classroom-uuid',
--   'Test Room 101',
--   'Test Building',
--   ST_GeogFromText('POINT(-122.4194 37.7749)'),  -- San Francisco
--   'test-secret-token-12345'
-- );

-- Step 4: Authenticate and call function
-- (Requires authentication context with JWT token)
-- SELECT mark_attendance(
--   'test-classroom-uuid'::UUID,
--   'test-secret-token-12345',
--   37.7749,  -- Latitude (San Francisco)
--   -122.4194  -- Longitude (San Francisco)
-- );

-- Expected Response:
-- {
--   "status": "PRESENT",
--   "rejection_reason": null,
--   "timestamp": "2024-01-15T10:30:00Z"
-- }

-- Step 5: Verify attendance log was created
-- SELECT * FROM attendance_logs
-- WHERE student_id = 'test-user-uuid'
-- AND classroom_id = 'test-classroom-uuid'
-- ORDER BY timestamp DESC
-- LIMIT 1;

-- Expected Result:
-- - Record exists
-- - status = 'PRESENT'
-- - rejection_reason IS NULL
-- - student_location matches input coordinates
-- - timestamp is recent

-- ============================================
-- Validation Test Cases
-- ============================================

-- Test Case 1: Valid parameters within geofence
-- Input: Valid classroom_id, correct secret, coordinates within 50m
-- Expected: status = 'PRESENT', rejection_reason = NULL

-- Test Case 2: Null classroom_id
-- Input: NULL classroom_id
-- Expected: Exception "Parameter p_classroom_id cannot be null"

-- Test Case 3: Null secret_token
-- Input: NULL secret_token
-- Expected: Exception "Parameter p_secret_token cannot be null"

-- Test Case 4: Null latitude
-- Input: NULL latitude
-- Expected: Exception "Parameter p_latitude cannot be null"

-- Test Case 5: Null longitude
-- Input: NULL longitude
-- Expected: Exception "Parameter p_longitude cannot be null"

-- Test Case 6: Invalid latitude (< -90)
-- Input: latitude = -91
-- Expected: Exception "Invalid latitude: -91. Must be between -90 and 90"

-- Test Case 7: Invalid latitude (> 90)
-- Input: latitude = 91
-- Expected: Exception "Invalid latitude: 91. Must be between -90 and 90"

-- Test Case 8: Invalid longitude (< -180)
-- Input: longitude = -181
-- Expected: Exception "Invalid longitude: -181. Must be between -180 and 180"

-- Test Case 9: Invalid longitude (> 180)
-- Input: longitude = 181
-- Expected: Exception "Invalid longitude: 181. Must be between -180 and 180"

-- Test Case 10: Empty secret token
-- Input: secret_token = '   ' (whitespace only)
-- Expected: Exception "Secret token cannot be empty"

-- Test Case 11: Boundary latitude values
-- Input: latitude = 90.0 or -90.0
-- Expected: Success (valid boundary values)

-- Test Case 12: Boundary longitude values
-- Input: longitude = 180.0 or -180.0
-- Expected: Success (valid boundary values)

-- ============================================
-- Manual Testing Instructions
-- ============================================

-- To manually test this function:

-- 1. Apply all migrations (Tasks 2.1, 2.2, 2.3, 3.1)
-- 2. Create a test user via Supabase Auth
-- 3. Insert test data:

/*
-- Insert test profile
INSERT INTO profiles (id, email, full_name, device_id)
VALUES (
  'your-test-user-uuid',
  'test@university.edu',
  'Test Student',
  'test-device-id-123'
);

-- Insert test classroom
INSERT INTO classrooms (name, building, location, nfc_secret)
VALUES (
  'Room 101',
  'Engineering Building',
  ST_GeogFromText('POINT(-122.4194 37.7749)'),
  'secret-abc123'
)
RETURNING id;  -- Note the returned UUID
*/

-- 4. Authenticate as the test user (get JWT token)
-- 5. Call the function via Supabase client or SQL:

/*
SELECT mark_attendance(
  'your-classroom-uuid'::UUID,
  'secret-abc123',
  37.7749,
  -122.4194
);
*/

-- 6. Verify the response JSON structure
-- 7. Query attendance_logs to verify record was created:

/*
SELECT 
  id,
  student_id,
  classroom_id,
  timestamp,
  status,
  ST_AsText(student_location::geometry) AS location,
  rejection_reason
FROM attendance_logs
ORDER BY timestamp DESC
LIMIT 5;
*/

-- ============================================
-- Automated Testing with pgTAP (Optional)
-- ============================================

-- If you have pgTAP installed, you can write automated tests:

/*
BEGIN;
SELECT plan(5);

-- Test 1: Function exists
SELECT has_function(
  'public',
  'mark_attendance',
  ARRAY['uuid', 'text', 'double precision', 'double precision'],
  'mark_attendance function should exist'
);

-- Test 2: Function returns JSON
SELECT function_returns(
  'public',
  'mark_attendance',
  ARRAY['uuid', 'text', 'double precision', 'double precision'],
  'json',
  'mark_attendance should return JSON'
);

-- Test 3: Function is SECURITY DEFINER
SELECT is(
  (SELECT prosecdef FROM pg_proc WHERE proname = 'mark_attendance'),
  true,
  'mark_attendance should be SECURITY DEFINER'
);

-- Test 4: Null parameter raises exception
SELECT throws_ok(
  'SELECT mark_attendance(NULL, ''token'', 37.7749, -122.4194)',
  'Parameter p_classroom_id cannot be null'
);

-- Test 5: Invalid latitude raises exception
SELECT throws_ok(
  'SELECT mark_attendance(''550e8400-e29b-41d4-a716-446655440000''::UUID, ''token'', 91.0, -122.4194)',
  'Invalid latitude: 91. Must be between -90 and 90'
);

SELECT * FROM finish();
ROLLBACK;
*/

-- ============================================
-- Summary
-- ============================================

SELECT 
  'Integration Test Summary' AS section,
  'This file provides test cases and instructions for testing mark_attendance' AS description,
  'Requires authentication context and test data to run' AS note;

SELECT 
  'Next Steps' AS section,
  'Apply migration 20240101000003_create_mark_attendance_function.sql' AS step_1,
  'Create test user and test data' AS step_2,
  'Run manual tests with authenticated user' AS step_3,
  'Verify JSON response structure and database state' AS step_4;
