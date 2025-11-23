-- Enable Row Level Security
alter table public.profiles enable row level security;
alter table public.videos enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
alter table public.follows enable row level security;
alter table public.shares enable row level security;

-- PROFILES policies
drop policy if exists profiles_select_all on public.profiles;
create policy profiles_select_all on public.profiles
  for select using (true);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert with check (auth.uid() = auth_user_id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update using (auth.uid() = auth_user_id) with check (auth.uid() = auth_user_id);

-- VIDEOS policies
drop policy if exists videos_select_all on public.videos;
create policy videos_select_all on public.videos
  for select using (true);

drop policy if exists videos_insert_own on public.videos;
create policy videos_insert_own on public.videos
  for insert with check (auth.uid() = author_auth_user_id);

drop policy if exists videos_update_own on public.videos;
create policy videos_update_own on public.videos
  for update using (auth.uid() = author_auth_user_id) with check (auth.uid() = author_auth_user_id);

drop policy if exists videos_delete_own on public.videos;
create policy videos_delete_own on public.videos
  for delete using (auth.uid() = author_auth_user_id);

-- COMMENTS policies
drop policy if exists comments_select_all on public.comments;
create policy comments_select_all on public.comments
  for select using (true);

drop policy if exists comments_insert_own on public.comments;
create policy comments_insert_own on public.comments
  for insert with check (auth.uid() = author_auth_user_id);

drop policy if exists comments_delete_own on public.comments;
create policy comments_delete_own on public.comments
  for delete using (auth.uid() = author_auth_user_id);

-- LIKES policies
drop policy if exists likes_select_all on public.likes;
create policy likes_select_all on public.likes
  for select using (true);

drop policy if exists likes_insert_own on public.likes;
create policy likes_insert_own on public.likes
  for insert with check (auth.uid() = user_auth_id);

drop policy if exists likes_delete_own on public.likes;
create policy likes_delete_own on public.likes
  for delete using (auth.uid() = user_auth_id);

-- FOLLOWS policies
drop policy if exists follows_select_all on public.follows;
create policy follows_select_all on public.follows
  for select using (true);

drop policy if exists follows_insert_own on public.follows;
create policy follows_insert_own on public.follows
  for insert with check (auth.uid() = follower_auth_user_id);

drop policy if exists follows_delete_own on public.follows;
create policy follows_delete_own on public.follows
  for delete using (auth.uid() = follower_auth_user_id);

-- SHARES policies
drop policy if exists shares_select_all on public.shares;
create policy shares_select_all on public.shares
  for select using (true);

drop policy if exists shares_insert_own on public.shares;
create policy shares_insert_own on public.shares
  for insert with check (auth.uid() = user_auth_id);
