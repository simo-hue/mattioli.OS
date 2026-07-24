-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "plpgsql" WITH SCHEMA "pg_catalog";
CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";

-- Set up configuration
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- Create generic update_updated_at_column function
CREATE OR REPLACE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

--
-- Table: public.reading_logs
--
CREATE TABLE public.reading_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    date date NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reading_logs_status_check CHECK ((status = ANY (ARRAY['done'::text, 'missed'::text]))),
    CONSTRAINT reading_logs_date_key UNIQUE (date)
);

--
-- Table: public.user_settings
--
CREATE TABLE public.user_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    key text NOT NULL,
    value text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_settings_key_key UNIQUE (key)
);

--
-- Table: public.goals
--
CREATE TABLE public.goals (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    description text,
    color text NOT NULL,
    icon text,
    frequency_days integer[],
    start_date timestamp with time zone NOT NULL,
    end_date timestamp with time zone,
    display_order integer,
    -- Auto-verified habits: the verification rule (all null => manual habit).
    -- Unconstrained by design so a future provider/metric round-trips instead
    -- of being rejected; validity is enforced in the client.
    verify_provider text,
    verify_metric text,
    verify_comparator text,
    verify_threshold numeric,
    verify_unit text,
    -- Forward-only rule-edit anchor (private schema v7): the day the current
    -- verification rule took effect. NULL => fall back to start_date.
    verify_effective_from date,
    -- Compound verifiable habits (v8): JSON {v,op,conditions:[...]} joining 2-3
    -- conditions. When set, the flat verify_* columns above are NULL.
    verify_conditions text,
    -- Quantitative target (v9): JSON {v,src,dir,per,agg,amount,unit,step,input}
    -- (package:evolve_targets). NULL => ordinary boolean habit.
    target text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Table: public.goal_logs
--
CREATE TABLE public.goal_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    goal_id uuid REFERENCES public.goals(id) ON DELETE CASCADE NOT NULL,
    date date NOT NULL,
    status text NOT NULL CHECK (status IN ('done', 'missed', 'skipped')),
    notes text,
    value numeric,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT goal_logs_goal_id_date_key UNIQUE (goal_id, date)
);

--
-- Table: public.goal_progress
--
-- One accumulated progress number per habit-day for quantitative habits.
-- `goal_logs` stays the VERDICT record; this table is the raw number, so a
-- partially-completed day renders without entering any completion-rate
-- denominator. `id` is deterministic ('<goal_id>:<date>') so two devices cannot
-- mint rival rows for one habit-day.
--
CREATE TABLE public.goal_progress (
    id text NOT NULL PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    goal_id uuid REFERENCES public.goals(id) ON DELETE CASCADE NOT NULL,
    date date NOT NULL,
    amount numeric NOT NULL,
    source text NOT NULL DEFAULT 'manual',
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT goal_progress_goal_id_date_key UNIQUE (goal_id, date)
);

CREATE INDEX idx_goal_progress_user_date ON public.goal_progress (user_id, date DESC);

--
-- Enum: public.long_term_goal_type
--
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'long_term_goal_type') THEN
        CREATE TYPE public.long_term_goal_type AS ENUM ('annual', 'monthly', 'weekly', 'quarterly', 'lifetime');
    ELSE
        -- Ensure 'quarterly' exists if type already exists
        ALTER TYPE public.long_term_goal_type ADD VALUE IF NOT EXISTS 'quarterly';
        ALTER TYPE public.long_term_goal_type ADD VALUE IF NOT EXISTS 'lifetime';
    END IF;
END $$;

