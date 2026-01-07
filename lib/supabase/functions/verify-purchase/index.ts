// supabase functions deploy verify-purchase

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

    // 1. Get the User
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) throw new Error('Unauthorized')

    const { reference } = await req.json()
    if (!reference) throw new Error('No reference provided')

    // 2. VERIFY WITH PAYSTACK (The Secret Handshake)
    // You must set PAYSTACK_SECRET_KEY in your Supabase Dashboard -> Edge Functions -> Secrets
    const secretKey = Deno.env.get('PAYSTACK_SECRET_KEY')
    if (!secretKey) throw new Error('Server misconfigured: Missing Secret Key')

    const paystackRes = await fetch(`https://api.paystack.co/transaction/verify/${reference}`, {
      headers: { Authorization: `Bearer ${secretKey}` }
    })
    
    const paystackData = await paystackRes.json()

    if (!paystackData.status || paystackData.data.status !== 'success') {
      throw new Error('Payment verification failed')
    }

    const amountPaid = paystackData.data.amount / 100 // Convert Kobo to Naira

    // 3. SECURELY UPDATE DATABASE (Service Role)
    // We use the Admin client to bypass RLS and write to the payments table
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // A. Log Payment
    const { error: logError } = await supabaseAdmin
      .from('payments')
      .insert({
        user_id: user.id,
        reference: reference,
        amount: amountPaid,
        status: 'success',
        currency: 'NGN'
      })
    
    if (logError && logError.code !== '23505') { // Ignore duplicate reference errors
        console.error('Payment Log Error:', logError)
    }

    // B. Upgrade Profile
    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({
        is_premium: true,
        monetization_status: 'active',
        updated_at: new Date().toISOString()
      })
      .eq('auth_user_id', user.id)

    if (updateError) throw updateError

    return new Response(JSON.stringify({ success: true, message: 'Welcome to Elite!' }), {
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
