-- Capture of live function get_habit_correlations (was missing from repo / schema drift).
-- Verbatim from pg_get_functiondef on the production Supabase DB.
CREATE OR REPLACE FUNCTION public.get_habit_correlations(p_user_id uuid, p_target_goal_id uuid)
 RETURNS TABLE(goal_id uuid, together_count integer, percentage integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH target_done_dates AS (
        SELECT gl.date
        FROM public.goal_logs gl
        WHERE gl.user_id = p_user_id AND gl.goal_id = p_target_goal_id AND gl.status = 'done'
    ),
    other_habits_stats AS (
        SELECT
            gl2.goal_id as other_goal_id,
            COUNT(gl2.id) as count_together
        FROM public.goal_logs gl2
        JOIN target_done_dates tdd ON gl2.date = tdd.date
        WHERE gl2.user_id = p_user_id AND gl2.goal_id != p_target_goal_id AND gl2.status = 'done'
        GROUP BY gl2.goal_id
    ),
    target_total_done AS (
        SELECT COUNT(*)::float as total_target_done FROM target_done_dates
    )
    SELECT
        ohs.other_goal_id, -- Mappa automaticamente sulla colonna goal_id del RETURN TABLE
        ohs.count_together::integer as together_count,
        CASE
            WHEN ttd.total_target_done > 0 THEN ROUND((ohs.count_together::float / ttd.total_target_done) * 100)::integer
            ELSE 0
        END as percentage
    FROM other_habits_stats ohs
    CROSS JOIN target_total_done ttd
    ORDER BY percentage DESC;
END;
$function$;
