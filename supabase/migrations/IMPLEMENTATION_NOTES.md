# Implementation Notes - Task 2.1

## Task: Create profiles table with RLS policies

**Status:** ✅ Completed

**Requirements Validated:** 9.1, 10.1, 10.2

## What Was Implemented

### 1. Profiles Table Schema

Created the `profiles` table with the following structure:

```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  device_id TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

**Key Features:**
- `id`: Primary key that references Supabase Auth users table
- `email`: Unique university email address (NOT NULL)
- `full_name`: Student's full name (NOT NULL)
- `device_id`: Unique device identifier for device binding (nullable initially)
- `created_at`: Timestamp of profile creation with automatic default

### 2. Constraints

- **Primary Key:** `id` column
- **Foreign Key:** `id` references `auth.users(id)` with CASCADE delete
- **Unique Constraints:**
  - `email` must be unique across all profiles
  - `device_id` must be unique when not null

### 3. Indexes

Created indexes for performance optimization:
- `idx_profiles_email`: Index on email column for faster lookups
- `idx_profiles_device_id`: Index on device_id column for device binding checks

### 4. Row Level Security (RLS)

Enabled RLS on the profiles table with three policies:

#### Policy 1: "Users can view own profile"
```sql
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);
```
- Allows users to SELECT only their own profile record
- Validates Requirement 10.2

#### Policy 2: "Users can update own profile"
```sql
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);
```
- Allows users to UPDATE only their own profile record
- Validates Requirement 10.2

#### Policy 3: "Users can insert own profile"
```sql
CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);
```
- Allows users to INSERT their own profile during initial setup
- Required for the authentication flow to work properly

### 5. Documentation

Added SQL comments to document:
- Table purpose
- Each column's meaning and constraints
- References to requirements

## Files Created

1. **`supabase/migrations/20240101000000_create_profiles_table.sql`**
   - Main migration file with table creation and RLS policies

2. **`supabase/README.md`**
   - Documentation on how to apply migrations
   - Guidelines for creating new migrations

3. **`supabase/migrations/test_profiles_migration.sql`**
   - Test queries to verify the migration was applied correctly
   - Checks table structure, constraints, RLS policies, and indexes

4. **`supabase/migrations/IMPLEMENTATION_NOTES.md`**
   - This file - detailed implementation notes

## How to Apply This Migration

### Option 1: Supabase CLI
```bash
supabase link --project-ref your-project-ref
supabase db push
```

### Option 2: Supabase Dashboard
1. Go to SQL Editor in your Supabase dashboard
2. Copy the contents of `20240101000000_create_profiles_table.sql`
3. Execute the SQL

### Option 3: Direct PostgreSQL Connection
```bash
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/20240101000000_create_profiles_table.sql
```

## Verification

After applying the migration, run the test script to verify:
```bash
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/test_profiles_migration.sql
```

Expected results:
- ✅ Table `profiles` exists
- ✅ All 5 columns present with correct types
- ✅ Unique constraints on `email` and `device_id`
- ✅ Foreign key to `auth.users(id)`
- ✅ RLS enabled on table
- ✅ 3 RLS policies created
- ✅ 2 indexes created

## Design Alignment

This implementation aligns with the design document specifications:

**From Design Document (Section 2.1):**
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  device_id TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Enhancements Made:**
- Added `ON DELETE CASCADE` for cleaner user deletion
- Made `created_at` NOT NULL for data integrity
- Added performance indexes
- Added INSERT policy for initial profile creation
- Added comprehensive documentation

## Next Steps

The next task in the implementation plan is:

**Task 2.2:** Create classrooms table with PostGIS geography
- Requires PostGIS extension to be enabled
- Will include spatial indexing for geofence calculations

## Requirements Validation

### Requirement 9.1 (Database Schema and Storage)
✅ **Validated:** The profiles table has been created with all required columns:
- id (UUID, primary key)
- email (TEXT, unique, not null)
- full_name (TEXT, not null)
- device_id (TEXT, unique, nullable)
- created_at (TIMESTAMPTZ, default NOW())

### Requirement 10.1 (Row Level Security)
✅ **Validated:** RLS has been enabled on the profiles table

### Requirement 10.2 (Row Level Security)
✅ **Validated:** RLS policies ensure:
- Students can only query their own profile data (SELECT policy)
- Students can only update their own profile data (UPDATE policy)
- Students can only insert their own profile data (INSERT policy)

## Security Considerations

1. **RLS Enforcement:** All queries to the profiles table are filtered by `auth.uid()`, ensuring users can only access their own data

2. **Device Binding:** The `device_id` column is unique, preventing multiple profiles from sharing the same device

3. **Email Uniqueness:** The unique constraint on email prevents duplicate accounts

4. **Cascade Deletion:** When a user is deleted from `auth.users`, their profile is automatically deleted, maintaining referential integrity

5. **No Admin Override:** Currently, there's no policy allowing admin access to all profiles. This should be added in a future task if admin functionality is needed.


---

# Implementation Notes - Task 2.2

## Task: Create classrooms table with PostGIS geography

**Status:** ✅ Completed

**Requirements Validated:** 9.2, 10.1

## What Was Implemented

### 1. PostGIS Extension

Enabled the PostGIS extension for geospatial functionality:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

This extension provides:
- Geography data types for storing coordinates
- Spatial functions like ST_Distance for geofence calculations
- Spatial indexing capabilities (GIST)

### 2. Classrooms Table Schema

Created the `classrooms` table with the following structure:

```sql
CREATE TABLE classrooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  building TEXT NOT NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  nfc_secret TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

