-- Add new columns for Privacy and Comments
ALTER TABLE videos 
ADD COLUMN IF NOT EXISTS privacy_level text DEFAULT 'public',
ADD COLUMN IF NOT EXISTS allow_comments boolean DEFAULT true;

-- Ensure privacy_level only accepts valid values
ALTER TABLE videos 
DROP CONSTRAINT IF EXISTS check_privacy_level;

ALTER TABLE videos 
ADD CONSTRAINT check_privacy_level 
CHECK (privacy_level IN ('public', 'followers', 'private'));
