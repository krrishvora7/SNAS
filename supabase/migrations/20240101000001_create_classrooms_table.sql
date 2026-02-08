-- Migration: Create classrooms table with PostGIS geography
-- Task: 2.2 Create classrooms table with PostGIS geography
-- Validates Requirements: 9.2, 10.1

-- Enable PostGIS extension if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create classrooms table
CREATE TABLE classrooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  building TEXT NOT NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  nfc_secret TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create spatial index on location column for efficient geospatial queries
CREATE INDEX idx_classrooms_location ON classrooms USING GIST(location);

-- Create index on nfc_secret for faster validation lookups
CREATE INDEX idx_classrooms_nfc_secret ON classrooms(nfc_secret);

-- Enable Row Level Security
ALTER TABLE classrooms ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Anyone can view classrooms (but not the nfc_secret in queries)
CREATE POLICY "Anyone can view classrooms"
  ON classrooms
  FOR SELECT
  USING (true);

-- Add comments to table and columns
COMMENT ON TABLE classrooms IS 'Classroom locations with NFC secrets for attendance validation';
COMMENT ON COLUMN classrooms.id IS 'Unique classroom identifier (UUID)';
COMMENT ON COLUMN classrooms.name IS 'Classroom name (e.g., "Room 301")';
COMMENT ON COLUMN classrooms.building IS 'Building name (e.g., "Engineering Building")';
COMMENT ON COLUMN classrooms.location IS 'Geographic location (PostGIS POINT with WGS84 coordinates)';
COMMENT ON COLUMN classrooms.nfc_secret IS 'Secret token for NFC tag validation (unique)';
COMMENT ON COLUMN classrooms.created_at IS 'Classroom record creation timestamp';
