-- XpreX Master Schema
-- Current State: Full Feature Set (Feed Algorithm, Payments, Verification, Bank Accounts, Analytics)

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
  is_verified boolean not null default false,
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

-- VERIFICATION REQUESTS
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

-- CREATOR BANK ACCOUNTS (New: For Payouts)
create table if not exists public.creator_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  bank_name text not null,
  account_number text not null,
  account_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id)
);
alter table public.creator_bank_accounts enable row level security;
create policy "Users can manage own bank account" on public.creator_bank_accounts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

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
    v.created_at > (now() - interval '7 days')
  order by
    (
      (v.likes_count * 2) + (v.comments_count * 3) + (v.saves_count * 4) + (v.reposts_count * 5)
      / (extract(epoch from (now() - v.created_at)) / 3600 + 2)^1.5
    ) 
    * (case when ui.score is not null then (1.0 + (ui.score * 0.1)) else 1.0 end)
    * (case when p.is_premium then 1.5 else 1.0 end)
    DESC
  limit limit_count;
end;
$$; 

-- PARTNER PROGRAM LEDGER 
-- 1. UPGRADE VIDEO VIEWS (To track Duration)
-- We need to know HOW LONG they watched, not just 'that' they watched.
alter table public.video_views 
add column if not exists duration_seconds int not null default 0;

-- 2. SYSTEM CONFIG (The "Brains")
-- Stores your 70/30 split logic so you can change it later without coding.
create table if not exists public.system_config (
  key text primary key,
  value text not null,
  description text
);

-- Insert your default policy (70% to Creator Pool)
insert into public.system_config (key, value, description)
values 
  ('creator_pool_percentage', '0.70', 'Percentage of daily revenue allocated to creators'),
  ('min_payout_threshold', '5000', 'Minimum NGN required to request withdrawal');

-- 3. DAILY POOL STATS (The "Market Rate")
-- Stores the calculated "Rate per Second" for every single day.
create table if not exists public.daily_pool_stats (
  date date primary key default current_date,
  total_revenue numeric not null default 0, -- Total cash collected that day
  creator_pool_amount numeric not null default 0, -- The 70% share
  total_platform_seconds bigint not null default 0, -- Total time watched by everyone
  calculated_rate_per_second numeric not null default 0, -- The resulting rate (Pool / Seconds)
  is_finalized boolean default false, -- True when the batch job finishes
  created_at timestamptz default now()
);

-- 4. DAILY CREATOR EARNINGS (The "Paycheck stub")
-- Stores exactly what each user earned that day based on the calculated rate.
create table if not exists public.daily_creator_earnings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null default current_date,
  total_seconds_watched int not null default 0, -- How long their content was watched
  amount_earned numeric not null default 0, -- (Seconds * Rate)
  video_breakdown jsonb default '[]'::jsonb, -- Stores which videos earned what
  created_at timestamptz default now(),
  unique(user_id, date)
);

-- Security: Creators can see their own daily earnings
alter table public.daily_creator_earnings enable row level security;
create policy "Users view own daily earnings" 
on public.daily_creator_earnings for select 
using (auth.uid() = user_id);

-- PARTNER PROGRAM EARNINGS CALCULATIONS 
-- =================================================================
-- 1. SETUP TABLES (If you haven't run Phase 1 yet)
-- =================================================================

-- Add duration tracking if missing
alter table public.video_views 
add column if not exists duration_seconds int not null default 0;

-- Configuration Table (70% Split)
create table if not exists public.system_config (
  key text primary key,
  value text not null
);

insert into public.system_config (key, value)
values 
  ('subscription_price', '7000'), -- NGN
  ('creator_pool_percentage', '0.70'), -- 70%
  ('pool_duration_days', '30') -- Smoothing factor
on conflict (key) do nothing;

-- Ledger Tables
create table if not exists public.daily_pool_stats (
  date date primary key default current_date,
  total_revenue numeric not null default 0,
  creator_pool_amount numeric not null default 0,
  total_premium_seconds bigint not null default 0, -- CHANGED: Premium Only
  rate_per_second numeric not null default 0,
  created_at timestamptz default now()
);

create table if not exists public.daily_creator_earnings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null default current_date,
  seconds_watched int not null default 0,
  amount_earned numeric not null default 0,
  video_breakdown jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  unique(user_id, date)
);

alter table public.daily_creator_earnings enable row level security;
create policy "Users see own earnings" on public.daily_creator_earnings for select using (auth.uid() = user_id);

-- =================================================================
-- 2. THE ENGINE (The Calculation Function)
-- =================================================================

create or replace function calculate_daily_earnings()
returns json
language plpgsql
security definer
as $$
declare
  -- Config variables
  v_sub_price numeric;
  v_split_pct numeric;
  v_days numeric;
  
  -- Calculation variables
  v_yesterday date;
  v_active_subs int;
  v_daily_pool numeric;
  v_total_premium_seconds bigint;
  v_rate numeric;
  
  -- Loop variables
  r_creator record;
  v_video_breakdown jsonb;
