-- XpreX Master Schema
-- Current State: Full Feature Set (Feed Algorithm, Payments, Verification, Analytics)

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
  is_verified boolean not null default false, -- Added for Verification Badge
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

-- VERIFICATION REQUESTS (For Phase 3)
create table if not exists public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  id_document_url text not null,
  status text not null default 'pending', -- pending, approved, rejected
  created_at timestamptz not null default now()
);
alter table public.verification_requests enable row level security;
create policy "Users can insert own requests" on public.verification_requests for insert with check (auth.uid() = user_id);
create policy "Users can view own requests" on public.verification_requests for select using (auth.uid() = user_id);

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
  parent_id uuid references public.comments(id) on delete cascade, -- NULL = Root Comment
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

-- LIKES (Video Likes)
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

-- USER INTERESTS
create table if not exists public.user_interests (
  user_id uuid references auth.users(id) on delete cascade,
  tag text not null,
  score int default 1,
  last_interaction timestamptz default now(),
  primary key (user_id, tag)
);

-- NOTIFICATIONS (Pulse)
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
-- 2. ANALYTICS & ALGORITHM FUNCTIONS
-- ==========================================

-- Function: Get 30-Day Stats for Creator Hub
create or replace function get_creator_stats(target_user_id uuid)
returns json language plpgsql security definer as $$
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
  from video_views vv
  join videos v on vv.video_id = v.id
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

-- Function: Get Full Analytics Dashboard
create or replace function get_analytics_dashboard(target_user_id uuid, days_range int default 30)
returns json language plpgsql security definer as $$
declare
  current_start timestamptz := now() - make_interval(days := days_range);
  prev_start timestamptz := now() - make_interval(days := days_range * 2);
  
  curr_views int; prev_views int;
  curr_engagements int; prev_engagements int;
  curr_saves int; prev_saves int;
  curr_reposts int; prev_reposts int;
  curr_followers int; prev_followers int;
  curr_engaged_audience int; prev_engaged_audience int;
  top_videos json;
begin
  select count(vv.id) into curr_views from video_views vv join videos v on vv.video_id = v.id where v.author_auth_user_id = target_user_id and vv.created_at >= current_start;
  select count(vv.id) into prev_views from video_views vv join videos v on vv.video_id = v.id where v.author_auth_user_id = target_user_id and vv.created_at >= prev_start and vv.created_at < current_start;
  select count(s.id) into curr_saves from saved_videos s join videos v on s.video_id = v.id where v.author_auth_user_id = target_user_id and s.created_at >= current_start;
  select count(s.id) into prev_saves from saved_videos s join videos v on s.video_id = v.id where v.author_auth_user_id = target_user_id and s.created_at >= prev_start and s.created_at < current_start;
  select count(r.id) into curr_reposts from reposts r join videos v on r.video_id = v.id where v.author_auth_user_id = target_user_id and r.created_at >= current_start;
  select count(r.id) into prev_reposts from reposts r join videos v on r.video_id = v.id where v.author_auth_user_id = target_user_id and r.created_at >= prev_start and r.created_at < current_start;
  select count(*) into curr_followers from follows where followee_auth_user_id = target_user_id and created_at >= current_start;
  select count(*) into prev_followers from follows where followee_auth_user_id = target_user_id and created_at >= prev_start and created_at < current_start;
  with interactions as (
    select created_at from likes l join videos v on l.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select created_at from comments c join videos v on c.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select created_at from saved_videos sa join videos v on sa.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select created_at from reposts re join videos v on re.video_id = v.id where v.author_auth_user_id = target_user_id
  )
  select count(*) filter (where created_at >= current_start), count(*) filter (where created_at >= prev_start and created_at < current_start)
  into curr_engagements, prev_engagements from interactions;
  with audience as (
    select l.user_auth_id as uid, l.created_at from likes l join videos v on l.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select c.author_auth_user_id, c.created_at from comments c join videos v on c.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select s.user_auth_id, s.created_at from saved_videos s join videos v on s.video_id = v.id where v.author_auth_user_id = target_user_id
    union all select r.user_auth_id, r.created_at from reposts r join videos v on r.video_id = v.id where v.author_auth_user_id = target_user_id
  )
  select count(distinct uid) filter (where created_at >= current_start), count(distinct uid) filter (where created_at >= prev_start and created_at < current_start)
  into curr_engaged_audience, prev_engaged_audience from audience;
  select json_agg(t) into top_videos from (
    select v.*, profiles.username as author_username, profiles.display_name as author_display_name, profiles.avatar_url as author_avatar_url
    from videos v join profiles on v.author_auth_user_id = profiles.auth_user_id
    where v.author_auth_user_id = target_user_id
    order by v.playback_count desc limit 5
  ) t;
  return json_build_object(
    'metrics', json_build_object(
      'views', json_build_object('value', coalesce(curr_views, 0), 'prev', coalesce(prev_views, 0)),
      'engagements', json_build_object('value', coalesce(curr_engagements, 0), 'prev', coalesce(prev_engagements, 0)),
      'saves', json_build_object('value', coalesce(curr_saves, 0), 'prev', coalesce(prev_saves, 0)),
      'reposts', json_build_object('value', coalesce(curr_reposts, 0), 'prev', coalesce(prev_reposts, 0)),
      'followers', json_build_object('value', coalesce(curr_followers, 0), 'prev', coalesce(prev_followers, 0)),
      'engaged_audience', json_build_object('value', coalesce(curr_engaged_audience, 0), 'prev', coalesce(prev_engaged_audience, 0))
    ),
    'top_videos', coalesce(top_videos, '[]'::json)
  );
