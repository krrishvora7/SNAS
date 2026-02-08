-- Test script for classrooms table migration
-- This script verifies the migration was applied correctly

-- Test 1: Verify PostGIS extension is enabled
SELECT EXISTS (
  SELECT FROM pg_extension
  WHERE extname = 'postgis'
) AS postgis_extension_exists;

-- Test 2: Verify table exists
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'classrooms'
) AS classrooms_table_exists;

-- Test 3: Verify columns exist with correct types
SELECT 
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'classrooms'
ORDER BY ordinal_position;

-- Test 4: Verify unique constraints
SELECT
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'classrooms'
  AND tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY')
ORDER BY tc.constraint_type, kcu.column_name;

-- Test 5: Verify RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'classrooms';

-- Test 6: Verify RLS policies exist
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'classrooms'
ORDER BY policyname;

-- Test 7: Verify indexes exist (including spatial index)
SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'classrooms'
ORDER BY indexname;

-- Test 8: Verify spatial index type (GIST)
SELECT
  i.relname AS index_name,
  am.amname AS index_type,
  a.attname AS column_name
FROM pg_class t
JOIN pg_index ix ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_am am ON i.relam = am.oid
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
WHERE t.relname = 'classrooms'
  AND a.attname = 'location'
ORDER BY i.relname;

-- Test 9: Verify geography column type and SRID
SELECT 
  f_table_name,
  f_geography_column,
  coord_dimension,
  srid,
  type
FROM geography_columns
WHERE f_table_name = 'classrooms';
