-- Migration: Create attendance_logs table with constraints
-- Task: 2.3 Create attendance_logs table with constraints
-- Validates Requirements: 9.3, 10.1, 10.3

-- Create attendance_logs table
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

-- Create index on student_id and timestamp for efficient student attendance queries
CREATE INDEX idx_attendance_student ON attendance_logs(student_id, timestamp DESC);

-- Create index on classroom_id and timestamp for efficient classroom attendance queries
CREATE INDEX idx_attendance_classroom ON attendance_logs(classroom_id, timestamp DESC);

-- Create index on timestamp for efficient time-based queries
CREATE INDEX idx_attendance_timestamp ON attendance_logs(timestamp DESC);

-- Create spatial index on student_location for geospatial queries
CREATE INDEX idx_attendance_student_location ON attendance_logs USING GIST(student_location);

-- Enable Row Level Security
ALTER TABLE attendance_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own attendance logs
CREATE POLICY "Users can view own attendance"
  ON attendance_logs
  FOR SELECT
  USING (auth.uid() = student_id);

-- RLS Policy: Only system can insert attendance (via RPC function with SECURITY DEFINER)
-- This policy blocks all direct INSERT attempts from users
CREATE POLICY "Only system can insert attendance"
  ON attendance_logs
  FOR INSERT
  WITH CHECK (false);

-- Add comments to table and columns
COMMENT ON TABLE attendance_logs IS 'Immutable log of all attendance marking attempts (successful and rejected)';
COMMENT ON COLUMN attendance_logs.id IS 'Unique attendance log identifier (UUID)';
COMMENT ON COLUMN attendance_logs.student_id IS 'References profiles.id - the student marking attendance';
COMMENT ON COLUMN attendance_logs.classroom_id IS 'References classrooms.id - the classroom being checked into';
COMMENT ON COLUMN attendance_logs.timestamp IS 'Timestamp when attendance was marked';
COMMENT ON COLUMN attendance_logs.status IS 'Attendance status: PRESENT (accepted) or REJECTED (validation failed)';
COMMENT ON COLUMN attendance_logs.student_location IS 'Student GPS location at time of attendance marking (PostGIS POINT)';
COMMENT ON COLUMN attendance_logs.rejection_reason IS 'Reason for rejection (required if status=REJECTED, null if status=PRESENT)';
COMMENT ON CONSTRAINT valid_rejection ON attendance_logs IS 'Ensures rejection_reason is provided for REJECTED status and null for PRESENT status';
