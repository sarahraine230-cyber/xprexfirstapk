import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// [FIXED] Pinned version to prevent 522 deployment errors
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8"

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
        max_rows: 200 
      })

    if (error) throw error

    if (!candidates || candidates.length === 0) {
      candidates = []
    }

    // --- GATEKEEPER 1: PUBLIC ONLY FILTER ---
    candidates = candidates.filter((v: any) => v.privacy_level === 'public')

    // 4. Fetch Viewed History
    const { data: viewed } = await supabaseClient
      .from('video_views')
      .select('video_id')
      .eq('viewer_id', user.id)
      .order('created_at', { ascending: false })
      .limit(100)
    
    const watchedSet = new Set(viewed?.map((v: any) => v.video_id) || [])

    // 5. Fetch Profiles Map
    const authorIds = [...new Set(candidates.map((v: any) => v.author_auth_user_id))]
    const { data: profiles } = await supabaseClient
      .from('profiles')
      .select('auth_user_id, username, display_name, avatar_url, is_premium') // [NOTE] Ensure is_premium is selected
      .in('auth_user_id', authorIds)

    const profileMap: any = {}
    profiles?.forEach((p: any) => { profileMap[p.auth_user_id] = p })

    // 6. SCORING LOOP
    const scoredVideos = candidates.map((video: any) => {
      let engagementScore = 
        (video.likes_count * 1) + 
        (video.comments_count * 2) + 
        (video.shares_count * 3) + 
        (video.saves_count * 2) + 
        (video.reposts_count * 4) +
        (video.playback_count * 0.1);

      // Recency Decay
      const created = new Date(video.created_at).getTime();
      const now = new Date().getTime();
      const hoursAgo = (now - created) / (1000 * 60 * 60);
      const recencyFactor = Math.pow(hoursAgo + 2, 1.5);
      
      let finalScore = engagementScore / recencyFactor;

      const authorProfile = profileMap[video.author_auth_user_id];

      // --- [NEW] THE PREMIUM BOOST LOGIC ---
      if (authorProfile && authorProfile.is_premium) {
        finalScore = finalScore * 1.5; 
      }

      // C. PENALTY LOGIC
      if (video.author_auth_user_id === user.id) {
        finalScore *= 0.01; 
      }
      if (watchedSet.has(video.id)) {
        finalScore *= 0.1; 
      }

      return { 
        ...video, 
        algorithm_score: finalScore,
        profiles: authorProfile ? {
          username: authorProfile.username,
          display_name: authorProfile.display_name,
          avatar_url: authorProfile.avatar_url,
          is_premium: authorProfile.is_premium
        } : null
      };
    })

    // 7. Sort & Return
    scoredVideos.sort((a: any, b: any) => b.algorithm_score - a.algorithm_score);
    const finalFeed = scoredVideos.slice(0, 20);

    return new Response(JSON.stringify(finalFeed), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