begin
  -- A. Load Config
  select value::numeric into v_sub_price from system_config where key = 'subscription_price';
  select value::numeric into v_split_pct from system_config where key = 'creator_pool_percentage';
  select value::numeric into v_days from system_config where key = 'pool_duration_days';
  
  v_yesterday := current_date - 1;

  -- B. Calculate The Pool (Amortized Revenue)
  -- Count users who are CURRENTLY premium
  select count(*) into v_active_subs from profiles where is_premium = true;
  
  -- Math: (Subs * 7000 * 0.70) / 30
  v_daily_pool := (v_active_subs * v_sub_price * v_split_pct) / v_days;

  -- C. Calculate Total Work (PREMIUM SECONDS ONLY)
  -- This is the "Premium Eyes Only" filter you requested
  select coalesce(sum(v.duration_seconds), 0)
  into v_total_premium_seconds
  from video_views v
  join profiles viewer on v.viewer_id = viewer.auth_user_id
  where 
    v.created_at >= v_yesterday::timestamp
    and v.created_at < current_date::timestamp
    and v.viewer_id != v.author_id -- No self-views
    and viewer.is_premium = true;  -- ONLY Premium Viewers Count!

  -- Safety Check: Avoid division by zero
  if v_total_premium_seconds > 0 then
    v_rate := v_daily_pool / v_total_premium_seconds;
  else
    v_rate := 0;
  end if;

  -- D. Log the Day's Stats
  insert into daily_pool_stats (date, total_revenue, creator_pool_amount, total_premium_seconds, rate_per_second)
  values (v_yesterday, (v_active_subs * v_sub_price)/v_days, v_daily_pool, v_total_premium_seconds, v_rate)
  on conflict (date) do update set 
    rate_per_second = EXCLUDED.rate_per_second, 
    total_premium_seconds = EXCLUDED.total_premium_seconds;

  -- E. Pay The Creators (If rate > 0)
  if v_rate > 0 then
    
    -- Loop through every creator who got PREMIUM views yesterday
    for r_creator in 
      select 
        v.author_id, 
        sum(v.duration_seconds) as total_sec,
        jsonb_agg(jsonb_build_object('video_id', v.video_id, 'sec', v.duration_seconds)) as videos
      from video_views v
      join profiles viewer on v.viewer_id = viewer.auth_user_id
      where 
        v.created_at >= v_yesterday::timestamp
        and v.created_at < current_date::timestamp
        and v.viewer_id != v.author_id
        and viewer.is_premium = true -- Filter again for the payout list
      group by v.author_id
    loop
      -- 1. Insert Record
      insert into daily_creator_earnings (user_id, date, seconds_watched, amount_earned, video_breakdown)
      values (
        r_creator.author_id, 
        v_yesterday, 
        r_creator.total_sec, 
        (r_creator.total_sec * v_rate), 
        r_creator.videos
      )
      on conflict (user_id, date) do update set 
        amount_earned = EXCLUDED.amount_earned,
        seconds_watched = EXCLUDED.seconds_watched;

      -- 2. Update Wallet (Atomic Increment)
      update profiles 
      set earnings_balance = coalesce(earnings_balance, 0) + (r_creator.total_sec * v_rate)
      where auth_user_id = r_creator.author_id;
      
    end loop;
  end if;

  return json_build_object(
    'status', 'success',
    'date', v_yesterday,
    'pool', v_daily_pool,
    'rate', v_rate
  );
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

-- This creates the ledger and the automated function to generate final payout invoices.
-- 1. Create the Payouts Ledger
create table if not exists public.payouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  period date not null, -- Stores "2025-11-01" for November payout
  amount numeric not null,
  status text not null default 'Processing', -- 'Processing', 'Paid', 'Failed'
  processed_at timestamptz, -- When you actually transferred the money
  created_at timestamptz default now(),
  unique(user_id, period) -- Safety: Prevent double-paying the same month
);

-- 2. Enable Security (So users can see THEIR checks only)
alter table public.payouts enable row level security;
create policy "Users see own payouts" on public.payouts 
for select using (auth.uid() = user_id);

-- 3. The "Monthly Close" Generator Function
create or replace function generate_monthly_payouts(target_date date default null)
returns json
language plpgsql
security definer
as $$
declare
  v_start date;
  v_end date;
  v_count int;
begin
  -- Logic: If no date is given, assume we are generating for LAST MONTH
  if target_date is null then
    v_start := date_trunc('month', current_date - interval '1 month');
  else
    v_start := date_trunc('month', target_date);
  end if;
  
  -- The end date is the 1st of the NEXT month
  v_end := v_start + interval '1 month';

  -- Aggregation: Sum up daily earnings for that specific month
  with monthly_sums as (
    select user_id, sum(amount_earned) as total
    from daily_creator_earnings
    where date >= v_start and date < v_end
    group by user_id
    having sum(amount_earned) > 0 -- Only generate invoice if they earned > 0
  )
  insert into payouts (user_id, period, amount, status)
  select user_id, v_start, total, 'Processing'
  from monthly_sums
  on conflict (user_id, period) do nothing; -- Idempotency: Running it twice won't duplicate checks

  get diagnostics v_count = row_count;

  return json_build_object(
    'status', 'success', 
    'period', v_start, 
    'invoices_generated', v_count
  );
