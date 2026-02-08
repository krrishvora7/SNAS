-- Migration: Create token rotation support for NFC secret tokens
-- Task: 14.3 Add NFC secret token rotation support
-- Validates Requirements: 11.5

-- Create table to log token rotation events
CREATE TABLE IF NOT EXISTS token_rotation_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  classroom_id UUID NOT NULL REFERENCES classrooms(id) ON DELETE CASCADE,
  old_secret TEXT NOT NULL,
  new_secret TEXT NOT NULL,
  rotated_by UUID REFERENCES auth.users(id),
  rotated_at TIMESTAMPTZ DEFAULT NOW(),
  reason TEXT
);

-- Create index on classroom_id for faster lookups
CREATE INDEX idx_token_rotation_classroom ON token_rotation_logs(classroom_id, rotated_at DESC);

-- Add comment
COMMENT ON TABLE token_rotation_logs IS 
'Audit log for NFC secret token rotation events. Tracks when tokens are changed and by whom.';

-- Enable RLS on token_rotation_logs
ALTER TABLE token_rotation_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can view token rotation logs
CREATE POLICY "Admins can view token rotation logs"
  ON token_rotation_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND (auth.users.raw_app_meta_data->>'role' = 'admin' OR auth.users.raw_user_meta_data->>'role' = 'admin')
    )
  );

-- Create function to rotate NFC secret token
-- This function updates the classroom's nfc_secret and logs the rotation
CREATE OR REPLACE FUNCTION rotate_nfc_secret(
  p_classroom_id UUID,
  p_new_secret TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER  -- Run with elevated privileges
SET search_path = public
AS $
DECLARE
  v_old_secret TEXT;
  v_admin_id UUID;
  v_rotation_timestamp TIMESTAMPTZ;
BEGIN
  -- Get the authenticated user's ID
  v_admin_id := auth.uid();
  v_rotation_timestamp := NOW();
  
  -- ============================================
  -- AUTHORIZATION CHECK
  -- ============================================
  
  -- Verify user is authenticated
  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated'
      USING HINT = 'Please log in before rotating tokens';
  END IF;
  
  -- Verify user has admin role
  -- Check both app_metadata and user_metadata for role
  IF NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = v_admin_id
    AND (
      raw_app_meta_data->>'role' = 'admin' OR 
      raw_user_meta_data->>'role' = 'admin'
    )
  ) THEN
    RAISE EXCEPTION 'Insufficient permissions'
      USING HINT = 'Only administrators can rotate NFC secret tokens';
  END IF;
  
  -- ============================================
  -- INPUT VALIDATION
  -- ============================================
  
  -- Validate: classroom_id must be provided
  IF p_classroom_id IS NULL THEN
    RAISE EXCEPTION 'Parameter p_classroom_id cannot be null'
      USING HINT = 'Provide a valid classroom UUID';
  END IF;
  
  -- Validate: new_secret must be provided and not empty
  IF p_new_secret IS NULL OR LENGTH(TRIM(p_new_secret)) = 0 THEN
    RAISE EXCEPTION 'Parameter p_new_secret cannot be null or empty'
      USING HINT = 'Provide a valid non-empty secret token';
  END IF;
  
  -- Validate: new_secret must be unique (not used by any other classroom)
  IF EXISTS (
    SELECT 1 FROM classrooms
    WHERE nfc_secret = p_new_secret
    AND id != p_classroom_id
  ) THEN
    RAISE EXCEPTION 'Secret token already in use by another classroom'
      USING HINT = 'Generate a unique secret token';
  END IF;
  
  -- ============================================
  -- TOKEN ROTATION
  -- ============================================
  
  -- Get the current secret token
  SELECT nfc_secret INTO v_old_secret
  FROM classrooms
  WHERE id = p_classroom_id;
  
  -- Check if classroom exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Classroom not found: %', p_classroom_id
      USING HINT = 'Provide a valid classroom UUID';
  END IF;
  
  -- Check if the new secret is the same as the old one
  IF v_old_secret = p_new_secret THEN
    RAISE EXCEPTION 'New secret must be different from current secret'
      USING HINT = 'Provide a different secret token';
  END IF;
  
  -- Update the classroom's nfc_secret
  -- This immediately invalidates the old token
  UPDATE classrooms
  SET nfc_secret = p_new_secret
  WHERE id = p_classroom_id;
  
  -- Log the rotation event
  INSERT INTO token_rotation_logs (
    classroom_id,
    old_secret,
    new_secret,
    rotated_by,
    rotated_at,
    reason
  ) VALUES (
    p_classroom_id,
    v_old_secret,
    p_new_secret,
    v_admin_id,
    v_rotation_timestamp,
    p_reason
  );
  
  -- ============================================
  -- RETURN RESPONSE
  -- ============================================
  
  -- Return success response
  RETURN json_build_object(
    'success', true,
    'classroom_id', p_classroom_id,
    'rotated_at', v_rotation_timestamp,
    'message', 'NFC secret token rotated successfully. Old token is now invalid.'
  );
  
EXCEPTION
  -- Handle any unexpected errors
  WHEN OTHERS THEN
    -- Re-raise the exception with context
    RAISE EXCEPTION 'rotate_nfc_secret failed: %', SQLERRM
      USING HINT = 'Check input parameters and permissions';
END;
$;

-- Add function comment
COMMENT ON FUNCTION rotate_nfc_secret(UUID, TEXT, TEXT) IS 
'Admin function to rotate NFC secret tokens for classrooms. Immediately invalidates old tokens and logs the rotation event. Requires admin role.';

-- Grant execute permission to authenticated users (function checks admin role internally)
GRANT EXECUTE ON FUNCTION rotate_nfc_secret(UUID, TEXT, TEXT) TO authenticated;

-- Create helper function to get token rotation history for a classroom
CREATE OR REPLACE FUNCTION get_token_rotation_history(
  p_classroom_id UUID,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  rotated_at TIMESTAMPTZ,
  rotated_by_email TEXT,
  reason TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $
DECLARE
  v_admin_id UUID;
BEGIN
  -- Get the authenticated user's ID
  v_admin_id := auth.uid();
  
  -- Verify user is authenticated and has admin role
  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = v_admin_id
    AND (
      raw_app_meta_data->>'role' = 'admin' OR 
      raw_user_meta_data->>'role' = 'admin'
    )
  ) THEN
    RAISE EXCEPTION 'Insufficient permissions';
  END IF;
  
  -- Return rotation history
  RETURN QUERY
  SELECT 
    trl.id,
    trl.rotated_at,
    u.email as rotated_by_email,
    trl.reason
  FROM token_rotation_logs trl
  LEFT JOIN auth.users u ON trl.rotated_by = u.id
  WHERE trl.classroom_id = p_classroom_id
  ORDER BY trl.rotated_at DESC
  LIMIT p_limit;
END;
$;

-- Add function comment
COMMENT ON FUNCTION get_token_rotation_history(UUID, INTEGER) IS 
'Admin function to retrieve token rotation history for a classroom. Returns the last N rotation events. Requires admin role.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_token_rotation_history(UUID, INTEGER) TO authenticated;
