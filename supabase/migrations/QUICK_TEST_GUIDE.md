# Quick Test Guide - Task 4 Checkpoint

## Prerequisites

1. Supabase project with PostgreSQL 15+ and PostGIS
2. Migrations applied (tasks 2.1-2.3, 3.1-3.5)
3. Test user authenticated via Supabase Auth
4. Example classroom data loaded

## Quick Setup

```bash
# 1. Apply all migrations
supabase db push

# 2. Load example classroom data
psql -h your-db-host -U postgres -d postgres \
  -f supabase/migrations/example_classrooms_data.sql
```

## Essential Tests

### Test 1: Verify Database Setup

```sql
-- Check all tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('profiles', 'classrooms', 'attendance_logs');
-- Expected: 3 rows

-- Check PostGIS enabled
SELECT extname FROM pg_extension WHERE extname = 'postgis';
-- Expected: 1 row

-- Check function exists
SELECT proname FROM pg_proc WHERE proname = 'mark_attendance';
-- Expected: 1 row
```

### Test 2: Get Test Classroom Data

```sql
-- Get classroom details for testing
SELECT 
  id,
  name,
  nfc_secret,
  ST_Y(location::geometry) AS latitude,
  ST_X(location::geometry) AS longitude
FROM classrooms
LIMIT 1;
```

**Save these values for the next tests!**

### Test 3: Successful Attendance (Valid)

```sql
-- Replace with actual values from Test 2
SELECT mark_attendance(
  'your-classroom-uuid'::UUID,
  'eng301_secret_a1b2c3d4e5f6',
  37.7749,  -- Classroom latitude
  -122.4194  -- Classroom longitude
);
```

**Expected:**
```json
{"status": "PRESENT", "rejection_reason": null, "timestamp": "..."}
```

### Test 4: Invalid Secret Token

```sql
SELECT mark_attendance(
  'your-classroom-uuid'::UUID,
  'wrong_secret',  -- Wrong token
  37.7749,
  -122.4194
);
```

**Expected:**
```json
{"status": "REJECTED", "rejection_reason": "invalid_token", "timestamp": "..."}
```

### Test 5: Outside Geofence

```sql
-- 100 meters away (~0.0009 degrees latitude)
SELECT mark_attendance(
  'your-classroom-uuid'::UUID,
  'eng301_secret_a1b2c3d4e5f6',
  37.7759,  -- 100m north
  -122.4194
);
```

**Expected:**
```json
{"status": "REJECTED", "rejection_reason": "outside_geofence", "timestamp": "..."}
```

### Test 6: Invalid Input

```sql
-- Out of range latitude
SELECT mark_attendance(
  'your-classroom-uuid'::UUID,
  'eng301_secret_a1b2c3d4e5f6',
  91.0,  -- Invalid
  -122.4194
);
```

**Expected:** ERROR: Invalid latitude: 91. Must be between -90 and 90

### Test 7: Verify Logs

```sql
-- Check your attendance logs
SELECT 
  timestamp,
  status,
  rejection_reason,
  ST_Y(student_location::geometry) AS lat,
  ST_X(student_location::geometry) AS lng
FROM attendance_logs
WHERE student_id = auth.uid()
ORDER BY timestamp DESC
LIMIT 5;
```

**Expected:** All test attempts should be logged

### Test 8: Performance Check

```sql
-- Enable timing
\timing on

-- Run function and check execution time
SELECT mark_attendance(
  'your-classroom-uuid'::UUID,
  'eng301_secret_a1b2c3d4e5f6',
  37.7749,
  -122.4194
);
```

**Expected:** Time < 200ms

## Distance Reference (San Francisco Latitude)

For testing geofence boundaries:

| Distance | Latitude Offset | Example Latitude |
|----------|----------------|------------------|
| 0m | 0.0 | 37.7749 |
| 25m | +0.000225 | 37.77515 |
| 50m | +0.00045 | 37.77535 |
| 51m | +0.00046 | 37.77536 |
| 100m | +0.0009 | 37.7759 |

## Common Issues

### Issue: "relation does not exist"
**Solution:** Run migrations: `supabase db push`

### Issue: "function mark_attendance does not exist"
**Solution:** Apply migration 20240101000003_create_mark_attendance_function.sql

### Issue: "must be owner of function mark_attendance"
**Solution:** You need database admin privileges to create functions

### Issue: "User must be authenticated"
**Solution:** Authenticate via Supabase Auth before calling function

### Issue: No classrooms found
**Solution:** Load example data: `example_classrooms_data.sql`

## Success Criteria

✅ All 3 tables exist  
✅ PostGIS extension enabled  
✅ mark_attendance function exists  
✅ Valid attendance returns PRESENT  
✅ Invalid token returns REJECTED with "invalid_token"  
✅ Outside geofence returns REJECTED with "outside_geofence"  
✅ Invalid input raises appropriate error  
✅ All attempts logged in attendance_logs  
✅ Function executes < 200ms  

## Next Steps

If all tests pass:
- ✅ Mark Task 4 as complete
- ✅ Proceed to Task 5 (Flutter authentication module)

If tests fail:
- Review error messages
- Check TASK_4_CHECKPOINT_VERIFICATION.md for detailed troubleshooting
- Ask user for guidance

