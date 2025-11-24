-- XpreX Database Schema
-- Run this script in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- PROFILES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  followers_count INT DEFAULT 0 CHECK (followers_count >= 0),
  total_video_views BIGINT DEFAULT 0 CHECK (total_video_views >= 0),
  is_premium BOOLEAN DEFAULT FALSE,
  monetization_status TEXT DEFAULT 'locked' CHECK (monetization_status IN ('locked', 'eligible', 'active')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create unique index for case-insensitive username
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username_lower ON public.profiles (LOWER(username));

-- Create index on auth_user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_auth_user_id ON public.profiles (auth_user_id);

-- =====================================================
-- VIDEOS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_auth_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  cover_image_url TEXT,
  title TEXT NOT NULL,
  description TEXT,
  duration INT NOT NULL CHECK (duration > 0),
  playback_count BIGINT DEFAULT 0 CHECK (playback_count >= 0),
  likes_count INT DEFAULT 0 CHECK (likes_count >= 0),
  comments_count INT DEFAULT 0 CHECK (comments_count >= 0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index on created_at for feed ordering (descending)
CREATE INDEX IF NOT EXISTS idx_videos_created_at_desc ON public.videos (created_at DESC);

-- Create index on author for profile video listing
CREATE INDEX IF NOT EXISTS idx_videos_author ON public.videos (author_auth_user_id);

-- =====================================================
-- COMMENTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  author_auth_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT NOT NULL CHECK (LENGTH(text) > 0 AND LENGTH(text) <= 500),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for fetching comments by video
CREATE INDEX IF NOT EXISTS idx_comments_video_id ON public.comments (video_id, created_at DESC);

-- Create index for user's comments
CREATE INDEX IF NOT EXISTS idx_comments_author ON public.comments (author_auth_user_id);

-- =====================================================
-- LIKES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  user_auth_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(video_id, user_auth_id)
);

-- Create index for checking if user liked a video
CREATE INDEX IF NOT EXISTS idx_likes_video_user ON public.likes (video_id, user_auth_id);

-- Create index for user's liked videos
CREATE INDEX IF NOT EXISTS idx_likes_user ON public.likes (user_auth_id);

-- =====================================================
-- FLAGS TABLE (Content Moderation)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_type TEXT NOT NULL CHECK (resource_type IN ('video', 'comment', 'profile')),
  resource_id UUID NOT NULL,
  reporter_auth_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'dismissed')),
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for filtering by status
CREATE INDEX IF NOT EXISTS idx_flags_status ON public.flags (status, created_at DESC);

-- Create index for resource lookup
CREATE INDEX IF NOT EXISTS idx_flags_resource ON public.flags (resource_type, resource_id);

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for profiles
DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for videos
DROP TRIGGER IF EXISTS update_videos_updated_at ON public.videos;
CREATE TRIGGER update_videos_updated_at
  BEFORE UPDATE ON public.videos
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for comments
DROP TRIGGER IF EXISTS update_comments_updated_at ON public.comments;
CREATE TRIGGER update_comments_updated_at
  BEFORE UPDATE ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for flags
DROP TRIGGER IF EXISTS update_flags_updated_at ON public.flags;
CREATE TRIGGER update_flags_updated_at
  BEFORE UPDATE ON public.flags
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Important: run as SECURITY DEFINER so RLS on videos doesn't block counter updates
CREATE OR REPLACE FUNCTION increment_video_likes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.videos
  SET likes_count = likes_count + 1
  WHERE id = NEW.video_id;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_video_likes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.videos
  SET likes_count = likes_count - 1
  WHERE id = OLD.video_id;
  RETURN OLD;
END;
$$;

-- Trigger for like insert
DROP TRIGGER IF EXISTS increment_likes_count ON public.likes;
CREATE TRIGGER increment_likes_count
  AFTER INSERT ON public.likes
  FOR EACH ROW
  EXECUTE FUNCTION increment_video_likes();

-- Trigger for like delete
DROP TRIGGER IF EXISTS decrement_likes_count ON public.likes;
CREATE TRIGGER decrement_likes_count
  AFTER DELETE ON public.likes
  FOR EACH ROW
  EXECUTE FUNCTION decrement_video_likes();

CREATE OR REPLACE FUNCTION increment_video_comments()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.videos
  SET comments_count = comments_count + 1
  WHERE id = NEW.video_id;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_video_comments()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.videos
  SET comments_count = comments_count - 1
  WHERE id = OLD.video_id;
  RETURN OLD;
END;
$$;

-- Trigger for comment insert
DROP TRIGGER IF EXISTS increment_comments_count ON public.comments;
CREATE TRIGGER increment_comments_count
  AFTER INSERT ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION increment_video_comments();

