-- Capture of live function get_habit_analytics (was missing from repo / schema drift).
-- Verbatim from pg_get_functiondef on the production Supabase DB.
CREATE OR REPLACE FUNCTION public.get_habit_analytics(p_user_id uuid)
 RETURNS TABLE(goal_id uuid, worst_dow integer, avg_recovery_days numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH
    -- 1. Worst Day of Week (Giorno Nero)
    dow_stats AS (
        SELECT
            gl.goal_id,
            EXTRACT(ISODOW FROM gl.date)::integer as dow,
            COUNT(*) as total_days,
            COUNT(*) FILTER (WHERE gl.status = 'done') as done_days
        FROM public.goal_logs gl
        WHERE gl.user_id = p_user_id
        GROUP BY gl.goal_id, dow
    ),
    dow_rate AS (
        SELECT
            ds.goal_id,
            ds.dow,
            CASE WHEN ds.total_days > 0 THEN ds.done_days::float / ds.total_days ELSE 0 END as rate
        FROM dow_stats ds
    ),
    ranked_dow AS (
        SELECT
            dr.goal_id,
            dr.dow,
            ROW_NUMBER() OVER (PARTITION BY dr.goal_id ORDER BY dr.rate ASC, dr.dow ASC) as rank
        FROM dow_rate dr
    ),
    worst_days AS (
        SELECT rd.goal_id, rd.dow
        FROM ranked_dow rd
        WHERE rd.rank = 1
    ),

    -- 2. Average Recovery Time (Tempo di Recupero)
    lead_done AS (
        SELECT
            gl.goal_id,
            gl.date,
            LEAD(gl.date) OVER (PARTITION BY gl.goal_id ORDER BY gl.date) as next_done_date
        FROM public.goal_logs gl
        WHERE gl.user_id = p_user_id AND gl.status = 'done'
    ),
    recovery_stats AS (
        SELECT
            ld.goal_id,
            AVG(ld.next_done_date - ld.date - 1)::numeric as avg_rec
        FROM lead_done ld
        WHERE ld.next_done_date IS NOT NULL
        GROUP BY ld.goal_id
    )

    SELECT
        g.id as goal_id,
        COALESCE(wd.dow, 1) as worst_dow,
        COALESCE(rs.avg_rec, 0) as avg_recovery_days
    FROM public.goals g
    LEFT JOIN worst_days wd ON g.id = wd.goal_id
    LEFT JOIN recovery_stats rs ON g.id = rs.goal_id
    WHERE g.user_id = p_user_id;
END;
$function$;
