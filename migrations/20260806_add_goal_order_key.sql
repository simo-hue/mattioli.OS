-- Migration: Fractional habit ordering — goals.order_key + order_key_updated_at
-- Date: 2026-08-06
-- Purpose: Replace the dense `display_order` sequence with a fractional key, so
--          a habit's position is a property of ITS OWN ROW.
--
-- Mirrors packages/evolve_sync PrivateDbSchema v12 so the two backends stay
-- column-compatible. Additive and nullable — no existing row, query, RPC or
-- client is affected, and an app build predating this migration keeps working
-- unchanged (it reads and writes `display_order`, which is untouched).
--
-- WHY (the defect this encodes the fix for):
--   `display_order` was a dense 0..n-1 sequence — a property of the whole
--   COLLECTION — while the private (CloudKit) sync engine merges last-write-wins
--   PER ROW. One goal row pulled from another device therefore overwrote that
--   habit's slot in isolation, leaving duplicate and missing positions;
--   `ORDER BY display_order, created_at` then broke the ties by creation date
--   and the list settled into an order nobody chose. A fractional key is a
--   property of the row — a value strictly between its neighbours — so per-row
--   LWW is correct by construction, two devices moving different habits cannot
--   conflict, and a drag writes ONE row instead of all of them.
--
-- WHY double precision AND NOT text:
--   Lexicographic keys (LexoRank and friends) never exhaust, but SQLite compares
--   TEXT with BINARY collation while PostgreSQL uses a locale-aware default —
--   the same keys would order differently on the two backends unless every
--   comparison and index carried COLLATE "C". Doubles compare identically
--   everywhere. Their only cost is exhaustion (~40 consecutive drops into the
--   same shrinking gap), which the client detects and resolves by renumbering.
--
-- WHY order_key_updated_at:
--   FIELD-level last-write-wins for that one column. Whole-row LWW would let an
--   unrelated edit (a rename on another device, carrying its own older
--   order_key) drag a habit back to a position the user already moved it out of.
--   It must not be possible to move a habit by renaming it. Carried on the cloud
--   table too so a Supabase round-trip does not drop it.
--
-- BACKFILL: deliberately NOT done here. Each client backfills its own rows from
-- `display_order` (tie-broken by created_at then id) as part of the v12 private
-- migration, and pushes the result. Seeding server-side from a different rule
-- would fight that.

ALTER TABLE public.goals
  ADD COLUMN IF NOT EXISTS order_key double precision;

ALTER TABLE public.goals
  ADD COLUMN IF NOT EXISTS order_key_updated_at timestamp with time zone;

COMMENT ON COLUMN public.goals.order_key IS
  'Fractional list position. A value strictly between the neighbouring habits, '
  'so per-row last-write-wins merges correctly. NULL on rows written by a '
  'client predating this migration; those sort after the keyed rows.';

COMMENT ON COLUMN public.goals.order_key_updated_at IS
  'When order_key was last set, for field-level last-write-wins on that column '
  'alone — an unrelated edit must not carry a stale position.';

-- Reads are "every habit for this user, in order".
CREATE INDEX IF NOT EXISTS idx_goals_user_order_key
  ON public.goals (user_id, order_key);