-- Trigger for comment delete
DROP TRIGGER IF EXISTS decrement_comments_count ON public.comments;
CREATE TRIGGER decrement_comments_count
  AFTER DELETE ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION decrement_video_comments();

-- =====================================================
-- VIEWS FOR ANALYTICS
-- =====================================================

-- View for user engagement metrics
CREATE OR REPLACE VIEW user_engagement_stats AS
SELECT
  p.auth_user_id,
  p.username,
  p.display_name,
  p.followers_count,
  p.total_video_views,
  p.is_premium,
  p.monetization_status,
  COUNT(DISTINCT v.id) as videos_count,
  COALESCE(SUM(v.likes_count), 0) as total_likes,
  COALESCE(SUM(v.comments_count), 0) as total_comments,
  p.created_at as account_created_at
FROM public.profiles p
LEFT JOIN public.videos v ON v.author_auth_user_id = p.auth_user_id
GROUP BY p.auth_user_id, p.username, p.display_name, p.followers_count,
         p.total_video_views, p.is_premium, p.monetization_status, p.created_at;

-- View for daily analytics
CREATE OR REPLACE VIEW daily_analytics AS
SELECT
  DATE(created_at) as date,
  'video' as resource_type,
  COUNT(*) as count
FROM public.videos
GROUP BY DATE(created_at)
UNION ALL
SELECT
  DATE(created_at) as date,
  'comment' as resource_type,
  COUNT(*) as count
FROM public.comments
GROUP BY DATE(created_at)
UNION ALL
SELECT
  DATE(created_at) as date,
  'like' as resource_type,
  COUNT(*) as count
FROM public.likes
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

-- Grant access to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant select on views
GRANT SELECT ON user_engagement_stats TO authenticated;
GRANT SELECT ON daily_analytics TO authenticated;

COMMENT ON TABLE public.profiles IS 'User profile information';
COMMENT ON TABLE public.videos IS 'Video metadata and statistics';
COMMENT ON TABLE public.comments IS 'Video comments';
COMMENT ON TABLE public.likes IS 'Video likes by users';
COMMENT ON TABLE public.flags IS 'Content moderation flags';

-- =====================================================
-- SOCIAL: FOLLOWS, SHARES, SAVES, REPOSTS
-- =====================================================

-- FOLLOWS
CREATE TABLE IF NOT EXISTS public.follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_auth_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  followee_auth_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_auth_user_id, followee_auth_user_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_followee ON public.follows (followee_auth_user_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.follows (follower_auth_user_id);

-- SHARES
CREATE TABLE IF NOT EXISTS public.shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  user_auth_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shares_video ON public.shares (video_id);
CREATE INDEX IF NOT EXISTS idx_shares_user ON public.shares (user_auth_id);

-- SAVES / BOOKMARKS
CREATE TABLE IF NOT EXISTS public.saves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  user_auth_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(video_id, user_auth_id)
);

CREATE INDEX IF NOT EXISTS idx_saves_video_user ON public.saves (video_id, user_auth_id);
CREATE INDEX IF NOT EXISTS idx_saves_user ON public.saves (user_auth_id);

-- REPOSTS
CREATE TABLE IF NOT EXISTS public.reposts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  reposter_auth_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(video_id, reposter_auth_user_id)
);

CREATE INDEX IF NOT EXISTS idx_reposts_video_user ON public.reposts (video_id, reposter_auth_user_id);
CREATE INDEX IF NOT EXISTS idx_reposts_user ON public.reposts (reposter_auth_user_id);

-- =====================================================
-- TRIGGERS TO MAINTAIN COUNTS
-- =====================================================

-- Followers count on profiles
CREATE OR REPLACE FUNCTION increment_followers()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles SET followers_count = followers_count + 1
  WHERE auth_user_id = NEW.followee_auth_user_id;
  RETURN NEW;
END;$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION decrement_followers()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles SET followers_count = followers_count - 1
  WHERE auth_user_id = OLD.followee_auth_user_id;
  RETURN OLD;
END;$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS increment_followers_count ON public.follows;
CREATE TRIGGER increment_followers_count
  AFTER INSERT ON public.follows
  FOR EACH ROW EXECUTE FUNCTION increment_followers();

DROP TRIGGER IF EXISTS decrement_followers_count ON public.follows;
CREATE TRIGGER decrement_followers_count
  AFTER DELETE ON public.follows
  FOR EACH ROW EXECUTE FUNCTION decrement_followers();

-- =====================================================
-- RPCs
-- =====================================================

-- Increment profile.total_video_views
CREATE OR REPLACE FUNCTION increment_video_views(user_id UUID, increment_by INT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET total_video_views = total_video_views + increment_by
  WHERE auth_user_id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
