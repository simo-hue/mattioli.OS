import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Constant-time comparison. Both sides are hashed first so the two fixed-length
// digests can be compared with no early exit and no length branch.
async function secureEquals(a: string, b: string): Promise<boolean> {
  const encoder = new TextEncoder()
  const [digestA, digestB] = await Promise.all([
    crypto.subtle.digest('SHA-256', encoder.encode(a)),
    crypto.subtle.digest('SHA-256', encoder.encode(b)),
  ])
  const bytesA = new Uint8Array(digestA)
  const bytesB = new Uint8Array(digestB)
  let diff = 0
  for (let i = 0; i < bytesA.length; i++) {
    diff |= bytesA[i] ^ bytesB[i]
  }
  return diff === 0
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Authenticate the caller.
    // RevenueCat cannot mint a Supabase JWT, so config.toml has to keep
    // verify_jwt = false and the shared secret it sends in the Authorization
    // header is the only authentication this endpoint has. Without the secret
    // configured there is no way to tell RevenueCat from an anonymous caller, and
    // the service role client below bypasses RLS on any app_user_id in the body —
    // so an unconfigured secret must refuse every request, never wave them through.
    const webhookSecret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET')

    if (!webhookSecret) {
      console.error('[RevenueCat Webhook] REVENUECAT_WEBHOOK_SECRET non configurato: richiesta rifiutata.')
      return new Response(
        JSON.stringify({ error: 'Webhook is not configured.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const authHeader = req.headers.get('Authorization') ?? ''

    if (!(await secureEquals(authHeader, `Bearer ${webhookSecret}`))) {
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

    // 3. Decide how this event affects the "Evolve Pro" entitlement.
    //
    // RevenueCat WEBHOOK payloads do NOT carry event.subscriber.entitlements —
    // that nested map is the REST /subscribers (CustomerInfo) shape, not the
    // webhook event shape. An earlier version keyed off it, so the lookup was
    // always empty and every event fell through to a type check that recognised
    // only a few types and left is_pro at its `false` initializer for all the
    // rest (BILLING_ISSUE, PRODUCT_CHANGE, CANCELLATION, SUBSCRIPTION_PAUSED,
    // ...), silently revoking Pro from paying users. We classify by event.type,
    // which is the field the webhook actually sends.
    //
    // Type is preferred over deriving from expiration_at_ms: the
    // expiration-in-the-future heuristic misclassifies three still-entitled
    // cases — lifetime purchases (no expiration), the billing-issue grace period
    // (expiration already passed but access continues), and temporary grants
    // (often no expiration).
    const GRANT_EVENTS = new Set([
      'INITIAL_PURCHASE',
      'RENEWAL',
      'UNCANCELLATION',
      'PRODUCT_CHANGE',            // plan switch: still subscribed
      'SUBSCRIPTION_EXTENDED',
      'TEMPORARY_ENTITLEMENT_GRANT',
      'TRANSFER',                  // grant to the receiving app_user_id
      'BILLING_ISSUE',             // grace period: renewal failed but still entitled
    ])
    const REVOKE_EVENTS = new Set([
      'EXPIRATION',
      'REFUND',
      'SUBSCRIPTION_PAUSED',       // access stops once the pause takes effect
    ])

    // CANCELLATION only disables auto-renew; access continues until EXPIRATION,
    // so it must NOT revoke here. It — and every unknown/ambiguous type — leaves
    // is_pro untouched: we early-return 200 without writing rather than ever
    // default-writing false.
    let intendedIsPro: boolean
    if (GRANT_EVENTS.has(eventType)) {
      intendedIsPro = true
    } else if (REVOKE_EVENTS.has(eventType)) {
      intendedIsPro = false
    } else {
      console.log(`[RevenueCat Webhook] Evento ${eventType} non modifica l'entitlement: nessuna scrittura per ${userId}.`)
      return new Response(
        JSON.stringify({ success: true, ignored: true, type: eventType }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 4. Load the current profile first. A blind update reports success even
    // when it matches zero rows, so reading lets us (a) make the write
    // idempotent — absorbing exact redeliveries — and (b) detect a missing row.
    // maybeSingle() returns data=null (not an error) when no row matches.
    const { data: profile, error: readError } = await supabase
      .from('profiles')
      .select('id, is_pro')
      .eq('id', userId)
      .maybeSingle()

    if (readError) {
      console.error(`[Error] Impossibile leggere il profilo per ${userId}:`, readError)
      return new Response(
        JSON.stringify({ error: 'Internal Server Error during database read.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!profile) {
      // No profile row matches this app_user_id. RevenueCat anonymous ids
      // ($RCAnonymousID:...) come from purchases made before the account was
      // linked; they will never map to a profile, so retrying is futile — ack
      // with 200 and warn instead of forcing RevenueCat to retry forever.
      if (typeof userId === 'string' && userId.startsWith('$RCAnonymousID:')) {
        console.warn(`[RevenueCat Webhook] app_user_id anonimo ${userId}: nessun profilo da aggiornare, evento ignorato.`)
        return new Response(
          JSON.stringify({ success: true, ignored: true, reason: 'anonymous_app_user_id' }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      // A real (non-anonymous) id with no row is usually a race: the webhook
      // beat profile creation. Dropping an entitlement grant here would silently
      // lose a paying user, so fail non-2xx and let RevenueCat retry until the
      // row exists. A revoke has nothing to strip, so ack.
      if (intendedIsPro) {
        console.error(`[Error] Nessun profilo per ${userId} su evento ${eventType}: rispondo 500 per forzare il retry di RevenueCat.`)
        return new Response(
          JSON.stringify({ error: 'Profile not found; retry expected.' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      console.warn(`[RevenueCat Webhook] Nessun profilo per ${userId} su evento di revoca ${eventType}: nulla da revocare.`)
      return new Response(
        JSON.stringify({ success: true, ignored: true, reason: 'no_profile_row' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Idempotent: nothing to do when the stored state already matches.
    if (profile.is_pro === intendedIsPro) {
      console.log(`[RevenueCat Webhook] is_pro già ${intendedIsPro} per ${userId}: nessuna scrittura.`)
      return new Response(
        JSON.stringify({ success: true, is_pro: intendedIsPro, unchanged: true }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[RevenueCat Webhook] Impostazione is_pro = ${intendedIsPro} per l'utente: ${userId}`)

    // 5. Apply the change and confirm a row was actually written. .select()
    // returns the updated rows, so a zero-row match is not mistaken for success.
    const { data: updated, error } = await supabase
      .from('profiles')
      .update({ is_pro: intendedIsPro })
      .eq('id', userId)
      .select('id')

    if (error) {
      console.error(`[Error] Impossibile aggiornare la tabella profiles per ${userId}:`, error)
      return new Response(
        JSON.stringify({ error: 'Internal Server Error during database update.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!updated || updated.length === 0) {
      // The row vanished between the read and the write. Same policy as a
      // missing row above: retry a lost grant, ack a lost revoke.
      if (intendedIsPro) {
        console.error(`[Error] Update di is_pro ha toccato 0 righe per ${userId}: rispondo 500 per il retry.`)
        return new Response(
          JSON.stringify({ error: 'Profile row vanished; retry expected.' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      console.warn(`[RevenueCat Webhook] Update di is_pro ha toccato 0 righe per ${userId} (revoca): nulla da revocare.`)
      return new Response(
        JSON.stringify({ success: true, ignored: true, reason: 'no_profile_row' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ success: true, is_pro: intendedIsPro }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[Error] Errore critico nel webhook:', error)
    return new Response(
      JSON.stringify({ error: 'Critical server error.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
