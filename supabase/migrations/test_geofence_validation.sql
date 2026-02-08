-- Test script for Task 3.4: Geofence Validation with PostGIS
-- This script tests the geofence validation logic in mark_attendance function
-- Validates Requirements: 5.4, 6.2, 6.3

-- ============================================
-- SETUP: Create test data
-- ============================================

-- Clean up any existing test data
DO $$
BEGIN
  -- Delete test attendance logs
  DELETE FROM attendance_logs WHERE student_id IN (
    SELECT id FROM profiles WHERE email LIKE 'test_geofence_%@test.com'
  );
  
  -- Delete test profiles
  DELETE FROM profiles WHERE email LIKE 'test_geofence_%@test.com';
  
  -- Delete test classrooms
  DELETE FROM classrooms WHERE name LIKE 'Test Classroom Geofence%';
END $$;

-- Create test classroom at a known location
-- Using San Francisco coordinates: 37.7749° N, 122.4194° W
INSERT INTO classrooms (id, name, building, location, nfc_secret)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
  'Test Classroom Geofence 1',
  'Test Building',
  ST_GeogFromText('POINT(-122.4194 37.7749)'),  -- San Francisco
  'geofence_test_token_123'
);

-- Create test user profile
INSERT INTO profiles (id, email, full_name, device_id)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::UUID,
  'test_geofence_user@test.com',
  'Test Geofence User',
  'test_device_geofence_001'
);

-- ============================================
-- Test 1: Student at exact classroom location (0 meters)
-- ============================================
-- This test verifies that a student at the exact classroom location
-- is within the geofence and attendance is marked as PRESENT

SELECT 'Test 1: Exact location (0 meters)' AS test_name;

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
--   - secret_token: 'geofence_test_token_123'
--   - latitude: 37.7749, longitude: -122.4194 (exact classroom location)
-- Then:
--   - Distance should be 0 meters
--   - Status should be 'PRESENT'
--   - rejection_reason should be NULL

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
--   'geofence_test_token_123',
--   37.7749,
--   -122.4194
-- );
-- Expected result: {"status": "PRESENT", "rejection_reason": null, "timestamp": "..."}

-- ============================================
-- Test 2: Student within geofence (25 meters)
-- ============================================
-- This test verifies that a student within 50 meters is accepted

SELECT 'Test 2: Within geofence (25 meters)' AS test_name;

-- Calculate a point approximately 25 meters north of the classroom
-- At this latitude, 1 degree ≈ 111,000 meters
-- So 25 meters ≈ 0.000225 degrees
-- New latitude: 37.7749 + 0.000225 = 37.775125

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
--   - secret_token: 'geofence_test_token_123'
--   - latitude: 37.775125, longitude: -122.4194 (≈25m north)
-- Then:
--   - Distance should be approximately 25 meters
--   - Status should be 'PRESENT'
--   - rejection_reason should be NULL

-- Verify the distance calculation
SELECT 
  'Distance verification' AS check_name,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    ST_GeogFromText('POINT(-122.4194 37.775125)')
  ) AS distance_meters;
-- Expected: approximately 25 meters

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
--   'geofence_test_token_123',
--   37.775125,
--   -122.4194
-- );
-- Expected result: {"status": "PRESENT", "rejection_reason": null, "timestamp": "..."}

-- ============================================
-- Test 3: Student at geofence boundary (exactly 50 meters)
-- ============================================
-- This test verifies behavior at the exact boundary

SELECT 'Test 3: At geofence boundary (50 meters)' AS test_name;

-- Calculate a point approximately 50 meters north
-- 50 meters ≈ 0.00045 degrees
-- New latitude: 37.7749 + 0.00045 = 37.77535

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
--   - secret_token: 'geofence_test_token_123'
--   - latitude: 37.77535, longitude: -122.4194 (≈50m north)
-- Then:
--   - Distance should be approximately 50 meters
--   - Status should be 'PRESENT' (within or equal to 50m)
--   - rejection_reason should be NULL

-- Verify the distance calculation
SELECT 
  'Distance verification' AS check_name,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    ST_GeogFromText('POINT(-122.4194 37.77535)')
  ) AS distance_meters;