--
-- Table: public.long_term_goals
--
CREATE TABLE public.long_term_goals (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    is_completed boolean DEFAULT false NOT NULL,
    type public.long_term_goal_type NOT NULL,
    year integer,
    month integer CHECK (month >= 1 AND month <= 12),
    week_number integer CHECK (week_number >= 1 AND week_number <= 53),
    quarter integer CHECK (quarter >= 1 AND quarter <= 4),
    color text DEFAULT null,
    -- Cumulative numeric macro goals (private schema v10). NULL target_amount =>
    -- an ordinary boolean macro goal. Progress is DERIVED (summed from the
    -- linked habit's goal_progress over this goal's period) when linked_goal_id
    -- is set, else STORED in progress_amount. target_unit is a TargetUnit wire
    -- name (count/minutes/hours/kilocalories/kilometers), unconstrained so a
    -- newer client's unit round-trips. linked_goal_id is ON DELETE SET NULL:
    -- deleting the linked habit un-links (never deletes) this goal.
    target_amount numeric,
    target_unit text,
    progress_amount numeric,
    linked_goal_id uuid REFERENCES public.goals(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Table: public.goal_category_settings
--
CREATE TABLE public.goal_category_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    mappings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT goal_category_settings_user_id_key UNIQUE (user_id)
);

--
-- Enable Row Level Security (RLS)
--

ALTER TABLE public.reading_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.long_term_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_category_settings ENABLE ROW LEVEL SECURITY;

--
-- RLS Policies
--

-- reading_logs / user_settings: legacy tables from the retired src/ web client,
-- referenced by neither Flutter app. They carry no ownership column, so no policy
-- can scope them to auth.uid(); they are left with RLS enabled and NO policy,
-- which denies every row to anon and authenticated. See
-- migrations/20260716_close_legacy_table_rls.sql.
REVOKE ALL ON public.reading_logs FROM anon, authenticated;
REVOKE ALL ON public.user_settings FROM anon, authenticated;

-- goals
CREATE POLICY "Users can view their own goals" ON public.goals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own goals" ON public.goals FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own goals" ON public.goals FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own goals" ON public.goals FOR DELETE USING (auth.uid() = user_id);

-- goal_logs
CREATE POLICY "Users can view their own goal logs" ON public.goal_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own goal logs" ON public.goal_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own goal logs" ON public.goal_logs FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own goal logs" ON public.goal_logs FOR DELETE USING (auth.uid() = user_id);

-- goal_progress
CREATE POLICY "Users can view their own goal progress" ON public.goal_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own goal progress" ON public.goal_progress FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own goal progress" ON public.goal_progress FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own goal progress" ON public.goal_progress FOR DELETE USING (auth.uid() = user_id);

-- long_term_goals
CREATE POLICY "Users can view their own long term goals" ON public.long_term_goals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own long term goals" ON public.long_term_goals FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own long term goals" ON public.long_term_goals FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own long term goals" ON public.long_term_goals FOR DELETE USING (auth.uid() = user_id);

-- goal_category_settings
CREATE POLICY "Users can manage their own category settings" ON public.goal_category_settings FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

--
-- Triggers for updated_at
--

CREATE TRIGGER update_reading_logs_updated_at BEFORE UPDATE ON public.reading_logs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON public.user_settings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_goals_updated_at BEFORE UPDATE ON public.goals FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_goal_logs_updated_at BEFORE UPDATE ON public.goal_logs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_goal_progress_updated_at BEFORE UPDATE ON public.goal_progress FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_long_term_goals_updated_at BEFORE UPDATE ON public.long_term_goals FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_goal_category_settings_updated_at BEFORE UPDATE ON public.goal_category_settings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Table: public.user_memos
--
CREATE TABLE public.user_memos (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    content text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_memos_user_id_key UNIQUE (user_id)
);

ALTER TABLE public.user_memos ENABLE ROW LEVEL SECURITY;

-- user_memos policies
CREATE POLICY "Users can view their own memo" ON public.user_memos FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own memo" ON public.user_memos FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own memo" ON public.user_memos FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own memo" ON public.user_memos FOR DELETE USING (auth.uid() = user_id);

CREATE TRIGGER update_user_memos_updated_at BEFORE UPDATE ON public.user_memos FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Table: public.daily_moods
--
CREATE TABLE public.daily_moods (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date date NOT NULL,
    mood_score integer NOT NULL CHECK (mood_score >= 1 AND mood_score <= 5),
    energy_score integer NOT NULL CHECK (energy_score >= 1 AND energy_score <= 5),
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT daily_moods_user_id_date_key UNIQUE (user_id, date)
);

ALTER TABLE public.daily_moods ENABLE ROW LEVEL SECURITY;

-- daily_moods policies
CREATE POLICY "Users can view their own moods" ON public.daily_moods FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own moods" ON public.daily_moods FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own moods" ON public.daily_moods FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own moods" ON public.daily_moods FOR DELETE USING (auth.uid() = user_id);

CREATE TRIGGER update_daily_moods_updated_at BEFORE UPDATE ON public.daily_moods FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
