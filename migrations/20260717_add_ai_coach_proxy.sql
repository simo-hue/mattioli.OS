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
  -- and a byte ceiling is the bound that actually matters for cost. ~4 chars per
  -- token, so 32000 ≈ 8k tokens ≈ $0.0024 at $0.30/M.
  --
  -- This clamp is the whole ballgame. `max_tokens` limits OUTPUT only and
  -- OpenRouter enforces NO input cap — the only input-side limit is the context
  -- window itself, and google/gemini-2.5-flash has 1,048,576 tokens of it. One
  -- crafted max-context request costs ~$0.31; a loop costs thousands per hour.
  -- Without this line the endpoint is an unmetered hole.
  max_input_chars integer NOT NULL DEFAULT 32000,

  -- Output ceiling. Gemini 2.5 Flash is a REASONING model: its reasoning tokens
  -- bill at the completion rate ($2.50/M) and never appear in the text we stream
  -- back, so they are invisible spend. max_tokens caps the completion budget
  -- they are drawn from.
  max_output_tokens integer NOT NULL DEFAULT 1000,

  -- Request windows. A real user talking to a coach sends maybe 100 messages a
  -- month, so these are ~10x a heavy human and no human will ever feel them.
  -- With the clamps above bounding a request at ~$0.005, the monthly ceiling
  -- bounds one account at ~$5 — against EUR 4.99/mo revenue, and only if someone
  -- deliberately maxes every window every day.
  max_per_10min integer NOT NULL DEFAULT 20,
  max_per_day integer NOT NULL DEFAULT 150,
  max_per_month integer NOT NULL DEFAULT 1000,

  model text NOT NULL DEFAULT 'google/gemini-2.5-flash',

  -- Provider pinning, and it is a compliance control rather than a preference.
  -- Guideline 5.1.2(i) requires disclosing WHO receives personal data. OpenRouter
  -- is a router: unpinned, it may fan out to providers we never named, which
  -- would make our disclosure untrue the moment it happened.
  --
  -- `google-vertex` is the only Zero-Data-Retention endpoint serving this model
  -- (google-ai-studio retains prompts for 55 days and would have to be disclosed
  -- as such). Conveniently, only Google serves gemini-2.5-flash at all, so the
  -- honest recipient list is short: OpenRouter, Inc. and Google LLC.
  --
  -- Changing this array changes who receives user data. Update the privacy
  -- policy and the in-app consent copy in the same breath, or the disclosure
  -- silently becomes a lie.
  providers text[] NOT NULL DEFAULT ARRAY['google-vertex'],

  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.ai_coach_limits IS
  'Singleton fair-use ceiling for the AI Coach proxy. Server-side so limits can '
  'be tuned without an App Store release. Service role only.';
COMMENT ON COLUMN public.ai_coach_limits.providers IS
  'Pinned OpenRouter provider slugs. This is the Guideline 5.1.2(i) recipient '
  'list — changing it changes who receives user data.';

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
