-- Migration: Add verify_conditions to goals table
-- Date: 2026-07-23
-- Purpose: Compound verifiable habits (Q1–Q5). A JSON string
--          {"v":1,"op":"or"|"and","conditions":[{provider,metric,comparator,
--          threshold,unit}, ...]} joining 2..3 auto-verified conditions
--          (e.g. "10k steps OR 30 min exercise"). When set, the flat verify_*
--          columns are NULL — so a pre-compound client reads the habit as
--          manual and never mis-verifies it. Nullable, additive, backwards-
--          compatible.
--
-- Design notes:
--   * TEXT, not jsonb, on purpose: the client stores the SAME opaque JSON string
--     on both backends (SQLite TEXT + here). Sending that string to a jsonb
--     column via PostgREST would double-encode it (a jsonb string value, not the
--     object). The value is parsed/validated in the client (decodeVerifyConditions),
--     which also lets a set from a newer client round-trip rather than be rejected.
--   * Mirrors packages/evolve_sync PrivateDbSchema v8 so the two backends stay
--     column-compatible.

ALTER TABLE public.goals ADD COLUMN IF NOT EXISTS verify_conditions text;

COMMENT ON COLUMN public.goals.verify_conditions IS 'Compound verifiable habit: JSON string {v,op,conditions:[...]} joining 2-3 conditions (Q1-Q5). When set, the flat verify_* columns are NULL. NULL = single-rule or manual habit.';

-- No RLS change: goals policies are row-scoped by user_id and unaffected by
-- new columns.
