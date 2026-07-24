-- Migration: Add target_effective_from to goals table
-- Date: 2026-07-24
-- Purpose: Forward-only quantitative-target edits. The day the goal's current
--          `target` took effect. The manual-target end-of-day sweep never
--          rewrites days before this date, so editing a target's amount (or
--          changing a habit's tracking class) applies forward instead of
--          retroactively re-deriving past done/missed verdicts. Nullable and
--          additive; NULL means "fall back to start_date", so habits that
--          predate this column keep their existing behaviour until the target
--          is next edited.
--
-- Design notes:
--   * Direct analogue of goals.verify_effective_from (the D10 rule anchor). A
--     target is the same kind of forward-only definition as a verification rule,
--     so it gets the same anchor treatment.
--   * Stored as a date (calendar day, local to the device that made the edit),
--     matching the day-keyed reconcile logic. Left UNCONSTRAINED for the same
--     reason as the target / verify_* columns — a value from a newer client must
--     round-trip rather than be rejected.
--   * The client stamps this to "today" on target create and on any change to
--     the target's content; it is preserved across non-target edits (title,
--     color, reminder, schedule).
--   * Mirrors packages/evolve_sync PrivateDbSchema v11 (the SQLCipher/CloudKit
--     side) so the two backends stay column-compatible.

ALTER TABLE public.goals ADD COLUMN IF NOT EXISTS target_effective_from date;

COMMENT ON COLUMN public.goals.target_effective_from IS 'Day the current quantitative target took effect (v11, forward-only edits). NULL = fall back to start_date. The manual-target sweep never rewrites days before this date.';

-- No RLS change: goals policies are row-scoped by user_id and unaffected by
-- new columns.
