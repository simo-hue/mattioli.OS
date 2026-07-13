-- Migration: Add verification-rule columns to goals table
-- Date: 2026-07-13
-- Purpose: Auto-verified habits. A goal may carry a verification rule that is
--          checked automatically from Apple data (HealthKit / Screen Time) on
--          iOS. All columns are nullable; all-null means an ordinary manual
--          habit. Additive and backwards-compatible.
--
-- Design notes:
--   * Left UNCONSTRAINED (no CHECK) on purpose — a rule created by a newer
--     client (a future provider/metric/unit) must round-trip through the cloud
--     rather than be rejected. Validity is enforced in the client.
--   * verify_threshold is numeric (e.g. 10000 steps, 120 minutes, 8 hours).
--   * The measured value for a HealthKit verdict reuses the existing
--     goal_logs.value column; Screen Time verdicts leave it null (binary).
--   * Mirrors packages/evolve_sync PrivateDbSchema v4 (the SQLCipher/CloudKit
--     side) so the two backends stay column-compatible.

ALTER TABLE public.goals ADD COLUMN IF NOT EXISTS verify_provider text;
ALTER TABLE public.goals ADD COLUMN IF NOT EXISTS verify_metric text;
ALTER TABLE public.goals ADD COLUMN IF NOT EXISTS verify_comparator text;
ALTER TABLE public.goals ADD COLUMN IF NOT EXISTS verify_threshold numeric;
ALTER TABLE public.goals ADD COLUMN IF NOT EXISTS verify_unit text;

COMMENT ON COLUMN public.goals.verify_provider IS 'Auto-verification data source: healthkit | screentime. NULL = manual habit.';
COMMENT ON COLUMN public.goals.verify_metric IS 'Verification template key, e.g. steps, sleep_hours, screen_time_total.';
COMMENT ON COLUMN public.goals.verify_comparator IS 'Threshold direction: gte (reach a target) | lte (stay under a limit).';
COMMENT ON COLUMN public.goals.verify_threshold IS 'Numeric threshold in verify_unit (e.g. 10000 steps, 120 minutes).';
COMMENT ON COLUMN public.goals.verify_unit IS 'Unit of verify_threshold: count | minutes | hours | kilocalories | kilometers.';

-- No RLS change: goals policies are row-scoped by user_id and unaffected by
-- new columns.
