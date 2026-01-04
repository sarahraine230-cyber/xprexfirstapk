-- 1. OPTIMIZE COMMENT FETCHING
-- Speeds up: "Show me all comments for this video"
CREATE INDEX IF NOT EXISTS idx_comments_video_id ON public.comments(video_id);
-- Speeds up: "Show me replies to this specific comment"
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON public.comments(parent_id);

-- 2. OPTIMIZE FEED & PROFILE VIDEOS
-- Speeds up: "Show me all videos by this user" (Profile Screen)
CREATE INDEX IF NOT EXISTS idx_videos_author_id ON public.videos(author_auth_user_id);
-- Speeds up: "Show me only public videos" (For You Feed)
CREATE INDEX IF NOT EXISTS idx_videos_privacy ON public.videos(privacy_level);

-- 3. OPTIMIZE USER LOOKUPS
-- Speeds up: Deep links /u/userid and Profile loading
CREATE INDEX IF NOT EXISTS idx_profiles_auth_id ON public.profiles(auth_user_id);
-- Speeds up: @mentions and Search by username
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- 4. OPTIMIZE ANALYTICS & MONETIZATION (The Heavy Lifters)
-- Speeds up: "How much did I earn this month?" (Monetization Screen)
CREATE INDEX IF NOT EXISTS idx_earnings_user_date ON public.daily_creator_earnings(user_id, date);
-- Speeds up: "Count views for this video" (Algorithm & Stats)
CREATE INDEX IF NOT EXISTS idx_video_views_video_id ON public.video_views(video_id);
-- Speeds up: "Check if I have already watched this" (Feed Algorithm filtering)
CREATE INDEX IF NOT EXISTS idx_video_views_viewer_video ON public.video_views(viewer_id, video_id);

-- 5. OPTIMIZE SOCIAL GRAPH
-- Speeds up: "Am I following this user?" (Follow Button state)
CREATE INDEX IF NOT EXISTS idx_follows_follower_followee ON public.follows(follower_auth_user_id, followee_auth_user_id);
-- Speeds up: "Who is this user following?" (Following Feed)
CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.follows(follower_auth_user_id);

-- 6. OPTIMIZE REPOSTS
-- Speeds up: "Show me videos reposted by this user" (Profile Repost Tab)
CREATE INDEX IF NOT EXISTS idx_reposts_user_id ON public.reposts(user_auth_id);