end;
$$;

-- MARK PAYOUTS AS PAID 
create or replace function mark_payouts_as_paid(target_period date)
returns json
language plpgsql
security definer
as $$
declare
  v_count int;
begin
  -- Update pending payouts for the specific month to 'Paid'
  update public.payouts
  set 
    status = 'Paid',
    processed_at = now()
  where 
    period = target_period 
    and status = 'Processing';

  get diagnostics v_count = row_count;

  return json_build_object(
    'status', 'success',
    'period', target_period,
    'payouts_marked_paid', v_count
  );
end;
$$;
-- AD WALLET TRANSACTIONS $ CAMPAIGN 
-- 1. Add Real Credit Balance to Profile
alter table public.profiles 
add column if not exists ad_credits numeric default 0;

-- 2. Create the Wallet History (The Statement)
create table if not exists public.ad_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  amount numeric not null, -- Positive for deposits, Negative for spends
  description text not null, -- e.g. "Monthly Grant" or "Boost: My Video"
  created_at timestamptz default now()
);

-- 3. Create the Campaign Ledger (The Orders for the Wizard)
create table if not exists public.ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  video_id uuid references public.videos(id) not null,
  package_name text not null, -- "Spark", "Amplify", "Velocity"
  cost numeric not null,
  target_reach int not null, -- e.g. 500, 2000, 10000
  status text default 'Pending', -- 'Pending' -> 'Active' -> 'Completed'
  created_at timestamptz default now()
);

-- 4. The "Purchase" Function (Safe Transaction)
-- This ensures we don't take money if they don't have enough.
create or replace function purchase_ad_campaign(
  p_video_id uuid,
  p_package_name text,
  p_cost numeric,
  p_target_reach int
)
returns json
language plpgsql
security definer
as $$
declare
  v_user_id uuid;
  v_current_balance numeric;
begin
  v_user_id := auth.uid();
  
  -- Check Balance
  select ad_credits into v_current_balance from profiles where id = v_user_id;
  
  if v_current_balance < p_cost then
    return json_build_object('status', 'error', 'message', 'Insufficient ad credits');
  end if;

  -- 1. Deduct Money
  update profiles set ad_credits = ad_credits - p_cost where id = v_user_id;

  -- 2. Record Transaction
  insert into ad_wallet_transactions (user_id, amount, description)
  values (v_user_id, -p_cost, 'Purchased ' || p_package_name || ' Plan');

  -- 3. Create Order (For the Wizard to see)
  insert into ad_campaigns (user_id, video_id, package_name, cost, target_reach, status)
  values (v_user_id, p_video_id, p_package_name, p_cost, p_target_reach, 'Pending');

  return json_build_object('status', 'success', 'new_balance', v_current_balance - p_cost);
end;
$$;

-- 5. Give you some starter money for testing (Optional)
update profiles set ad_credits = 5000 where is_premium = true;

-- FIXING THE PROFILE SCREEN FOLLOWING DISCREPANCY 
-- 1. UPGRADE: Add the missing 'following_count' column
alter table public.profiles 
add column if not exists following_count int not null default 0;

-- 2. AUTOMATION: The Counter Trigger
-- This keeps the numbers in sync forever.
create or replace function update_follow_counts() returns trigger as $$
begin
  if (TG_OP = 'INSERT') then
    -- Someone followed someone:
    -- 1. Increase 'followers_count' for the person being followed
    update public.profiles 
    set followers_count = followers_count + 1 
    where auth_user_id = new.followee_auth_user_id;
    
    -- 2. Increase 'following_count' for the person doing the following
    update public.profiles 
    set following_count = following_count + 1 
    where auth_user_id = new.follower_auth_user_id;
    
    return new;
  elsif (TG_OP = 'DELETE') then
    -- Unfollow logic:
    update public.profiles 
    set followers_count = followers_count - 1 
    where auth_user_id = old.followee_auth_user_id;
    
    update public.profiles 
    set following_count = following_count - 1 
    where auth_user_id = old.follower_auth_user_id;
    
    return old;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- Attach the trigger to the 'follows' table
drop trigger if exists on_follow_change on public.follows;
create trigger on_follow_change
after insert or delete on public.follows
for each row execute function update_follow_counts();

-- 3. REPAIR: Fix the data right now
-- This calculates the real counts from the 'follows' table and updates profiles.
with calculated_followers as (
  select followee_auth_user_id as uid, count(*) as c
  from follows
  group by followee_auth_user_id
),
calculated_following as (
  select follower_auth_user_id as uid, count(*) as c
  from follows
  group by follower_auth_user_id
)
update profiles p
set 
  followers_count = coalesce((select c from calculated_followers where uid = p.auth_user_id), 0),
  following_count = coalesce((select c from calculated_following where uid = p.auth_user_id), 0);
