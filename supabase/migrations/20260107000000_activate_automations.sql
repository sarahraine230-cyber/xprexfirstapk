-- 1. TRIGGER FOR WELCOME EMAIL (On New User Signup)
-- This assumes your users are automatically copied to public.profiles
-- If they aren't, you might need to trigger on auth.users, but profiles is safer for accessing username.

create or replace trigger on_profile_created
  after insert on public.profiles
  for each row execute function supabase_functions.http_request(
    'https://svyuxdowffweanjjzvis.supabase.co/functions/v1/send-welcome-email',
    'POST',
    '{"Content-type":"application/json"}',
    '{}',
    '1000'
  );

-- 2. TRIGGER FOR PREMIUM GUIDE (On Upgrade)
create or replace trigger on_premium_upgrade
  after update on public.profiles
  for each row
  when (old.is_premium is distinct from true and new.is_premium = true)
  execute function supabase_functions.http_request(
    'https://svyuxdowffweanjjzvis.supabase.co/functions/v1/send-premium-guide',
    'POST',
    '{"Content-type":"application/json"}',
    '{}',
    '1000'
  );
