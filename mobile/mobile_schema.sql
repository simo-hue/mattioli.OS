-- ============================================================
-- FILE: mobile_schema.sql
-- Mattioli.OS Mobile — Schema Completo (Database Vuoto)
--
-- ISTRUZIONI:
--   DB nuovo, vuoto. Questo file crea TUTTO da zero.
--   Esegui integralmente nel SQL Editor di Supabase.
--   È idempotente: sicuro da rieseguire più volte.
--   Autore: Antigravity — Database Architect
--   Data: 2026-04-30
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- ESTENSIONI
-- ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto"  WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


-- ─────────────────────────────────────────────────────────────
-- FUNZIONE: update_updated_at_column()
-- Aggiorna automaticamente updated_at ad ogni UPDATE.
-- Usata da tutti i trigger qui sotto.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


-- ============================================================
-- TABLE: profiles
-- Hub centrale dell'utente. Creata automaticamente al signup
-- tramite il trigger on_auth_user_created.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id              uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,

    -- Dati anagrafici (opzionali, popolati da OAuth)
    username        text,
    full_name       text,
    avatar_url      text,

    -- Localizzazione
    language        text NOT NULL DEFAULT 'it',

    -- Tema e UI
    theme_mode      text    NOT NULL DEFAULT 'dark'
                                CHECK (theme_mode IN ('dark', 'light', 'system')),
    accent_color    text    NOT NULL DEFAULT '#FFFFFF',
    pref_glass_effects          boolean NOT NULL DEFAULT true,
    pref_default_calendar_view  text    NOT NULL DEFAULT 'week',
    pref_start_week_on_monday   boolean NOT NULL DEFAULT true,
    pref_show_weekend           boolean NOT NULL DEFAULT true,
    pref_haptic_feedback        boolean NOT NULL DEFAULT true,
    pref_time_format_24h        boolean NOT NULL DEFAULT true,

    -- Piano abbonamento
    is_pro          boolean NOT NULL DEFAULT false,
    pro_expires_at  timestamp with time zone,  -- NULL = free o lifetime

    -- Notifiche
    notif_habit_reminders   boolean NOT NULL DEFAULT true,
    notif_goal_deadlines    boolean NOT NULL DEFAULT true,
    notif_ai_insights       boolean NOT NULL DEFAULT false,
    notif_weekly_reports    boolean NOT NULL DEFAULT false,
    notif_evening_review    boolean NOT NULL DEFAULT true,

    -- Privacy
    biometric_lock      boolean NOT NULL DEFAULT false,
    anonymous_analytics boolean NOT NULL DEFAULT true,

    -- Timestamps
    created_at  timestamp with time zone DEFAULT now() NOT NULL,
    updated_at  timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles: select own"
    ON public.profiles FOR SELECT    USING (auth.uid() = id);
CREATE POLICY "profiles: insert own"
    ON public.profiles FOR INSERT    WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles: update own"
    ON public.profiles FOR UPDATE    USING (auth.uid() = id);

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger: crea il profilo automaticamente ad ogni nuovo signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data ->> 'full_name',
        NEW.raw_user_meta_data ->> 'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- TABLE: goals  (abitudini quotidiane / habits)
-- Ogni riga è un'abitudine dell'utente.
-- frequency_days: array di giorni della settimana [1=Lun … 7=Dom]
-- ============================================================
CREATE TABLE IF NOT EXISTS public.goals (
    id              uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id         uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title           text NOT NULL,
    description     text,
    color           text NOT NULL,
    icon            text,
    frequency_days  integer[],              -- es. {1,2,3,4,5} = lun-ven
    start_date      timestamp with time zone NOT NULL,
    end_date        timestamp with time zone,
    display_order   integer,
    created_at      timestamp with time zone DEFAULT now() NOT NULL,
    updated_at      timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "goals: select own"
    ON public.goals FOR SELECT    USING (auth.uid() = user_id);
CREATE POLICY "goals: insert own"
    ON public.goals FOR INSERT    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "goals: update own"
    ON public.goals FOR UPDATE    USING (auth.uid() = user_id);
CREATE POLICY "goals: delete own"
    ON public.goals FOR DELETE    USING (auth.uid() = user_id);

CREATE TRIGGER update_goals_updated_at
    BEFORE UPDATE ON public.goals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ============================================================
-- TABLE: goal_logs  (log giornaliero delle abitudini)
-- Un record per abitudine per giorno.
-- status: 'done' | 'missed' | 'skipped'
-- ============================================================
CREATE TABLE IF NOT EXISTS public.goal_logs (
    id      uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id)  ON DELETE CASCADE NOT NULL,
    goal_id uuid REFERENCES public.goals(id) ON DELETE CASCADE NOT NULL,
    date    date NOT NULL,
    status  text NOT NULL CHECK (status IN ('done', 'missed', 'skipped')),
    notes   text,
    value   numeric,  -- per abitudini misurabili (es. km corsi, pagine lette)
    created_at  timestamp with time zone DEFAULT now() NOT NULL,
    updated_at  timestamp with time zone DEFAULT now() NOT NULL,
    -- Un solo log per abitudine per giorno
    CONSTRAINT goal_logs_goal_date_unique UNIQUE (goal_id, date)
);

