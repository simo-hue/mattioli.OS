-- profiles.is_pro / profiles.pro_expires_at are the paid-tier entitlement. Their
-- only legitimate writer is the RevenueCat webhook
-- (supabase/functions/revenuecat-webhook), which holds the service role key.
--
-- RLS cannot express that. A policy's USING / WITH CHECK predicates decide which
-- ROWS a caller may write, never which COLUMNS, so the pre-existing "own profile"
-- UPDATE policies (20260623_add_profiles.sql) let any authenticated user PATCH
-- themselves is_pro = true with their own session JWT.
--
-- Column-level GRANTs are the other standard remedy, but they would have to
-- enumerate every one of the ~30 writable columns and be revisited on each column
-- added to profiles; the clients write this table with upsert(), so a column
-- missed there breaks settings sync silently rather than loudly. Pinning the two
-- entitlement columns in a BEFORE trigger is the narrower and more durable
-- contract: it names only what must not move.

CREATE OR REPLACE FUNCTION public.profiles_pin_entitlement_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  -- SECURITY INVOKER (the default) is load-bearing: current_user must resolve to
  -- the role PostgREST switched to for the caller — anon/authenticated for the
  -- apps, service_role for the webhook — and not to this function's owner.
  -- Unknown roles fall through to the pinning branch, so the guard fails closed.
  IF current_user IN ('service_role', 'postgres', 'supabase_admin') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- The apps create the profile row themselves (auth_controller upsert), so an
    -- INSERT is a grant vector too until the row exists.
    NEW.is_pro := false;
    NEW.pro_expires_at := NULL;
  ELSE
    NEW.is_pro := OLD.is_pro;
    NEW.pro_expires_at := OLD.pro_expires_at;
  END IF;

  RETURN NEW;
END;
$$;

-- Silently pinning rather than raising: a backup import upserts a caller-supplied
-- profile map, and an exception there would fail the whole restore over a field
-- the user is not allowed to set anyway.
DROP TRIGGER IF EXISTS profiles_pin_entitlement_columns ON public.profiles;
CREATE TRIGGER profiles_pin_entitlement_columns
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_pin_entitlement_columns();
