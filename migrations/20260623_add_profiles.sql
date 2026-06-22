-- Capture of live table profiles (referenced by the app via from('profiles')
-- but previously missing from schema.sql / migrations). Reconstructed from the
-- production DB catalog (columns, defaults, constraints).
CREATE TABLE public.profiles (
    id uuid NOT NULL,
    username text,
    full_name text,
    avatar_url text,
    language text NOT NULL DEFAULT 'it'::text,
    theme_mode text NOT NULL DEFAULT 'dark'::text,
    accent_color text NOT NULL DEFAULT '#FFFFFF'::text,
    pref_glass_effects boolean NOT NULL DEFAULT true,
    pref_default_calendar_view text NOT NULL DEFAULT 'week'::text,
    pref_start_week_on_monday boolean NOT NULL DEFAULT true,
    pref_show_weekend boolean NOT NULL DEFAULT true,
    pref_haptic_feedback boolean NOT NULL DEFAULT true,
    pref_time_format_24h boolean NOT NULL DEFAULT true,
    is_pro boolean NOT NULL DEFAULT false,
    pro_expires_at timestamp with time zone,
    notif_habit_reminders boolean NOT NULL DEFAULT true,
    notif_goal_deadlines boolean NOT NULL DEFAULT true,
    notif_ai_insights boolean NOT NULL DEFAULT false,
    notif_weekly_reports boolean NOT NULL DEFAULT false,
    notif_evening_review boolean NOT NULL DEFAULT true,
    biometric_lock boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    date_of_birth date,
    morning_brief_time text DEFAULT '09:00'::text,
    evening_review_time text DEFAULT '21:00'::text,
    terms_accepted_at timestamp with time zone,
    sentry_consent boolean NOT NULL DEFAULT false,
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE,
    PRIMARY KEY (id),
    CHECK ((theme_mode = ANY (ARRAY['dark'::text, 'light'::text, 'system'::text])))
);

-- Row Level Security (captured from prod; policies imply RLS is enabled).
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "L'utente può aggiornare il proprio profilo" ON public.profiles AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((auth.uid() = id))
  WITH CHECK ((auth.uid() = id));

CREATE POLICY "L'utente può leggere il proprio profilo" ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated
  USING ((auth.uid() = id));

CREATE POLICY "profiles: insert own" ON public.profiles AS PERMISSIVE FOR INSERT TO public
  WITH CHECK ((auth.uid() = id));

CREATE POLICY "profiles: select own" ON public.profiles AS PERMISSIVE FOR SELECT TO public
  USING ((auth.uid() = id));

CREATE POLICY "profiles: update own" ON public.profiles AS PERMISSIVE FOR UPDATE TO public
  USING ((auth.uid() = id));
