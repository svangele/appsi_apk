-- Add mail_user and mail_pass columns to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS mail_user TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS mail_pass TEXT;

-- Add comment for documentation
COMMENT ON COLUMN profiles.mail_user IS 'Email system username';
COMMENT ON COLUMN profiles.mail_pass IS 'Email system password';