-- Expected: approximately 50 meters

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
--   'geofence_test_token_123',
--   37.77535,
--   -122.4194
-- );
-- Expected result: {"status": "PRESENT", "rejection_reason": null, "timestamp": "..."}

-- ============================================
-- Test 4: Student just outside geofence (51 meters)
-- ============================================
-- This test verifies that a student just outside 50 meters is rejected

SELECT 'Test 4: Just outside geofence (51 meters)' AS test_name;

-- Calculate a point approximately 51 meters north
-- 51 meters ≈ 0.000459 degrees
-- New latitude: 37.7749 + 0.000459 = 37.775359

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
--   - secret_token: 'geofence_test_token_123'
--   - latitude: 37.775359, longitude: -122.4194 (≈51m north)
-- Then:
--   - Distance should be approximately 51 meters
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'outside_geofence'

-- Verify the distance calculation
SELECT 
  'Distance verification' AS check_name,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    ST_GeogFromText('POINT(-122.4194 37.775359)')
  ) AS distance_meters;
-- Expected: approximately 51 meters

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
--   'geofence_test_token_123',
--   37.775359,
--   -122.4194
-- );
-- Expected result: {"status": "REJECTED", "rejection_reason": "outside_geofence", "timestamp": "..."}

-- ============================================
-- Test 5: Student far outside geofence (100 meters)
-- ============================================
-- This test verifies that a student far outside the geofence is rejected

SELECT 'Test 5: Far outside geofence (100 meters)' AS test_name;

-- Calculate a point approximately 100 meters north
-- 100 meters ≈ 0.0009 degrees
-- New latitude: 37.7749 + 0.0009 = 37.7758

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
--   - secret_token: 'geofence_test_token_123'
--   - latitude: 37.7758, longitude: -122.4194 (≈100m north)
-- Then:
--   - Distance should be approximately 100 meters
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'outside_geofence'

-- Verify the distance calculation
SELECT 
  'Distance verification' AS check_name,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    ST_GeogFromText('POINT(-122.4194 37.7758)')
  ) AS distance_meters;
-- Expected: approximately 100 meters

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
--   'geofence_test_token_123',
--   37.7758,
--   -122.4194
-- );
-- Expected result: {"status": "REJECTED", "rejection_reason": "outside_geofence", "timestamp": "..."}

-- ============================================
-- Test 6: Student very far away (1 kilometer)
-- ============================================
-- This test verifies rejection for very distant locations

SELECT 'Test 6: Very far away (1 kilometer)' AS test_name;

-- Calculate a point approximately 1000 meters (1 km) north
-- 1000 meters ≈ 0.009 degrees
-- New latitude: 37.7749 + 0.009 = 37.7839

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
--   - secret_token: 'geofence_test_token_123'
--   - latitude: 37.7839, longitude: -122.4194 (≈1km north)
-- Then:
--   - Distance should be approximately 1000 meters
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'outside_geofence'

-- Verify the distance calculation
SELECT 
  'Distance verification' AS check_name,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    ST_GeogFromText('POINT(-122.4194 37.7839)')
  ) AS distance_meters;
-- Expected: approximately 1000 meters

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
--   'geofence_test_token_123',
--   37.7839,
--   -122.4194
-- );
-- Expected result: {"status": "REJECTED", "rejection_reason": "outside_geofence", "timestamp": "..."}

-- ============================================
-- Test 7: Student in different direction (east, 30 meters)
-- ============================================
-- This test verifies geofence works in all directions

SELECT 'Test 7: Different direction (30 meters east)' AS test_name;

-- Calculate a point approximately 30 meters east
-- At this latitude, 1 degree longitude ≈ 111,000 * cos(37.7749°) ≈ 87,800 meters
-- So 30 meters ≈ 0.000342 degrees
-- New longitude: -122.4194 + 0.000342 = -122.419058

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
--   - secret_token: 'geofence_test_token_123'
--   - latitude: 37.7749, longitude: -122.419058 (≈30m east)
-- Then:
--   - Distance should be approximately 30 meters
--   - Status should be 'PRESENT'
--   - rejection_reason should be NULL

