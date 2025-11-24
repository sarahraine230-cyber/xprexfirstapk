-- XpreX Row Level Security (RLS) Policies
-- Run this after create_tables.sql

-- =====================================================
-- ENABLE RLS
-- =====================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reposts ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- PROFILES POLICIES
-- =====================================================

-- Anyone can view profiles (for public discovery)
CREATE POLICY "Profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

-- Users can insert their own profile
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = auth_user_id);

-- Users can update their own profile
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = auth_user_id)
  WITH CHECK (auth.uid() = auth_user_id);

-- Users can delete their own profile
CREATE POLICY "Users can delete their own profile"
  ON public.profiles FOR DELETE
  USING (auth.uid() = auth_user_id);

-- =====================================================
-- VIDEOS POLICIES
-- =====================================================

-- Anyone can view videos (public feed)
CREATE POLICY "Videos are viewable by everyone"
  ON public.videos FOR SELECT
  USING (true);

-- Authenticated users can insert videos
CREATE POLICY "Authenticated users can insert videos"
  ON public.videos FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = author_auth_user_id);

-- Users can update their own videos
CREATE POLICY "Users can update their own videos"
  ON public.videos FOR UPDATE
  USING (auth.uid() = author_auth_user_id)
  WITH CHECK (auth.uid() = author_auth_user_id);

-- Users can delete their own videos
CREATE POLICY "Users can delete their own videos"
  ON public.videos FOR DELETE
  USING (auth.uid() = author_auth_user_id);

-- =====================================================
-- COMMENTS POLICIES
-- =====================================================

-- Anyone can view comments
CREATE POLICY "Comments are viewable by everyone"
  ON public.comments FOR SELECT
  USING (true);

-- Authenticated users can insert comments
CREATE POLICY "Authenticated users can insert comments"
  ON public.comments FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = author_auth_user_id);

-- Users can update their own comments
CREATE POLICY "Users can update their own comments"
  ON public.comments FOR UPDATE
  USING (auth.uid() = author_auth_user_id)
  WITH CHECK (auth.uid() = author_auth_user_id);

-- Users can delete their own comments
CREATE POLICY "Users can delete their own comments"
  ON public.comments FOR DELETE
  USING (auth.uid() = author_auth_user_id);

-- =====================================================
-- LIKES POLICIES
-- =====================================================

-- Anyone can view likes
CREATE POLICY "Likes are viewable by everyone"
  ON public.likes FOR SELECT
  USING (true);

-- Authenticated users can insert likes
CREATE POLICY "Authenticated users can insert likes"
  ON public.likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_auth_id);

-- Users can delete their own likes
CREATE POLICY "Users can delete their own likes"
  ON public.likes FOR DELETE
  USING (auth.uid() = user_auth_id);

-- =====================================================
-- FLAGS POLICIES
-- =====================================================

-- Users can view their own flags
CREATE POLICY "Users can view their own flags"
  ON public.flags FOR SELECT
  USING (auth.uid() = reporter_auth_user_id);

-- Authenticated users can insert flags
CREATE POLICY "Authenticated users can insert flags"
  ON public.flags FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = reporter_auth_user_id);

-- Note: Only admin API can update/delete flags (handled via service role key)

-- =====================================================
-- FOLLOWS POLICIES
-- =====================================================

-- Anyone can view follows (for counts and relations)
CREATE POLICY "Follows are viewable by everyone"
  ON public.follows FOR SELECT
  USING (true);

-- Authenticated users can follow others
CREATE POLICY "Authenticated users can insert follows"
  ON public.follows FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = follower_auth_user_id AND follower_auth_user_id <> followee_auth_user_id);

-- Users can unfollow (delete their own follows)
CREATE POLICY "Users can delete their own follows"
  ON public.follows FOR DELETE
  USING (auth.uid() = follower_auth_user_id);

-- =====================================================
-- SHARES POLICIES
-- =====================================================
CREATE POLICY "Shares are viewable by everyone"
  ON public.shares FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can insert shares"
  ON public.shares FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_auth_id);

-- =====================================================
-- SAVES POLICIES
-- =====================================================
CREATE POLICY "Saves are viewable by everyone"
  ON public.saves FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can insert saves"
  ON public.saves FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_auth_id);

CREATE POLICY "Users can delete their own saves"
  ON public.saves FOR DELETE
  USING (auth.uid() = user_auth_id);

-- =====================================================
-- REPOSTS POLICIES
-- =====================================================
CREATE POLICY "Reposts are viewable by everyone"
  ON public.reposts FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can insert reposts"
  ON public.reposts FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = reposter_auth_user_id);

CREATE POLICY "Users can delete their own reposts"
  ON public.reposts FOR DELETE
  USING (auth.uid() = reposter_auth_user_id);