end;
$$;

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

-- THE BRAIN: Get For You Feed (With 1.5x Premium Boost)
create or replace function get_for_you_feed(limit_count int default 20)
returns setof public.videos
language plpgsql
security definer
as $$
declare
  viewer_id uuid;
begin
  viewer_id := auth.uid();

  return query
  select v.*
  from public.videos v
  join public.profiles p on v.author_auth_user_id = p.auth_user_id
  left join public.user_interests ui on viewer_id = ui.user_id and ui.tag = any(v.tags)
  where 
    v.created_at > (now() - interval '7 days') -- Only recent videos
  order by
    (
      -- 1. BASE SCORE (Engagement)
      (v.likes_count * 2) + (v.comments_count * 3) + (v.saves_count * 4) + (v.reposts_count * 5)
      
      -- 2. RECENCY DECAY
      / (extract(epoch from (now() - v.created_at)) / 3600 + 2)^1.5
    ) 
    * -- 3. PERSONALIZATION MULTIPLIER
    (case when ui.score is not null then (1.0 + (ui.score * 0.1)) else 1.0 end)
    * -- 4. PREMIUM BOOST (The 1.5x Multiplier)
    (case when p.is_premium then 1.5 else 1.0 end)
    
    DESC
  limit limit_count;
end;
$$;

-- ==========================================
-- 3. AUTOMATION TRIGGERS
-- ==========================================

-- Video View Count
create or replace function update_video_view_count() returns trigger as $$
begin
  update public.videos set playback_count = playback_count + 1 where id = new.video_id;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_view_record on public.video_views;
create trigger on_view_record after insert on public.video_views for each row execute function update_video_view_count();

-- Comment Reply Counter
create or replace function update_comment_reply_count() returns trigger as $$
begin
  if (TG_OP = 'INSERT') then
    if new.parent_id is not null then
        update public.comments set reply_count = reply_count + 1 where id = new.parent_id;
    end if;
  elsif (TG_OP = 'DELETE') then
    if old.parent_id is not null then
        update public.comments set reply_count = reply_count - 1 where id = old.parent_id;
    end if;
  end if;
  return null;
end;
$$ language plpgsql security definer;

