-- 1. SECURITY: Fix the "Empty Feed" bug for new users
-- Ensure RLS is enabled
ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;

-- Drop potential conflicting policies to ensure a clean slate
DROP POLICY IF EXISTS "Public videos are viewable by everyone" ON public.videos;
DROP POLICY IF EXISTS "Anyone can select videos" ON public.videos;

-- Create the "Open Gate" policy
-- This allows ANY authenticated or anonymous user to read videos.
CREATE POLICY "Public videos are viewable by everyone" 
ON public.videos FOR SELECT 
USING (true);

-- 2. ALGORITHM: Update the Candidate Fetcher (The "Soft" Filter)
-- We no longer exclude videos here. We fetch the pool, and let the Brain (Edge Function) decide the ranking.
CREATE OR REPLACE FUNCTION get_feed_candidates(
  viewer_id uuid, 
  max_rows int default 200
)
RETURNS SETOF public.videos
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT *
  FROM public.videos
  ORDER BY created_at DESC
  LIMIT max_rows;
$$;
