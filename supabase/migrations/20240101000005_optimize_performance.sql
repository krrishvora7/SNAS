-- Migration: Performance Optimization
-- Task: 16.2 Optimize database queries and indexes
-- Validates Requirements: 5.5, 13.1

-- ============================================
-- 1. ADDITIONAL INDEXES FOR PERFORMANCE
-- ============================================

-- Add composite index for rate limiting query optimization
-- This speeds up the MAX(timestamp) query for a specific student
CREATE INDEX IF NOT EXISTS idx_attendance_student_timestamp 
ON attendance_logs(student_id, timestamp DESC);

-- Add index on status for filtered queries
CREATE INDEX IF NOT EXISTS idx_attendance_status 
ON attendance_logs(status);

-- Add composite index for dashboard filtered queries
-- Supports queries filtering by classroom_id and status with timestamp ordering
CREATE INDEX IF NOT EXISTS idx_attendance_classroom_status_timestamp 
ON attendance_logs(classroom_id, status, timestamp DESC);

-- Add composite index for time-range queries with status filter
CREATE INDEX IF NOT EXISTS idx_attendance_timestamp_status 
ON attendance_logs(timestamp DESC, status);

-- Add index on profiles.device_id for faster device binding lookups
CREATE INDEX IF NOT EXISTS idx_profiles_device_id 
ON profiles(device_id) WHERE device_id IS NOT NULL;

-- ============================================
-- 2. OPTIMIZE MARK_ATTENDANCE FUNCTION
-- ============================================

-- Drop the existing function
DROP FUNCTION IF EXISTS mark_attendance(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION);

