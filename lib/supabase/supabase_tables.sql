-- XpreX core schema (first-time creation)
-- Tables are defined to match lib/models and current services.

-- Enable required extensions
create extension if not exists pgcrypto;

-- PROFILES
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  email text not null,
  username text not null unique,
  display_name text not null,
  avatar_url text,
  bio text,
  followers_count int not null default 0,
  total_video_views int not null default 0,
  is_premium boolean not null default false,
  monetization_status text not null default 'locked',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_profiles_username on public.profiles (username);

-- VIDEOS
create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  author_auth_user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  cover_image_url text,
  title text not null,
  description text,
  duration int not null,
  playback_count int not null default 0,
  likes_count int not null default 0,
  comments_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_videos_author on public.videos (author_auth_user_id);
create index if not exists idx_videos_created_at on public.videos (created_at desc);

-- COMMENTS
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  author_auth_user_id uuid not null references auth.users(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_comments_video on public.comments (video_id, created_at desc);

-- LIKES
create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_auth_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (video_id, user_auth_id)
);
create index if not exists idx_likes_video on public.likes (video_id);
create index if not exists idx_likes_user on public.likes (user_auth_id);

-- FOLLOWS
create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_auth_user_id uuid not null references auth.users(id) on delete cascade,
  followee_auth_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (follower_auth_user_id, followee_auth_user_id)
);
create index if not exists idx_follows_follower on public.follows (follower_auth_user_id);
create index if not exists idx_follows_followee on public.follows (followee_auth_user_id);

-- SHARES
create table if not exists public.shares (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_auth_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists idx_shares_video on public.shares (video_id);
create index if not exists idx_shares_user on public.shares (user_auth_id);
