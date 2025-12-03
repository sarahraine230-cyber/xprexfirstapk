-- XpreX Master Schema
-- Includes Tables, Indexes, and Automation Triggers

-- Enable required extensions
create extension if not exists pgcrypto;

-- ==========================================
-- 1. TABLES & INDEXES
-- ==========================================

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
  saves_count int not null default 0,
  reposts_count int not null default 0,
  tags text[] default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_videos_author on public.videos (author_auth_user_id);
create index if not exists idx_videos_created_at on public.videos (created_at desc);
create index if not exists idx_videos_tags on public.videos using gin(tags);

-- VIDEO VIEWS (Analytics)
-- Tracks individual views for unique reach calculation
create table if not exists public.video_views (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  viewer_id uuid references auth.users(id) on delete set null,
  author_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now()
);
create index if not exists idx_video_views_author_time on public.video_views (author_id, created_at);

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

-- FOLLOWS
create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_auth_user_id uuid not null references auth.users(id) on delete cascade,
  followee_auth_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (follower_auth_user_id, followee_auth_user_id)
);

-- SHARES
create table if not exists public.shares (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_auth_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- SAVED VIDEOS
create table if not exists public.saved_videos (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_auth_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_auth_id, video_id)
);

-- REPOSTS
create table if not exists public.reposts (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_auth_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_auth_id, video_id)
);

-- ==========================================
-- 2. AUTOMATION & TRIGGERS
-- ==========================================

-- Function: Automatically increment video playback_count when a view is recorded
create or replace function update_video_view_count()
returns trigger as $$
begin
  update public.videos
  set playback_count = playback_count + 1
  where id = new.video_id;
  return new;
end;
$$ language plpgsql security definer;

-- Trigger: Attach to video_views
drop trigger if exists on_view_record on public.video_views;
create trigger on_view_record
after insert on public.video_views
for each row execute function update_video_view_count();