-- Recreate with optimizations
CREATE OR REPLACE FUNCTION mark_attendance(
  p_classroom_id UUID,
  p_secret_token TEXT,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $
DECLARE
  v_student_id UUID;
  v_status TEXT;
  v_rejection_reason TEXT;
  v_timestamp TIMESTAMPTZ;
  v_student_location GEOGRAPHY;
  v_stored_device_id TEXT;
  v_current_device_id TEXT;
  v_classroom_record RECORD;
  v_last_attempt_time TIMESTAMPTZ;
  v_time_since_last_attempt INTERVAL;
  v_rate_limit_seconds INTEGER := 60;
  v_distance_meters DOUBLE PRECISION;
  v_geofence_radius_meters DOUBLE PRECISION := 50.0;
  v_email_confirmed BOOLEAN;
BEGIN
  -- Get the authenticated user's ID
  v_student_id := auth.uid();
  
  -- Initialize timestamp once
  v_timestamp := NOW();
  
  -- ============================================
  -- INPUT VALIDATION (Fast Fail)
  -- ============================================
  
  -- Validate: User must be authenticated (fail fast)
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated'
      USING HINT = 'Please log in before marking attendance';
  END IF;
  
  -- Validate: All parameters must be provided
  IF p_classroom_id IS NULL OR p_secret_token IS NULL OR 
     p_latitude IS NULL OR p_longitude IS NULL THEN
    RAISE EXCEPTION 'All parameters are required'
      USING HINT = 'Provide classroom_id, secret_token, latitude, and longitude';
  END IF;
  
  -- Validate: Coordinate ranges (fast check)
  IF p_latitude < -90 OR p_latitude > 90 OR 
     p_longitude < -180 OR p_longitude > 180 THEN
    RAISE EXCEPTION 'Invalid coordinates: lat=%, lng=%', p_latitude, p_longitude
      USING HINT = 'Latitude must be [-90, 90], longitude must be [-180, 180]';
  END IF;
  
  -- Validate: Secret token must not be empty
  IF LENGTH(TRIM(p_secret_token)) = 0 THEN
    RAISE EXCEPTION 'Secret token cannot be empty';
  END IF;
  
  -- Create geography point (validate coordinates)
  BEGIN
    v_student_location := ST_GeogFromText('POINT(' || p_longitude || ' ' || p_latitude || ')');
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Invalid coordinates: lat=%, lng=%', p_latitude, p_longitude;
  END;
  
  -- ============================================
  -- RATE LIMITING (Optimized Query)
  -- ============================================
  
  -- Use optimized index: idx_attendance_student_timestamp
  SELECT timestamp INTO v_last_attempt_time
  FROM attendance_logs
  WHERE student_id = v_student_id
  ORDER BY timestamp DESC
  LIMIT 1;
  
  IF v_last_attempt_time IS NOT NULL THEN
    v_time_since_last_attempt := v_timestamp - v_last_attempt_time;
    
    IF EXTRACT(EPOCH FROM v_time_since_last_attempt) < v_rate_limit_seconds THEN
      v_status := 'REJECTED';
      v_rejection_reason := 'rate_limit_exceeded';
      
      -- Log the rejected attempt
      INSERT INTO attendance_logs (
        student_id, classroom_id, timestamp, status, 
        student_location, rejection_reason
      ) VALUES (
        v_student_id, p_classroom_id, v_timestamp, v_status,
        v_student_location, v_rejection_reason
      );
      
      -- Return early
      RETURN json_build_object(
        'status', v_status,
        'rejection_reason', v_rejection_reason,
        'timestamp', v_timestamp,
        'retry_after_seconds', v_rate_limit_seconds - EXTRACT(EPOCH FROM v_time_since_last_attempt)
      );
    END IF;
  END IF;
  
  -- ============================================
  -- EMAIL VERIFICATION (Optimized)
  -- ============================================
  
  -- Single query to check email verification
  SELECT email_confirmed_at IS NOT NULL INTO v_email_confirmed
  FROM auth.users
  WHERE id = v_student_id;
  
  IF NOT COALESCE(v_email_confirmed, false) THEN
    v_status := 'REJECTED';
    v_rejection_reason := 'email_not_verified';
    
    -- Log and return early
    INSERT INTO attendance_logs (
      student_id, classroom_id, timestamp, status,
      student_location, rejection_reason
    ) VALUES (
      v_student_id, p_classroom_id, v_timestamp, v_status,
      v_student_location, v_rejection_reason
    );
    
    RETURN json_build_object(
      'status', v_status,
      'rejection_reason', v_rejection_reason,
      'timestamp', v_timestamp
    );
  END IF;
  
  -- ============================================
  -- DEVICE BINDING VERIFICATION (Optimized)
  -- ============================================
  
  -- Single query to get device_id from profile
  SELECT device_id INTO v_stored_device_id
  FROM profiles
  WHERE id = v_student_id;
  
  IF NOT FOUND THEN
    v_status := 'REJECTED';
    v_rejection_reason := 'profile_not_found';
    
    INSERT INTO attendance_logs (
      student_id, classroom_id, timestamp, status,
      student_location, rejection_reason
    ) VALUES (
      v_student_id, p_classroom_id, v_timestamp, v_status,
      v_student_location, v_rejection_reason
    );
    
    RETURN json_build_object(
      'status', v_status,
      'rejection_reason', v_rejection_reason,
      'timestamp', v_timestamp
    );
  END IF;
  
  -- Extract device_id from JWT
  v_current_device_id := COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'device_id',
    auth.jwt() -> 'user_metadata' ->> 'device_id'
  );
  
  IF v_current_device_id IS NULL THEN
    v_status := 'REJECTED';
    v_rejection_reason := 'device_id_missing';
    
    INSERT INTO attendance_logs (
      student_id, classroom_id, timestamp, status,
      student_location, rejection_reason
    ) VALUES (
      v_student_id, p_classroom_id, v_timestamp, v_status,
      v_student_location, v_rejection_reason
    );
    
    RETURN json_build_object(
      'status', v_status,
      'rejection_reason', v_rejection_reason,
      'timestamp', v_timestamp
    );
  END IF;
  
  IF v_stored_device_id IS NOT NULL AND v_stored_device_id != v_current_device_id THEN
    v_status := 'REJECTED';
    v_rejection_reason := 'device_mismatch';
    
    INSERT INTO attendance_logs (
      student_id, classroom_id, timestamp, status,
      student_location, rejection_reason
    ) VALUES (
      v_student_id, p_classroom_id, v_timestamp, v_status,
      v_student_location, v_rejection_reason
    );
    
    RETURN json_build_object(
      'status', v_status,
      'rejection_reason', v_rejection_reason,
      'timestamp', v_timestamp
    );
  END IF;
  
  -- ============================================
  -- CLASSROOM VALIDATION (Single Query)
  -- ============================================
  
  -- Fetch classroom data in one query (secret + location)
  -- Uses primary key index for fast lookup
  SELECT nfc_secret, location INTO v_classroom_record
  FROM classrooms
  WHERE id = p_classroom_id;
  
  IF NOT FOUND THEN
    v_status := 'REJECTED';
    v_rejection_reason := 'classroom_not_found';
    
    INSERT INTO attendance_logs (
      student_id, classroom_id, timestamp, status,
      student_location, rejection_reason
    ) VALUES (
      v_student_id, p_classroom_id, v_timestamp, v_status,
      v_student_location, v_rejection_reason
    );
    
    RETURN json_build_object(
      'status', v_status,
      'rejection_reason', v_rejection_reason,
      'timestamp', v_timestamp
    );
  END IF;
  
  -- ============================================
  -- SECRET TOKEN VALIDATION
  -- ============================================
  
  IF v_classroom_record.nfc_secret != p_secret_token THEN
    v_status := 'REJECTED';
    v_rejection_reason := 'invalid_token';
    
    INSERT INTO attendance_logs (
      student_id, classroom_id, timestamp, status,
      student_location, rejection_reason
    ) VALUES (
      v_student_id, p_classroom_id, v_timestamp, v_status,
      v_student_location, v_rejection_reason
    );
    
    RETURN json_build_object(
      'status', v_status,
      'rejection_reason', v_rejection_reason,
      'timestamp', v_timestamp
    );
  END IF;
  
  -- ============================================
  -- GEOFENCE VALIDATION (Optimized)
  -- ============================================
  
  -- Calculate distance using PostGIS (uses spatial index)
  v_distance_meters := ST_Distance(v_student_location, v_classroom_record.location);
  
  IF v_distance_meters > v_geofence_radius_meters THEN
    v_status := 'REJECTED';
    v_rejection_reason := 'outside_geofence';
  ELSE
    v_status := 'PRESENT';
    v_rejection_reason := NULL;
  END IF;
  
  -- ============================================
  -- ATTENDANCE LOGGING
  -- ============================================
  
  INSERT INTO attendance_logs (
    student_id, classroom_id, timestamp, status,
    student_location, rejection_reason
  ) VALUES (
    v_student_id, p_classroom_id, v_timestamp, v_status,
    v_student_location, v_rejection_reason
  );
  
  -- ============================================
  -- RETURN RESPONSE
  -- ============================================
  
  RETURN json_build_object(
    'status', v_status,
    'rejection_reason', v_rejection_reason,
    'timestamp', v_timestamp
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'mark_attendance failed: %', SQLERRM
      USING HINT = 'Check input parameters and database state';
END;
$;

-- Add function comment
COMMENT ON FUNCTION mark_attendance(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) IS 
'Optimized server-side attendance validation function. Validates device binding, secret tokens, and geofence boundaries. Target execution time: <200ms.';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION mark_attendance(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

-- ============================================
-- 3. CREATE MATERIALIZED VIEW FOR DASHBOARD (Optional)
-- ============================================

-- This can be used for dashboard queries to improve performance
-- Refresh periodically or on-demand
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_recent_attendance AS
SELECT 
  al.id,
  al.timestamp,
  al.status,
  al.rejection_reason,
  p.full_name as student_name,
  p.email as student_email,
  c.name as classroom_name,
  c.building,
  ST_X(al.student_location::geometry) as student_lng,
  ST_Y(al.student_location::geometry) as student_lat,
  ST_X(c.location::geometry) as classroom_lng,
  ST_Y(c.location::geometry) as classroom_lat,
  al.student_id,
  al.classroom_id
FROM attendance_logs al
JOIN profiles p ON al.student_id = p.id
JOIN classrooms c ON al.classroom_id = c.id
WHERE al.timestamp >= NOW() - INTERVAL '7 days'
ORDER BY al.timestamp DESC;

-- Create index on materialized view
CREATE INDEX IF NOT EXISTS idx_mv_recent_attendance_timestamp 
ON mv_recent_attendance(timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_mv_recent_attendance_classroom 
ON mv_recent_attendance(classroom_id, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_mv_recent_attendance_status 
ON mv_recent_attendance(status, timestamp DESC);

-- Add comment
COMMENT ON MATERIALIZED VIEW mv_recent_attendance IS 
'Materialized view of recent attendance (last 7 days) with joined data for dashboard queries. Refresh periodically for best performance.';

-- ============================================
-- 4. VACUUM AND ANALYZE
-- ============================================

-- Update table statistics for query planner
ANALYZE attendance_logs;
ANALYZE classrooms;
ANALYZE profiles;

-- ============================================
-- 5. PERFORMANCE MONITORING FUNCTION
-- ============================================

-- Create a function to monitor mark_attendance performance
CREATE OR REPLACE FUNCTION get_attendance_performance_stats()
RETURNS TABLE (
  metric TEXT,
  value NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $
BEGIN
  RETURN QUERY
  SELECT 'total_attendance_logs'::TEXT, COUNT(*)::NUMERIC FROM attendance_logs
  UNION ALL
  SELECT 'logs_last_24h'::TEXT, COUNT(*)::NUMERIC FROM attendance_logs WHERE timestamp >= NOW() - INTERVAL '24 hours'
  UNION ALL
  SELECT 'present_rate_pct'::TEXT, 
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'PRESENT') / NULLIF(COUNT(*), 0), 2)
  FROM attendance_logs WHERE timestamp >= NOW() - INTERVAL '24 hours'
  UNION ALL
  SELECT 'avg_logs_per_student'::TEXT,
    ROUND(COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT student_id), 0), 2)
  FROM attendance_logs WHERE timestamp >= NOW() - INTERVAL '7 days'
  UNION ALL
  SELECT 'total_classrooms'::TEXT, COUNT(*)::NUMERIC FROM classrooms
  UNION ALL
  SELECT 'total_students'::TEXT, COUNT(*)::NUMERIC FROM profiles;
END;
$;

COMMENT ON FUNCTION get_attendance_performance_stats() IS 
'Returns performance and usage statistics for the attendance system';

GRANT EXECUTE ON FUNCTION get_attendance_performance_stats() TO authenticated;

