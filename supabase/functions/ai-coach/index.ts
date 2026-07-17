// AI Coach proxy — OpenRouter chat completions for paying subscribers.
//
// WHY THIS EXISTS
// App Store Guideline 3.1.1 rejected the app for enabling paid functionality
// with a mechanism other than In-App Purchase: users pasted their own OpenRouter
// key. The compliant shape is the inverse — we hold the key, and the IAP
// subscription unlocks it. The key lives ONLY here: a compile-time constant in
// the Dart app is recoverable from the AOT snapshot with `strings`, which is why
// the previous one had to be revoked.
//
// Bring-your-own-key still exists in the apps, free, for anyone who prefers it —
// notably Private mode, which has no account and therefore can never reach this
// function.
//
// WHAT THIS GUARDS, AND WHY EACH GUARD IS HERE
//  1. Identity comes from the caller's JWT, never from the body.
//  2. Entitlement is read server-side from profiles.is_pro, which only the
//     RevenueCat webhook can write (pinned by a BEFORE trigger).
//  3. Input is clamped in characters. OpenRouter enforces NO input cap and
//     gemini-2.5-flash has a 1,048,576-token context, so one crafted request is
//     ~$0.31 and a loop is thousands per hour. This is the hole.
//  4. Output is clamped via max_tokens — which also bounds Gemini's reasoning
//     tokens, billed at the completion rate and invisible in the streamed text.
//  5. Providers are PINNED. Guideline 5.1.2(i) requires naming who receives
//     personal data; an unpinned router may fan out to providers we never named.
//  6. Quotas bound one account's monthly spend.
//
// Deploy:  supabase functions deploy ai-coach
// Secret:  supabase secrets set OPENROUTER_API_KEY=...   (Simone runs this)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions'

// Fallbacks for a first deploy before the limits row exists. They mirror the
// column defaults in migrations/20260717_add_ai_coach_proxy.sql; the table is
// the source of truth, and the whole point of it being a table is that these are
// tunable without an App Store release.
const FALLBACK_LIMITS: Limits = {
  max_input_chars: 32000,
  max_output_tokens: 1000,
  max_per_10min: 20,
  max_per_day: 150,
  max_per_month: 1000,
  model: 'google/gemini-2.5-flash',
  providers: ['google-vertex'],
}

interface Limits {
  max_input_chars: number
  max_output_tokens: number
  max_per_10min: number
  max_per_day: number
  max_per_month: number
  model: string
  providers: string[]
}

function json(body: unknown, status: number) {
  return new Response(
    JSON.stringify(body),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  )
}

/** Machine-readable `code` so the client can say something specific. */
function fail(code: string, message: string, status: number) {
  return json({ error: { code, message } }, status)
}

/**
 * Total characters the caller is asking us to pay for.
 *
 * Exported for tests: this is the only thing standing between us and a
 * 1,048,576-token context at $0.30/M.
 */
export function totalInputChars(messages: { content: string }[]): number {
  return messages.reduce((sum, m) => sum + m.content.length, 0)
}

/** Which quota window (if any) this request would break. */
export function quotaExceeded(
  stampsMs: number[],
  nowMs: number,
  limits: Pick<Limits, 'max_per_10min' | 'max_per_day' | 'max_per_month'>,
): 'per_10min' | 'per_day' | 'per_month' | null {
  const since = (ms: number) => stampsMs.filter((t) => t >= nowMs - ms).length
  if (since(10 * 60 * 1000) >= limits.max_per_10min) return 'per_10min'
  if (since(24 * 60 * 60 * 1000) >= limits.max_per_day) return 'per_day'
  if (stampsMs.length >= limits.max_per_month) return 'per_month'
  return null
}

export interface StreamObservations {
  /** The provider that actually served the request, per the chunks themselves. */
  provider: string | null
  /** Mid-stream errors, which arrive as ordinary data: events on an HTTP 200. */
  errors: unknown[]
}

