-- Test script for mark_attendance function
-- This script verifies the function was created correctly and validates input validation logic

-- ============================================
-- Test 1: Verify function exists
-- ============================================
SELECT 
  'Test 1: Function exists' AS test_name,
  EXISTS (
    SELECT 1 
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' 
    AND p.proname = 'mark_attendance'
  ) AS result;

-- ============================================
-- Test 2: Verify function signature
-- ============================================
SELECT 
  'Test 2: Function signature' AS test_name,
  p.proname AS function_name,
  pg_get_function_arguments(p.oid) AS arguments,
  pg_get_function_result(p.oid) AS return_type,
  p.prosecdef AS is_security_definer
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'mark_attendance';

-- ============================================
-- Test 3: Verify function permissions
-- ============================================
SELECT 
  'Test 3: Function permissions' AS test_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'mark_attendance'
AND routine_schema = 'public'
ORDER BY grantee, privilege_type;

-- ============================================
-- Test 4: Verify function is SECURITY DEFINER
-- ============================================
SELECT 
  'Test 4: SECURITY DEFINER check' AS test_name,
  prosecdef AS is_security_definer,
  CASE 
    WHEN prosecdef THEN 'PASS: Function uses SECURITY DEFINER'
    ELSE 'FAIL: Function should use SECURITY DEFINER'
  END AS result
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'mark_attendance';

-- ============================================
-- Test 5: Verify function language
-- ============================================
SELECT 
  'Test 5: Function language' AS test_name,
  l.lanname AS language,
  CASE 
    WHEN l.lanname = 'plpgsql' THEN 'PASS: Function uses plpgsql'
    ELSE 'FAIL: Function should use plpgsql'
  END AS result
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
JOIN pg_language l ON p.prolang = l.oid
WHERE n.nspname = 'public' 
AND p.proname = 'mark_attendance';

-- ============================================
-- INPUT VALIDATION TESTS
-- Note: These tests require authentication context
-- They should be run in a test environment with proper auth setup
-- ============================================

-- Test 6: Test null classroom_id validation
-- Expected: Should raise exception
-- SELECT 'Test 6: Null classroom_id' AS test_name;
-- SELECT mark_attendance(NULL, 'test_token', 37.7749, -122.4194);
-- Expected error: "Parameter p_classroom_id cannot be null"

-- Test 7: Test null secret_token validation
-- Expected: Should raise exception
-- SELECT 'Test 7: Null secret_token' AS test_name;
-- SELECT mark_attendance('550e8400-e29b-41d4-a716-446655440000'::UUID, NULL, 37.7749, -122.4194);
-- Expected error: "Parameter p_secret_token cannot be null"

-- Test 8: Test null latitude validation
-- Expected: Should raise exception
-- SELECT 'Test 8: Null latitude' AS test_name;
-- SELECT mark_attendance('550e8400-e29b-41d4-a716-446655440000'::UUID, 'test_token', NULL, -122.4194);
-- Expected error: "Parameter p_latitude cannot be null"

-- Test 9: Test null longitude validation
-- Expected: Should raise exception
-- SELECT 'Test 9: Null longitude' AS test_name;
-- SELECT mark_attendance('550e8400-e29b-41d4-a716-446655440000'::UUID, 'test_token', 37.7749, NULL);
-- Expected error: "Parameter p_longitude cannot be null"

-- Test 10: Test invalid latitude (too low)
-- Expected: Should raise exception
-- SELECT 'Test 10: Invalid latitude (< -90)' AS test_name;
-- SELECT mark_attendance('550e8400-e29b-41d4-a716-446655440000'::UUID, 'test_token', -91.0, -122.4194);
-- Expected error: "Invalid latitude: -91. Must be between -90 and 90"

-- Test 11: Test invalid latitude (too high)
-- Expected: Should raise exception
-- SELECT 'Test 11: Invalid latitude (> 90)' AS test_name;
-- SELECT mark_attendance('550e8400-e29b-41d4-a716-446655440000'::UUID, 'test_token', 91.0, -122.4194);
-- Expected error: "Invalid latitude: 91. Must be between -90 and 90"

-- Test 12: Test invalid longitude (too low)
-- Expected: Should raise exception
-- SELECT 'Test 12: Invalid longitude (< -180)' AS test_name;
-- SELECT mark_attendance('550e8400-e29b-41d4-a716-446655440000'::UUID, 'test_token', 37.7749, -181.0);
-- Expected error: "Invalid longitude: -181. Must be between -180 and 180"

-- Test 13: Test invalid longitude (too high)
-- Expected: Should raise exception
-- SELECT 'Test 13: Invalid longitude (> 180)' AS test_name;
-- SELECT mark_attendance('550e8400-e29b-41d4-a716-446655440000'::UUID, 'test_token', 37.7749, 181.0);
-- Expected error: "Invalid longitude: 181. Must be between -180 and 180"

-- Test 14: Test empty secret token
-- Expected: Should raise exception
-- SELECT 'Test 14: Empty secret token' AS test_name;
-- SELECT mark_attendance('550e8400-e29b-41d4-a716-446655440000'::UUID, '   ', 37.7749, -122.4194);
-- Expected error: "Secret token cannot be empty"

-- Test 15: Test valid parameters (boundary values)
-- Expected: Should succeed
-- SELECT 'Test 15: Valid parameters (boundary latitude)' AS test_name;
-- SELECT mark_attendance('550e8400-e29b-41d4-a716-446655440000'::UUID, 'test_token', 90.0, 180.0);
-- Expected: JSON response with status

-- Test 16: Test valid parameters (boundary values negative)
-- Expected: Should succeed
-- SELECT 'Test 16: Valid parameters (boundary latitude negative)' AS test_name;
-- SELECT mark_attendance('550e8400-e29b-41d4-a716-446655440000'::UUID, 'test_token', -90.0, -180.0);
-- Expected: JSON response with status

-- ============================================
-- SUMMARY
-- ============================================
SELECT 
  'Summary' AS section,
  'Tests 1-5 verify function structure and configuration' AS description,
  'Tests 6-16 verify input validation (require auth context)' AS note;

-- ============================================
-- INSTRUCTIONS FOR RUNNING VALIDATION TESTS
-- ============================================
-- To run the input validation tests (Tests 6-16):
-- 1. Set up test data (profiles, classrooms)
-- 2. Authenticate as a test user
-- 3. Uncomment and run each test individually
-- 4. Verify that exceptions are raised with correct messages
-- 5. For valid parameter tests, verify JSON response structure
