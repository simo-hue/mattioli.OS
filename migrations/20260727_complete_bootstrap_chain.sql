-- Completes the fresh-bootstrap chain (schema.sql + migrations/*.sql in date
-- order). Three objects existed ONLY in the now-deleted mobile/mobile_schema.sql,
-- so a project provisioned from this repo got a `long_term_goals.category_id`
-- with no referential integrity, a `profiles` table nothing ever populated, and
-- a `profiles.updated_at` that never advanced (silently breaking any
-- last-write-wins comparison over the settings row).
--
-- EVERY statement here is GUARDED so that re-running it against the live
-- production database is a strict no-op. Production already has these objects
-- (signup works and categories resolve), so this migration must not replace or
-- redefine them — replacing a live SECURITY DEFINER function with a version
-- reconstructed from a stale snapshot is exactly how signup breaks. It creates
-- them only where they are ABSENT.
--
-- APPLIED to the live project on 2026-07-27; all six objects verified present.

-- ---------------------------------------------------------------------------
-- 1. long_term_goals.category_id -> macro_goal_categories.id
-- ---------------------------------------------------------------------------
-- schema.sql declares the bare `category_id uuid` column because
-- public.macro_goal_categories is created later in the chain
-- (20260623_add_macro_goal_categories.sql). The FK is attached here, once the
-- referenced table is guaranteed to exist. ON DELETE SET NULL: deleting a
-- category un-categorises its goals, it never deletes them.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'long_term_goals_category_id_fkey'
          AND conrelid = 'public.long_term_goals'::regclass
    ) THEN
        ALTER TABLE public.long_term_goals
            ADD CONSTRAINT long_term_goals_category_id_fkey
            FOREIGN KEY (category_id)
            REFERENCES public.macro_goal_categories(id)
            ON DELETE SET NULL;
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2. handle_new_user() + on_auth_user_created
-- ---------------------------------------------------------------------------
-- Seeds a public.profiles row when auth.users gains a row. Without it a fresh
-- project has a profiles table that is never populated, so every settings /
-- entitlement read returns nothing for a newly signed-up user.
--
-- Deliberately NOT `CREATE OR REPLACE`: on production this function already
-- exists and is authoritative. Only create it when it is missing.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'handle_new_user'
    ) THEN
        EXECUTE $fn$
            CREATE FUNCTION public.handle_new_user()
            RETURNS trigger
            LANGUAGE plpgsql
            SECURITY DEFINER
            SET search_path = public
            AS $body$
            BEGIN
                INSERT INTO public.profiles (
                    id, full_name, avatar_url, terms_accepted_at, sentry_consent
                )
                VALUES (
                    NEW.id,
                    NEW.raw_user_meta_data ->> 'full_name',
                    NEW.raw_user_meta_data ->> 'avatar_url',
                    (NEW.raw_user_meta_data ->> 'terms_accepted_at')::timestamp with time zone,
                    COALESCE((NEW.raw_user_meta_data ->> 'sentry_consent')::boolean, false)
                )
                ON CONFLICT (id) DO NOTHING;
                RETURN NEW;
            END;
            $body$;
        $fn$;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'on_auth_user_created'
          AND tgrelid = 'auth.users'::regclass
          AND NOT tgisinternal
    ) THEN
        CREATE TRIGGER on_auth_user_created
            AFTER INSERT ON auth.users
            FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 3. update_profiles_updated_at
-- ---------------------------------------------------------------------------
-- schema.sql installs update_updated_at_column() on every table it declares,
-- but public.profiles is created by 20260623_add_profiles.sql and never got the
-- trigger — it too lived only in mobile_schema.sql. Without it `updated_at`
-- freezes at insert time, which silently breaks any last-write-wins comparison
-- over the settings row.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_profiles_updated_at'
          AND tgrelid = 'public.profiles'::regclass
          AND NOT tgisinternal
    ) THEN
        CREATE TRIGGER update_profiles_updated_at
            BEFORE UPDATE ON public.profiles
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;
END $$;
