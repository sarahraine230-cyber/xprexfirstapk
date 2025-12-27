// Follow Supabase Edge Function setup guide to deploy this:
// supabase functions new feed-algorithm
// supabase functions deploy feed-algorithm

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // 1. Get User
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) throw new Error('Unauthorized: User not logged in')

    // 2. Fetch Candidates (Raw Videos)
    let { data: candidates, error } = await supabaseClient
      .rpc('get_feed_candidates', { 
        viewer_id: user.id, 
        max_rows: 100 
      })

    if (error) throw error

    // Fallback if empty
    if (!candidates || candidates.length === 0) {
      console.log("Fallback Mode.")
      const { data: fallback } = await supabaseClient
        .from('videos')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(20)
      candidates = fallback || []
    }

    // 3. --- FIX: FETCH PROFILES ---
    // Extract unique author IDs to avoid fetching the same profile multiple times
    const userIds = [...new Set(candidates.map((v: any) => v.author_auth_user_id))];
    
    // Fetch profile data for these authors
    const { data: profiles } = await supabaseClient
      .from('profiles')
      .select('auth_user_id, username, display_name, avatar_url')
      .in('auth_user_id', userIds);

    // Create a quick lookup map: ID -> Profile Data
    const profileMap: any = {};
    if (profiles) {
      profiles.forEach((p: any) => {
        profileMap[p.auth_user_id] = p;
      });
    }

    // 4. Scoring & Merging
    const scoredVideos = candidates.map((video: any) => {
      // Score Calculation
      const engagementScore = (video.likes_count * 5) + (video.comments_count * 3) + (video.playback_count * 0.1);
      const uploadTime = new Date(video.created_at).getTime();
      const now = new Date().getTime();
      const hoursAgo = Math.max(0, (now - uploadTime) / (1000 * 60 * 60));
      const recencyFactor = Math.pow(hoursAgo + 2, 1.5);
      const finalScore = engagementScore / recencyFactor;

      // --- MERGE PROFILE DATA ---
      // We attach the profile object so the Flutter model can parse it via "profiles" key
      const authorProfile = profileMap[video.author_auth_user_id];
      
      return { 
        ...video, 
        algorithm_score: finalScore,
        // Attach profile data exactly how the Flutter Model expects it (as 'profiles' map)
        profiles: authorProfile ? {
          username: authorProfile.username,
          display_name: authorProfile.display_name,
          avatar_url: authorProfile.avatar_url
        } : null
      };
    })

    // 5. Sort & Return
    scoredVideos.sort((a: any, b: any) => b.algorithm_score - a.algorithm_score);
    const finalFeed = scoredVideos.slice(0, 20);

    return new Response(JSON.stringify(finalFeed), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
