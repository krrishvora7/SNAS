-- Migration: Create mark_attendance RPC function with input validation
-- Task: 3.1 Create mark_attendance function with input validation
-- Validates Requirements: 5.1, 14.2

-- Create the mark_attendance function
-- This function is the core server-side validation logic for attendance marking
-- It validates device binding, secret tokens, and geofence boundaries
CREATE OR REPLACE FUNCTION mark_attendance(
  p_classroom_id UUID,
  p_secret_token TEXT,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER  -- Bypass RLS to insert into attendance_logs
SET search_path = public
AS $$
DECLARE
  v_student_id UUID;
  v_status TEXT;
  v_rejection_reason TEXT;
  v_timestamp TIMESTAMPTZ;
  v_student_location GEOGRAPHY;
  v_stored_device_id TEXT;
  v_current_device_id TEXT;
BEGIN
  -- Get the authenticated user's ID
  v_student_id := auth.uid();
  
  -- Initialize timestamp
  v_timestamp := NOW();
  
  -- ============================================
  -- INPUT VALIDATION
  -- ============================================
  
  -- Validate: All parameters must be provided (not null)
  IF p_classroom_id IS NULL THEN
    RAISE EXCEPTION 'Parameter p_classroom_id cannot be null'
      USING HINT = 'Provide a valid classroom UUID';
  END IF;
  
  IF p_secret_token IS NULL THEN
    RAISE EXCEPTION 'Parameter p_secret_token cannot be null'
      USING HINT = 'Provide a valid secret token';
  END IF;
  
  IF p_latitude IS NULL THEN
    RAISE EXCEPTION 'Parameter p_latitude cannot be null'
      USING HINT = 'Provide a valid latitude coordinate';
  END IF;
  
  IF p_longitude IS NULL THEN
    RAISE EXCEPTION 'Parameter p_longitude cannot be null'
      USING HINT = 'Provide a valid longitude coordinate';
  END IF;
  
  -- Validate: User must be authenticated
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated'
      USING HINT = 'Please log in before marking attendance';
  END IF;
  
  -- Validate: Latitude range (-90 to 90)
  IF p_latitude < -90 OR p_latitude > 90 THEN
    RAISE EXCEPTION 'Invalid latitude: %. Must be between -90 and 90', p_latitude
      USING HINT = 'Latitude must be in the range [-90, 90]';
  END IF;
  
  -- Validate: Longitude range (-180 to 180)
  IF p_longitude < -180 OR p_longitude > 180 THEN
    RAISE EXCEPTION 'Invalid longitude: %. Must be between -180 and 180', p_longitude
      USING HINT = 'Longitude must be in the range [-180, 180]';
  END IF;
  
  -- Validate: Secret token must not be empty
  IF LENGTH(TRIM(p_secret_token)) = 0 THEN
    RAISE EXCEPTION 'Secret token cannot be empty'
      USING HINT = 'Provide a non-empty secret token';
  END IF;
  
  -- Create geography point from coordinates
  -- This will also validate that the coordinates are valid
  BEGIN
    v_student_location := ST_GeogFromText('POINT(' || p_longitude || ' ' || p_latitude || ')');
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Invalid coordinates: latitude=%, longitude=%', p_latitude, p_longitude
      USING HINT = 'Coordinates must be valid WGS84 values';
  END;
  
  -- ============================================
  -- VALIDATION LOGIC
  -- ============================================
  
  -- TASK 14.2: Rate Limiting
  -- Validates Requirements: 14.5
  -- Limit to 1 request per minute per user
  DECLARE
    v_last_attempt_time TIMESTAMPTZ;
    v_time_since_last_attempt INTERVAL;
    v_rate_limit_seconds INTEGER := 60; -- 1 minute
  BEGIN
    -- Get the timestamp of the user's most recent attendance attempt
    SELECT MAX(timestamp) INTO v_last_attempt_time
    FROM attendance_logs
    WHERE student_id = v_student_id;
    
    -- If there was a previous attempt, check if rate limit is exceeded
    IF v_last_attempt_time IS NOT NULL THEN
      v_time_since_last_attempt := v_timestamp - v_last_attempt_time;
      
      -- If less than rate limit seconds have passed, reject
      IF EXTRACT(EPOCH FROM v_time_since_last_attempt) < v_rate_limit_seconds THEN
        v_status := 'REJECTED';
        v_rejection_reason := 'rate_limit_exceeded';
        
        -- Still log the rejected attempt
        INSERT INTO attendance_logs (
          student_id,
          classroom_id,
          timestamp,
          status,
          student_location,
          rejection_reason
        ) VALUES (
          v_student_id,
          p_classroom_id,
          v_timestamp,
          v_status,
          v_student_location,
          v_rejection_reason
        );
        
        -- Return early with rate limit error
        RETURN json_build_object(
          'status', v_status,
          'rejection_reason', v_rejection_reason,
          'timestamp', v_timestamp,
          'retry_after_seconds', v_rate_limit_seconds - EXTRACT(EPOCH FROM v_time_since_last_attempt)
        );
      END IF;
    END IF;
  END;
  
  -- TASK 14.1: Email Verification Enforcement
  -- Validates Requirements: 1.4
  DECLARE
    v_email_confirmed BOOLEAN;
  BEGIN
    -- Check if the user's email is verified
    SELECT raw_user_meta_data->>'email_confirmed' = 'true' OR 
           (auth.jwt() -> 'email_verified')::boolean = true
    INTO v_email_confirmed
    FROM auth.users
    WHERE id = v_student_id;
    
    -- Alternative: Check email_confirmed_at field
    IF v_email_confirmed IS NULL OR v_email_confirmed = false THEN
      -- Check using email_confirmed_at timestamp
      SELECT email_confirmed_at IS NOT NULL
      INTO v_email_confirmed
      FROM auth.users
      WHERE id = v_student_id;
    END IF;
    
    -- Reject if email is not verified
    IF v_email_confirmed IS NULL OR v_email_confirmed = false THEN
      v_status := 'REJECTED';
      v_rejection_reason := 'email_not_verified';
    END IF;
  END;
  
  -- Only proceed with device binding check if email verification passed
  IF v_status IS NULL THEN
    -- TASK 3.2: Device Binding Verification
    -- Validates Requirements: 2.2, 5.3
    
    -- Get the stored device_id from the user's profile
    SELECT device_id INTO v_stored_device_id
    FROM profiles
    WHERE id = v_student_id;
    
    -- Check if profile exists
    IF NOT FOUND THEN
      v_status := 'REJECTED';
      v_rejection_reason := 'profile_not_found';
    ELSE
    -- Extract device_id from JWT claims
    -- The JWT contains app_metadata which should include device_id
    v_current_device_id := COALESCE(
      auth.jwt() -> 'app_metadata' ->> 'device_id',
      auth.jwt() -> 'user_metadata' ->> 'device_id'
    );
    
    -- Verify device binding
    -- If stored_device_id is NULL, the device hasn't been bound yet (first login)
    -- If stored_device_id is not NULL, it must match the current device_id
    IF v_stored_device_id IS NOT NULL AND v_current_device_id IS NOT NULL THEN
      IF v_stored_device_id != v_current_device_id THEN
        v_status := 'REJECTED';
        v_rejection_reason := 'device_mismatch';
      END IF;
    END IF;
    
    -- If device_id is not in JWT claims, reject for security
    IF v_current_device_id IS NULL THEN
      v_status := 'REJECTED';
      v_rejection_reason := 'device_id_missing';
    END IF;
  END IF;  -- End of device binding check
  END IF;  -- End of email verification check
  
  -- Only proceed with other validations if device binding passed
  IF v_status IS NULL THEN
    -- TASK 3.3: Secret Token Validation
    -- Validates Requirements: 5.2
    DECLARE
      v_stored_secret TEXT;
    BEGIN
      -- Query the classrooms table for the provided classroom_id
      SELECT nfc_secret INTO v_stored_secret
      FROM classrooms
      WHERE id = p_classroom_id;
      
      -- Check if classroom exists
      IF NOT FOUND THEN
        v_status := 'REJECTED';
        v_rejection_reason := 'classroom_not_found';
      ELSE
        -- Compare the provided secret token with the stored nfc_secret
        IF v_stored_secret != p_secret_token THEN
          v_status := 'REJECTED';
          v_rejection_reason := 'invalid_token';
        END IF;
      END IF;
    END;
  END IF;
  
  -- Only proceed with geofence validation if previous validations passed
  IF v_status IS NULL THEN
    -- TASK 3.4: Geofence Validation with PostGIS
    -- Validates Requirements: 5.4, 6.2, 6.3
    DECLARE
      v_classroom_location GEOGRAPHY;
      v_distance_meters DOUBLE PRECISION;
      v_geofence_radius_meters DOUBLE PRECISION := 50.0;
    BEGIN
      -- Get the classroom's location
      SELECT location INTO v_classroom_location
      FROM classrooms
      WHERE id = p_classroom_id;
      
      -- Calculate distance between student location and classroom location
      -- ST_Distance returns distance in meters for geography type
      v_distance_meters := ST_Distance(v_student_location, v_classroom_location);
      
      -- Check if student is within the geofence (50 meters)
      IF v_distance_meters > v_geofence_radius_meters THEN
        v_status := 'REJECTED';
        v_rejection_reason := 'outside_geofence';
      ELSE
        -- All validations passed - mark as PRESENT
        v_status := 'PRESENT';
        v_rejection_reason := NULL;
      END IF;
    END;
  END IF;
  
  -- ============================================
  -- ATTENDANCE LOGGING
  -- ============================================
  
  -- Insert attendance log record
  -- SECURITY DEFINER allows this function to bypass the RLS INSERT policy
  INSERT INTO attendance_logs (
    student_id,
    classroom_id,
    timestamp,
    status,
    student_location,
    rejection_reason
  ) VALUES (
    v_student_id,
    p_classroom_id,
    v_timestamp,
    v_status,
    v_student_location,
    v_rejection_reason
  );
  
  -- ============================================
  -- RETURN RESPONSE
  -- ============================================
  
  -- Return structured JSON response
  RETURN json_build_object(
    'status', v_status,
    'rejection_reason', v_rejection_reason,
    'timestamp', v_timestamp
  );
  
EXCEPTION
  -- Handle any unexpected errors
  WHEN OTHERS THEN
    -- Re-raise the exception with context
    RAISE EXCEPTION 'mark_attendance failed: %', SQLERRM
      USING HINT = 'Check input parameters and database state';
END;
$$;

-- Add function comment
COMMENT ON FUNCTION mark_attendance(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) IS 
'Server-side attendance validation function. Validates device binding, secret tokens, and geofence boundaries before logging attendance. Uses SECURITY DEFINER to bypass RLS policies.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION mark_attendance(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