ALTER TABLE public.goal_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "goal_logs: select own"
    ON public.goal_logs FOR SELECT    USING (auth.uid() = user_id);
CREATE POLICY "goal_logs: insert own"
    ON public.goal_logs FOR INSERT    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "goal_logs: update own"
    ON public.goal_logs FOR UPDATE    USING (auth.uid() = user_id);
CREATE POLICY "goal_logs: delete own"
    ON public.goal_logs FOR DELETE    USING (auth.uid() = user_id);

CREATE TRIGGER update_goal_logs_updated_at
    BEFORE UPDATE ON public.goal_logs
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ============================================================
-- ENUM: long_term_goal_type  (tipi di macro goal)
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'long_term_goal_type') THEN
        CREATE TYPE public.long_term_goal_type AS ENUM
            ('lifetime', 'annual', 'quarterly', 'monthly', 'weekly');
    END IF;
END $$;


-- ============================================================
-- TABLE: long_term_goals  (macro goals)
-- Specchio esatto del modello MacroGoal in Flutter.
-- status: 'active' | 'completed' | 'failed'
-- ============================================================
CREATE TABLE IF NOT EXISTS public.long_term_goals (
    id          uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title       text NOT NULL,
    status      text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'completed', 'failed')),
    type        public.long_term_goal_type NOT NULL,
    year        integer,
    month       integer CHECK (month >= 1 AND month <= 12),
    week_number integer CHECK (week_number >= 1 AND week_number <= 6),
    quarter     integer CHECK (quarter >= 1 AND quarter <= 4),
    color       text,
    category_key text,  -- es. 'lavoro', 'salute', 'finanza' ...
    created_at  timestamp with time zone DEFAULT now() NOT NULL,
    updated_at  timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.long_term_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "long_term_goals: select own"
    ON public.long_term_goals FOR SELECT    USING (auth.uid() = user_id);
CREATE POLICY "long_term_goals: insert own"
    ON public.long_term_goals FOR INSERT    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "long_term_goals: update own"
    ON public.long_term_goals FOR UPDATE    USING (auth.uid() = user_id);
CREATE POLICY "long_term_goals: delete own"
    ON public.long_term_goals FOR DELETE    USING (auth.uid() = user_id);

CREATE TRIGGER update_long_term_goals_updated_at
    BEFORE UPDATE ON public.long_term_goals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ============================================================
-- TABLE: daily_moods
-- Un record per utente per giorno.
-- mood_score e energy_score: scala 1-5
-- ============================================================
CREATE TABLE IF NOT EXISTS public.daily_moods (
    id           uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id      uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date         date NOT NULL,
    mood_score   integer NOT NULL CHECK (mood_score   >= 1 AND mood_score   <= 5),
    energy_score integer NOT NULL CHECK (energy_score >= 1 AND energy_score <= 5),
    note         text,
    created_at   timestamp with time zone DEFAULT now() NOT NULL,
    updated_at   timestamp with time zone DEFAULT now() NOT NULL,
    -- Un solo record mood per utente per giorno
    CONSTRAINT daily_moods_user_date_unique UNIQUE (user_id, date)
);

ALTER TABLE public.daily_moods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "daily_moods: select own"
    ON public.daily_moods FOR SELECT    USING (auth.uid() = user_id);
CREATE POLICY "daily_moods: insert own"
    ON public.daily_moods FOR INSERT    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "daily_moods: update own"
    ON public.daily_moods FOR UPDATE    USING (auth.uid() = user_id);
CREATE POLICY "daily_moods: delete own"
    ON public.daily_moods FOR DELETE    USING (auth.uid() = user_id);

CREATE TRIGGER update_daily_moods_updated_at
    BEFORE UPDATE ON public.daily_moods
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ============================================================
-- TABLE: user_memos
-- Nota rapida dell'utente (una sola per utente).
-- Sostituisce il SharedPreferences locale di Flutter.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_memos (
    id      uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    content text,
    created_at  timestamp with time zone DEFAULT now() NOT NULL,
    updated_at  timestamp with time zone DEFAULT now() NOT NULL,
    -- Un solo memo per utente
    CONSTRAINT user_memos_user_unique UNIQUE (user_id)
);

