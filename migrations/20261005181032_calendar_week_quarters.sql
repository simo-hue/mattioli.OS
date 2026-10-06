-- Follow-up to calendar_goal_weeks: quarterly statistics must use the
-- owning month of the week, including rows already converted by that migration.
-- No week dates, targets, statuses or progress values are rescheduled.
BEGIN;

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
  NEW.quarter := (NEW.month - 1) / 3 + 1;
  NEW.week_number := (EXTRACT(DAY FROM thursday)::integer - 1) / 7 + 1;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.normalize_macro_goal_week() FROM PUBLIC;

-- The installed BEFORE trigger keeps future old/new client writes consistent.
-- Repair only derived quarters of already-migrated weekly rows.
UPDATE public.long_term_goals
SET quarter = EXTRACT(QUARTER FROM week_start_date + 3)::integer
WHERE type::text = 'weekly' AND week_start_date IS NOT NULL
  AND quarter IS DISTINCT FROM
      EXTRACT(QUARTER FROM week_start_date + 3)::integer;

COMMIT;
