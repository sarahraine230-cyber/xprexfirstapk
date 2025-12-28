-- Fix Like Counters: Create the missing RPC functions

-- 1. Increment Like
create or replace function increment_video_like(video_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.videos
  set likes_count = likes_count + 1
  where id = video_id;
end;
$$;

-- 2. Decrement Like
create or replace function decrement_video_like(video_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.videos
  set likes_count = greatest(0, likes_count - 1) -- Safety: prevent negative counts
  where id = video_id;
end;
$$;
