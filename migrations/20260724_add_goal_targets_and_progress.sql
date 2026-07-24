-- Migration: Quantitative habit targets — goals.target + the goal_progress table
-- Date: 2026-07-24
-- Purpose: A habit may carry a numeric daily target instead of being a pure
--          checkbox: "80 push-ups", "20 minutes", "at most 1 coffee". The
--          target lives on `goals` as an opaque versioned JSON envelope; the
--          number accumulated on a given day lives in a new `goal_progress`
--          table, one row per habit-day.
--
-- Mirrors packages/evolve_sync PrivateDbSchema v9 so the two backends stay
-- column-compatible. Both halves are additive and nullable/new — no existing
-- row, query, RPC or client is affected, and an app build predating this
-- migration keeps working unchanged.
--
-- WHY PROGRESS IS NOT ON goal_logs (the decision this migration encodes):
--   * `goal_logs.status` is CHECK-constrained to ('done','missed','skipped').
--     A day that is 40 of 80 done has no honest value in that set. Writing
--     'missed' would enter four rate denominators that today count only LOGGED
--     rows (get_best_habits, get_habit_performance_by_day, get_habit_analytics,
--     habit_stats), so a user who engages daily but rarely finishes would score
--     WORSE than one who ignores the habit entirely. Widening the CHECK is
--     worse still: the private-mode sync engine quarantines rows whose status
--     it does not recognise, so every device on an older build would park the
--     row instead of storing it.
--   * `goal_logs.value` is not free either. Three separate guards null it, one
--     of them deliberately on every manual toggle, and it carries the
--     documented health-measurement privacy rule.
--   Keeping progress in its own table leaves `goal_logs` as purely the VERDICT
--   record. All 11 analytics objects over goal_logs keep working untouched, and
--   an unfinished day stays out of every denominator while still rendering.

-- ---------------------------------------------------------------------------
-- 1. goals.target
-- ---------------------------------------------------------------------------

-- TEXT, not jsonb, for the same reason as verify_conditions: the client stores
-- the SAME opaque JSON string on both backends, and PostgREST would
-- double-encode it into a jsonb string value rather than an object. Validity is
-- enforced in the client (decodeHabitTarget), which also lets a target written
-- by a newer client round-trip through an older one instead of being rejected.
ALTER TABLE public.goals ADD COLUMN IF NOT EXISTS target text;

COMMENT ON COLUMN public.goals.target IS 'Quantitative target: JSON string {v,src,dir,per,agg,amount,unit,step,input,preset} (package:evolve_targets). NULL = ordinary boolean habit.';

-- ---------------------------------------------------------------------------
-- 2. goal_progress
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.goal_progress (
    -- DETERMINISTIC: '<goal_id>:<date>'. Not a uuid, and not cosmetic — with
    -- random ids two devices logging the same habit-day mint two rows for one
    -- natural key, and the private-mode pull resolves that by DELETING the
    -- loser. A shared id makes it an ordinary last-write-wins instead.
    id text NOT NULL PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    goal_id uuid REFERENCES public.goals(id) ON DELETE CASCADE NOT NULL,
    date date NOT NULL,
    -- The total accumulated for the period so far, NOT a delta. Sync is a
    -- whole-row last-write-wins with no column-aware merge, so a delta column
    -- would silently double-count or drop increments on replay.
    amount numeric NOT NULL,
    -- 'manual' | 'healthkit' | 'screentime'. Unconstrained by deliberate policy,
    -- matching verify_provider: a source added by a newer client must round-trip
    -- rather than be rejected.
    --
    -- It also makes the health-privacy rule a fact on the row rather than a
    -- guess through the goal: the client uploads a row only when source =
    -- 'manual', so an Apple-measured quantity cannot reach this table. That is
    -- the same rule already applied to goal_logs.value, stated locally instead
    -- of inferred (today's inference defaults an unresolvable goal to "health").
    source text NOT NULL DEFAULT 'manual',
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT goal_progress_goal_id_date_key UNIQUE (goal_id, date)
);

CREATE INDEX IF NOT EXISTS idx_goal_progress_user_date
    ON public.goal_progress (user_id, date DESC);

ALTER TABLE public.goal_progress ENABLE ROW LEVEL SECURITY;

-- Row-scoped by user_id, identical in shape to the goals / goal_logs policies.
DROP POLICY IF EXISTS "Users can view their own goal progress" ON public.goal_progress;
CREATE POLICY "Users can view their own goal progress" ON public.goal_progress
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own goal progress" ON public.goal_progress;
CREATE POLICY "Users can insert their own goal progress" ON public.goal_progress
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own goal progress" ON public.goal_progress;
CREATE POLICY "Users can update their own goal progress" ON public.goal_progress
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own goal progress" ON public.goal_progress;
CREATE POLICY "Users can delete their own goal progress" ON public.goal_progress
    FOR DELETE USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS update_goal_progress_updated_at ON public.goal_progress;
CREATE TRIGGER update_goal_progress_updated_at
    BEFORE UPDATE ON public.goal_progress
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

COMMENT ON TABLE public.goal_progress IS 'One accumulated progress number per habit-day for quantitative habits. goal_logs stays the verdict record; this table is the raw number, so a partially-completed day is visible without entering any completion-rate denominator.';

-- No analytics RPC is changed by this migration. That is the point: a target
-- habit still materialises an ordinary goal_logs 'done'/'missed' row when its
-- day resolves, so every existing function and view keeps scoring it exactly as
-- it scores a checkbox habit.