-- Verify the distance calculation
SELECT 
  'Distance verification' AS check_name,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    ST_GeogFromText('POINT(-122.419058 37.7749)')
  ) AS distance_meters;
-- Expected: approximately 30 meters

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
--   'geofence_test_token_123',
--   37.7749,
--   -122.419058
-- );
-- Expected result: {"status": "PRESENT", "rejection_reason": null, "timestamp": "..."}

-- ============================================
-- Test 8: Student in diagonal direction (35 meters northeast)
-- ============================================
-- This test verifies geofence calculation for diagonal movement

SELECT 'Test 8: Diagonal direction (35 meters northeast)' AS test_name;

-- Calculate a point approximately 35 meters northeast
-- Using Pythagorean theorem: 35m = sqrt(x^2 + y^2)
-- For simplicity, use 25m north and 25m east: sqrt(625+625) ≈ 35.4m
-- North: 25m ≈ 0.000225 degrees latitude
-- East: 25m ≈ 0.000285 degrees longitude
-- New coordinates: (37.775125, -122.419115)

-- Expected behavior:
-- When mark_attendance is called with:
--   - classroom_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
--   - secret_token: 'geofence_test_token_123'
--   - latitude: 37.775125, longitude: -122.419115 (≈35m northeast)
-- Then:
--   - Distance should be approximately 35 meters
--   - Status should be 'PRESENT'
--   - rejection_reason should be NULL

-- Verify the distance calculation
SELECT 
  'Distance verification' AS check_name,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    ST_GeogFromText('POINT(-122.419115 37.775125)')
  ) AS distance_meters;
-- Expected: approximately 35 meters

-- Test query (requires auth context):
-- SELECT mark_attendance(
--   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
--   'geofence_test_token_123',
--   37.775125,
--   -122.419115
-- );
-- Expected result: {"status": "PRESENT", "rejection_reason": null, "timestamp": "..."}

-- ============================================
-- Test 9: Verify ST_Distance accuracy
-- ============================================
-- This test verifies that PostGIS ST_Distance returns accurate results

SELECT 'Test 9: ST_Distance accuracy verification' AS test_name;

-- Test known distances
SELECT 
  'Known distance test' AS test_type,
  ST_Distance(
    ST_GeogFromText('POINT(0 0)'),
    ST_GeogFromText('POINT(0 0)')
  ) AS distance_0m,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    ST_GeogFromText('POINT(-122.4194 37.7749)')
  ) AS distance_same_point;
-- Expected: Both should be 0 meters

-- Test that ST_Distance returns meters for geography type
SELECT 
  'Distance unit test' AS test_type,
  ST_Distance(
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    ST_GeogFromText('POINT(-122.4194 37.7758)')
  ) AS distance_meters,
  'Should be approximately 100 meters' AS expected;

-- ============================================
-- Test 10: Geofence validation happens after other validations
-- ============================================
-- This test verifies the validation order

SELECT 'Test 10: Validation order' AS test_name;

-- Expected behavior:
-- When mark_attendance is called with:
--   - Wrong device_id (device_mismatch)
--   - Valid secret_token
--   - Location outside geofence
-- Then:
--   - Device binding should fail first
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'device_mismatch' (not 'outside_geofence')
--   - Geofence validation should not be reached

-- When mark_attendance is called with:
--   - Valid device_id
--   - Wrong secret_token (invalid_token)
--   - Location outside geofence
-- Then:
--   - Secret token validation should fail
--   - Status should be 'REJECTED'
--   - rejection_reason should be 'invalid_token' (not 'outside_geofence')
--   - Geofence validation should not be reached

-- This confirms that geofence validation only runs if previous validations pass

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Verify test classroom was created
SELECT 
  'Verification: Test classroom' AS check_name,
  COUNT(*) AS classroom_count,
  CASE 
    WHEN COUNT(*) = 1 THEN 'PASS: Test classroom created'
    ELSE 'FAIL: Expected 1 test classroom'
  END AS result
FROM classrooms 
WHERE name LIKE 'Test Classroom Geofence%';

