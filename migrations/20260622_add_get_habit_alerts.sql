-- Capture of live function get_habit_alerts (was missing from repo / schema drift).
-- Verbatim from pg_get_functiondef on the production Supabase DB.
-- worst_negative_days = longest consecutive run of 'missed' logs.
-- broken_streaks = up to 5 most recent 'done' runs that were ended by a 'missed' log.
CREATE OR REPLACE FUNCTION public.get_habit_alerts(p_user_id uuid, p_goal_id uuid)
 RETURNS TABLE(worst_negative_days integer, worst_negative_start date, broken_streaks jsonb)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_worst_neg_days integer := 0;
    v_worst_neg_start date;
    v_broken_streaks jsonb;
BEGIN
    -- 1. Calcolo serie negativa peggiore
    WITH grouped_logs AS (
        SELECT
            date,
            status,
            ROW_NUMBER() OVER (ORDER BY date) as rn,
            ROW_NUMBER() OVER (PARTITION BY status ORDER BY date) as rn_status
        FROM public.goal_logs
        WHERE user_id = p_user_id AND goal_id = p_goal_id
    ),
    islands AS (
        SELECT
            MIN(date) as start_date,
            COUNT(*) as streak_length
        FROM grouped_logs
        WHERE status = 'missed'
        GROUP BY (rn - rn_status)
    )
    SELECT streak_length::integer, start_date
    INTO v_worst_neg_days, v_worst_neg_start
    FROM islands
    ORDER BY streak_length DESC
    LIMIT 1;

    -- 2. Calcolo streak interrotti
    WITH grouped_logs_pos AS (
        SELECT
            date,
            status,
            ROW_NUMBER() OVER (ORDER BY date) as rn,
            ROW_NUMBER() OVER (PARTITION BY status ORDER BY date) as rn_status
        FROM public.goal_logs
        WHERE user_id = p_user_id AND goal_id = p_goal_id
    ),
    islands_pos AS (
        SELECT
            MAX(date) as end_date,
            COUNT(*) as streak_length
        FROM grouped_logs_pos
        WHERE status = 'done'
        GROUP BY (rn - rn_status)
    ),
    broken AS (
        SELECT
            ip.streak_length::integer as days,
            (SELECT date FROM public.goal_logs WHERE user_id = p_user_id AND goal_id = p_goal_id AND date > ip.end_date AND status = 'missed' ORDER BY date ASC LIMIT 1) as break_date
        FROM islands_pos ip
        WHERE EXISTS (SELECT 1 FROM public.goal_logs WHERE user_id = p_user_id AND goal_id = p_goal_id AND date > ip.end_date AND status = 'missed')
        ORDER BY break_date DESC
        LIMIT 5
    )
    SELECT jsonb_agg(jsonb_build_object('days', days, 'date', break_date))
    INTO v_broken_streaks
    FROM broken;

    RETURN QUERY SELECT
        COALESCE(v_worst_neg_days, 0),
        v_worst_neg_start,
        COALESCE(v_broken_streaks, '[]'::jsonb);
END;
$function$;
