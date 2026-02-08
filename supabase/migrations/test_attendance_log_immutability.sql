-- Property Test: Attendance Log Immutability
-- Feature: smart-nfc-attendance-system, Property 18: Attendance Log Immutability
-- Validates: Requirements 7.4
-- 
-- Property: For any attendance log record after creation, 
-- attempts to update any field should fail (logs are append-only)

\echo '========================================='
\echo 'Property Test 18: Attendance Log Immutability'
\echo '========================================='
\echo ''

-- Setup: Create test data
DO $$
DECLARE
  test_student_id UUID;
  test_classroom_id UUID;
  test_log_id UUID;
  test_iteration INT;
  update_succeeded BOOLEAN;
  delete_succeeded BOOLEAN;
BEGIN
  -- Clean up any existing test data
  DELETE FROM attendance_logs WHERE student_id IN (
    SELECT id FROM profiles WHERE email LIKE 'immutable_test_%@test.edu'
  );
  DELETE FROM profiles WHERE email LIKE 'immutable_test_%@test.edu';
  DELETE FROM classrooms WHERE name LIKE 'Immutable Test Room%';

  RAISE NOTICE 'Setup: Creating test data for property-based testing...';
  
  -- Create test classroom
  INSERT INTO classrooms (id, name, building, location, nfc_secret)
  VALUES (
    gen_random_uuid(),
    'Immutable Test Room',
    'Test Building',
    ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography,
    'immutable_test_secret_' || gen_random_uuid()::text
  )
  RETURNING id INTO test_classroom_id;

  RAISE NOTICE 'Created test classroom: %', test_classroom_id;
  RAISE NOTICE '';

  -- Property Test: Run 100 iterations with different update attempts
  FOR test_iteration IN 1..100 LOOP
    -- Create a test student for this iteration
    test_student_id := gen_random_uuid();

    -- Insert student profile
    INSERT INTO profiles (id, email, full_name, device_id)
    VALUES (
      test_student_id,
      'immutable_test_student_' || test_iteration || '@test.edu',
      'Immutable Test Student ' || test_iteration,
      'device_' || test_student_id::text
    );

    -- Create an attendance log
    INSERT INTO attendance_logs (id, student_id, classroom_id, status, student_location)
    VALUES (
      gen_random_uuid(),
      test_student_id,
      test_classroom_id,
      'PRESENT',
      ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography
    )
    RETURNING id INTO test_log_id;

    -- Test 1: Try to update status field
    update_succeeded := false;
    BEGIN
      UPDATE attendance_logs
      SET status = 'REJECTED'
      WHERE id = test_log_id;
      
      -- If we get here, the update succeeded (which is bad)
      IF FOUND THEN
        update_succeeded := true;
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        -- Expected: RLS should block this
        update_succeeded := false;
      WHEN OTHERS THEN
        -- Any other error also means update failed
        update_succeeded := false;
    END;

    IF update_succeeded THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: UPDATE on status field should be blocked', test_iteration;
    END IF;

    -- Test 2: Try to update rejection_reason field
    update_succeeded := false;
    BEGIN
      UPDATE attendance_logs
      SET rejection_reason = 'test_reason'
      WHERE id = test_log_id;
      
      IF FOUND THEN
        update_succeeded := true;
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        update_succeeded := false;
      WHEN OTHERS THEN
        update_succeeded := false;
    END;

    IF update_succeeded THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: UPDATE on rejection_reason field should be blocked', test_iteration;
    END IF;

    -- Test 3: Try to update student_location field
    update_succeeded := false;
    BEGIN
      UPDATE attendance_logs
      SET student_location = ST_SetSRID(ST_MakePoint(-122.5000, 37.8000), 4326)::geography
      WHERE id = test_log_id;
      
      IF FOUND THEN
        update_succeeded := true;
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        update_succeeded := false;
      WHEN OTHERS THEN
        update_succeeded := false;
    END;

    IF update_succeeded THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: UPDATE on student_location field should be blocked', test_iteration;
    END IF;

    -- Test 4: Try to update timestamp field
    update_succeeded := false;
    BEGIN
      UPDATE attendance_logs
      SET timestamp = NOW() - INTERVAL '1 hour'
      WHERE id = test_log_id;
      
      IF FOUND THEN
        update_succeeded := true;
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        update_succeeded := false;
      WHEN OTHERS THEN
        update_succeeded := false;
    END;

    IF update_succeeded THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: UPDATE on timestamp field should be blocked', test_iteration;
    END IF;

    -- Test 5: Try to update multiple fields at once
    update_succeeded := false;
    BEGIN
      UPDATE attendance_logs
      SET 
        status = 'REJECTED',
        rejection_reason = 'test_reason',
        timestamp = NOW()
      WHERE id = test_log_id;
      
      IF FOUND THEN
        update_succeeded := true;
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        update_succeeded := false;
      WHEN OTHERS THEN
        update_succeeded := false;
    END;

    IF update_succeeded THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: UPDATE on multiple fields should be blocked', test_iteration;
    END IF;

    -- Test 6: Try to delete the attendance log
    delete_succeeded := false;
    BEGIN
      DELETE FROM attendance_logs
      WHERE id = test_log_id;
      
      IF FOUND THEN
        delete_succeeded := true;
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        delete_succeeded := false;
      WHEN OTHERS THEN
        delete_succeeded := false;
    END;

    IF delete_succeeded THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: DELETE should be blocked', test_iteration;
    END IF;

    -- Test 7: Verify the log still exists with original values
    IF NOT EXISTS (
      SELECT 1 FROM attendance_logs
      WHERE id = test_log_id
      AND status = 'PRESENT'
      AND rejection_reason IS NULL
    ) THEN
      RAISE EXCEPTION '❌ FAIL [Iteration %]: Attendance log was modified or deleted', test_iteration;
    END IF;

    -- Progress indicator every 10 iterations
    IF test_iteration % 10 = 0 THEN
      RAISE NOTICE 'Progress: Completed % iterations...', test_iteration;
    END IF;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ PASS: Property 18 verified across 100 iterations';
  RAISE NOTICE 'All UPDATE and DELETE attempts on attendance_logs were blocked';
  RAISE NOTICE 'Attendance logs are immutable after creation';
  RAISE NOTICE '';

  -- Additional Test: Verify no UPDATE or DELETE policies exist
  RAISE NOTICE 'Verifying RLS policy configuration...';
  
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'attendance_logs'
    AND cmd IN ('UPDATE', 'DELETE')
  ) THEN
    RAISE WARNING '⚠️  WARNING: UPDATE or DELETE policies exist on attendance_logs';
    RAISE WARNING '   This may allow modifications to logs';
    
    -- List the policies
    FOR test_iteration IN (
      SELECT policyname, cmd
      FROM pg_policies
      WHERE tablename = 'attendance_logs'
      AND cmd IN ('UPDATE', 'DELETE')
    ) LOOP
      RAISE WARNING '   Found policy: % (%)', test_iteration.policyname, test_iteration.cmd;
    END LOOP;
  ELSE
    RAISE NOTICE '✅ No UPDATE or DELETE policies found (as expected)';
  END IF;
  
  RAISE NOTICE '';

  -- Cleanup
  DELETE FROM attendance_logs WHERE student_id IN (
    SELECT id FROM profiles WHERE email LIKE 'immutable_test_%@test.edu'
  );
  DELETE FROM profiles WHERE email LIKE 'immutable_test_%@test.edu';
  DELETE FROM classrooms WHERE id = test_classroom_id;

  RAISE NOTICE 'Cleanup: Test data removed';

EXCEPTION
  WHEN OTHERS THEN
    -- Cleanup on failure
    DELETE FROM attendance_logs WHERE student_id IN (
      SELECT id FROM profiles WHERE email LIKE 'immutable_test_%@test.edu'
    );
    DELETE FROM profiles WHERE email LIKE 'immutable_test_%@test.edu';
    DELETE FROM classrooms WHERE name LIKE 'Immutable Test Room%';
    
    RAISE;
END $$;

\echo ''
\echo '========================================='
\echo 'Property Test 18: Complete'
\echo '========================================='
\echo ''
\echo 'Note: This test verifies that RLS policies prevent'
\echo 'modifications to attendance_logs. In production,'
\echo 'ensure no UPDATE or DELETE policies are added to'
\echo 'maintain immutability guarantee.'