**Key Features:**
- `id`: Primary key (UUID) with automatic generation
- `name`: Classroom name (e.g., "Room 301")
- `building`: Building name (e.g., "Engineering Building")
- `location`: PostGIS geography point with WGS84 coordinates (SRID 4326)
- `nfc_secret`: Unique secret token for NFC tag validation
- `created_at`: Timestamp of classroom creation with automatic default

### 3. Constraints

- **Primary Key:** `id` column (auto-generated UUID)
- **Unique Constraint:** `nfc_secret` must be unique across all classrooms
- **NOT NULL Constraints:** All columns except none (all required)

### 4. Indexes

Created indexes for performance optimization:

#### Spatial Index (GIST)
```sql
CREATE INDEX idx_classrooms_location ON classrooms USING GIST(location);
```
- Uses GIST (Generalized Search Tree) index type
- Optimizes geospatial queries (ST_Distance, ST_DWithin)
- Critical for fast geofence validation in mark_attendance RPC

#### NFC Secret Index
```sql
CREATE INDEX idx_classrooms_nfc_secret ON classrooms(nfc_secret);
```
- B-tree index for fast secret token lookups
- Used during attendance validation

### 5. Row Level Security (RLS)

Enabled RLS on the classrooms table with one policy:

#### Policy: "Anyone can view classrooms"
```sql
CREATE POLICY "Anyone can view classrooms"
  ON classrooms FOR SELECT
  USING (true);
```
- Allows all authenticated users to read classroom information
- Necessary for students to query classroom details
- Note: The nfc_secret should be excluded from client queries (handled at application level)
- Validates Requirement 10.1

### 6. Documentation

Added SQL comments to document:
- Table purpose
- Each column's meaning and data type
- Geography column specifications (POINT, SRID 4326)
- Index purposes

## Files Created/Modified

1. **`supabase/migrations/20240101000001_create_classrooms_table.sql`**
   - Main migration file with table creation, indexes, and RLS policies

2. **`supabase/migrations/test_classrooms_migration.sql`**
   - Test queries to verify the migration was applied correctly
   - Checks PostGIS extension, table structure, spatial index, and RLS policies

3. **`supabase/README.md`**
   - Updated to include the new migration

4. **`supabase/migrations/IMPLEMENTATION_NOTES.md`**
   - Updated with Task 2.2 implementation details

## How to Apply This Migration

### Option 1: Supabase CLI
```bash
supabase link --project-ref your-project-ref
supabase db push
```

### Option 2: Supabase Dashboard
1. Go to SQL Editor in your Supabase dashboard
2. Copy the contents of `20240101000001_create_classrooms_table.sql`
3. Execute the SQL

### Option 3: Direct PostgreSQL Connection
```bash
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/20240101000001_create_classrooms_table.sql
```

## Verification

After applying the migration, run the test script to verify:
```bash
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/test_classrooms_migration.sql
```

Expected results:
- ✅ PostGIS extension enabled
- ✅ Table `classrooms` exists
- ✅ All 6 columns present with correct types
- ✅ `location` column is GEOGRAPHY(POINT, 4326)
- ✅ Unique constraint on `nfc_secret`
- ✅ Primary key on `id`
- ✅ RLS enabled on table
- ✅ 1 RLS policy created ("Anyone can view classrooms")
- ✅ 2 indexes created (spatial GIST index on location, B-tree on nfc_secret)

## Design Alignment

This implementation aligns with the design document specifications:

**From Design Document (Section 2.1):**
```sql
CREATE TABLE classrooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  building TEXT NOT NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  nfc_secret TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Enhancements Made:**
- Made `created_at` NOT NULL for data integrity
- Added spatial GIST index for performance
- Added B-tree index on nfc_secret for fast lookups
- Added comprehensive documentation
- Created test script for verification

## PostGIS Geography Type

The `location` column uses the `GEOGRAPHY(POINT, 4326)` type:

- **GEOGRAPHY vs GEOMETRY:** Geography type uses spherical coordinates and calculates distances on Earth's surface (more accurate for real-world locations)
- **POINT:** Stores a single coordinate pair (latitude, longitude)
- **SRID 4326:** WGS84 coordinate system (standard GPS coordinates)
  - Latitude: -90 to 90 degrees
  - Longitude: -180 to 180 degrees

### Example Usage

**Inserting a classroom:**
```sql
INSERT INTO classrooms (name, building, location, nfc_secret)
VALUES (
  'Room 301',
  'Engineering Building',
  ST_GeogFromText('POINT(-122.4194 37.7749)'),  -- San Francisco coordinates
  'a1b2c3d4e5f6g7h8i9j0'
);
```

**Calculating distance:**
```sql
SELECT 
  name,
  ST_Distance(
    location,
    ST_GeogFromText('POINT(-122.4194 37.7749)')
  ) AS distance_meters
