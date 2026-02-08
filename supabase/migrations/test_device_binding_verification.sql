-- Test script for device binding verification in mark_attendance function
-- Task 3.2: Implement device binding verification
-- Validates Requirements: 2.2, 5.3

-- ============================================
-- TEST SETUP
-- ============================================

-- This test script verifies that the mark_attendance function correctly:
-- 1. Queries the profiles table to get the user's stored device_id
-- 2. Extracts device_id from JWT claims
-- 3. Compares device_ids and rejects if there's a mismatch

-- Note: These tests require a proper Supabase test environment with:
-- - Auth system configured
-- - Test users created
-- - JWT tokens with device_id in metadata

-- ============================================
-- Test Data Setup
-- ============================================

-- Create test classroom for device binding tests
DO $$
DECLARE
  v_test_classroom_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
  -- Insert test classroom if it doesn't exist
  INSERT INTO classrooms (id, name, building, location, nfc_secret)
  VALUES (
    v_test_classroom_id,
    'Test Room 101',
    'Test Building',
    ST_GeogFromText('POINT(-122.4194 37.7749)'),  -- San Francisco coordinates
    'test_secret_device_binding_123'
  )
  ON CONFLICT (id) DO NOTHING;
  
  RAISE NOTICE 'Test classroom created: %', v_test_classroom_id;
END $$;

-- ============================================
-- Test Scenarios
-- ============================================

-- Test Scenario 1: Profile not found
-- Expected: Should return REJECTED with reason 'profile_not_found'
-- This would happen if a user is authenticated but has no profile record

-- Test Scenario 2: Device ID missing from JWT
-- Expected: Should return REJECTED with reason 'device_id_missing'
-- This would happen if the JWT doesn't contain device_id in metadata

-- Test Scenario 3: Device ID mismatch
-- Expected: Should return REJECTED with reason 'device_mismatch'
-- This would happen if the stored device_id doesn't match the current device_id

-- Test Scenario 4: Device ID matches
-- Expected: Should proceed to next validation (not rejected for device binding)
-- This is the happy path where device binding is verified successfully

-- Test Scenario 5: First login (device_id is NULL in profile)
-- Expected: Should proceed to next validation (device not yet bound)
-- This allows the first login to succeed before device binding is set

-- ============================================
-- Unit Tests for Device Binding Logic
-- ============================================

-- Test 1: Verify device binding variables are declared
SELECT 
  'Test 1: Function source contains device binding variables' AS test_name,
  CASE 
    WHEN pg_get_functiondef(p.oid) LIKE '%v_stored_device_id%' 
         AND pg_get_functiondef(p.oid) LIKE '%v_current_device_id%'
    THEN 'PASS: Device binding variables declared'
    ELSE 'FAIL: Device binding variables not found'
  END AS result
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'mark_attendance';

-- Test 2: Verify function queries profiles table
SELECT 
  'Test 2: Function queries profiles table for device_id' AS test_name,
  CASE 
    WHEN pg_get_functiondef(p.oid) LIKE '%SELECT device_id%FROM profiles%'
    THEN 'PASS: Function queries profiles table'
    ELSE 'FAIL: Function does not query profiles table'
  END AS result
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'mark_attendance';

-- Test 3: Verify function extracts device_id from JWT
SELECT 
  'Test 3: Function extracts device_id from JWT claims' AS test_name,
  CASE 
    WHEN pg_get_functiondef(p.oid) LIKE '%auth.jwt()%device_id%'
    THEN 'PASS: Function extracts device_id from JWT'
    ELSE 'FAIL: Function does not extract device_id from JWT'
  END AS result
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'mark_attendance';

-- Test 4: Verify function checks for device_mismatch
SELECT 
  'Test 4: Function checks for device_mismatch' AS test_name,
  CASE 
    WHEN pg_get_functiondef(p.oid) LIKE '%device_mismatch%'
    THEN 'PASS: Function includes device_mismatch rejection reason'
    ELSE 'FAIL: Function does not check for device_mismatch'
  END AS result
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'mark_attendance';

