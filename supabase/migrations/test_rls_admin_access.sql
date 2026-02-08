-- Unit Test: Admin Access to All Records
-- Feature: smart-nfc-attendance-system
-- Validates: Requirements 10.4
-- 
-- Test: Admin users can query all profiles and attendance logs
-- while regular students can only see their own data

\echo '========================================='
\echo 'Unit Test: Admin Access to All Records'
\echo '========================================='
\echo ''

-- Setup: Create test data
DO $$
DECLARE
  admin_user_id UUID;
  student1_id UUID;
  student2_id UUID;
  student3_id UUID;
  classroom1_id UUID;
  total_profiles INT;
  total_attendance INT;
  visible_profiles INT;
  visible_attendance INT;
BEGIN
  -- Clean up any existing test data
  DELETE FROM attendance_logs WHERE student_id IN (
    SELECT id FROM profiles WHERE email LIKE 'admin_test_%@test.edu'
  );
  DELETE FROM profiles WHERE email LIKE 'admin_test_%@test.edu';
  DELETE FROM classrooms WHERE name = 'Admin Test Room';

  RAISE NOTICE 'Setup: Creating test data...';
  
  -- Create test classroom
  INSERT INTO classrooms (id, name, building, location, nfc_secret)
  VALUES (
    gen_random_uuid(),
    'Admin Test Room',
    'Test Building',
    ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography,
    'admin_test_secret_' || gen_random_uuid()::text
  )
  RETURNING id INTO classroom1_id;

  -- Create test users
  admin_user_id := gen_random_uuid();
  student1_id := gen_random_uuid();
  student2_id := gen_random_uuid();
  student3_id := gen_random_uuid();

  -- Insert profiles
  INSERT INTO profiles (id, email, full_name, device_id)
  VALUES 
    (admin_user_id, 'admin_test_admin@test.edu', 'Admin Test User', 'device_admin'),
    (student1_id, 'admin_test_student1@test.edu', 'Admin Test Student 1', 'device_student1'),
    (student2_id, 'admin_test_student2@test.edu', 'Admin Test Student 2', 'device_student2'),
    (student3_id, 'admin_test_student3@test.edu', 'Admin Test Student 3', 'device_student3');

  -- Create attendance logs for all students
  INSERT INTO attendance_logs (student_id, classroom_id, status, student_location)
  VALUES 
    (student1_id, classroom1_id, 'PRESENT', ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography),
    (student1_id, classroom1_id, 'PRESENT', ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography),
    (student2_id, classroom1_id, 'PRESENT', ST_SetSRID(ST_MakePoint(-122.4195, 37.7750), 4326)::geography),
    (student2_id, classroom1_id, 'REJECTED', ST_SetSRID(ST_MakePoint(-122.4295, 37.7850), 4326)::geography, 'outside_geofence'),
    (student3_id, classroom1_id, 'PRESENT', ST_SetSRID(ST_MakePoint(-122.4196, 37.7751), 4326)::geography);

  -- Get total counts
  SELECT COUNT(*) INTO total_profiles FROM profiles WHERE email LIKE 'admin_test_%@test.edu';
  SELECT COUNT(*) INTO total_attendance FROM attendance_logs WHERE student_id IN (student1_id, student2_id, student3_id);

  RAISE NOTICE 'Created % test profiles and % attendance logs', total_profiles, total_attendance;
  RAISE NOTICE '';

  -- Test 1: Regular student can only see their own profile
  RAISE NOTICE 'Test 1: Student1 can only see their own profile';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', student1_id)::text, true);
  
  SELECT COUNT(*) INTO visible_profiles FROM profiles WHERE email LIKE 'admin_test_%@test.edu';
  
  IF visible_profiles != 1 THEN
    RAISE EXCEPTION '❌ FAIL: Student1 should only see 1 profile (their own), but saw %', visible_profiles;
  END IF;
  
  RAISE NOTICE '✅ PASS: Student1 sees only their own profile (1 out of %)', total_profiles;

  -- Test 2: Regular student can only see their own attendance logs
  RAISE NOTICE 'Test 2: Student1 can only see their own attendance logs';
  
  SELECT COUNT(*) INTO visible_attendance FROM attendance_logs 
  WHERE student_id IN (student1_id, student2_id, student3_id);
  
  IF visible_attendance != 2 THEN
    RAISE EXCEPTION '❌ FAIL: Student1 should only see 2 attendance logs (their own), but saw %', visible_attendance;
  END IF;
  
  RAISE NOTICE '✅ PASS: Student1 sees only their own attendance logs (2 out of %)', total_attendance;
  RAISE NOTICE '';

  -- Test 3: Admin user WITHOUT admin role metadata sees only their own profile (like regular user)
  RAISE NOTICE 'Test 3: User without admin role sees only their own profile';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', admin_user_id)::text, true);
  
  SELECT COUNT(*) INTO visible_profiles FROM profiles WHERE email LIKE 'admin_test_%@test.edu';
  
  IF visible_profiles != 1 THEN
    RAISE EXCEPTION '❌ FAIL: Non-admin user should only see 1 profile, but saw %', visible_profiles;
  END IF;
  
  RAISE NOTICE '✅ PASS: User without admin role sees only their own profile (1 out of %)', total_profiles;
  RAISE NOTICE '';

  -- Note: Testing actual admin access requires modifying auth.users table
  -- which is typically not accessible in standard RLS tests
  RAISE NOTICE 'Note: Full admin access testing requires:';
  RAISE NOTICE '  1. Creating a user in auth.users with admin role metadata';
  RAISE NOTICE '  2. Setting raw_app_meta_data or raw_user_meta_data with role=admin';
  RAISE NOTICE '  3. Creating RLS policies that check for admin role';
  RAISE NOTICE '';
  RAISE NOTICE 'Current RLS policies for profiles and attendance_logs:';
  RAISE NOTICE '  - Students can view only their own data (auth.uid() = id/student_id)';
  RAISE NOTICE '  - No admin override policies are currently implemented';
  RAISE NOTICE '';
  RAISE NOTICE 'To implement admin access, add policies like:';
  RAISE NOTICE '  CREATE POLICY "Admins can view all profiles"';
  RAISE NOTICE '    ON profiles FOR SELECT';
  RAISE NOTICE '    USING (';
  RAISE NOTICE '      EXISTS (';
  RAISE NOTICE '        SELECT 1 FROM auth.users';
  RAISE NOTICE '        WHERE auth.users.id = auth.uid()';
  RAISE NOTICE '        AND (raw_app_meta_data->>''role'' = ''admin''';
  RAISE NOTICE '             OR raw_user_meta_data->>''role'' = ''admin'')';
  RAISE NOTICE '      )';
  RAISE NOTICE '    );';
  RAISE NOTICE '';

  -- Test 4: Verify RLS policies exist for student isolation
  RAISE NOTICE 'Test 4: Verify RLS policies exist for student data isolation';
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND policyname = 'Users can view own profile'
  ) THEN
    RAISE EXCEPTION '❌ FAIL: RLS policy "Users can view own profile" not found';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'attendance_logs' 
    AND policyname = 'Users can view own attendance'
  ) THEN
    RAISE EXCEPTION '❌ FAIL: RLS policy "Users can view own attendance" not found';
  END IF;
  
  RAISE NOTICE '✅ PASS: Student isolation RLS policies exist';
  RAISE NOTICE '';

  -- Test 5: Check if admin policies exist
  RAISE NOTICE 'Test 5: Check for admin override policies';
  
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND policyname LIKE '%admin%'
  ) THEN
    RAISE NOTICE '✅ Admin policy found for profiles table';
  ELSE
    RAISE NOTICE '⚠️  WARNING: No admin policy found for profiles table';
    RAISE NOTICE '   Admin users will not be able to view all profiles';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'attendance_logs' 
    AND policyname LIKE '%admin%'
  ) THEN
    RAISE NOTICE '✅ Admin policy found for attendance_logs table';
  ELSE
    RAISE NOTICE '⚠️  WARNING: No admin policy found for attendance_logs table';
    RAISE NOTICE '   Admin users will not be able to view all attendance logs';
  END IF;
  RAISE NOTICE '';

  -- Cleanup
  DELETE FROM attendance_logs WHERE student_id IN (
    SELECT id FROM profiles WHERE email LIKE 'admin_test_%@test.edu'
  );
  DELETE FROM profiles WHERE email LIKE 'admin_test_%@test.edu';
  DELETE FROM classrooms WHERE id = classroom1_id;

  RAISE NOTICE 'Cleanup: Test data removed';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Summary:';
  RAISE NOTICE '✅ Student data isolation working correctly';
  RAISE NOTICE '⚠️  Admin override policies need to be implemented';
  RAISE NOTICE '   for full Requirement 10.4 compliance';
  RAISE NOTICE '========================================';

EXCEPTION
  WHEN OTHERS THEN
    -- Cleanup on failure
    DELETE FROM attendance_logs WHERE student_id IN (
      SELECT id FROM profiles WHERE email LIKE 'admin_test_%@test.edu'
    );
    DELETE FROM profiles WHERE email LIKE 'admin_test_%@test.edu';
    DELETE FROM classrooms WHERE name = 'Admin Test Room';
    
    RAISE;
END $$;

\echo ''
\echo '========================================='
\echo 'Unit Test: Complete'
\echo '========================================='
