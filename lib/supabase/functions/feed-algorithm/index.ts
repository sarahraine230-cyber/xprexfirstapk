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
  // Handle CORS for browser/app requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Initialize Supabase Client
    // We use the Service Role Key if we need to bypass RLS, 
    // but here we can stick to the user's context for safety.
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // 2. Get the User ID from the request auth context
    const {
      data: { user },
    } = await supabaseClient.auth.getUser()

    if (!user) {
      throw new Error('Unauthorized: User not logged in')
    }

    // 3. FETCH CANDIDATES via the SQL RPC we created
    // We ask for 100 candidates to rank.
    let { data: candidates, error } = await supabaseClient
      .rpc('get_feed_candidates', { 
        viewer_id: user.id, 
        max_rows: 100 
      })

    if (error) throw error

    // --- FALLBACK MECHANISM ---
    // If candidates is empty (User watched everything!), fetch general popular videos instead
    if (!candidates || candidates.length === 0) {
      console.log("User has watched everything. Switching to Fallback Mode.")
      const { data: fallback } = await supabaseClient
        .from('videos')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(20)
      candidates = fallback || []
    }

    // 4. THE ALGORITHM (Scoring Logic)
    const scoredVideos = candidates.map((video: any) => {
      // A. Engagement Score
      const engagementScore = 
        (video.likes_count * 5) + 
        (video.comments_count * 3) + 
        (video.playback_count * 0.1);

      // B. Recency Decay
      // How many hours since upload?
      const uploadTime = new Date(video.created_at).getTime();
      const now = new Date().getTime();
      const hoursAgo = Math.max(0, (now - uploadTime) / (1000 * 60 * 60));
      
      // Decay formula: Score / (Age + 2)^1.5
      // This makes older videos drop in rank unless they are VERY viral
      const recencyFactor = Math.pow(hoursAgo + 2, 1.5);
      
      const finalScore = engagementScore / recencyFactor;

      return { ...video, algorithm_score: finalScore };
    })

    // 5. SORT & RETURN
    // Sort by our new calculated score (Highest first)
    scoredVideos.sort((a: any, b: any) => b.algorithm_score - a.algorithm_score);

    // Return top 20 for the feed page
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
