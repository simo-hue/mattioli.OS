-- Migration: Add verify_effective_from to goals table
-- Date: 2026-07-23
-- Purpose: Forward-only verification-rule edits (D10). The day the goal's
--          current verification rule took effect. Reconcile never rewrites
--          days before this date, so editing a threshold (or, later, a
--          compound condition set) no longer silently re-derives recent
--          history. Nullable and additive; NULL means "fall back to
--          start_date", so habits that predate this column keep their existing
--          behavior until the rule is next edited.
--
-- Design notes:
--   * Stored as a date (calendar day, local to the device that made the edit),
--     matching the day-keyed reconcile logic. Left UNCONSTRAINED for the same
--     reason as the verify_* columns — a value from a newer client must
--     round-trip rather than be rejected.
--   * The client stamps this to "today" on rule create and on any change to the
--     rule's verifiable content; it is preserved across non-rule edits (title,
--     color, reminder, schedule).
--   * Mirrors packages/evolve_sync PrivateDbSchema v7 (the SQLCipher/CloudKit
--     side) so the two backends stay column-compatible.

ALTER TABLE public.goals ADD COLUMN IF NOT EXISTS verify_effective_from date;

COMMENT ON COLUMN public.goals.verify_effective_from IS 'Day the current verification rule took effect (D10, forward-only edits). NULL = fall back to start_date. Reconcile never rewrites days before this date.';

-- No RLS change: goals policies are row-scoped by user_id and unaffected by
-- new columns.