ALTER TABLE public.user_memos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_memos: select own"
    ON public.user_memos FOR SELECT    USING (auth.uid() = user_id);
CREATE POLICY "user_memos: insert own"
    ON public.user_memos FOR INSERT    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_memos: update own"
    ON public.user_memos FOR UPDATE    USING (auth.uid() = user_id);
CREATE POLICY "user_memos: delete own"
    ON public.user_memos FOR DELETE    USING (auth.uid() = user_id);

CREATE TRIGGER update_user_memos_updated_at
    BEFORE UPDATE ON public.user_memos
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ============================================================
-- TABLE: goal_category_settings
-- Salva il mapping personalizzato categoria→colore per utente.
-- mappings è un oggetto JSONB: { "lavoro": "#3B82F6", ... }
-- ============================================================
CREATE TABLE IF NOT EXISTS public.goal_category_settings (
    id       uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id  uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    mappings jsonb NOT NULL DEFAULT '{}',
    created_at  timestamp with time zone DEFAULT now() NOT NULL,
    updated_at  timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT goal_category_settings_user_unique UNIQUE (user_id)
);

ALTER TABLE public.goal_category_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "goal_category_settings: all own"
    ON public.goal_category_settings FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE TRIGGER update_goal_category_settings_updated_at
    BEFORE UPDATE ON public.goal_category_settings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ============================================================
-- TABLE: ai_insights
-- Cache delle analisi AI generate da Edge Functions.
-- Evita di ripetere la stessa chiamata LLM per lo stesso periodo.
--
-- Struttura di `content` (jsonb):
-- {
--   "summary": "Stai migliorando del 12%...",
--   "suggestions": ["...", "..."],
--   "score": 78,
--   "highlights": [{ "habit": "Meditazione", "streak": 14 }]
-- }
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ai_insights (
    id           uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id      uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    insight_type text NOT NULL
                    CHECK (insight_type IN ('trend', 'improvement', 'weekly_summary', 'coaching')),
    period_key   text NOT NULL,   -- es. '2026-W17', '2026-04', '2026', 'all-time'
    content      jsonb NOT NULL,
    model_used   text,            -- es. 'gpt-4o-mini'
    tokens_used  integer,
    created_at   timestamp with time zone DEFAULT now() NOT NULL,
    -- Un solo insight per tipo+periodo per utente
    CONSTRAINT ai_insights_user_type_period_unique
        UNIQUE (user_id, insight_type, period_key)
);

ALTER TABLE public.ai_insights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_insights: select own"
    ON public.ai_insights FOR SELECT    USING (auth.uid() = user_id);
CREATE POLICY "ai_insights: insert own"
    ON public.ai_insights FOR INSERT    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ai_insights: update own"
    ON public.ai_insights FOR UPDATE    USING (auth.uid() = user_id);
CREATE POLICY "ai_insights: delete own"
    ON public.ai_insights FOR DELETE    USING (auth.uid() = user_id);


-- ============================================================
-- PERFORMANCE INDEXES
-- Ottimizzano le query più frequenti dell'app mobile.
-- ============================================================

-- Abitudini: listing per utente ordinata
CREATE INDEX IF NOT EXISTS idx_goals_user_order
    ON public.goals (user_id, display_order NULLS LAST);

-- Log abitudini: query per utente + range di date (vista calendario)
CREATE INDEX IF NOT EXISTS idx_goal_logs_user_date
    ON public.goal_logs (user_id, date DESC);

-- Macro goals: filtraggio per tipo + anno
CREATE INDEX IF NOT EXISTS idx_ltg_user_type_year
    ON public.long_term_goals (user_id, type, year);

-- Macro goals: filtraggio per status (active/completed/failed)
CREATE INDEX IF NOT EXISTS idx_ltg_user_status
    ON public.long_term_goals (user_id, status);

-- Mood: query per grafico degli ultimi N giorni
CREATE INDEX IF NOT EXISTS idx_moods_user_date
    ON public.daily_moods (user_id, date DESC);

-- AI Insights: lookup per tipo + periodo
CREATE INDEX IF NOT EXISTS idx_ai_insights_lookup
    ON public.ai_insights (user_id, insight_type, period_key);


-- ============================================================
-- VERIFICA FINALE
-- Esegui questa SELECT per confermare che tutto sia corretto:
--
-- SELECT table_name
-- FROM information_schema.tables
-- WHERE table_schema = 'public'
-- ORDER BY table_name;
--
-- Risultato atteso:
--   ai_insights
--   daily_moods
--   goal_category_settings
--   goal_logs
--   goals
--   long_term_goals
--   profiles
--   user_memos
-- ============================================================
