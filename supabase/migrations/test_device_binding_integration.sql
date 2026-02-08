-- Integration Test: Device Binding Verification
-- Task 3.2: Implement device binding verification
-- This test demonstrates the device binding verification flow

-- ============================================
-- TEST SETUP
-- ============================================

-- Note: This is a demonstration test that shows the expected behavior.
-- In a real environment, this would require:
-- 1. Supabase Auth configured
-- 2. Test users with JWT tokens
-- 3. Device IDs in JWT metadata

BEGIN;

-- Clean up any existing test data
DELETE FROM attendance_logs WHERE classroom_id IN (
  SELECT id FROM classrooms WHERE name LIKE 'Device Test%'
);
DELETE FROM classrooms WHERE name LIKE 'Device Test%';
DELETE FROM profiles WHERE email LIKE 'device.test%';

-- Create test classroom
INSERT INTO classrooms (id, name, building, location, nfc_secret)
VALUES (
  '22222222-2222-2222-2222-222222222222'::UUID,
  'Device Test Room',
  'Test Building',
  ST_GeogFromText('POINT(-122.4194 37.7749)'),
  'device_test_secret_token'
);

-- ============================================
-- TEST SCENARIO 1: Profile Not Found
-- ============================================

-- Expected behavior: If a user is authenticated but has no profile,
-- the function should reject with 'profile_not_found'

-- This would happen if:
-- - User is authenticated via Supabase Auth
-- - But no profile record exists in the profiles table
-- - This is an edge case that should be handled gracefully

SELECT 
  'Test Scenario 1: Profile Not Found' AS test_name,
  'If authenticated user has no profile, should reject with profile_not_found' AS expected_behavior;

-- ============================================
-- TEST SCENARIO 2: Device ID Missing from JWT
-- ============================================

-- Expected behavior: If JWT doesn't contain device_id,
-- the function should reject with 'device_id_missing'

-- This would happen if:
-- - User is authenticated
-- - Profile exists
-- - But JWT doesn't contain device_id in app_metadata or user_metadata
-- - This is a security measure to prevent bypass

SELECT 
  'Test Scenario 2: Device ID Missing from JWT' AS test_name,
  'If JWT lacks device_id, should reject with device_id_missing' AS expected_behavior;

-- ============================================
-- TEST SCENARIO 3: Device ID Mismatch
-- ============================================

-- Expected behavior: If stored device_id doesn't match JWT device_id,
-- the function should reject with 'device_mismatch'

-- Create test profile with device_id
INSERT INTO profiles (id, email, full_name, device_id)
VALUES (
  '33333333-3333-3333-3333-333333333333'::UUID,
  'device.test.mismatch@example.com',
  'Device Test User - Mismatch',
  'stored_device_abc123'
);

SELECT 
  'Test Scenario 3: Device ID Mismatch' AS test_name,
  'Profile device_id: stored_device_abc123' AS setup,
  'JWT device_id: different_device_xyz789' AS jwt_claim,
  'Expected: REJECTED with device_mismatch' AS expected_result;

-- In a real test with auth context:
-- SET LOCAL jwt.claims.app_metadata = '{"device_id": "different_device_xyz789"}';
-- SELECT mark_attendance(
--   '22222222-2222-2222-2222-222222222222'::UUID,
--   'device_test_secret_token',
--   37.7749,
--   -122.4194
-- );
-- Expected result: {"status": "REJECTED", "rejection_reason": "device_mismatch", ...}

-- ============================================
-- TEST SCENARIO 4: Device ID Match (Success)
-- ============================================

-- Expected behavior: If stored device_id matches JWT device_id,
-- device binding verification should pass

-- Create test profile with device_id
INSERT INTO profiles (id, email, full_name, device_id)
VALUES (
  '44444444-4444-4444-4444-444444444444'::UUID,
  'device.test.match@example.com',
  'Device Test User - Match',
  'matching_device_abc123'
);

SELECT 
  'Test Scenario 4: Device ID Match' AS test_name,
  'Profile device_id: matching_device_abc123' AS setup,
  'JWT device_id: matching_device_abc123' AS jwt_claim,
  'Expected: Device binding passes, proceeds to next validation' AS expected_result;