/**
 * Passes the upstream stream through untouched while reading it in passing.
 *
 * Buffering (`await upstream.text()`) would turn a streaming coach into a
 * ten-second stare at a spinner. But we still need to see the chunks: each one
 * names the provider that served it, which is the only runtime proof the pin
 * held — and mid-stream errors arrive as ordinary `data:` events on an HTTP 200,
 * so a status check never sees them.
 *
 * The parsing is deliberately defensive. OpenRouter interleaves
 * `: OPENROUTER PROCESSING` keep-alive comments, and a chunk boundary can split
 * a JSON payload in half; either will throw in JSON.parse, and an unhandled
 * throw in a transform kills the user's stream. Nothing observed here may ever
 * break the pass-through.
 */
export function observeSseStream(
  onChunk?: (o: StreamObservations) => void,
): { stream: TransformStream<Uint8Array, Uint8Array>; observations: StreamObservations } {
  const decoder = new TextDecoder()
  const observations: StreamObservations = { provider: null, errors: [] }
  // Holds the trailing partial line between chunks, so a payload split across a
  // boundary is parsed once it is whole rather than dropped or half-parsed.
  let pending = ''

  const stream = new TransformStream<Uint8Array, Uint8Array>({
    transform(chunk, controller) {
      controller.enqueue(chunk) // forward first: the user never waits on us
      try {
        pending += decoder.decode(chunk, { stream: true })
        const lines = pending.split('\n')
        pending = lines.pop() ?? '' // last element is partial until a \n arrives
        for (const raw of lines) {
          const line = raw.trim()
          // `: OPENROUTER PROCESSING` and friends. JSON.parse on one throws.
          if (!line.startsWith('data:')) continue
          const payload = line.slice(5).trim()
          if (payload === '' || payload === '[DONE]') continue
          let parsed: Record<string, unknown>
          try {
            parsed = JSON.parse(payload)
          } catch {
            continue // malformed or truncated; never fatal
          }
          if (typeof parsed.provider === 'string') observations.provider = parsed.provider
          if (parsed.error) observations.errors.push(parsed.error)
        }
        onChunk?.(observations)
      } catch (e) {
        // Observation is best-effort. The stream is not.
        console.error('[AI Coach] Observer failed (stream unaffected)', e)
      }
    },
  })

  return { stream, observations }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return fail('method_not_allowed', 'Use POST.', 405)

  try {
    // 1. Fail closed on missing configuration. Returning a cheerful 200 here
    //    would leave the coach silently dead for every subscriber.
    const openRouterKey = Deno.env.get('OPENROUTER_API_KEY')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    const missing = Object.entries({
      OPENROUTER_API_KEY: openRouterKey,
      SUPABASE_URL: supabaseUrl,
      SUPABASE_ANON_KEY: anonKey,
      SUPABASE_SERVICE_ROLE_KEY: serviceKey,
    }).filter(([, v]) => !v).map(([k]) => k)

    if (missing.length > 0) {
      console.error(`[AI Coach] Missing required secrets: ${missing.join(', ')}`)
      return fail('not_configured', 'The AI Coach is not configured.', 500)
    }

    // 2. Identity from the caller's own JWT. Never trust a user id in the body:
    //    that would let anyone spend on anyone else's quota.
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return fail('unauthorized', 'Missing Authorization header.', 401)
    }

    const asUser = createClient(supabaseUrl!, anonKey!, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: { user }, error: userError } = await asUser.auth.getUser()
    if (userError || !user) {
      return fail('unauthorized', 'Invalid or expired session.', 401)
    }

    // Service role for everything the client must not be able to read or forge:
    // the quota ledger and the limits. RLS denies both to anon/authenticated.
    const asAdmin = createClient(supabaseUrl!, serviceKey!, {
      auth: { persistSession: false },
    })

    // 3. Entitlement, server-side. profiles.is_pro is real server state — the
    //    RevenueCat webhook is its only writer, pinned by a BEFORE trigger
    //    (20260716_pin_profiles_entitlement_columns.sql), so a client cannot
    //    PATCH itself Pro.
    //
    //    is_pro is the ONLY guard, deliberately. profiles.pro_expires_at exists
    //    in the schema but the webhook never writes it, so it is always NULL —
    //    checking it would either deny everyone or grant everyone forever,
    //    depending on which way the predicate fell.
    const { data: profile, error: profileError } = await asAdmin
      .from('profiles')
      .select('is_pro')
      .eq('id', user.id)
      .maybeSingle()

    if (profileError) {
      console.error(`[AI Coach] Entitlement lookup failed for ${user.id}`, profileError)
      return fail('server_error', 'Could not verify the subscription.', 500)
    }
    if (!profile?.is_pro) {
      // Not an error: the app offers a free bring-your-own-key mode, and this
      // code is what tells it to say so.
      return fail('not_subscribed', 'Evolve Pro is required for this mode.', 403)
    }

    // 4. Limits. A missing row is not fatal — fall back rather than take the
    //    coach down for everyone over a bootstrapping detail.
    const { data: limitsRow, error: limitsError } = await asAdmin
      .from('ai_coach_limits')
      .select('*')
      .eq('id', true)
      .maybeSingle()

    if (limitsError) {
      console.error('[AI Coach] Limits lookup failed; using fallbacks', limitsError)
    }
    const limits: Limits = { ...FALLBACK_LIMITS, ...(limitsRow ?? {}) }

    // 5. Validate and clamp the request.
    const body = await req.json().catch(() => null)
    if (!body || !Array.isArray(body.messages) || body.messages.length === 0) {
      return fail('bad_request', 'messages must be a non-empty array.', 400)
    }

    const messages = body.messages
    for (const m of messages) {
      if (
        typeof m !== 'object' || m === null ||
        typeof m.role !== 'string' || typeof m.content !== 'string'
      ) {
        return fail('bad_request', 'Each message needs a string role and content.', 400)
      }
      if (!['system', 'user', 'assistant'].includes(m.role)) {
        return fail('bad_request', `Unsupported role: ${m.role}`, 400)
      }
    }

    // THE cost guard. Reject rather than truncate: silently dropping the middle
    // of someone's conversation bills us for a request that answers a question
    // they did not ask.
    const totalChars = totalInputChars(messages)
    if (totalChars > limits.max_input_chars) {
      return fail(
        'context_too_long',
        `The conversation is too long (${totalChars} of ${limits.max_input_chars} characters). Clear the chat and try again.`,
        413,
      )
    }

    // 6. Quota. Counting rows in three windows over one index.
    const now = Date.now()
    const monthAgo = new Date(now - 30 * 24 * 60 * 60 * 1000).toISOString()
    const { data: recent, error: usageError } = await asAdmin
      .from('ai_coach_usage')
      .select('used_at')
      .eq('user_id', user.id)
      .gte('used_at', monthAgo)

    if (usageError) {
      // Fail CLOSED. An unreadable ledger means an unbounded bill, and the bill
      // is ours.
      console.error(`[AI Coach] Usage lookup failed for ${user.id}`, usageError)
      return fail('server_error', 'Could not check your usage.', 500)
    }

    const stamps = (recent ?? []).map((r: { used_at: string }) => Date.parse(r.used_at))
    const exceeded = quotaExceeded(stamps, now, limits)

    if (exceeded) {
      console.warn(`[AI Coach] Quota ${exceeded} hit by ${user.id}`)
      return fail(
        'rate_limited',
        'You have reached the AI Coach usage limit. Please try again later.',
        429,
      )
    }

    // 7. Reserve the slot BEFORE spending. Recording afterwards would let a
    //    client abort mid-stream and never be counted, which is a free
    //    unlimited endpoint for anyone who notices. Refunded below if OpenRouter
    //    never starts.
    const { data: reservation, error: reserveError } = await asAdmin
      .from('ai_coach_usage')
      .insert({ user_id: user.id })
      .select('id')
      .single()

    if (reserveError) {
      console.error(`[AI Coach] Could not reserve a slot for ${user.id}`, reserveError)
      return fail('server_error', 'Could not start the request.', 500)
    }

    const refund = async () => {
      await asAdmin.from('ai_coach_usage').delete().eq('id', reservation.id)
    }

    // 8. Upstream.
    //
    //    `only` is the hard restriction: `order` merely PRIORITISES and would
    //    still let the router reach anyone. `allow_fallbacks` defaults to TRUE
    //    and must be turned off explicitly, or the pin leaks the moment the
    //    pinned provider hiccups. `zdr: true` restricts to Zero-Data-Retention
    //    endpoints. Together they make the recipient list in our privacy policy
    //    true rather than aspirational.
    //
    //    No HTTP-Referer / X-OpenRouter-Title: both are optional for a server
    //    proxy and exist to list the app publicly in OpenRouter's rankings.
    let upstream: Response
    try {
      upstream = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openRouterKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: limits.model,
          messages,
          stream: true,
          max_tokens: limits.max_output_tokens,
          provider: {
            only: limits.providers,
            allow_fallbacks: false,
            zdr: true,
            data_collection: 'deny',
          },
        }),
      })
    } catch (e) {
      await refund()
      console.error('[AI Coach] Upstream unreachable', e)
      return fail('upstream_unavailable', 'The AI Coach is unavailable right now.', 502)
    }

    if (!upstream.ok || !upstream.body) {
      // Nothing was generated, so nothing was billed: give the slot back.
      await refund()
      const detail = await upstream.text().catch(() => '')
      console.error(`[AI Coach] Upstream ${upstream.status} for ${user.id}: ${detail.slice(0, 500)}`)
      // Deliberately not forwarding OpenRouter's body: it names our vendor and,
      // on 402, our billing state. Neither is the user's business.
      const code = upstream.status === 429 ? 'upstream_rate_limited' : 'upstream_error'
      return fail(code, 'The AI Coach is unavailable right now.', 502)
    }

    // 9. Stream through, observing without buffering. See observeSseStream.
    let lastErrorCount = 0
    const { stream: observer, observations } = observeSseStream((o) => {
      // Log mid-stream errors as they land: they arrive as ordinary data: events
      // on an HTTP 200, so nothing else would ever surface them.
      for (let i = lastErrorCount; i < o.errors.length; i++) {
        console.error(`[AI Coach] Mid-stream error for ${user.id}: ${JSON.stringify(o.errors[i])}`)
      }
      lastErrorCount = o.errors.length

      // Runtime proof that the provider pin held. OpenRouter's docs say a
      // per-request `only` list is "merged" with any account-wide allowlist
      // without defining whether that means union or intersection — so assert
      // what actually served the request rather than trusting what we asked for.
      // If this ever fires, our privacy policy names the wrong recipient and
      // Guideline 5.1.2(i) is breached until it is fixed.
      if (observations.provider && !limits.providers.includes(observations.provider)) {
        console.error(
          `[AI Coach] PROVIDER PIN LEAKED: served by "${observations.provider}", ` +
          `pinned to ${JSON.stringify(limits.providers)}. The disclosed recipient ` +
          `list is wrong until this is resolved.`,
        )
      }
    })

    // 10. Opportunistic retention prune, for this user only. Keeps the ledger
    //     bounded without a scheduled job; ~40 days covers the 30-day window
    //     with room to spare. Not awaited — the user's stream does not wait on
    //     housekeeping.
    const cutoff = new Date(now - 40 * 24 * 60 * 60 * 1000).toISOString()
    asAdmin.from('ai_coach_usage')
      .delete()
      .eq('user_id', user.id)
      .lt('used_at', cutoff)
      .then(({ error }) => {
        if (error) console.warn('[AI Coach] Retention prune failed', error)
      })

    return new Response(upstream.body.pipeThrough(observer), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    })
  } catch (error) {
    console.error('[AI Coach] Unexpected error', error)
    return fail('server_error', 'Critical server error.', 500)
  }
})
