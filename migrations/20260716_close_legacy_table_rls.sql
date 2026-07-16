-- reading_logs and user_settings are leftovers from the retired React/web client
-- under src/: neither Flutter app nor packages/* references either table.
--
-- Both shipped with `USING (true) WITH CHECK (true)` policies carrying no FOR and
-- no TO clause, so they defaulted to FOR ALL / TO PUBLIC — which includes anon.
-- Combined with Supabase's default table grants, that left both tables readable,
-- writable and deletable through PostgREST by anyone holding the publishable key
-- that ships inside both apps, with no account at all.
--
-- Neither table has a user_id or any other ownership column, so the policies
-- cannot be rewritten as auth.uid() = user_id — there is nothing to scope
-- against. Until the owner decides whether to drop the tables outright, close
-- them: drop the policies and revoke the PostgREST grants. RLS stays enabled with
-- no policy, which denies every row to every non-owner role. Existing rows are
-- preserved, and the service role still bypasses RLS for an eventual export or
-- migration.

DROP POLICY IF EXISTS "Allow all access to reading_logs" ON public.reading_logs;
DROP POLICY IF EXISTS "Allow all access to user_settings" ON public.user_settings;

REVOKE ALL ON public.reading_logs FROM anon, authenticated;
REVOKE ALL ON public.user_settings FROM anon, authenticated;
