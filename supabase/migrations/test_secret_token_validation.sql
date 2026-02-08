-- Test script for Task 3.3: Secret Token Validation
-- This script tests the secret token validation logic in mark_attendance function
-- Validates Requirements: 5.2

-- ============================================
-- SETUP: Create test data
-- ============================================

-- Clean up any existing test data
DO $
BEGIN
  -- Delete test attendance logs
  DELETE FROM attendance_logs WHERE student_id IN (
    SELECT id FROM profiles WHERE email LIKE 'test_secret_token_%@test.com'
  );
  
  -- Delete test profiles
  DELETE FROM profiles WHERE email LIKE 'test_secret_token_%@test.com';
  
  -- Delete test classrooms
  DELETE FROM classrooms WHERE name LIKE 'Test Classroom Secret Token%';
END $;

-- Create test classroom with known secret token
INSERT INTO classrooms (id, name, building, location, nfc_secret)
VALUES (
  '11111111-1111-1111-1111-111111111111'::UUID,
  'Test Classroom Secret Token 1',
  'Test Building',
  ST_GeogFromText('POINT(-122.4194 37.7749)'),  -- San Francisco coordinates
  'correct_secret_token_123'
);

-- Create another test classroom with different secret token
INSERT INTO classrooms (id, name, building, location, nfc_secret)
VALUES (
  '22222222-2222-2222-2222-222222222222'::UUID,
  'Test Classroom Secret Token 2',
  'Test Building',
  ST_GeogFromText('POINT(-122.4194 37.7749)'),
  'different_secret_token_456'
);

-- Create test user profile
-- Note: In a real test, this would be created through Supabase Auth
-- For this test, we'll create a profile directly
INSERT INTO profiles (id, email, full_name, device_id)
VALUES (
  '33333333-3333-3333-3333-333333333333'::UUID,
  'test_secret_token_user@test.com',
  'Test Secret Token User',
  'test_device_12345'
);

-- ============================================
-- Test 1: Valid secret token should pass validation
-- ============================================
-- This test verifies that when the correct secret token is provided,
-- the validation passes and does not set rejection status

SELECT 'Test 1: Valid secret token' AS test_name;

-- Note: This test requires authentication context
-- In a real environment, you would authenticate as the test user first
-- For demonstration, we show the expected behavior

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: '11111111-1111-1111-1111-111111111111'
--   - secret_token: 'correct_secret_token_123'
--   - Valid coordinates
-- Then:
--   - Secret token validation should pass
--   - Status should NOT be 'REJECTED' with reason 'invalid_token'
--   - Should proceed to next validation step (geofence)

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   '11111111-1111-1111-1111-111111111111'::UUID,
--   'correct_secret_token_123',
--   37.7749,
--   -122.4194
-- );

-- ============================================
-- Test 2: Invalid secret token should reject
-- ============================================
-- This test verifies that when an incorrect secret token is provided,
-- the validation fails with 'invalid_token' rejection reason

SELECT 'Test 2: Invalid secret token' AS test_name;

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: '11111111-1111-1111-1111-111111111111'
--   - secret_token: 'wrong_token_999' (incorrect)
--   - Valid coordinates
-- Then:
--   - Secret token validation should fail
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'invalid_token'

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   '11111111-1111-1111-1111-111111111111'::UUID,
--   'wrong_token_999',
--   37.7749,
--   -122.4194
-- );
-- Expected result: {"status": "REJECTED", "rejection_reason": "invalid_token", "timestamp": "..."}

-- ============================================
-- Test 3: Non-existent classroom should reject
-- ============================================
-- This test verifies that when a classroom_id doesn't exist,
-- the validation fails with 'classroom_not_found' rejection reason

SELECT 'Test 3: Non-existent classroom' AS test_name;

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: '99999999-9999-9999-9999-999999999999' (doesn't exist)
--   - secret_token: 'any_token'
--   - Valid coordinates
-- Then:
--   - Classroom lookup should fail
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'classroom_not_found'

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   '99999999-9999-9999-9999-999999999999'::UUID,
--   'any_token',
--   37.7749,
--   -122.4194
-- );
-- Expected result: {"status": "REJECTED", "rejection_reason": "classroom_not_found", "timestamp": "..."}

-- ============================================
-- Test 4: Case-sensitive token comparison
-- ============================================
-- This test verifies that secret token comparison is case-sensitive

SELECT 'Test 4: Case-sensitive token comparison' AS test_name;

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: '11111111-1111-1111-1111-111111111111'
--   - secret_token: 'CORRECT_SECRET_TOKEN_123' (wrong case)
--   - Valid coordinates
-- Then:
--   - Secret token validation should fail (case mismatch)
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'invalid_token'

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   '11111111-1111-1111-1111-111111111111'::UUID,
--   'CORRECT_SECRET_TOKEN_123',
--   37.7749,
--   -122.4194
-- );
-- Expected result: {"status": "REJECTED", "rejection_reason": "invalid_token", "timestamp": "..."}

-- ============================================
-- Test 5: Token with extra whitespace should fail
-- ============================================
-- This test verifies that tokens with leading/trailing whitespace don't match

