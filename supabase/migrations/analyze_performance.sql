-- Performance Analysis Script
-- Task: 16.2 Optimize database queries and indexes
-- This script analyzes query performance and identifies optimization opportunities

-- ============================================
-- 1. ANALYZE MARK_ATTENDANCE FUNCTION QUERIES
-- ============================================

-- Test data setup (if needed)
-- This assumes you have test data in profiles, classrooms, and attendance_logs

-- Analyze: Profile lookup by student_id
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT device_id 
FROM profiles 
WHERE id = '00000000-0000-0000-0000-000000000001'::UUID;

-- Analyze: Classroom lookup by classroom_id
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT nfc_secret, location 
FROM classrooms 
WHERE id = '00000000-0000-0000-0000-000000000001'::UUID;

-- Analyze: Rate limiting query (most recent attendance by student)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT MAX(timestamp) 
FROM attendance_logs 
WHERE student_id = '00000000-0000-0000-0000-000000000001'::UUID;

-- Analyze: Distance calculation with PostGIS
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  ST_Distance(
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    location
  ) as distance_meters
FROM classrooms 
WHERE id = '00000000-0000-0000-0000-000000000001'::UUID;

-- ============================================
-- 2. ANALYZE DASHBOARD QUERIES
-- ============================================

-- Analyze: Recent attendance with joins (dashboard query)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  al.id,
  al.timestamp,
  al.status,
  al.rejection_reason,
  p.full_name as student_name,
  c.name as classroom_name,
  c.building,
  ST_X(al.student_location::geometry) as student_lng,
  ST_Y(al.student_location::geometry) as student_lat,
  ST_X(c.location::geometry) as classroom_lng,
  ST_Y(c.location::geometry) as classroom_lat
FROM attendance_logs al
JOIN profiles p ON al.student_id = p.id
JOIN classrooms c ON al.classroom_id = c.id
WHERE al.timestamp >= NOW() - INTERVAL '24 hours'
ORDER BY al.timestamp DESC
LIMIT 100;

-- Analyze: Filtered attendance query (with date range and classroom filter)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  al.id,
  al.timestamp,
  al.status,
  p.full_name as student_name,
  c.name as classroom_name
FROM attendance_logs al
JOIN profiles p ON al.student_id = p.id
JOIN classrooms c ON al.classroom_id = c.id
WHERE al.timestamp BETWEEN '2024-01-01' AND '2024-12-31'
  AND al.classroom_id = '00000000-0000-0000-0000-000000000001'::UUID
  AND al.status = 'PRESENT'
ORDER BY al.timestamp DESC;

-- Analyze: Student attendance history query
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  al.id,
  al.timestamp,
  al.status,
  al.rejection_reason,
  c.name as classroom_name,
  c.building
FROM attendance_logs al
JOIN classrooms c ON al.classroom_id = c.id
WHERE al.student_id = '00000000-0000-0000-0000-000000000001'::UUID
ORDER BY al.timestamp DESC
LIMIT 50;

-- ============================================
-- 3. INDEX USAGE STATISTICS
-- ============================================

-- Check index usage on attendance_logs table
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan as index_scans,
  idx_tup_read as tuples_read,
  idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE tablename IN ('attendance_logs', 'classrooms', 'profiles')
ORDER BY tablename, indexname;

-- Check table statistics
SELECT 
  schemaname,
  tablename,
  seq_scan as sequential_scans,
  seq_tup_read as sequential_tuples_read,
  idx_scan as index_scans,
  idx_tup_fetch as index_tuples_fetched,
  n_tup_ins as inserts,
  n_tup_upd as updates,
  n_tup_del as deletes,
  n_live_tup as live_tuples
FROM pg_stat_user_tables
WHERE tablename IN ('attendance_logs', 'classrooms', 'profiles')
ORDER BY tablename;

-- ============================================
-- 4. MISSING INDEX RECOMMENDATIONS
-- ============================================

-- Check for missing indexes on foreign keys
SELECT 
  tc.table_name,
  kcu.column_name,
  tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name IN ('attendance_logs', 'classrooms', 'profiles')
ORDER BY tc.table_name, kcu.column_name;

-- List all existing indexes
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename IN ('attendance_logs', 'classrooms', 'profiles')
ORDER BY tablename, indexname;

-- ============================================
-- 5. QUERY PERFORMANCE SUMMARY
-- ============================================

-- Show slow queries (if pg_stat_statements is enabled)
-- This requires the pg_stat_statements extension
-- Uncomment if available:
/*
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  max_time,
  stddev_time
FROM pg_stat_statements
WHERE query LIKE '%attendance%' OR query LIKE '%classroom%'
ORDER BY mean_time DESC
LIMIT 20;
*/

