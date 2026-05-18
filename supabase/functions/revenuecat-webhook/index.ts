import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Verify Authorization Token (Optional but highly recommended for security)
    // You can set a custom Bearer token in RevenueCat's Authorization Header
    const authHeader = req.headers.get('Authorization')
    const webhookSecret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET')
    
    if (webhookSecret && authHeader !== `Bearer ${webhookSecret}`) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Invalid webhook secret token.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Parse the RevenueCat Event Payload
    const body = await req.json()
    const event = body.event

    if (!event) {
      return new Response(
        JSON.stringify({ error: 'Bad Request: Missing event object.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const userId = event.app_user_id
    const eventType = event.type
    
    console.log(`[RevenueCat Webhook] Ricevuto evento ${eventType} per l'utente ${userId}`)

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'No user ID provided in event.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase Client with service role key (bypass RLS for secure server updates)
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 3. Determine Pro Status based on Event Type & Active Entitlements
    let isPro = false;

    // Check actual active entitlements in the subscriber payload (most reliable method)
    const entitlements = event.subscriber?.entitlements || {}
    const evolvePro = entitlements['Evolve Pro']

    if (evolvePro) {
      const expiresDate = evolvePro.expires_date
      // If expires_date is null, it's a Lifetime purchase! Otherwise check if it has not expired yet.
      isPro = expiresDate === null || new Date(expiresDate) > new Date()
    } else {
      // Fallback evaluation based on event type if the entitlements block is absent
      if (
        eventType === 'INITIAL_PURCHASE' || 
        eventType === 'RENEWAL' || 
        eventType === 'UNCANCELLATION' || 
        eventType === 'TRANSFER'
      ) {
        isPro = true
      } else if (
        eventType === 'EXPIRATION' || 
        eventType === 'REFUND'
      ) {
        isPro = false
      }
    }

    console.log(`[RevenueCat Webhook] Impostazione is_pro = ${isPro} per l'utente: ${userId}`)

    // 4. Update the User Profile in Supabase
    const { error } = await supabase
      .from('profiles')
      .update({ is_pro: isPro })
      .eq('id', userId)

    if (error) {
      console.error(`[Error] Impossibile aggiornare la tabella profiles per ${userId}:`, error)
      return new Response(
        JSON.stringify({ error: 'Internal Server Error during database update.', details: error }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ success: true, is_pro: isPro }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[Error] Errore critico nel webhook:', error)
    return new Response(
      JSON.stringify({ error: 'Critical server error.', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
