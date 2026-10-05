-- Real Monday–Sunday weeks, owned by the month/year containing Thursday.
-- Apply before releasing either Flutter client. PrivateDbSchema v13 performs
-- the same conversion locally. Targets, statuses and stored progress stay put.
BEGIN;

ALTER TABLE public.long_term_goals
  ADD COLUMN IF NOT EXISTS week_start_date date;

COMMENT ON COLUMN public.long_term_goals.week_start_date IS
  'Authoritative Monday of a seven-day goal week. NULL means a legacy '
  'four-period month address, converted by greatest overlap (earlier on ties).';

CREATE OR REPLACE FUNCTION public.normalize_macro_goal_week()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  owner_date date;
  period_start date;
  period_end date;
  candidate date;
  chosen date;
  thursday date;
  overlap_days integer;
  best_overlap integer := -1;
  legacy_week integer;
BEGIN
  IF NEW.type::text <> 'weekly' THEN
    NEW.week_start_date := NULL;
    RETURN NEW;
  END IF;

  -- Match the Flutter reader: only a Monday is a valid format marker.
  IF NEW.week_start_date IS NOT NULL
      AND EXTRACT(ISODOW FROM NEW.week_start_date) <> 1 THEN
    NEW.week_start_date := NULL;
  END IF;

  -- An older client may reschedule without knowing the new column. If its
  -- address changed while the Monday did not, honor that legacy reschedule.
  IF TG_OP = 'UPDATE' AND NEW.week_start_date IS NOT NULL
      AND NEW.week_start_date IS NOT DISTINCT FROM OLD.week_start_date
      AND (NEW.year, NEW.month, NEW.week_number)
          IS DISTINCT FROM (OLD.year, OLD.month, OLD.week_number) THEN
    thursday := NEW.week_start_date + 3;
    IF (NEW.year, NEW.month, NEW.week_number) IS DISTINCT FROM
        (EXTRACT(YEAR FROM thursday)::integer,
         EXTRACT(MONTH FROM thursday)::integer,
         (EXTRACT(DAY FROM thursday)::integer - 1) / 7 + 1) THEN
      NEW.week_start_date := NULL;
    END IF;
  END IF;

  IF NEW.week_start_date IS NOT NULL THEN
    chosen := NEW.week_start_date;
  ELSE
    IF NEW.year IS NULL OR NEW.month IS NULL OR NEW.week_number IS NULL THEN
      RETURN NEW;
    END IF;
    owner_date := pg_catalog.make_date(NEW.year, NEW.month, 1);
    legacy_week := GREATEST(1, NEW.week_number);
    IF legacy_week >= 5 THEN
      owner_date := (owner_date + INTERVAL '1 month')::date;
      legacy_week := 1;
    END IF;
    period_start := owner_date + (legacy_week - 1) * 7;
    period_end := owner_date + legacy_week * 7 - 1;
    IF legacy_week = 1 AND EXTRACT(DAY FROM owner_date - 1) > 28 THEN
      period_start := (owner_date - INTERVAL '1 month')::date + 28;
    END IF;
    candidate := period_start
        - (EXTRACT(ISODOW FROM period_start)::integer - 1);
    WHILE candidate <= period_end LOOP
      overlap_days := LEAST(candidate + 6, period_end)
          - GREATEST(candidate, period_start) + 1;
      IF overlap_days > best_overlap THEN
        best_overlap := overlap_days;
        chosen := candidate;
      END IF;
      candidate := candidate + 7;
    END LOOP;
  END IF;

  thursday := chosen + 3;
  NEW.week_start_date := chosen;
  NEW.year := EXTRACT(YEAR FROM thursday)::integer;
  NEW.month := EXTRACT(MONTH FROM thursday)::integer;
  NEW.week_number := (EXTRACT(DAY FROM thursday)::integer - 1) / 7 + 1;
  RETURN NEW;
END;
$$;

-- Invoker function: no elevated permissions and no change to existing RLS.
REVOKE ALL ON FUNCTION public.normalize_macro_goal_week() FROM PUBLIC;
DROP TRIGGER IF EXISTS normalize_macro_goal_week ON public.long_term_goals;
CREATE TRIGGER normalize_macro_goal_week
  BEFORE INSERT OR UPDATE ON public.long_term_goals
  FOR EACH ROW EXECUTE FUNCTION public.normalize_macro_goal_week();

-- Idempotent: an explicit date is never interpreted as a legacy week again.
UPDATE public.long_term_goals SET week_start_date = NULL
WHERE type::text = 'weekly' AND week_start_date IS NULL
  AND year IS NOT NULL AND month IS NOT NULL AND week_number IS NOT NULL;

COMMIT;
