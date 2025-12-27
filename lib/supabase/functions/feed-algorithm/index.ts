// Follow Supabase Edge Function setup guide to deploy this:
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

    // 2. Fetch Candidates (ALL Recent Videos - No Exclusion yet)
    // We ask for 200 to ensure we have a good pool to rank
    let { data: candidates, error } = await supabaseClient
      .rpc('get_feed_candidates', { 
        viewer_id: user.id, 
        max_rows: 200 
      })

    if (error) throw error

    // Fallback if empty (Database is literally empty)
    if (!candidates || candidates.length === 0) {
      candidates = []
    }

    // 3. FETCH CONTEXT (Watch History)
    // We need to know what the user has seen to apply the "Boredom Penalty"
    // We fetch just the video_ids the user has watched
    const { data: history } = await supabaseClient
      .from('video_views')
      .select('video_id')
      .eq('viewer_id', user.id);
    
    // Create a Set for O(1) lookups
    const watchedSet = new Set((history || []).map((h: any) => h.video_id));

    // 4. FETCH PROFILES (Context for UI)
    const userIds = [...new Set(candidates.map((v: any) => v.author_auth_user_id))];
    const { data: profiles } = await supabaseClient
      .from('profiles')
      .select('auth_user_id, username, display_name, avatar_url')
      .in('auth_user_id', userIds);

    const profileMap: any = {};
    if (profiles) {
      profiles.forEach((p: any) => profileMap[p.auth_user_id] = p);
    }

    // 5. THE SCORING ENGINE (Derank Protocol)
    const scoredVideos = candidates.map((video: any) => {
      // A. Base Score (Engagement)
      const engagementScore = (video.likes_count * 5) + (video.comments_count * 3) + (video.playback_count * 0.1);
      
      // B. Recency Factor
      const uploadTime = new Date(video.created_at).getTime();
      const now = new Date().getTime();
      const hoursAgo = Math.max(0, (now - uploadTime) / (1000 * 60 * 60));
      const recencyFactor = Math.pow(hoursAgo + 2, 1.5);
      
      let finalScore = engagementScore / recencyFactor;

      // C. PENALTY LOGIC (The "Soft Filter")
      
      // Penalty 1: Own Video (Buried Deep)
      if (video.author_auth_user_id === user.id) {
        finalScore *= 0.01; // 99% penalty
      }

      // Penalty 2: Already Watched (Deranked)
      if (watchedSet.has(video.id)) {
        finalScore *= 0.1; // 90% penalty (Only shows if nothing else is good)
      }

      // Merge Profile
      const authorProfile = profileMap[video.author_auth_user_id];
      
      return { 
        ...video, 
        algorithm_score: finalScore,
        profiles: authorProfile ? {
          username: authorProfile.username,
          display_name: authorProfile.display_name,
          avatar_url: authorProfile.avatar_url
        } : null
      };
    })

    // 6. Sort & Return
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
