-- Add horario column to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS horario TEXT;

-- Add comment for documentation
COMMENT ON COLUMN profiles.horario IS 'Reference to schedules table (schedule id)';