drop trigger if exists on_reply_count on public.comments;
create trigger on_reply_count after insert or delete on public.comments for each row execute function update_comment_reply_count();

-- Comment Like Counter
create or replace function update_comment_like_count() returns trigger as $$
begin
  if (TG_OP = 'INSERT') then
    update public.comments set likes_count = likes_count + 1 where id = new.comment_id;
  elsif (TG_OP = 'DELETE') then
    update public.comments set likes_count = likes_count - 1 where id = old.comment_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

drop trigger if exists on_comment_like_count on public.comment_likes;
create trigger on_comment_like_count after insert or delete on public.comment_likes for each row execute function update_comment_like_count();

-- User Interest Learning
create or replace function learn_user_interests() returns trigger as $$
declare v_tags text[]; t text;
begin
  select tags into v_tags from videos where id = new.video_id;
  if v_tags is not null then
    foreach t in array v_tags loop
      insert into user_interests (user_id, tag, score, last_interaction)
      values (new.user_auth_id, t, 1, now())
      on conflict (user_id, tag) do update set score = user_interests.score + 1, last_interaction = now();
    end loop;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_like_learn on public.likes;
create trigger on_like_learn after insert on public.likes for each row execute function learn_user_interests();

-- NOTIFICATION TRIGGERS

-- A. Like (Video)
create or replace function notify_on_like() returns trigger as $$
declare video_owner_id uuid;
begin
  select author_auth_user_id into video_owner_id from public.videos where id = new.video_id;
  if video_owner_id != new.user_auth_id then
    insert into public.notifications (recipient_id, actor_id, video_id, type)
    values (video_owner_id, new.user_auth_id, new.video_id, 'like');
  end if;
  return new;
end;
$$ language plpgsql security definer;
drop trigger if exists on_like_notify on public.likes;
create trigger on_like_notify after insert on public.likes for each row execute function notify_on_like();

-- B. Comment & Reply (Smart Notification)
create or replace function notify_on_comment() returns trigger as $$
declare 
  video_owner_id uuid;
  parent_author_id uuid;
begin
  if new.parent_id is not null then
    select author_auth_user_id into parent_author_id from public.comments where id = new.parent_id;
    if parent_author_id != new.author_auth_user_id then
      insert into public.notifications (recipient_id, actor_id, video_id, type)
      values (parent_author_id, new.author_auth_user_id, new.video_id, 'reply');
    end if;
  else
    select author_auth_user_id into video_owner_id from public.videos where id = new.video_id;
    if video_owner_id != new.author_auth_user_id then
      insert into public.notifications (recipient_id, actor_id, video_id, type)
      values (video_owner_id, new.author_auth_user_id, new.video_id, 'comment');
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer;
drop trigger if exists on_comment_notify on public.comments;
create trigger on_comment_notify after insert on public.comments for each row execute function notify_on_comment();

-- C. Repost
create or replace function notify_on_repost() returns trigger as $$
declare video_owner_id uuid;
begin
  select author_auth_user_id into video_owner_id from public.videos where id = new.video_id;
  if video_owner_id != new.user_auth_id then
    insert into public.notifications (recipient_id, actor_id, video_id, type)
    values (video_owner_id, new.user_auth_id, new.video_id, 'repost');
  end if;
  return new;
end;
$$ language plpgsql security definer;
drop trigger if exists on_repost_notify on public.reposts;
create trigger on_repost_notify after insert on public.reposts for each row execute function notify_on_repost();

-- D. Follow
create or replace function notify_on_follow() returns trigger as $$
begin
  if new.follower_auth_user_id != new.followee_auth_user_id then
    insert into public.notifications (recipient_id, actor_id, video_id, type)
    values (new.followee_auth_user_id, new.follower_auth_user_id, null, 'follow');
  end if;
  return new;
end;
$$ language plpgsql security definer;
drop trigger if exists on_follow_notify on public.follows;
create trigger on_follow_notify after insert on public.follows for each row execute function notify_on_follow();
