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

    // 2. Fetch Candidates
    let { data: candidates, error } = await supabaseClient
      .rpc('get_feed_candidates', { 
        viewer_id: user.id, 
        max_rows: 200 
      })

    if (error) throw error

    if (!candidates || candidates.length === 0) {
      candidates = []
    }

    // --- GATEKEEPER 1: PUBLIC ONLY FILTER ---
    // Ensure "For You" only shows Public videos
    // (We assume the RPC returns the privacy_level column)
    candidates = candidates.filter((v: any) => v.privacy_level === 'public');

    // 3. FETCH CONTEXT (Watch History)
    const { data: history } = await supabaseClient
      .from('video_views')
      .select('video_id')
      .eq('viewer_id', user.id);

    const watchedSet = new Set((history || []).map((h: any) => h.video_id));

    // 4. FETCH PROFILES
    const userIds = [...new Set(candidates.map((v: any) => v.author_auth_user_id))];
    const { data: profiles } = await supabaseClient
      .from('profiles')
      .select('auth_user_id, username, display_name, avatar_url')
      .in('auth_user_id', userIds);

    const profileMap: any = {};
    if (profiles) {
      profiles.forEach((p: any) => profileMap[p.auth_user_id] = p);
    }

    // 5. THE SCORING ENGINE
    const scoredVideos = candidates.map((video: any) => {
      // A. Base Score (Engagement)
      const engagementScore = (video.likes_count * 5) + (video.comments_count * 3) + (video.playback_count * 0.1);
      
      // B. Recency Factor
      const uploadTime = new Date(video.created_at).getTime();
      const now = new Date().getTime();
      const hoursAgo = Math.max(0, (now - uploadTime) / (1000 * 60 * 60));
      const recencyFactor = Math.pow(hoursAgo + 2, 1.5);
      
      let finalScore = engagementScore / recencyFactor;

      // C. PENALTY LOGIC
      if (video.author_auth_user_id === user.id) {
        finalScore *= 0.01; 
      }
      if (watchedSet.has(video.id)) {
        finalScore *= 0.1; 
      }

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