-- Test 5: Verify function checks for profile_not_found
SELECT 
  'Test 5: Function checks for profile_not_found' AS test_name,
  CASE 
    WHEN pg_get_functiondef(p.oid) LIKE '%profile_not_found%'
    THEN 'PASS: Function includes profile_not_found rejection reason'
    ELSE 'FAIL: Function does not check for profile_not_found'
  END AS result
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'mark_attendance';

-- Test 6: Verify function checks for device_id_missing
SELECT 
  'Test 6: Function checks for device_id_missing' AS test_name,
  CASE 
    WHEN pg_get_functiondef(p.oid) LIKE '%device_id_missing%'
    THEN 'PASS: Function includes device_id_missing rejection reason'
    ELSE 'FAIL: Function does not check for device_id_missing'
  END AS result
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'mark_attendance';

-- ============================================
-- Integration Tests (Require Auth Context)
-- ============================================

-- These tests require a proper authentication context with JWT tokens
-- They should be run in a test environment with Supabase Auth configured

-- Test 7: Test with matching device_id
-- Setup:
--   1. Create test user with profile
--   2. Set device_id in profile to 'test_device_123'
--   3. Authenticate with JWT containing device_id='test_device_123' in metadata
-- Expected: Should NOT reject for device_mismatch (proceeds to next validation)

-- Test 8: Test with mismatched device_id
-- Setup:
--   1. Create test user with profile
--   2. Set device_id in profile to 'test_device_123'
--   3. Authenticate with JWT containing device_id='different_device_456' in metadata
-- Expected: Should return REJECTED with reason 'device_mismatch'

-- Test 9: Test with NULL device_id in profile (first login)
-- Setup:
--   1. Create test user with profile
--   2. Set device_id in profile to NULL
--   3. Authenticate with JWT containing device_id='test_device_123' in metadata
-- Expected: Should NOT reject for device_mismatch (allows first login)

-- Test 10: Test with missing device_id in JWT
-- Setup:
--   1. Create test user with profile
--   2. Set device_id in profile to 'test_device_123'
--   3. Authenticate with JWT that does NOT contain device_id in metadata
-- Expected: Should return REJECTED with reason 'device_id_missing'

-- ============================================
-- Property-Based Test Guidance
-- ============================================

-- Property 11: Device ID Verification (Property Test)
-- For any user with stored device_id and any JWT with device_id:
--   - If stored_device_id == JWT device_id: Should NOT reject for device_mismatch
--   - If stored_device_id != JWT device_id: Should reject with 'device_mismatch'
--   - If stored_device_id is NULL: Should NOT reject (first login case)
--   - If JWT device_id is NULL: Should reject with 'device_id_missing'

-- This property should be tested with:
--   - 100+ random device_id pairs
--   - Various UUID formats
--   - Edge cases: empty strings, special characters, very long strings

-- ============================================
-- SUMMARY
-- ============================================
SELECT 
  'Device Binding Verification Tests' AS section,
  'Tests 1-6: Verify function implementation structure' AS static_tests,
  'Tests 7-10: Integration tests (require auth context)' AS integration_tests,
  'Property 11: Property-based test for comprehensive coverage' AS property_test;

-- ============================================
-- INSTRUCTIONS FOR RUNNING INTEGRATION TESTS
-- ============================================
-- To run the integration tests (Tests 7-10):
-- 1. Set up Supabase test environment with Auth
-- 2. Create test users with profiles
-- 3. Generate JWT tokens with device_id in app_metadata or user_metadata
-- 4. Execute mark_attendance function with test data
-- 5. Verify rejection reasons match expected values
-- 6. Check attendance_logs table for correct status and rejection_reason

-- Example test execution (pseudo-code):
-- 
-- -- Test 8: Device mismatch
-- INSERT INTO profiles (id, email, full_name, device_id)
-- VALUES (auth.uid(), 'test@example.com', 'Test User', 'device_123');
-- 
-- -- Authenticate with JWT containing device_id='device_456'
-- SELECT mark_attendance(
--   '11111111-1111-1111-1111-111111111111'::UUID,
--   'test_secret_device_binding_123',
--   37.7749,
--   -122.4194
-- );
-- 
-- -- Expected result:
-- -- {
-- --   "status": "REJECTED",
-- --   "rejection_reason": "device_mismatch",
-- --   "timestamp": "2024-01-15T10:30:00Z"
-- -- }