SELECT 'Test 5: Token with whitespace' AS test_name;

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: '11111111-1111-1111-1111-111111111111'
--   - secret_token: ' correct_secret_token_123 ' (with spaces)
--   - Valid coordinates
-- Then:
--   - Secret token validation should fail (whitespace mismatch)
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'invalid_token'

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   '11111111-1111-1111-1111-111111111111'::UUID,
--   ' correct_secret_token_123 ',
--   37.7749,
--   -122.4194
-- );
-- Expected result: {"status": "REJECTED", "rejection_reason": "invalid_token", "timestamp": "..."}

-- ============================================
-- Test 6: Using token from different classroom should fail
-- ============================================
-- This test verifies that a token from one classroom doesn't work for another

SELECT 'Test 6: Token from different classroom' AS test_name;

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: '11111111-1111-1111-1111-111111111111' (Classroom 1)
--   - secret_token: 'different_secret_token_456' (Token from Classroom 2)
--   - Valid coordinates
-- Then:
--   - Secret token validation should fail (wrong classroom)
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'invalid_token'

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   '11111111-1111-1111-1111-111111111111'::UUID,
--   'different_secret_token_456',
--   37.7749,
--   -122.4194
-- );
-- Expected result: {"status": "REJECTED", "rejection_reason": "invalid_token", "timestamp": "..."}

-- ============================================
-- Test 7: Verify secret token validation happens after device binding
-- ============================================
-- This test verifies the validation order: device binding is checked first

SELECT 'Test 7: Validation order' AS test_name;

-- Expected behavior:
-- When mark_attendance is called with:
--   - Wrong device_id in JWT (device_mismatch)
--   - Wrong secret_token
-- Then:
--   - Device binding should fail first
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'device_mismatch' (not 'invalid_token')
--   - Secret token validation should not be reached

-- This test confirms that validations are performed in the correct order
-- and that earlier validation failures prevent later validations from running

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Verify test classrooms were created
SELECT 
  'Verification: Test classrooms' AS check_name,
  COUNT(*) AS classroom_count,
  CASE 
    WHEN COUNT(*) = 2 THEN 'PASS: 2 test classrooms created'
    ELSE 'FAIL: Expected 2 test classrooms'
  END AS result
FROM classrooms 
WHERE name LIKE 'Test Classroom Secret Token%';

-- Verify test profile was created
SELECT 
  'Verification: Test profile' AS check_name,
  COUNT(*) AS profile_count,
  CASE 
    WHEN COUNT(*) = 1 THEN 'PASS: Test profile created'
    ELSE 'FAIL: Expected 1 test profile'
  END AS result
FROM profiles 
WHERE email = 'test_secret_token_user@test.com';

-- Verify secret tokens are stored correctly
SELECT 
  'Verification: Secret tokens' AS check_name,
  id,
  name,
  nfc_secret
FROM classrooms 
WHERE name LIKE 'Test Classroom Secret Token%'
ORDER BY name;

-- ============================================
-- CLEANUP (Optional - uncomment to clean up test data)
-- ============================================

-- DO $
-- BEGIN
--   -- Delete test attendance logs
--   DELETE FROM attendance_logs WHERE student_id IN (
--     SELECT id FROM profiles WHERE email LIKE 'test_secret_token_%@test.com'
--   );
--   
--   -- Delete test profiles
--   DELETE FROM profiles WHERE email LIKE 'test_secret_token_%@test.com';
--   
--   -- Delete test classrooms
--   DELETE FROM classrooms WHERE name LIKE 'Test Classroom Secret Token%';
-- END $;

-- ============================================
-- SUMMARY
-- ============================================

SELECT 
  'Summary' AS section,
  'Task 3.3: Secret Token Validation Tests' AS task,
  'Requirements: 5.2' AS validates;

SELECT 
  'Test Coverage' AS section,
  'Test 1: Valid token passes' AS test_1,
  'Test 2: Invalid token rejects' AS test_2,
  'Test 3: Non-existent classroom rejects' AS test_3,
  'Test 4: Case-sensitive comparison' AS test_4,
  'Test 5: Whitespace handling' AS test_5,
  'Test 6: Cross-classroom token fails' AS test_6,
  'Test 7: Validation order' AS test_7;

-- ============================================
-- INSTRUCTIONS FOR RUNNING TESTS
-- ============================================
-- To run these tests in a real environment:
-- 
-- 1. Apply the migration that creates the mark_attendance function
-- 2. Run this test script to create test data
-- 3. Set up Supabase Auth test user with the test profile ID
-- 4. Authenticate as the test user
-- 5. Uncomment and run each test query individually
-- 6. Verify the JSON responses match expected results
-- 7. Check attendance_logs table to verify records were created
-- 8. Run cleanup script to remove test data
--
-- Expected Results:
-- - Test 1: Status should be PRESENT or proceed to geofence validation
-- - Test 2: Status REJECTED, reason 'invalid_token'
-- - Test 3: Status REJECTED, reason 'classroom_not_found'
-- - Test 4: Status REJECTED, reason 'invalid_token'
-- - Test 5: Status REJECTED, reason 'invalid_token'
-- - Test 6: Status REJECTED, reason 'invalid_token'
-- - Test 7: Status REJECTED, reason 'device_mismatch' (not 'invalid_token')