-- In a real test with auth context:
-- SET LOCAL jwt.claims.app_metadata = '{"device_id": "matching_device_abc123"}';
-- SELECT mark_attendance(
--   '22222222-2222-2222-2222-222222222222'::UUID,
--   'device_test_secret_token',
--   37.7749,
--   -122.4194
-- );
-- Expected result: Device binding passes, status depends on other validations

-- ============================================
-- TEST SCENARIO 5: First Login (NULL device_id)
-- ============================================

-- Expected behavior: If profile has NULL device_id (first login),
-- device binding should not reject

-- Create test profile without device_id
INSERT INTO profiles (id, email, full_name, device_id)
VALUES (
  '55555555-5555-5555-5555-555555555555'::UUID,
  'device.test.firstlogin@example.com',
  'Device Test User - First Login',
  NULL  -- Device not yet bound
);

SELECT 
  'Test Scenario 5: First Login (NULL device_id)' AS test_name,
  'Profile device_id: NULL' AS setup,
  'JWT device_id: new_device_first_login' AS jwt_claim,
  'Expected: Device binding passes (allows first login)' AS expected_result;

-- In a real test with auth context:
-- SET LOCAL jwt.claims.app_metadata = '{"device_id": "new_device_first_login"}';
-- SELECT mark_attendance(
--   '22222222-2222-2222-2222-222222222222'::UUID,
--   'device_test_secret_token',
--   37.7749,
--   -122.4194
-- );
-- Expected result: Device binding passes, status depends on other validations
-- Note: The mobile app should then UPDATE the profile to set device_id

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Verify test profiles were created
SELECT 
  'Verification: Test Profiles Created' AS check_name,
  COUNT(*) AS profile_count,
  CASE 
    WHEN COUNT(*) = 3 THEN 'PASS: 3 test profiles created'
    ELSE 'FAIL: Expected 3 test profiles'
  END AS result
FROM profiles
WHERE email LIKE 'device.test%';

-- Verify test classroom was created
SELECT 
  'Verification: Test Classroom Created' AS check_name,
  COUNT(*) AS classroom_count,
  CASE 
    WHEN COUNT(*) = 1 THEN 'PASS: Test classroom created'
    ELSE 'FAIL: Expected 1 test classroom'
  END AS result
FROM classrooms
WHERE name = 'Device Test Room';

-- Show test profiles
SELECT 
  'Test Profiles Summary' AS section,
  email,
  device_id,
  CASE 
    WHEN device_id IS NULL THEN 'First login scenario'
    ELSE 'Device bound scenario'
  END AS scenario
FROM profiles
WHERE email LIKE 'device.test%'
ORDER BY email;

-- ============================================
-- CLEANUP
-- ============================================

-- Rollback to clean up test data
ROLLBACK;

-- ============================================
-- SUMMARY
-- ============================================

SELECT 
  'Device Binding Integration Test Summary' AS summary,
  'This test demonstrates 5 device binding scenarios' AS description,
  'Run with proper auth context to test actual behavior' AS note;

-- ============================================
-- INSTRUCTIONS FOR REAL TESTING
-- ============================================

-- To test with actual authentication:
-- 
-- 1. Set up Supabase local development environment:
--    supabase start
-- 
-- 2. Create test users via Supabase Auth:
--    supabase auth signup --email device.test.mismatch@example.com --password testpass123
-- 
-- 3. Get JWT token for test user:
--    supabase auth login --email device.test.mismatch@example.com --password testpass123
-- 
-- 4. Update user metadata to include device_id:
--    supabase auth update-user --user-id <uuid> --app-metadata '{"device_id": "test_device"}'
-- 
-- 5. Make authenticated request to mark_attendance:
--    curl -X POST https://your-project.supabase.co/rest/v1/rpc/mark_attendance \
--      -H "Authorization: Bearer <jwt-token>" \
--      -H "Content-Type: application/json" \
--      -d '{
--        "p_classroom_id": "22222222-2222-2222-2222-222222222222",
--        "p_secret_token": "device_test_secret_token",
--        "p_latitude": 37.7749,
--        "p_longitude": -122.4194
--      }'
-- 
-- 6. Verify response contains expected rejection reason or success status
-- 
-- 7. Check attendance_logs table for logged attempt:
--    SELECT * FROM attendance_logs ORDER BY timestamp DESC LIMIT 1;

