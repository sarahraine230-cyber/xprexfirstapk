-- Add shares_count to videos table
ALTER TABLE public.videos 
ADD COLUMN IF NOT EXISTS shares_count int NOT NULL DEFAULT 0;

-- Create RPC to increment share count safely
CREATE OR REPLACE FUNCTION increment_video_share(video_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.videos
  SET shares_count = shares_count + 1
  WHERE id = video_id;
END;
$$;
