-- Backing tables for the AI Coach proxy (supabase/functions/ai-coach).
--
-- WHY THE PROXY EXISTS
-- App Store Guideline 3.1.1 rejected the app for enabling paid functionality
-- with a mechanism other than In-App Purchase: the user pasted their own
-- OpenRouter key. The compliant shape is the inverse — WE hold the key, and the
-- IAP subscription is what unlocks it. That makes every token a cost we pay, so
-- these two tables exist to bound it.
--
-- Neither table is ever touched by the apps. Only the Edge Function reads or
-- writes them, with the service role. RLS is enabled with no policy, which
-- denies every row to every non-owner role (the same posture as
-- 20260716_close_legacy_table_rls.sql), and the PostgREST grants are revoked so
-- the publishable key shipped inside both apps cannot reach them at all.
--
-- Deliberately NOT modelled on `ai_insights`: its `tokens_used` is writable by
-- the client under an `insert own` policy, which is exactly the hole a quota
-- must not have. A quota the client can edit is not a quota.

-- ---------------------------------------------------------------------------
-- ai_coach_limits — the fair-use ceiling, tunable without an App Store release
-- ---------------------------------------------------------------------------
-- A singleton row. Being server-side is the point: if abuse appears, the limits
-- move in seconds. Baking them into the Dart client would mean a build, a
-- review, and a week of waiting while someone drains the account.
CREATE TABLE IF NOT EXISTS public.ai_coach_limits (
  -- Singleton: `id` can only ever be true, so there is exactly one row.
  id boolean PRIMARY KEY DEFAULT true CHECK (id),

  -- Input is clamped in CHARACTERS, not tokens: the function has no tokenizer,
  -- and a byte ceiling is the bound that actually matters. ~4 chars per token,
  -- so 32000 ≈ 8k tokens.
  --
  -- Still the whole ballgame even on a FREE model. `max_tokens` limits OUTPUT
  -- only and OpenRouter enforces NO input cap; the only input-side limit is the
  -- context window, and the free tier's daily request quota is shared across the
  -- whole app (one OpenRouter account, one key). An unbounded request wastes a
  -- slot in that shared quota and can blow the model's context window — this
  -- clamp is what stops one crafted message from starving everyone.
  max_input_chars integer NOT NULL DEFAULT 32000,

  -- Output ceiling. gemma-4-26b-a4b is a reasoning model: its reasoning tokens
  -- never appear in the streamed text, so an uncapped completion runs long and
  -- slow for no visible benefit. Free means no bill, but the cap still bounds
  -- response length and keeps replies snappy.
  max_output_tokens integer NOT NULL DEFAULT 1000,

  -- Request windows. On the FREE tier these are the real ceiling that matters:
  -- OpenRouter caps a free model at 20 req/min and 50 req/day (1000/day once the
  -- account has ≥$10 of lifetime credits), PER ACCOUNT, globally — and the proxy
  -- is one shared account. These per-user windows exist so one user cannot drain
  -- that shared daily pool and lock everyone else out. Sized deliberately generous
  -- for the current handful of Pro users; tighten them if the base grows.
  max_per_10min integer NOT NULL DEFAULT 20,
  max_per_day integer NOT NULL DEFAULT 150,
  max_per_month integer NOT NULL DEFAULT 1000,

  -- The Pro proxy runs a FREE OpenRouter model, by explicit product decision
  -- (2026-07-17): the coach costs the developer nothing. The trade-off is that
  -- the free tier is not private the way a paid endpoint is — see the privacy
  -- columns below. To switch back to a paid, zero-retention model later, this is
  -- one UPDATE (model + providers + the two privacy columns) with NO redeploy —
  -- that is the entire point of these being columns.
  model text NOT NULL DEFAULT 'nvidia/nemotron-3-nano-30b-a3b:free',

  -- Provider pinning, and it is a compliance control rather than a preference.
  -- Guideline 5.1.2(i) requires disclosing WHO receives personal data. OpenRouter
  -- is a router: unpinned, it may fan out to providers we never named, which
  -- would make our disclosure untrue the moment it happened.
  --
  -- `google-ai-studio` is Google LLC's free endpoint for this model. Pinned to it
  -- ALONE (with allow_fallbacks off in the function) so the recipient list stays
  -- exactly OpenRouter, Inc. and Google LLC — the free model's only other server,
  -- Darkbloom, would otherwise become an unnamed recipient. This is the same
  -- two-company disclosure as before; only the Google product (AI Studio, not
  -- Vertex) and its data policy changed.
  --
  -- Changing this array changes who receives user data. Update the privacy
  -- policy and the in-app consent copy in the same breath, or the disclosure
  -- silently becomes a lie.
  providers text[] NOT NULL DEFAULT ARRAY['google-ai-studio'],

  -- The privacy posture sent to OpenRouter's provider router, kept in the table
  -- so it travels with the model choice rather than being hardcoded in the
  -- function — otherwise a future model swap via SQL could silently keep or drop
  -- the wrong posture. These are the 5.1.2(i) surface as much as `providers` is:
  -- they decide whether the endpoint may retain and learn from the data, which
  -- is exactly what the privacy policy discloses.
  --
  -- Both default to the FREE-tier reality: NOT zero-retention, and data
  -- collection allowed (Google AI Studio's free tier may retain prompts and use
  -- them to improve its services). A paid Vertex switch would set these back to
  -- true / 'deny' in the same UPDATE.
  zero_data_retention boolean NOT NULL DEFAULT false,
  data_collection text NOT NULL DEFAULT 'allow'
    CHECK (data_collection IN ('allow', 'deny')),

  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.ai_coach_limits IS
  'Singleton fair-use ceiling for the AI Coach proxy. Server-side so limits can '
  'be tuned without an App Store release. Service role only.';
COMMENT ON COLUMN public.ai_coach_limits.providers IS
  'Pinned OpenRouter provider slugs. This is the Guideline 5.1.2(i) recipient '
  'list — changing it changes who receives user data. Update the privacy policy '
  'and in-app consent copy in the same change.';
COMMENT ON COLUMN public.ai_coach_limits.zero_data_retention IS
  'Whether to restrict OpenRouter to Zero-Data-Retention endpoints (zdr). false '
  'on the free tier, which offers none. Part of the 5.1.2(i) disclosure.';
COMMENT ON COLUMN public.ai_coach_limits.data_collection IS
  'OpenRouter provider data_collection policy: allow | deny. allow on the free '
  'tier. deny requires a paid endpoint. Part of the 5.1.2(i) disclosure.';

INSERT INTO public.ai_coach_limits (id) VALUES (true) ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- ai_coach_usage — one row per proxied request
-- ---------------------------------------------------------------------------
-- Counts REQUESTS, not tokens, deliberately. Token accounting would mean parsing
-- usage out of the last SSE chunk and reconciling it after the fact; counting
-- requests is exact, auditable, and — because every request is clamped on both
-- ends — bounds cost just as tightly for a fraction of the machinery.
CREATE TABLE IF NOT EXISTS public.ai_coach_usage (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  -- ON DELETE CASCADE so account deletion takes the usage history with it; the
  -- app already promises deletion removes everything.
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  used_at timestamptz NOT NULL DEFAULT now()
);

-- Every quota question is "how many rows for this user since T", so this index
-- serves all three windows and the retention prune.
CREATE INDEX IF NOT EXISTS ai_coach_usage_user_time_idx
  ON public.ai_coach_usage (user_id, used_at DESC);

COMMENT ON TABLE public.ai_coach_usage IS
  'One row per AI Coach request served through the proxy. Service role only — a '
  'quota the client can write is not a quota. Pruned to ~40 days by the Edge '
  'Function.';

-- ---------------------------------------------------------------------------
-- Lock both tables away from the apps
-- ---------------------------------------------------------------------------
-- RLS enabled with NO policy denies every row to every non-owner role. The
-- service role bypasses RLS, which is how the Edge Function reaches them. The
-- REVOKEs are belt and braces: without a grant PostgREST will not expose the
-- table even if a policy is ever added by accident.
ALTER TABLE public.ai_coach_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_coach_usage ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.ai_coach_limits FROM anon, authenticated;
REVOKE ALL ON public.ai_coach_usage FROM anon, authenticated;
