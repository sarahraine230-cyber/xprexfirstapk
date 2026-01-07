import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

const handler = async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const payload = await req.json()
    const user = payload.record 
    const email = user.email
    const username = user.username || "Creator"

    if (!RESEND_API_KEY) throw new Error('Missing RESEND_API_KEY')

    console.log(`Sending welcome email to ${email}`)

    const htmlContent = `
      <div style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #1a1a1a; max-width: 600px; margin: 0 auto; line-height: 1.6;">
        <h1 style="font-size: 24px; font-weight: 800; letter-spacing: -0.5px;">You’re in. Now, let’s talk about your rent.</h1>
        <p>Hey @${username},</p>
        <p>You just took the first step toward leaving the "Digital Tenant" life behind.</p>
        <p>Most platforms treat Nigerian creators like ghost workers. On Xprex, we’re flipping the script.</p>
        <p><strong>But you aren’t a Partner yet.</strong></p>
        <p>To join the Xprex Partner Program and start earning, you need to activate your Premium status.</p>
        
        <div style="background: #f4f4f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <ul style="padding-left: 20px; margin: 0;">
            <li style="margin-bottom: 10px;"><strong>Direct Earning:</strong> No 10k follower threshold.</li>
            <li style="margin-bottom: 10px;"><strong>Algorithmic Priority:</strong> Partners get a 1.5x reach boost.</li>
            <li style="margin-bottom: 0;"><strong>The Pool:</strong> You earn based on engagement.</li>
          </ul>
        </div>
        <p>We are looking for the "First 100".</p>
        <div style="background: #000; color: #fff; padding: 15px; border-radius: 8px; text-align: center; margin: 30px 0;">
          <p style="margin: 0; font-weight: bold; font-size: 16px;">Open the Xprex app and tap "Premium" to activate your status.</p>
        </div>
        <p>See you on the inside,<br/><strong>The Xprex Team</strong></p>
      </div>
    `

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: 'Xprex Team <welcome@getxprex.com>', 
        to: [email],
        subject: 'You’re in. Now, let’s talk about your rent.',
        html: htmlContent,
      }),
    })

    const data = await res.json()
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
}

serve(handler)
