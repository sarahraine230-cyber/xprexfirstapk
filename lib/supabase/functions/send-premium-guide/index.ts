// supabase functions deploy send-premium-guide --no-verify-jwt

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

serve(async (req) => {
  try {
    const payload = await req.json()
    const newRecord = payload.record // Profile row
    const oldRecord = payload.old_record

    // ONLY Send if they JUST became premium
    if (oldRecord.is_premium === true || newRecord.is_premium !== true) {
      return new Response('Not a new premium activation', { status: 200 })
    }

    // Attempt to get email from profile, fallback to auth API
    let email = newRecord.email
    if (!email) {
      const { data: userData } = await supabase.auth.admin.getUserById(newRecord.auth_user_id)
      email = userData.user?.email
    }
    
    // [UPDATED] Use username from profile
    const username = newRecord.username || "Partner"

    if (!RESEND_API_KEY) throw new Error('Missing RESEND_API_KEY')

    console.log(`Sending Premium Guide to ${email}`)

    const htmlContent = `
      <div style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #1a1a1a; max-width: 600px; margin: 0 auto; line-height: 1.6;">
        <h1 style="font-size: 24px; font-weight: 800;">Welcome to the Elite.</h1>
        
        <p>You have successfully activated your Partner Status. The velvet rope is open.</p>
        
        <p><strong>Here is the uncomfortable truth:</strong> Xprex works differently than TikTok or Instagram.</p>
        <p>We do not rely on random viral hits from strangers. We rely on a community of professionals.</p>

        <div style="background: #eef2ff; padding: 20px; border-radius: 8px; border-left: 4px solid #4f46e5; margin: 25px 0;">
          <h3 style="margin: 0 0 10px 0; color: #4f46e5;">Strategy: The "LinkedIn Effect"</h3>
          <p style="margin: 0;">On Xprex, <strong>Creators are the Audience</strong>. Your earnings come from the subscription pool of other members. If you ghost the community, the community cannot pay you.</p>
        </div>

        <h3>How to Maximize Your Earnings:</h3>
        
        <p><strong>1. Engage to Earn</strong><br/>
        The algorithm sends strong signals when Premium users interact. Commenting on and sharing other Partners' work puts <em>your</em> profile in front of them.</p>
        
        <p><strong>2. Consistency is Currency</strong><br/>
        Posting daily signals to the system that you are a serious builder. Serious builders get the 1.5x boost.</p>
        
        <p><strong>3. Build Your Tribe</strong><br/>
        Don't just post and leave. Reply to comments. Treat your followers like investors in your startup.</p>

        <p>You have the tools. You have the platform. The rest is up to you, @${username}.</p>

        <div style="background: #000; color: #fff; padding: 15px; border-radius: 8px; text-align: center; margin: 30px 0;">
          <p style="margin: 0; font-weight: bold; font-size: 16px;">Your Revenue Studio is now active in the app.</p>
        </div>

        <p>Let's build this empire.<br/><strong>The Xprex Team</strong></p>
      </div>
    `

    await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: 'Xprex Team <welcome@getxprex.com>', 
        to: [email],
        subject: 'You’re Elite. Here is how to actually earn.',
        html: htmlContent,
      }),
    })

    return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } })
  } catch (error) {
    console.error(error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})

serve()
