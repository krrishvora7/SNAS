-- Performance Testing Script
-- Task: 16.2 Optimize database queries and indexes
-- Tests that mark_attendance executes within 200ms

-- ============================================
-- SETUP TEST DATA
-- ============================================

-- Create test profile if not exists
DO $
BEGIN
  -- Insert test user profile
  INSERT INTO profiles (id, email, full_name, device_id)
  VALUES (
    '11111111-1111-1111-1111-111111111111'::UUID,
    'test.student@university.edu',
    'Test Student',
    'test-device-123'
  )
  ON CONFLICT (id) DO NOTHING;
  
  -- Insert test classroom
  INSERT INTO classrooms (id, name, building, location, nfc_secret)
  VALUES (
    '22222222-2222-2222-2222-222222222222'::UUID,
    'Test Room 101',
    'Test Building',
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    'test-secret-token-12345'
  )
  ON CONFLICT (id) DO NOTHING;
END $;

-- ============================================
-- PERFORMANCE TEST 1: Valid Attendance Marking
-- ============================================

-- Test execution time for valid attendance marking
-- Target: < 200ms

DO $
DECLARE
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
  v_execution_time_ms NUMERIC;
  v_result JSON;
  v_test_passed BOOLEAN := false;
BEGIN
  -- Clear previous test attempts (to avoid rate limiting)
  DELETE FROM attendance_logs 
  WHERE student_id = '11111111-1111-1111-1111-111111111111'::UUID;
  
  -- Record start time
  v_start_time := clock_timestamp();
  
  -- Execute mark_attendance function
  -- Note: This test assumes the user is authenticated with the test profile
  -- In a real test, you would need to set up proper authentication context
  SELECT mark_attendance(
    '22222222-2222-2222-2222-222222222222'::UUID,  -- classroom_id
    'test-secret-token-12345',                      -- secret_token
    37.7749,                                        -- latitude (within 50m)
    -122.4194                                       -- longitude
  ) INTO v_result;
  
  -- Record end time
  v_end_time := clock_timestamp();
  
  -- Calculate execution time in milliseconds
  v_execution_time_ms := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
  
  -- Check if execution time is within target
  v_test_passed := v_execution_time_ms < 200;
  
  -- Output results
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Performance Test 1: Valid Attendance Marking';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Execution Time: % ms', ROUND(v_execution_time_ms, 2);
  RAISE NOTICE 'Target: < 200 ms';
  RAISE NOTICE 'Status: %', CASE WHEN v_test_passed THEN 'PASSED ✓' ELSE 'FAILED ✗' END;
  RAISE NOTICE 'Result: %', v_result;
  RAISE NOTICE '';
  
  IF NOT v_test_passed THEN
    RAISE WARNING 'Performance test failed: Execution time (% ms) exceeds target (200 ms)', 
      ROUND(v_execution_time_ms, 2);
  END IF;
END $;

-- ============================================
-- PERFORMANCE TEST 2: Rate Limited Request
-- ============================================

DO $
DECLARE
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
  v_execution_time_ms NUMERIC;
  v_result JSON;
  v_test_passed BOOLEAN := false;
BEGIN
  -- First request (should succeed or be rejected for other reasons)
  PERFORM mark_attendance(
    '22222222-2222-2222-2222-222222222222'::UUID,
    'test-secret-token-12345',
    37.7749,
    -122.4194
  );
  
  -- Wait a moment
  PERFORM pg_sleep(0.1);
  
  -- Record start time
  v_start_time := clock_timestamp();
  
  -- Second request (should be rate limited)
  SELECT mark_attendance(
    '22222222-2222-2222-2222-222222222222'::UUID,
    'test-secret-token-12345',
    37.7749,
    -122.4194
  ) INTO v_result;
  
  -- Record end time
  v_end_time := clock_timestamp();
  
  -- Calculate execution time
  v_execution_time_ms := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
  
  -- Rate limited requests should also be fast
  v_test_passed := v_execution_time_ms < 200;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Performance Test 2: Rate Limited Request';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Execution Time: % ms', ROUND(v_execution_time_ms, 2);
  RAISE NOTICE 'Target: < 200 ms';
  RAISE NOTICE 'Status: %', CASE WHEN v_test_passed THEN 'PASSED ✓' ELSE 'FAILED ✗' END;
  RAISE NOTICE 'Result: %', v_result;
  RAISE NOTICE '';
  
  IF NOT v_test_passed THEN
    RAISE WARNING 'Performance test failed: Rate limited request took % ms', 
      ROUND(v_execution_time_ms, 2);
  END IF;
END $;

-- ============================================
-- PERFORMANCE TEST 3: Dashboard Query
-- ============================================

DO $
DECLARE
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
  v_execution_time_ms NUMERIC;
  v_record_count INTEGER;
  v_test_passed BOOLEAN := false;
