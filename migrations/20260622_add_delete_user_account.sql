-- Capture of live function delete_user_account (was missing from repo / schema drift).
-- Verbatim from pg_get_functiondef on the production Supabase DB.
CREATE OR REPLACE FUNCTION public.delete_user_account()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  BEGIN
      IF auth.uid() IS NULL THEN
          RAISE EXCEPTION 'Non autorizzato';
      END IF;

      DELETE FROM auth.users WHERE id = auth.uid();
  END;
  $function$;
