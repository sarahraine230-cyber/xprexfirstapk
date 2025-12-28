-- Turbo-Charge Performance with Indexes
-- These indexes speed up lookups for likes, comments, and views significantly.

-- 1. Comments: Faster loading of comment sheets
-- This allows the database to instantly find all comments for a specific video
CREATE INDEX IF NOT EXISTS idx_comments_video_id ON public.comments(video_id);

-- 2. Likes: Faster "Is Liked" checks and count updates
-- Finding "Did I like this?" becomes O(1) instead of O(N)
CREATE INDEX IF NOT EXISTS idx_likes_video_id ON public.likes(video_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON public.likes(user_id);
-- Compound index for the specific check: "Does User X like Video Y?"
CREATE INDEX IF NOT EXISTS idx_likes_video_user ON public.likes(video_id, user_id);

-- 3. Views: Faster view counting and history checks
CREATE INDEX IF NOT EXISTS idx_video_views_video_id ON public.video_views(video_id);
CREATE INDEX IF NOT EXISTS idx_video_views_viewer_id ON public.video_views(viewer_id);

-- 4. Reposts: Faster profile/feed checks
CREATE INDEX IF NOT EXISTS idx_reposts_video_id ON public.reposts(video_id);
CREATE INDEX IF NOT EXISTS idx_reposts_user_id ON public.reposts(user_auth_id);

-- 5. Saved Videos (Assuming table is 'saved_videos' or 'saves')
-- We use a safe check block to handle potential table naming differences
DO $$
BEGIN
    -- Check for 'saved_videos' table
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'saved_videos') THEN
        CREATE INDEX IF NOT EXISTS idx_saved_videos_video_id ON public.saved_videos(video_id);
        CREATE INDEX IF NOT EXISTS idx_saved_videos_user_id ON public.saved_videos(user_id);
    END IF;
    
    -- Check for 'saves' table (alternative name)
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'saves') THEN
        CREATE INDEX IF NOT EXISTS idx_saves_video_id ON public.saves(video_id);
        CREATE INDEX IF NOT EXISTS idx_saves_user_id ON public.saves(user_id);
    END IF;
END $$;
