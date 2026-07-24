-- Migration: Cumulative numeric macro goals — long_term_goals gains an optional
--            numeric target fed manually or by a linked habit.
-- Date: 2026-07-24
-- Purpose: Today a macro goal (long_term_goals) is boolean: active / completed /
--          failed, no numbers. This adds an OPTIONAL numeric target ("run 500 km
--          this year", "read 24 books") with a real progress bar. Progress is
--          DERIVED — summed from a linked habit's daily goal_progress over the
--          goal's period — when linked_goal_id is set (self-healing, survives
--          retroactive edits), and STORED in progress_amount for a manual-entry
--          numeric goal (no link).
--
-- Mirrors packages/evolve_sync PrivateDbSchema v10 so the two backends stay
-- column-compatible. All four columns are additive and nullable — no existing
-- row, query, RPC or client is affected, and an app build predating this
-- migration keeps working unchanged (a NULL target_amount is exactly the
-- current boolean macro goal).

-- ---------------------------------------------------------------------------
-- long_term_goals numeric-target columns
-- ---------------------------------------------------------------------------

-- The number to reach. NULL => an ordinary boolean macro goal (unchanged).
ALTER TABLE public.long_term_goals ADD COLUMN IF NOT EXISTS target_amount numeric;

-- A TargetUnit wire name (count / minutes / hours / kilocalories / kilometers,
-- from package:evolve_targets). TEXT and unconstrained for the same reason as
-- verify_unit: a unit added by a newer client must round-trip rather than be
-- rejected; validity is enforced in the client.
ALTER TABLE public.long_term_goals ADD COLUMN IF NOT EXISTS target_unit text;

-- The STORED progress value for a MANUAL-entry numeric goal (linked_goal_id
-- NULL). When linked_goal_id is set, progress is derived from the linked habit
-- and this column is ignored for display — but it is also the SNAPSHOT slot: the
-- client writes the derived total here at the moment the link is broken (habit
-- deleted / manually unlinked) so the accumulated value survives as a manual one.
ALTER TABLE public.long_term_goals ADD COLUMN IF NOT EXISTS progress_amount numeric;

-- The habit whose daily goal_progress feeds this macro goal. ON DELETE SET NULL
-- (NOT CASCADE): deleting the linked habit un-links the goal, it does not delete
-- it. Because goal_progress cascades away with the habit, the client snapshots
-- the derived total into progress_amount BEFORE the delete so the number does
-- not silently collapse to zero.
ALTER TABLE public.long_term_goals
    ADD COLUMN IF NOT EXISTS linked_goal_id uuid REFERENCES public.goals(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.long_term_goals.target_amount IS 'Optional numeric target (e.g. 500 km/year). NULL = ordinary boolean macro goal.';
COMMENT ON COLUMN public.long_term_goals.target_unit IS 'TargetUnit wire name (count/minutes/hours/kilocalories/kilometers). Unconstrained so a newer client value round-trips.';
COMMENT ON COLUMN public.long_term_goals.progress_amount IS 'Stored progress for a manual-entry numeric goal; also the snapshot slot written when a linked habit is unlinked/deleted. Ignored for display while linked_goal_id is set (progress is then derived).';
COMMENT ON COLUMN public.long_term_goals.linked_goal_id IS 'Habit (goals.id) whose daily goal_progress feeds this macro goal. ON DELETE SET NULL: deleting the habit un-links, never deletes, this goal.';

-- No analytics RPC is changed by this migration: get_macro_goals_stats still
-- scores a macro goal by its status (active/completed/failed). A numeric goal is
-- marked completed by the client when its target is reached, exactly as a
-- boolean one is, so every existing count keeps working. (NOTE: the legacy
-- web-only check_and_fail_expired_goals still hard-flips any still-active goal to
-- 'failed' at period end regardless of progress; it is dead code in both Flutter
-- apps, so it is left untouched here.)
