import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
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

    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) throw new Error('Unauthorized')

    const { reference } = await req.json()
    if (!reference) throw new Error('No reference provided')

    const secretKey = Deno.env.get('PAYSTACK_SECRET_KEY')
    if (!secretKey) throw new Error('Server misconfigured: Missing Secret Key')

    const paystackRes = await fetch(`https://api.paystack.co/transaction/verify/${reference}`, {
      headers: { Authorization: `Bearer ${secretKey}` }
    })
    
    const paystackData = await paystackRes.json()

    if (!paystackData.status || paystackData.data.status !== 'success') {
      throw new Error('Payment verification failed')
    }

    const amountPaid = paystackData.data.amount / 100 

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Log the payment
    await supabaseAdmin.from('payments').insert({
      user_id: user.id,
      reference: reference,
      amount: amountPaid,
      status: 'success',
      currency: 'NGN'
    })

    // Upgrade the user
    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({
        is_premium: true,
        monetization_status: 'active',
        updated_at: new Date().toISOString()
      })
      .eq('auth_user_id', user.id)

    if (updateError) throw updateError

    return new Response(JSON.stringify({ success: true }), {
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