-- Verify test profile was created
SELECT 
  'Verification: Test profile' AS check_name,
  COUNT(*) AS profile_count,
  CASE 
    WHEN COUNT(*) = 1 THEN 'PASS: Test profile created'
    ELSE 'FAIL: Expected 1 test profile'
  END AS result
FROM profiles 
WHERE email = 'test_geofence_user@test.com';

-- Verify classroom location is stored correctly
SELECT 
  'Verification: Classroom location' AS check_name,
  id,
  name,
  ST_Y(location::geometry) AS latitude,
  ST_X(location::geometry) AS longitude
FROM classrooms 
WHERE name LIKE 'Test Classroom Geofence%';
-- Expected: latitude ≈ 37.7749, longitude ≈ -122.4194

-- ============================================
-- DISTANCE CALCULATION REFERENCE
-- ============================================

-- Reference table for distance calculations at San Francisco latitude (37.7749°)
SELECT 
  'Distance Reference' AS info,
  '1 degree latitude ≈ 111,000 meters' AS lat_conversion,
  '1 degree longitude ≈ 87,800 meters (at this latitude)' AS lng_conversion,
  '0.00045 degrees latitude ≈ 50 meters' AS fifty_meters_lat,
  '0.000569 degrees longitude ≈ 50 meters' AS fifty_meters_lng;

-- ============================================
-- CLEANUP (Optional - uncomment to clean up test data)
-- ============================================

-- DO $$
-- BEGIN
--   -- Delete test attendance logs
--   DELETE FROM attendance_logs WHERE student_id IN (
--     SELECT id FROM profiles WHERE email LIKE 'test_geofence_%@test.com'
--   );
--   
--   -- Delete test profiles
--   DELETE FROM profiles WHERE email LIKE 'test_geofence_%@test.com';
--   
--   -- Delete test classrooms
--   DELETE FROM classrooms WHERE name LIKE 'Test Classroom Geofence%';
-- END $$;

-- ============================================
-- SUMMARY
-- ============================================

SELECT 
  'Summary' AS section,
  'Task 3.4: Geofence Validation with PostGIS Tests' AS task,
  'Requirements: 5.4, 6.2, 6.3' AS validates;

SELECT 
  'Test Coverage' AS section,
  'Test 1: Exact location (0m) - PRESENT' AS test_1,
  'Test 2: Within geofence (25m) - PRESENT' AS test_2,
  'Test 3: At boundary (50m) - PRESENT' AS test_3,
  'Test 4: Just outside (51m) - REJECTED' AS test_4,
  'Test 5: Far outside (100m) - REJECTED' AS test_5,
  'Test 6: Very far (1km) - REJECTED' AS test_6,
  'Test 7: Different direction (30m east) - PRESENT' AS test_7,
  'Test 8: Diagonal (35m northeast) - PRESENT' AS test_8,
  'Test 9: ST_Distance accuracy verification' AS test_9,
  'Test 10: Validation order' AS test_10;

-- ============================================
-- INSTRUCTIONS FOR RUNNING TESTS
-- ============================================
-- To run these tests in a real environment:
-- 
-- 1. Apply the migration that creates the mark_attendance function with geofence validation
-- 2. Run this test script to create test data
-- 3. Set up Supabase Auth test user with the test profile ID
-- 4. Authenticate as the test user with correct device_id in JWT
-- 5. Uncomment and run each test query individually
-- 6. Verify the JSON responses match expected results
-- 7. Check attendance_logs table to verify records were created with correct status
-- 8. Run cleanup script to remove test data
--
-- Expected Results:
-- - Tests 1, 2, 3, 7, 8: Status PRESENT (within 50m)
-- - Tests 4, 5, 6: Status REJECTED, reason 'outside_geofence' (beyond 50m)
-- - Test 9: Distance calculations should be accurate
-- - Test 10: Earlier validation failures should prevent geofence check
--
-- Key Properties Validated:
-- - Property 12: Distance calculation accuracy (within 1 meter)
-- - Property 15: Geofence boundary enforcement (50 meter threshold)
-- - Requirement 5.4: PostGIS ST_Distance for accurate calculation
-- - Requirement 6.2: Rejection when distance > 50 meters
-- - Requirement 6.3: Acceptance when distance ≤ 50 meters
