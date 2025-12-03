-- XpreX Master Schema
-- Defines Tables, Indexes, Functions, and Automation Triggers

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

-- USER INTERESTS (For Algorithm)
create table if not exists public.user_interests (
  user_id uuid references auth.users(id) on delete cascade,
  tag text not null,
  score int default 1,
  last_interaction timestamptz default now(),
  primary key (user_id, tag)
);

-- ==========================================
-- 2. ANALYTICS FUNCTIONS (RPC)
-- ==========================================

-- Function: Get 30-Day Stats for Creator Hub (Simple)
create or replace function get_creator_stats(target_user_id uuid)
returns json
language plpgsql
security definer
as $$
declare
  total_followers int;
  views_30d int;
  total_audience_30d int;
  engaged_audience_30d int;
  start_date timestamptz;
begin
  start_date := now() - interval '30 days';

  select count(*) into total_followers from follows where followee_auth_user_id = target_user_id;

  select count(vv.id) into views_30d
  from video_views vv join videos v on vv.video_id = v.id
  where v.author_auth_user_id = target_user_id and vv.created_at > start_date;

  select count(distinct vv.viewer_id) into total_audience_30d
  from video_views vv join videos v on vv.video_id = v.id
  where v.author_auth_user_id = target_user_id and vv.created_at > start_date and vv.viewer_id is not null;

  with interactions as (
    select l.user_auth_id as uid from likes l join videos v on l.video_id = v.id where v.author_auth_user_id = target_user_id and l.created_at > start_date
    union all select c.author_auth_user_id from comments c join videos v on c.video_id = v.id where v.author_auth_user_id = target_user_id and c.created_at > start_date
    union all select s.user_auth_id from saved_videos s join videos v on s.video_id = v.id where v.author_auth_user_id = target_user_id and s.created_at > start_date
    union all select r.user_auth_id from reposts r join videos v on r.video_id = v.id where v.author_auth_user_id = target_user_id and r.created_at > start_date
  )
  select count(distinct uid) into engaged_audience_30d from interactions;

  return json_build_object(
    'followers', total_followers,
    'views_30d', coalesce(views_30d, 0),
    'total_audience', coalesce(total_audience_30d, 0),
    'engaged_audience', coalesce(engaged_audience_30d, 0)
  );
end;
$$;

-- Function: Get Full Analytics Dashboard (Detailed w/ Trends)
create or replace function get_analytics_dashboard(target_user_id uuid)
returns json
language plpgsql
security definer
as $$
declare
  now_ts timestamptz := now();
  current_start timestamptz := now() - interval '30 days';
  prev_start timestamptz := now() - interval '60 days';
  
  curr_views int; prev_views int;
  curr_engagements int; prev_engagements int;
  curr_saves int; prev_saves int;
  curr_reposts int; prev_reposts int;
  curr_followers int; prev_followers int;
  curr_engaged_audience int; prev_engaged_audience int;
  
  top_videos json;
begin
  -- Views
  select count(*) into curr_views from video_views vv join videos v on vv.video_id = v.id where v.author_auth_user_id = target_user_id and vv.created_at >= current_start;
  select count(*) into prev_views from video_views vv join videos v on vv.video_id = v.id where v.author_auth_user_id = target_user_id and vv.created_at >= prev_start and vv.created_at < current_start;

  -- Saves
  select count(*) into curr_saves from saved_videos s join videos v on s.video_id = v.id where v.author_auth_user_id = target_user_id and s.created_at >= current_start;
  select count(*) into prev_saves from saved_videos s join videos v on s.video_id = v.id where v.author_auth_user_id = target_user_id and s.created_at >= prev_start and s.created_at < current_start;

  -- Reposts
  select count(*) into curr_reposts from reposts r join videos v on r.video_id = v.id where v.author_auth_user_id = target_user_id and r.created_at >= current_start;
  select count(*) into prev_reposts from reposts r join videos v on r.video_id = v.id where v.author_auth_user_id = target_user_id and r.created_at >= prev_start and r.created_at < current_start;

  -- Followers
  select count(*) into curr_followers from follows where followee_auth_user_id = target_user_id and created_at >= current_start;
  select count(*) into prev_followers from follows where followee_auth_user_id = target_user_id and created_at >= prev_start and created_at < current_start;

  -- Engagements (Total Actions)
  with interactions as (
    select created_at from likes l join videos v on l.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select created_at from comments c join videos v on c.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select created_at from shares sh join videos v on sh.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select created_at from saved_videos sa join videos v on sa.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select created_at from reposts re join videos v on re.video_id = v.id where v.author_auth_user_id = target_user_id
  )
  select 
    count(*) filter (where created_at >= current_start),
    count(*) filter (where created_at >= prev_start and created_at < current_start)
  into curr_engagements, prev_engagements
  from interactions;

  -- Engaged Audience (Unique Users)
  with audience as (
    select l.user_auth_id as uid, created_at from likes l join videos v on l.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select c.author_auth_user_id, created_at from comments c join videos v on c.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select s.user_auth_id, created_at from saved_videos s join videos v on s.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select r.user_auth_id, created_at from reposts r join videos v on r.video_id = v.id where v.author_auth_user_id = target_user_id
  )
  select 
    count(distinct uid) filter (where created_at >= current_start),
    count(distinct uid) filter (where created_at >= prev_start and created_at < current_start)
  into curr_engaged_audience, prev_engaged_audience
  from audience;

  -- Top Videos (Last 30 Days by Views)
  select json_agg(t) into top_videos from (
    select 
      v.*, 
      profiles.username as author_username, 
      profiles.display_name as author_display_name, 
      profiles.avatar_url as author_avatar_url
    from videos v
    join profiles on v.author_auth_user_id = profiles.auth_user_id
    where v.author_auth_user_id = target_user_id
    order by v.playback_count desc
    limit 5
  ) t;

  return json_build_object(
    'metrics', json_build_object(
      'views', json_build_object('value', curr_views, 'prev', prev_views),
      'engagements', json_build_object('value', curr_engagements, 'prev', prev_engagements),
      'saves', json_build_object('value', curr_saves, 'prev', prev_saves),
      'reposts', json_build_object('value', curr_reposts, 'prev', prev_reposts),
      'followers', json_build_object('value', curr_followers, 'prev', prev_followers),
      'engaged_audience', json_build_object('value', curr_engaged_audience, 'prev', prev_engaged_audience)
    ),
    'top_videos', coalesce(top_videos, '[]'::json)
  );
end;
$$;

-- ==========================================
-- 3. AUTOMATION TRIGGERS
-- ==========================================

create or replace function update_video_view_count()
returns trigger as $$
begin
  update public.videos
  set playback_count = playback_count + 1
  where id = new.video_id;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_view_record on public.video_views;
create trigger on_view_record
after insert on public.video_views
for each row execute function update_video_view_count();

create or replace function learn_user_interests()
returns trigger as $$
declare
  v_tags text[];
  t text;
begin
  select tags into v_tags from videos where id = new.video_id;
  if v_tags is not null then
    foreach t in array v_tags loop
      insert into user_interests (user_id, tag, score, last_interaction)
      values (new.user_auth_id, t, 1, now())
      on conflict (user_id, tag) 
      do update set score = user_interests.score + 1, last_interaction = now();
    end loop;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_like_learn on public.likes;
create trigger on_like_learn
after insert on public.likes
for each row execute function learn_user_interests();
