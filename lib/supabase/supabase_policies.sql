-- XpreX Master Policies
-- Security definitions for all tables

-- Enable Row Level Security on all tables
alter table public.profiles enable row level security;
alter table public.videos enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
alter table public.follows enable row level security;
alter table public.shares enable row level security;
alter table public.saved_videos enable row level security;
alter table public.reposts enable row level security;
alter table public.video_views enable row level security; -- New

-- PROFILES policies
create policy profiles_select_all on public.profiles for select using (true);
create policy profiles_insert_own on public.profiles for insert with check (auth.uid() = auth_user_id);
create policy profiles_update_own on public.profiles for update using (auth.uid() = auth_user_id) with check (auth.uid() = auth_user_id);

-- VIDEOS policies
create policy videos_select_all on public.videos for select using (true);
create policy videos_insert_own on public.videos for insert with check (auth.uid() = author_auth_user_id);
create policy videos_update_own on public.videos for update using (auth.uid() = author_auth_user_id) with check (auth.uid() = author_auth_user_id);
create policy videos_delete_own on public.videos for delete using (auth.uid() = author_auth_user_id);

-- VIDEO VIEWS policies (Analytics)
create policy "Public can record views" on public.video_views for insert with check (true);
create policy "Creators can view their own analytics" on public.video_views for select using (auth.uid() = author_id);

-- COMMENTS policies
create policy comments_select_all on public.comments for select using (true);
create policy comments_insert_own on public.comments for insert with check (auth.uid() = author_auth_user_id);
create policy comments_delete_own on public.comments for delete using (auth.uid() = author_auth_user_id);

-- LIKES policies
create policy likes_select_all on public.likes for select using (true);
create policy likes_insert_own on public.likes for insert with check (auth.uid() = user_auth_id);
create policy likes_delete_own on public.likes for delete using (auth.uid() = user_auth_id);

-- FOLLOWS policies
create policy follows_select_all on public.follows for select using (true);
create policy follows_insert_own on public.follows for insert with check (auth.uid() = follower_auth_user_id);
create policy follows_delete_own on public.follows for delete using (auth.uid() = follower_auth_user_id);

-- SAVED VIDEOS policies
create policy saved_select_own on public.saved_videos for select using (auth.uid() = user_auth_id);
create policy saved_insert_own on public.saved_videos for insert with check (auth.uid() = user_auth_id);
create policy saved_delete_own on public.saved_videos for delete using (auth.uid() = user_auth_id);

-- REPOSTS policies
create policy reposts_select_all on public.reposts for select using (true);
create policy reposts_insert_own on public.reposts for insert with check (auth.uid() = user_auth_id);
create policy reposts_delete_own on public.reposts for delete using (auth.uid() = user_auth_id);

-- SHARES policies
create policy shares_select_all on public.shares for select using (true);
create policy shares_insert_own on public.shares for insert with check (auth.uid() = user_auth_id);
