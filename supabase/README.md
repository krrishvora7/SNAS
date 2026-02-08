# Supabase Migrations

This directory contains SQL migration files for the Smart NFC Attendance System (SNAS) database schema.

## Directory Structure

```
supabase/
├── migrations/          # SQL migration files
│   └── *.sql           # Timestamped migration files
└── README.md           # This file
```

## Migration Files

Migrations are numbered sequentially with timestamps in the format: `YYYYMMDDHHMMSS_description.sql`

### Current Migrations

1. `20240101000000_create_profiles_table.sql` - Creates the profiles table with RLS policies
2. `20240101000001_create_classrooms_table.sql` - Creates the classrooms table with PostGIS geography and spatial indexing
3. `20240101000002_create_attendance_logs_table.sql` - Creates the attendance_logs table with constraints, indexes, and RLS policies

## Applying Migrations

### Using Supabase CLI

If you have the Supabase CLI installed:

```bash
# Link to your Supabase project
supabase link --project-ref your-project-ref

# Apply all pending migrations
supabase db push
```

### Using Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to the SQL Editor
3. Copy and paste the contents of each migration file
4. Execute the SQL in order (by timestamp)

### Manual Application

You can also apply migrations manually using any PostgreSQL client:

```bash
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/20240101000000_create_profiles_table.sql
```

## Migration Guidelines

- Each migration file should be idempotent when possible
- Use descriptive names for migration files
- Include comments explaining the purpose of each migration
- Reference the task number and requirements being validated
- Test migrations on a development database before applying to production

## Requirements Validation

Each migration file includes comments indicating which requirements it validates. See the main requirements document at `.kiro/specs/smart-nfc-attendance-system/requirements.md` for details.
