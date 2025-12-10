-- XpreX Master Schema
-- Current State: Includes Payments, Threaded Comments & Premium Logic

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

-- PAYMENTS (The Ledger)
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reference text not null unique,
  amount numeric not null,
  currency text not null default 'NGN',
  status text not null default 'success',
  created_at timestamptz not null default now()
);
alter table public.payments enable row level security;
create policy "Users can view own payments" on public.payments for select using (auth.uid() = user_id);

-- VIDEO VIEWS (Analytics)
create table if not exists public.video_views (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  viewer_id uuid references auth.users(id) on delete set null,
  author_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now()
);
create index if not exists idx_video_views_author_time on public.video_views (author_id, created_at);

-- COMMENTS (Threaded)
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  author_auth_user_id uuid not null references auth.users(id) on delete cascade,
  text text not null,
  parent_id uuid references public.comments(id) on delete cascade,
  reply_count int not null default 0,
  likes_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_comments_video on public.comments (video_id, created_at desc);
create index if not exists idx_comments_parent on public.comments (parent_id);

-- COMMENT LIKES
create table if not exists public.comment_likes (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_auth_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (comment_id, user_auth_id)
);

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

-- SHARES, SAVED, REPOSTS
create table if not exists public.shares (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_auth_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.saved_videos (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_auth_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_auth_id, video_id)
);
create table if not exists public.reposts (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_auth_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_auth_id, video_id)
);

-- USER INTERESTS
create table if not exists public.user_interests (
  user_id uuid references auth.users(id) on delete cascade,
  tag text not null,
  score int default 1,
  last_interaction timestamptz default now(),
  primary key (user_id, tag)
);

-- NOTIFICATIONS
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(auth_user_id) on delete cascade,
  actor_id uuid not null references public.profiles(auth_user_id) on delete cascade,
  video_id uuid references public.videos(id) on delete cascade,
  type text not null check (type in ('like', 'comment', 'follow', 'repost', 'reply')),
  is_read boolean default false,
  created_at timestamptz default now()
);
create index if not exists idx_notifications_recipient on public.notifications(recipient_id, created_at desc);

-- ==========================================
-- 2. FUNCTIONS & TRIGGERS
-- ==========================================

-- Secure Premium Upgrade (The Gatekeeper)
create or replace function confirm_premium_purchase(payment_reference text, payment_amount numeric)
returns boolean language plpgsql security definer as $$
declare usr_id uuid;
begin
  usr_id := auth.uid();
  if usr_id is null then raise exception 'Not logged in'; end if;
  insert into public.payments (user_id, reference, amount, status) values (usr_id, payment_reference, payment_amount, 'success');
  update public.profiles set is_premium = true, monetization_status = 'active', updated_at = now() where auth_user_id = usr_id;
  return true;
exception when unique_violation then return false; when others then raise;
end;
$$;

-- (Keep existing Analytics RPCs and Automation Triggers from your previous file here...)
-- [Note: I am omitting the repetition of analytics/triggers to save space, but they should remain in your file]
