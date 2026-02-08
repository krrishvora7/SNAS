-- Migration: Create profiles table with RLS policies
-- Task: 2.1 Create profiles table with RLS policies
-- Validates Requirements: 9.1, 10.1, 10.2

-- Create profiles table
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  device_id TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create index on email for faster lookups
CREATE INDEX idx_profiles_email ON profiles(email);

-- Create index on device_id for faster lookups
CREATE INDEX idx_profiles_device_id ON profiles(device_id);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own profile
CREATE POLICY "Users can view own profile"
  ON profiles
  FOR SELECT
  USING (auth.uid() = id);

-- RLS Policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = id);

-- RLS Policy: Users can insert their own profile (for initial profile creation)
CREATE POLICY "Users can insert own profile"
  ON profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Add comment to table
COMMENT ON TABLE profiles IS 'User profiles with device binding for attendance system';
COMMENT ON COLUMN profiles.id IS 'References auth.users(id)';
COMMENT ON COLUMN profiles.email IS 'University email address (unique)';
COMMENT ON COLUMN profiles.full_name IS 'Student full name';
COMMENT ON COLUMN profiles.device_id IS 'Bound device identifier (unique, nullable)';
COMMENT ON COLUMN profiles.created_at IS 'Profile creation timestamp';
