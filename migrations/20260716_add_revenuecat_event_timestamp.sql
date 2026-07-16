-- Per-user "last applied RevenueCat event time" used by the webhook
-- (supabase/functions/revenuecat-webhook) to reject out-of-order redeliveries.
-- RevenueCat does not guarantee delivery order and retries on non-2xx, so an
-- EXPIRATION can be redelivered AFTER the RENEWAL that supersedes it. The webhook
-- stores the event_timestamp_ms of the last event it applied here and drops any
-- later event whose timestamp is strictly older.
--
-- The column is nullable and its write is gated on itself, so it MUST NOT be
-- writable by the app roles. If an authenticated user could PATCH their own
-- revenuecat_event_timestamp_ms to a huge value with their session JWT, the
-- webhook would then treat every subsequent REAL event — including that user's
-- own EXPIRATION/REFUND — as "stale" and skip it, freezing is_pro = true forever.
-- That is a paid-tier privilege-escalation vector, so this column is pinned for
-- non-service writers exactly like is_pro / pro_expires_at
-- (20260716_pin_profiles_entitlement_columns.sql). Do NOT "simplify" the pin away.

-- Idempotent / re-runnable: the migration owner applies migrations manually and
-- the edge function may already be deployed against a DB without this column.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS revenuecat_event_timestamp_ms bigint;

COMMENT ON COLUMN public.profiles.revenuecat_event_timestamp_ms IS
  'Last-applied RevenueCat event_timestamp_ms (ordering guard for the webhook). '
  'Service-role-only: pinned against anon/authenticated by '
  'profiles_pin_revenuecat_timestamp so a user cannot freeze is_pro = true by '
  'writing a future timestamp.';

-- Independent, self-contained pin. Deliberately NOT reusing
-- profiles_pin_entitlement_columns: migration ordering among same-date files is
-- fragile and this file must not assume the pin migration ran first. Mirrors that
-- function's proven shape (SECURITY INVOKER, empty search_path, fail-closed for
-- unknown roles, silent pin rather than RAISE).
CREATE OR REPLACE FUNCTION public.profiles_pin_revenuecat_timestamp()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  -- SECURITY INVOKER (the default): current_user is the role PostgREST switched
  -- to for the caller — anon/authenticated for the apps, service_role for the
  -- webhook. Unknown roles fall through to the pinning branch, so it fails closed.
  IF current_user IN ('service_role', 'postgres', 'supabase_admin') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- The apps create the profile row themselves (auth_controller upsert), so an
    -- INSERT that supplies a timestamp is a freeze vector until the row exists.
    NEW.revenuecat_event_timestamp_ms := NULL;
  ELSE
    NEW.revenuecat_event_timestamp_ms := OLD.revenuecat_event_timestamp_ms;
  END IF;

  RETURN NEW;
END;
$$;

-- Silently pinning rather than raising: the clients upsert the full profile map
-- (settings sync, backup restore), and an exception over a field the user is not
-- allowed to set anyway would break those flows. A second BEFORE trigger touching
-- a different column coexists with profiles_pin_entitlement_columns.
DROP TRIGGER IF EXISTS profiles_pin_revenuecat_timestamp ON public.profiles;
CREATE TRIGGER profiles_pin_revenuecat_timestamp
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_pin_revenuecat_timestamp();