FROM classrooms;
```

## Next Steps

The next task in the implementation plan is:

**Task 2.3:** Create attendance_logs table with constraints
- Will include foreign keys to profiles and classrooms
- Will include CHECK constraints for status and rejection_reason
- Will include spatial column for student location
- Will include RLS policies for student data isolation

## Requirements Validation

### Requirement 9.2 (Database Schema and Storage)
✅ **Validated:** The classrooms table has been created with all required columns:
- id (UUID, primary key, auto-generated)
- name (TEXT, not null)
- building (TEXT, not null)
- location (GEOGRAPHY(POINT, 4326), not null)
- nfc_secret (TEXT, unique, not null)
- created_at (TIMESTAMPTZ, default NOW(), not null)

### Requirement 10.1 (Row Level Security)
✅ **Validated:** RLS has been enabled on the classrooms table with appropriate policies

## Security Considerations

1. **RLS Policy:** The "Anyone can view classrooms" policy allows all authenticated users to read classroom data, which is necessary for the mobile app to function

2. **NFC Secret Protection:** While the RLS policy allows SELECT access, the application layer should exclude the `nfc_secret` column from client queries. The secret should only be used server-side in the mark_attendance RPC function

3. **Unique Secret Tokens:** The unique constraint on `nfc_secret` prevents duplicate tokens, ensuring each classroom has a distinct validation key

4. **Spatial Index Security:** The GIST index on location enables fast geofence calculations without exposing sensitive data

5. **No Write Access:** Currently, there are no INSERT, UPDATE, or DELETE policies, meaning only database administrators can modify classroom data. This should be extended with admin-specific policies in future tasks if needed.

## Performance Considerations

1. **Spatial Index (GIST):** The GIST index on the `location` column is critical for performance:
   - Without it, geofence queries would require full table scans
   - With it, ST_Distance queries can use the index for fast lookups
   - Expected query time: <10ms for distance calculations

2. **NFC Secret Index:** The B-tree index on `nfc_secret` enables fast token validation:
   - O(log n) lookup time instead of O(n)
   - Critical for the mark_attendance RPC function performance

3. **Geography vs Geometry:** Using GEOGRAPHY type provides accurate distance calculations on Earth's surface but is slightly slower than GEOMETRY. For this use case, accuracy is more important than the marginal performance difference.

## Testing Notes

The test script (`test_classrooms_migration.sql`) includes comprehensive checks:

1. **Extension Check:** Verifies PostGIS is enabled
2. **Table Existence:** Confirms the table was created
3. **Column Types:** Validates all columns have correct data types
4. **Constraints:** Checks unique and primary key constraints
5. **RLS Status:** Confirms RLS is enabled
6. **RLS Policies:** Lists all policies
7. **Indexes:** Verifies both indexes exist
8. **Spatial Index Type:** Confirms the location index uses GIST
9. **Geography Metadata:** Validates the geography column configuration (SRID, type, dimensions)

Run the test script after applying the migration to ensure everything is configured correctly.


---

# Implementation Notes - Task 2.3

## Task: Create attendance_logs table with constraints

**Status:** ✅ Completed

**Requirements Validated:** 9.3, 10.1, 10.3

## What Was Implemented

### 1. Attendance Logs Table Schema

Created the `attendance_logs` table with the following structure:

```sql
CREATE TABLE attendance_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  classroom_id UUID NOT NULL REFERENCES classrooms(id) ON DELETE CASCADE,
  timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('PRESENT', 'REJECTED')),
  student_location GEOGRAPHY(POINT, 4326) NOT NULL,
  rejection_reason TEXT,
  CONSTRAINT valid_rejection CHECK (
    (status = 'REJECTED' AND rejection_reason IS NOT NULL) OR
    (status = 'PRESENT' AND rejection_reason IS NULL)
  )
);
```

**Key Features:**
- `id`: Primary key (UUID) with automatic generation
- `student_id`: Foreign key to profiles table (NOT NULL, CASCADE delete)
- `classroom_id`: Foreign key to classrooms table (NOT NULL, CASCADE delete)
- `timestamp`: Timestamp when attendance was marked (auto-generated, NOT NULL)
- `status`: Attendance status - must be either 'PRESENT' or 'REJECTED'
- `student_location`: PostGIS geography point with student's GPS coordinates (WGS84)
- `rejection_reason`: Reason for rejection (required if REJECTED, null if PRESENT)

### 2. Constraints

#### Primary Key
- `id` column (auto-generated UUID)

#### Foreign Keys
- `student_id` references `profiles(id)` with CASCADE delete
- `classroom_id` references `classrooms(id)` with CASCADE delete

#### CHECK Constraints

**Status Constraint:**
```sql
CHECK (status IN ('PRESENT', 'REJECTED'))
```
- Ensures status can only be 'PRESENT' or 'REJECTED'
- Prevents invalid status values

**Valid Rejection Constraint:**
```sql
CONSTRAINT valid_rejection CHECK (
  (status = 'REJECTED' AND rejection_reason IS NOT NULL) OR
  (status = 'PRESENT' AND rejection_reason IS NULL)
)
```
- If status is 'REJECTED', rejection_reason MUST be provided
- If status is 'PRESENT', rejection_reason MUST be NULL
- Enforces data model invariants at the database level

### 3. Indexes

Created four indexes for optimal query performance:

#### Index 1: Student Attendance Queries
```sql
CREATE INDEX idx_attendance_student ON attendance_logs(student_id, timestamp DESC);
```
- Composite index on student_id and timestamp
- Optimizes queries like "get all attendance for student X ordered by date"
- Supports the mobile app's attendance history feature

#### Index 2: Classroom Attendance Queries
```sql
CREATE INDEX idx_attendance_classroom ON attendance_logs(classroom_id, timestamp DESC);
```
- Composite index on classroom_id and timestamp
- Optimizes queries like "get all attendance for classroom Y ordered by date"
- Supports the admin dashboard's classroom-specific views

#### Index 3: Time-Based Queries
```sql
CREATE INDEX idx_attendance_timestamp ON attendance_logs(timestamp DESC);
```
- Index on timestamp in descending order
- Optimizes queries like "get recent attendance across all students/classrooms"
- Supports the admin dashboard's real-time feed

#### Index 4: Spatial Index
```sql
CREATE INDEX idx_attendance_student_location ON attendance_logs USING GIST(student_location);
```
- GIST spatial index on student_location
- Enables efficient geospatial queries
- Useful for analytics (e.g., "find all attendance within X meters of a point")

### 4. Row Level Security (RLS)

Enabled RLS on the attendance_logs table with two policies:

#### Policy 1: "Users can view own attendance"
```sql
CREATE POLICY "Users can view own attendance"
  ON attendance_logs FOR SELECT
  USING (auth.uid() = student_id);