BEGIN
  -- Record start time
  v_start_time := clock_timestamp();
  
  -- Execute dashboard query
  SELECT COUNT(*) INTO v_record_count
  FROM (
    SELECT 
      al.id,
      al.timestamp,
      al.status,
      al.rejection_reason,
      p.full_name as student_name,
      c.name as classroom_name,
      c.building
    FROM attendance_logs al
    JOIN profiles p ON al.student_id = p.id
    JOIN classrooms c ON al.classroom_id = c.id
    WHERE al.timestamp >= NOW() - INTERVAL '24 hours'
    ORDER BY al.timestamp DESC
    LIMIT 100
  ) subquery;
  
  -- Record end time
  v_end_time := clock_timestamp();
  
  -- Calculate execution time
  v_execution_time_ms := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
  
  -- Dashboard queries should complete within 2 seconds (2000ms)
  v_test_passed := v_execution_time_ms < 2000;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Performance Test 3: Dashboard Query';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Execution Time: % ms', ROUND(v_execution_time_ms, 2);
  RAISE NOTICE 'Target: < 2000 ms';
  RAISE NOTICE 'Records Retrieved: %', v_record_count;
  RAISE NOTICE 'Status: %', CASE WHEN v_test_passed THEN 'PASSED ✓' ELSE 'FAILED ✗' END;
  RAISE NOTICE '';
  
  IF NOT v_test_passed THEN
    RAISE WARNING 'Performance test failed: Dashboard query took % ms', 
      ROUND(v_execution_time_ms, 2);
  END IF;
END $;

-- ============================================
-- PERFORMANCE TEST 4: Index Usage Verification
-- ============================================

DO $
DECLARE
  v_index_count INTEGER;
  v_expected_indexes TEXT[] := ARRAY[
    'idx_attendance_student',
    'idx_attendance_classroom',
    'idx_attendance_timestamp',
    'idx_attendance_student_location',
    'idx_attendance_student_timestamp',
    'idx_attendance_status',
    'idx_attendance_classroom_status_timestamp',
    'idx_attendance_timestamp_status',
    'idx_classrooms_location',
    'idx_classrooms_nfc_secret',
    'idx_profiles_device_id'
  ];
  v_missing_indexes TEXT[];
BEGIN
  -- Check for missing indexes
  SELECT ARRAY_AGG(expected_idx)
  INTO v_missing_indexes
  FROM UNNEST(v_expected_indexes) AS expected_idx
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = expected_idx
  );
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Performance Test 4: Index Verification';
  RAISE NOTICE '========================================';
  
  IF v_missing_indexes IS NULL THEN
    RAISE NOTICE 'Status: PASSED ✓';
    RAISE NOTICE 'All expected indexes are present';
  ELSE
    RAISE WARNING 'Status: FAILED ✗';
    RAISE WARNING 'Missing indexes: %', array_to_string(v_missing_indexes, ', ');
  END IF;
  RAISE NOTICE '';
END $;

-- ============================================
-- PERFORMANCE TEST 5: Concurrent Request Simulation
-- ============================================

DO $
DECLARE
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
  v_execution_time_ms NUMERIC;
  v_test_passed BOOLEAN := false;
  i INTEGER;
BEGIN
  -- Clear previous attempts
  DELETE FROM attendance_logs 
  WHERE student_id = '11111111-1111-1111-1111-111111111111'::UUID;
  
  -- Wait to avoid rate limiting
  PERFORM pg_sleep(61);
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Performance Test 5: Sequential Requests';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Simulating 5 sequential requests...';
  
  -- Record start time
  v_start_time := clock_timestamp();
  
  -- Simulate multiple requests (sequential, not truly concurrent in this test)
  FOR i IN 1..5 LOOP
    -- Clear to avoid rate limiting
    DELETE FROM attendance_logs 
    WHERE student_id = '11111111-1111-1111-1111-111111111111'::UUID;
    
    PERFORM mark_attendance(
      '22222222-2222-2222-2222-222222222222'::UUID,
      'test-secret-token-12345',
      37.7749 + (i * 0.0001),  -- Slightly different locations
      -122.4194 + (i * 0.0001)
    );
  END LOOP;
  
  -- Record end time
  v_end_time := clock_timestamp();
  
  -- Calculate total execution time
  v_execution_time_ms := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
  
  -- Average should be under 200ms per request
  v_test_passed := (v_execution_time_ms / 5) < 200;
  
  RAISE NOTICE 'Total Time: % ms', ROUND(v_execution_time_ms, 2);
  RAISE NOTICE 'Average Time per Request: % ms', ROUND(v_execution_time_ms / 5, 2);
  RAISE NOTICE 'Target Average: < 200 ms';
  RAISE NOTICE 'Status: %', CASE WHEN v_test_passed THEN 'PASSED ✓' ELSE 'FAILED ✗' END;
  RAISE NOTICE '';
END $;

-- ============================================
-- SUMMARY
-- ============================================

RAISE NOTICE '========================================';
RAISE NOTICE 'Performance Testing Complete';
RAISE NOTICE '========================================';
RAISE NOTICE 'Review the results above to ensure:';
RAISE NOTICE '1. mark_attendance executes in < 200ms';
RAISE NOTICE '2. Rate limiting is fast';
RAISE NOTICE '3. Dashboard queries complete in < 2s';
RAISE NOTICE '4. All indexes are present';
RAISE NOTICE '5. Sequential requests maintain performance';
RAISE NOTICE '';

