-- Turbo-Charge Performance with Indexes
-- These indexes speed up lookups for likes, comments, and views significantly.

-- 1. Comments: Faster loading of comment sheets
CREATE INDEX IF NOT EXISTS idx_comments_video_id ON public.comments(video_id);

-- 2. Likes: Faster "Is Liked" checks and count updates
-- FIX: Changed 'user_id' to 'user_auth_id' to match your schema
CREATE INDEX IF NOT EXISTS idx_likes_video_id ON public.likes(video_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON public.likes(user_auth_id);
CREATE INDEX IF NOT EXISTS idx_likes_video_user ON public.likes(video_id, user_auth_id);

-- 3. Views: Faster view counting and history checks
CREATE INDEX IF NOT EXISTS idx_video_views_video_id ON public.video_views(video_id);
CREATE INDEX IF NOT EXISTS idx_video_views_viewer_id ON public.video_views(viewer_id);

-- 4. Reposts: Faster profile/feed checks
-- FIX: Changed 'user_id' to 'user_auth_id'
CREATE INDEX IF NOT EXISTS idx_reposts_video_id ON public.reposts(video_id);
CREATE INDEX IF NOT EXISTS idx_reposts_user_id ON public.reposts(user_auth_id);

-- 5. Saved Videos
-- FIX: Changed 'user_id' to 'user_auth_id'
DO $$
BEGIN
    -- Check for 'saved_videos' table
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'saved_videos') THEN
        CREATE INDEX IF NOT EXISTS idx_saved_videos_video_id ON public.saved_videos(video_id);
        CREATE INDEX IF NOT EXISTS idx_saved_videos_user_id ON public.saved_videos(user_auth_id);
    END IF;
END $$;