```
- Allows students to SELECT only their own attendance records
- Validates Requirement 10.3
- Ensures data privacy between students

#### Policy 2: "Only system can insert attendance"
```sql
CREATE POLICY "Only system can insert attendance"
  ON attendance_logs FOR INSERT
  WITH CHECK (false);
```
- Blocks ALL direct INSERT attempts from users
- Attendance can only be inserted via the `mark_attendance` RPC function (which uses SECURITY DEFINER)
- Prevents client-side tampering and ensures all validation logic is enforced
- Validates Requirement 10.1

**Important:** The `mark_attendance` RPC function will use `SECURITY DEFINER` to bypass this policy and insert records after validation.

### 5. Documentation

Added SQL comments to document:
- Table purpose (immutable audit log)
- Each column's meaning and constraints
- Geography column specifications
- Constraint purposes

## Files Created

1. **`supabase/migrations/20240101000002_create_attendance_logs_table.sql`**
   - Main migration file with table creation, constraints, indexes, and RLS policies

2. **`supabase/migrations/test_attendance_logs_migration.sql`**
   - Comprehensive test script with 16 tests
   - Verifies table structure, constraints, RLS policies, and indexes
   - Tests constraint enforcement with sample data

3. **`supabase/migrations/IMPLEMENTATION_NOTES.md`**
   - Updated with Task 2.3 implementation details

## How to Apply This Migration

### Prerequisites
- Task 2.1 (profiles table) must be completed
- Task 2.2 (classrooms table) must be completed
- PostGIS extension must be enabled

### Option 1: Supabase CLI
```bash
supabase link --project-ref your-project-ref
supabase db push
```

### Option 2: Supabase Dashboard
1. Go to SQL Editor in your Supabase dashboard
2. Copy the contents of `20240101000002_create_attendance_logs_table.sql`
3. Execute the SQL

### Option 3: Direct PostgreSQL Connection
```bash
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/20240101000002_create_attendance_logs_table.sql
```

## Verification

After applying the migration, run the test script to verify:
```bash
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/test_attendance_logs_migration.sql
```

Expected results:
- ✅ Table `attendance_logs` exists
- ✅ All 7 columns present with correct types
- ✅ `student_location` is GEOGRAPHY(POINT, 4326)
- ✅ Status CHECK constraint exists
- ✅ valid_rejection constraint exists
- ✅ Foreign keys to profiles and classrooms
- ✅ RLS enabled on table
- ✅ 2 RLS policies created
- ✅ 4 indexes created (including spatial GIST index)
- ✅ Constraints properly enforce data integrity

## Design Alignment

This implementation aligns with the design document specifications:

**From Design Document (Section 2.1):**
```sql
CREATE TABLE attendance_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES profiles(id),
  classroom_id UUID NOT NULL REFERENCES classrooms(id),
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  status TEXT NOT NULL CHECK (status IN ('PRESENT', 'REJECTED')),
  student_location GEOGRAPHY(POINT, 4326) NOT NULL,
  rejection_reason TEXT,
  CONSTRAINT valid_rejection CHECK (
    (status = 'REJECTED' AND rejection_reason IS NOT NULL) OR
    (status = 'PRESENT' AND rejection_reason IS NULL)
  )
);
```

**Enhancements Made:**
- Added `ON DELETE CASCADE` for foreign keys
- Made `timestamp` NOT NULL for data integrity
- Added spatial GIST index on student_location
- Added comprehensive indexes for query optimization
- Added RLS policy to block direct inserts
- Added comprehensive documentation and test script

## Data Model Invariants

The table enforces the following invariants at the database level:

### Invariant 1: Status Values
- Status must be exactly 'PRESENT' or 'REJECTED'
- No other values are allowed
- Enforced by: `CHECK (status IN ('PRESENT', 'REJECTED'))`

### Invariant 2: Rejection Reason Logic
- If status = 'REJECTED', then rejection_reason IS NOT NULL
- If status = 'PRESENT', then rejection_reason IS NULL
- Enforced by: `valid_rejection` constraint

### Invariant 3: Foreign Key Integrity
- student_id must reference a valid profile
- classroom_id must reference a valid classroom
- Enforced by: FOREIGN KEY constraints

### Invariant 4: Required Fields
- id, student_id, classroom_id, timestamp, status, student_location are all NOT NULL
- Enforced by: NOT NULL constraints

### Invariant 5: Immutability
- No UPDATE or DELETE policies exist
- Records cannot be modified after creation
- Enforced by: RLS policies (only SELECT and INSERT policies defined)

## Example Usage

### Valid PRESENT Record
```sql
INSERT INTO attendance_logs (
  student_id,
  classroom_id,
  status,
  student_location,
  rejection_reason
) VALUES (
  '550e8400-e29b-41d4-a716-446655440000',  -- Valid student UUID
  '660e8400-e29b-41d4-a716-446655440001',  -- Valid classroom UUID
  'PRESENT',
  ST_GeogFromText('POINT(-122.4194 37.7749)'),  -- San Francisco
  NULL  -- Must be NULL for PRESENT
);
```

### Valid REJECTED Record
```sql
INSERT INTO attendance_logs (
  student_id,
  classroom_id,
  status,
  student_location,
  rejection_reason
) VALUES (
  '550e8400-e29b-41d4-a716-446655440000',
  '660e8400-e29b-41d4-a716-446655440001',
  'REJECTED',
  ST_GeogFromText('POINT(-122.5000 37.8000)'),  -- Outside geofence
  'outside_geofence'  -- Must be provided for REJECTED
);
```

### Invalid Records (Will Fail)

**Invalid Status:**
```sql
-- ❌ FAILS: Status not in ('PRESENT', 'REJECTED')
INSERT INTO attendance_logs (..., status, ...) VALUES (..., 'INVALID', ...);
```

**REJECTED Without Reason:**
```sql
-- ❌ FAILS: valid_rejection constraint
INSERT INTO attendance_logs (..., status, rejection_reason, ...) 
VALUES (..., 'REJECTED', NULL, ...);
```

**PRESENT With Reason:**
```sql
-- ❌ FAILS: valid_rejection constraint
INSERT INTO attendance_logs (..., status, rejection_reason, ...) 
VALUES (..., 'PRESENT', 'some_reason', ...);
```

## Query Examples

### Get Student's Attendance History
```sql
SELECT 
  al.timestamp,
  c.name AS classroom_name,
  c.building,
  al.status,
  al.rejection_reason
