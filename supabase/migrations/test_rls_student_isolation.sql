-- Property Test: Row Level Security for Students
-- Feature: smart-nfc-attendance-system, Property 22: Row Level Security for Students
-- Validates: Requirements 10.2, 10.3
-- 
-- Property: For any student user:
-- - Querying profiles should return only their own profile
-- - Querying attendance_logs should return only their own attendance records
-- - Attempting to access other students' data should return empty results

\echo '========================================='
\echo 'Property Test 22: Row Level Security for Students'
\echo '========================================='
\echo ''

-- Setup: Create test users and data
DO $$
DECLARE
  student1_id UUID;
  student2_id UUID;
  classroom1_id UUID;
  test_iteration INT;
  records_count INT;
BEGIN
  -- Clean up any existing test data
  DELETE FROM attendance_logs WHERE student_id IN (
    SELECT id FROM profiles WHERE email LIKE 'rls_test_student%@test.edu'
  );
  DELETE FROM profiles WHERE email LIKE 'rls_test_student%@test.edu';
  DELETE FROM classrooms WHERE name LIKE 'RLS Test Room%';

  RAISE NOTICE 'Setup: Creating test data for property-based testing...';
  
  -- Create test classroom
  INSERT INTO classrooms (id, name, building, location, nfc_secret)
  VALUES (
    gen_random_uuid(),
    'RLS Test Room 101',
    'Test Building',
    ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography,
    'rls_test_secret_' || gen_random_uuid()::text
  )
  RETURNING id INTO classroom1_id;

  RAISE NOTICE 'Created test classroom: %', classroom1_id;

  -- Property Test: Run 100 iterations with different student pairs
  FOR test_iteration IN 1..100 LOOP
    -- Create two test students for this iteration
    student1_id := gen_random_uuid();
    student2_id := gen_random_uuid();

    -- Insert student profiles (simulating auth.users entries)
    INSERT INTO profiles (id, email, full_name, device_id)
    VALUES 
      (student1_id, 'rls_test_student1_' || test_iteration || '@test.edu', 'RLS Test Student 1 Iter ' || test_iteration, 'device_' || student1_id::text),
      (student2_id, 'rls_test_student2_' || test_iteration || '@test.edu', 'RLS Test Student 2 Iter ' || test_iteration, 'device_' || student2_id::text);

    -- Create attendance logs for both students
    INSERT INTO attendance_logs (student_id, classroom_id, status, student_location)
    VALUES 
      (student1_id, classroom1_id, 'PRESENT', ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography),
      (student2_id, classroom1_id, 'PRESENT', ST_SetSRID(ST_MakePoint(-122.4195, 37.7750), 4326)::geography);

    -- Test 1: Verify student1 can only see their own profile
    -- Simulate student1's session
    PERFORM set_config('request.jwt.claims', json_build_object('sub', student1_id)::text, true);
    
    SELECT COUNT(*) INTO records_count
    FROM profiles
    WHERE id = student1_id;
    
    IF records_count != 1 THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: Student1 should see their own profile (expected 1, got %)', test_iteration, records_count;
    END IF;

    -- Test 2: Verify student1 cannot see student2's profile
    SELECT COUNT(*) INTO records_count
    FROM profiles
    WHERE id = student2_id;
    
    IF records_count != 0 THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: Student1 should NOT see student2 profile (expected 0, got %)', test_iteration, records_count;
    END IF;

    -- Test 3: Verify student1 can only see their own attendance logs
    SELECT COUNT(*) INTO records_count
    FROM attendance_logs
    WHERE student_id = student1_id;
    
    IF records_count < 1 THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: Student1 should see their own attendance logs (expected >= 1, got %)', test_iteration, records_count;
    END IF;

    -- Test 4: Verify student1 cannot see student2's attendance logs
    SELECT COUNT(*) INTO records_count
    FROM attendance_logs
    WHERE student_id = student2_id;
    
    IF records_count != 0 THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: Student1 should NOT see student2 attendance logs (expected 0, got %)', test_iteration, records_count;
    END IF;

    -- Test 5: Now switch to student2's session and verify isolation
    PERFORM set_config('request.jwt.claims', json_build_object('sub', student2_id)::text, true);
    
    SELECT COUNT(*) INTO records_count
    FROM profiles
    WHERE id = student2_id;
    
    IF records_count != 1 THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: Student2 should see their own profile (expected 1, got %)', test_iteration, records_count;
    END IF;

    -- Test 6: Verify student2 cannot see student1's profile
    SELECT COUNT(*) INTO records_count
    FROM profiles
    WHERE id = student1_id;
    
    IF records_count != 0 THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: Student2 should NOT see student1 profile (expected 0, got %)', test_iteration, records_count;
    END IF;

    -- Test 7: Verify student2 can only see their own attendance logs
    SELECT COUNT(*) INTO records_count
    FROM attendance_logs
    WHERE student_id = student2_id;
    
    IF records_count < 1 THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: Student2 should see their own attendance logs (expected >= 1, got %)', test_iteration, records_count;
    END IF;

    -- Test 8: Verify student2 cannot see student1's attendance logs
    SELECT COUNT(*) INTO records_count
    FROM attendance_logs
    WHERE student_id = student1_id;
    
    IF records_count != 0 THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: Student2 should NOT see student1 attendance logs (expected 0, got %)', test_iteration, records_count;
    END IF;

    -- Progress indicator every 10 iterations
    IF test_iteration % 10 = 0 THEN
      RAISE NOTICE 'Progress: Completed % iterations...', test_iteration;
    END IF;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ PASS: Property 22 verified across 100 iterations';
  RAISE NOTICE 'All students can only access their own profiles and attendance logs';
  RAISE NOTICE '';

  -- Cleanup
  DELETE FROM attendance_logs WHERE student_id IN (
    SELECT id FROM profiles WHERE email LIKE 'rls_test_student%@test.edu'
  );
  DELETE FROM profiles WHERE email LIKE 'rls_test_student%@test.edu';
  DELETE FROM classrooms WHERE id = classroom1_id;

  RAISE NOTICE 'Cleanup: Test data removed';

EXCEPTION
  WHEN OTHERS THEN
    -- Cleanup on failure
    DELETE FROM attendance_logs WHERE student_id IN (
      SELECT id FROM profiles WHERE email LIKE 'rls_test_student%@test.edu'
    );
    DELETE FROM profiles WHERE email LIKE 'rls_test_student%@test.edu';
    DELETE FROM classrooms WHERE name LIKE 'RLS Test Room%';
    
    RAISE;
END $$;

\echo ''
\echo '========================================='
\echo 'Property Test 22: Complete'
\echo '========================================='