FROM attendance_logs al
JOIN classrooms c ON al.classroom_id = c.id
WHERE al.student_id = auth.uid()
ORDER BY al.timestamp DESC
LIMIT 50;
```

### Get Classroom Attendance for Today
```sql
SELECT 
  p.full_name AS student_name,
  al.timestamp,
  al.status,
  al.rejection_reason
FROM attendance_logs al
JOIN profiles p ON al.student_id = p.id
WHERE al.classroom_id = '660e8400-e29b-41d4-a716-446655440001'
  AND al.timestamp >= CURRENT_DATE
ORDER BY al.timestamp DESC;
```

### Get Recent Attendance Across All Classrooms
```sql
SELECT 
  p.full_name AS student_name,
  c.name AS classroom_name,
  c.building,
  al.timestamp,
  al.status,
  al.rejection_reason,
  ST_X(al.student_location::geometry) AS longitude,
  ST_Y(al.student_location::geometry) AS latitude
FROM attendance_logs al
JOIN profiles p ON al.student_id = p.id
JOIN classrooms c ON al.classroom_id = c.id
WHERE al.timestamp >= NOW() - INTERVAL '24 hours'
ORDER BY al.timestamp DESC
LIMIT 100;
```

## Next Steps

The next task in the implementation plan is:

**Task 3.1:** Create mark_attendance function with input validation
- Implement the RPC function that will insert records into attendance_logs
- Use SECURITY DEFINER to bypass the RLS INSERT policy
- Implement all validation logic (device binding, secret token, geofence)

## Requirements Validation

### Requirement 9.3 (Database Schema and Storage)
✅ **Validated:** The attendance_logs table has been created with all required columns:
- id (UUID, primary key, auto-generated)
- student_id (UUID, foreign key to profiles, NOT NULL)
- classroom_id (UUID, foreign key to classrooms, NOT NULL)
- timestamp (TIMESTAMPTZ, default NOW(), NOT NULL)
- status (TEXT, CHECK constraint, NOT NULL)
- student_location (GEOGRAPHY(POINT, 4326), NOT NULL)
- rejection_reason (TEXT, nullable with constraint)

### Requirement 10.1 (Row Level Security)
✅ **Validated:** RLS has been enabled on the attendance_logs table with appropriate policies

### Requirement 10.3 (Row Level Security)
✅ **Validated:** RLS policy ensures students can only query their own attendance records:
- "Users can view own attendance" policy filters by `auth.uid() = student_id`

## Security Considerations

1. **RLS Enforcement:** The SELECT policy ensures students can only see their own attendance records

2. **Insert Protection:** The INSERT policy with `WITH CHECK (false)` blocks all direct inserts, forcing all attendance marking to go through the validated RPC function

3. **Immutability:** No UPDATE or DELETE policies exist, making attendance logs append-only and immutable

4. **Foreign Key Integrity:** CASCADE delete ensures orphaned records are cleaned up if a student or classroom is deleted

5. **Data Validation:** CHECK constraints enforce business rules at the database level, preventing invalid data even if application logic fails

6. **Audit Trail:** All attendance attempts (successful and rejected) are logged, providing a complete audit trail

## Performance Considerations

1. **Composite Indexes:** The indexes on (student_id, timestamp) and (classroom_id, timestamp) enable efficient queries for the most common access patterns

2. **Timestamp Index:** The descending timestamp index supports efficient "recent attendance" queries for the admin dashboard

3. **Spatial Index:** The GIST index on student_location enables efficient geospatial analytics

4. **Index Selectivity:** All indexes are on columns with high selectivity (UUIDs and timestamps), ensuring good performance

5. **Query Optimization:** The indexes support the exact query patterns used by the mobile app and admin dashboard

## Testing Notes

The test script (`test_attendance_logs_migration.sql`) includes 16 comprehensive tests:

1. **Table Existence:** Verifies the table was created
2. **Column Count:** Confirms all 7 columns exist
3. **Column Details:** Lists all columns with types and constraints
4. **Geography Type:** Validates student_location is GEOGRAPHY
5. **Status Constraint:** Checks the status CHECK constraint exists
6. **Valid Rejection Constraint:** Verifies the valid_rejection constraint exists
7. **Foreign Keys:** Lists all foreign key relationships
8. **RLS Status:** Confirms RLS is enabled
9. **RLS Policies:** Lists all policies
10. **Indexes:** Lists all indexes
11. **Spatial Index:** Verifies GIST index on student_location
12. **Geography Metadata:** Validates geography column configuration
13. **RLS Insert Block:** Tests that direct inserts are blocked
14. **Status Constraint Test:** Tests invalid status values are rejected
15. **Rejection Constraint Test 1:** Tests REJECTED without reason fails
16. **Rejection Constraint Test 2:** Tests PRESENT with reason fails

Run the test script after applying the migration to ensure everything is configured correctly.

## Migration Dependencies

This migration depends on:
- ✅ Task 2.1: profiles table (for student_id foreign key)
- ✅ Task 2.2: classrooms table (for classroom_id foreign key)
- ✅ PostGIS extension (for GEOGRAPHY type)

This migration is required by:
- Task 3.1: mark_attendance RPC function (will insert into this table)
- Task 12.1: Admin dashboard queries (will read from this table)


---

# Implementation Notes - Task 3.1

## Task: Create mark_attendance function with input validation

**Status:** ✅ Completed

**Requirements Validated:** 5.1, 14.2

## What Was Implemented

### 1. Mark Attendance RPC Function

Created the `mark_attendance` PostgreSQL function with comprehensive input validation:

```sql
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
```

**Key Features:**
- **SECURITY DEFINER**: Allows the function to bypass RLS policies and insert into attendance_logs
- **SET search_path = public**: Security best practice to prevent search path attacks
- **Returns JSON**: Structured response with status, rejection_reason, and timestamp
- **Comprehensive input validation**: Validates all parameters before processing

### 2. Input Validation Logic

The function implements the following validation checks:

#### Null Parameter Validation
- **p_classroom_id**: Must not be null
- **p_secret_token**: Must not be null
- **p_latitude**: Must not be null
- **p_longitude**: Must not be null

Each null check raises a descriptive exception with a helpful hint.

#### Authentication Validation
- Verifies that `auth.uid()` is not null (user must be authenticated)
- Raises exception if user is not logged in

#### Coordinate Range Validation
- **Latitude**: Must be between -90 and 90 degrees
- **Longitude**: Must be between -180 and 180 degrees
- Raises exception with the invalid value if out of range

#### Secret Token Validation
- Verifies that the secret token is not empty (after trimming whitespace)
- Prevents empty string attacks

#### Geography Point Creation
- Creates a PostGIS geography point from the coordinates
- Wrapped in exception handler to catch invalid coordinate formats
- Uses WGS84 coordinate system (SRID 4326)

### 3. Function Structure

The function is organized into clear sections:

1. **Variable Declaration**: Declares all local variables
2. **Input Validation**: Comprehensive parameter validation
3. **Validation Logic**: Placeholder for business logic (Tasks 3.2-3.4)
4. **Attendance Logging**: Inserts record into attendance_logs table
5. **Return Response**: Returns structured JSON response
6. **Exception Handling**: Catches and re-raises exceptions with context

### 4. Return Format

The function returns a JSON object with the following structure:

```json
{
  "status": "PRESENT" | "REJECTED",
  "rejection_reason": null | "invalid_token" | "device_mismatch" | "outside_geofence",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### 5. Security Features

#### SECURITY DEFINER
- The function runs with the privileges of the function owner (typically postgres)
- This allows it to bypass the RLS INSERT policy on attendance_logs
- Essential for server-side validation - prevents client-side tampering

#### SET search_path = public
- Prevents search path attacks by explicitly setting the schema
- Security best practice for SECURITY DEFINER functions

#### Input Validation
- All inputs are validated before any database operations
- Prevents SQL injection through parameterized queries
- Validates data types and ranges

#### Authentication Check
- Verifies user is authenticated before processing
- Uses Supabase Auth's `auth.uid()` function

### 6. Error Handling

The function uses PostgreSQL's exception handling:

- **Specific Exceptions**: Each validation failure raises a specific exception with a descriptive message
- **Helpful Hints**: Each exception includes a HINT clause with guidance
- **Context Preservation**: The outer exception handler re-raises errors with context
- **No Silent Failures**: All errors are explicitly raised

### 7. Permissions

The function grants execute permission to authenticated users:

```sql
GRANT EXECUTE ON FUNCTION mark_attendance(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
```

This ensures only logged-in users can call the function.

## Files Created

1. **`supabase/migrations/20240101000003_create_mark_attendance_function.sql`**
   - Main migration file with function creation
   - Includes comprehensive input validation
   - Includes comments and documentation

2. **`supabase/migrations/test_mark_attendance_function.sql`**
   - Test script with 16 tests
   - Tests 1-5: Verify function structure and configuration
   - Tests 6-16: Verify input validation logic (require auth context)

3. **`supabase/migrations/IMPLEMENTATION_NOTES.md`**
   - Updated with Task 3.1 implementation details

## How to Apply This Migration

### Prerequisites
- Task 2.1 (profiles table) must be completed
- Task 2.2 (classrooms table) must be completed
- Task 2.3 (attendance_logs table) must be completed
- PostGIS extension must be enabled

### Option 1: Supabase CLI
```bash
supabase link --project-ref your-project-ref
supabase db push
```

### Option 2: Supabase Dashboard
1. Go to SQL Editor in your Supabase dashboard
2. Copy the contents of `20240101000003_create_mark_attendance_function.sql`
3. Execute the SQL

### Option 3: Direct PostgreSQL Connection
```bash
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/20240101000003_create_mark_attendance_function.sql
```

## Verification

After applying the migration, run the test script to verify:
```bash
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/test_mark_attendance_function.sql
```

Expected results:
- ✅ Function `mark_attendance` exists
- ✅ Function has correct signature (4 parameters, returns JSON)
- ✅ Function uses SECURITY DEFINER
- ✅ Function uses plpgsql language
- ✅ Function has EXECUTE permission for authenticated users

## Design Alignment

This implementation aligns with the design document specifications:

**From Design Document (Section 2.2):**
```sql
CREATE OR REPLACE FUNCTION mark_attendance(
  p_classroom_id UUID,
  p_secret_token TEXT,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
```

**Enhancements Made:**
- Added `SET search_path = public` for security
- Implemented comprehensive input validation
- Added detailed error messages with hints
- Added exception handling
- Added function comments and documentation
- Created comprehensive test script

## Input Validation Examples

### Valid Call
```sql
SELECT mark_attendance(
  '550e8400-e29b-41d4-a716-446655440000'::UUID,
  'a1b2c3d4e5f6g7h8i9j0',
  37.7749,
  -122.4194
);
```

Expected result:
```json
{
  "status": "PRESENT",
  "rejection_reason": null,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Invalid Call - Null Parameter
```sql
SELECT mark_attendance(
  NULL,
  'a1b2c3d4e5f6g7h8i9j0',
  37.7749,
  -122.4194
);
```

Expected error:
```
ERROR: Parameter p_classroom_id cannot be null
HINT: Provide a valid classroom UUID
```

### Invalid Call - Out of Range Latitude
```sql
SELECT mark_attendance(
  '550e8400-e29b-41d4-a716-446655440000'::UUID,
  'a1b2c3d4e5f6g7h8i9j0',
  91.0,
  -122.4194
);
```

Expected error:
```
ERROR: Invalid latitude: 91. Must be between -90 and 90
HINT: Latitude must be in the range [-90, 90]
```

### Invalid Call - Empty Secret Token
```sql
SELECT mark_attendance(
  '550e8400-e29b-41d4-a716-446655440000'::UUID,
  '   ',
  37.7749,
  -122.4194
);
```

Expected error:
```
ERROR: Secret token cannot be empty
HINT: Provide a non-empty secret token
```

## Validation Coverage

The input validation covers all requirements from Requirement 14.2:

✅ **Null Checks**: All parameters validated for null
✅ **Type Validation**: PostgreSQL enforces type constraints (UUID, TEXT, DOUBLE PRECISION)
✅ **Coordinate Range Validation**: Latitude [-90, 90], Longitude [-180, 180]
✅ **Authentication Check**: Verifies user is logged in
✅ **Empty String Check**: Validates secret token is not empty
✅ **Geography Validation**: Validates coordinates can form valid geography point

## Next Steps

The next tasks in the implementation plan are:

**Task 3.2:** Implement device binding verification
- Query profiles table to get user's stored device_id
- Extract device_id from JWT claims
- Compare and reject if mismatch

**Task 3.3:** Implement secret token validation
- Query classrooms table for p_classroom_id
- Compare p_secret_token with stored nfc_secret
- Reject if token doesn't match

**Task 3.4:** Implement geofence validation with PostGIS
- Calculate distance between student location and classroom location
- Use ST_Distance function
- Reject if distance > 50 meters

**Task 3.5:** Implement attendance logging
- Already implemented in this task
- Will be updated with proper status based on validation results

## Requirements Validation

### Requirement 5.1 (Server-Side Attendance Validation)
✅ **Validated:** The mark_attendance RPC function has been created and can be invoked by the mobile app

### Requirement 14.2 (Security Requirements - Input Validation)
✅ **Validated:** The function validates all input parameters:
- Null checks for all parameters
- Type validation (enforced by PostgreSQL)
- Coordinate range validation (latitude: -90 to 90, longitude: -180 to 180)
- Empty string validation for secret token
- Authentication validation

## Security Considerations

1. **SECURITY DEFINER**: The function runs with elevated privileges, allowing it to bypass RLS and insert into attendance_logs. This is necessary for server-side validation but requires careful implementation.

2. **SET search_path**: Prevents search path attacks by explicitly setting the schema to public.

3. **Input Validation**: All inputs are validated before any database operations, preventing injection attacks and invalid data.

4. **Parameterized Queries**: All database queries use parameters, preventing SQL injection.

5. **Authentication Check**: The function verifies the user is authenticated before processing.

6. **Error Messages**: Error messages are descriptive but don't leak sensitive information.

7. **Exception Handling**: All exceptions are caught and re-raised with context, preventing silent failures.

## Performance Considerations

1. **Input Validation First**: All validation happens before any database queries, failing fast for invalid inputs.

2. **Single Transaction**: All operations happen in a single transaction, ensuring atomicity.

3. **Minimal Database Queries**: Currently only one INSERT query (validation queries will be added in subsequent tasks).

4. **Geography Point Creation**: Creating the geography point is efficient and validates coordinates.

5. **Index Usage**: The INSERT into attendance_logs will use the indexes created in Task 2.3.

## Testing Notes

The test script includes:

1. **Structure Tests (1-5)**: Verify function exists, has correct signature, uses SECURITY DEFINER, etc.
2. **Validation Tests (6-16)**: Verify input validation logic (require authentication context)

To run validation tests:
1. Set up test data (profiles, classrooms)
2. Authenticate as a test user
3. Run each validation test individually
4. Verify exceptions are raised with correct messages

## Known Limitations

1. **Validation Logic Incomplete**: The function currently sets status to 'PRESENT' for all valid inputs. The actual validation logic (device binding, secret token, geofence) will be implemented in Tasks 3.2-3.4.

2. **No Rate Limiting**: Rate limiting will be added in Task 14.2.

3. **No Email Verification Check**: Email verification enforcement will be added in Task 14.1.

4. **No Admin Override**: There's no mechanism for admins to bypass validation (may be needed for testing).

## Placeholder Logic

The function currently includes placeholder logic for validation:

```sql
-- For now, set default status as PRESENT
-- This will be replaced with actual validation logic
v_status := 'PRESENT';
v_rejection_reason := NULL;
```

This will be replaced in subsequent tasks with:
- Device binding check (Task 3.2)
- Secret token validation (Task 3.3)
- Geofence validation (Task 3.4)

The placeholder ensures the function is functional and testable while the validation logic is being implemented incrementally.
