-- Capture of live function get_best_habits (was missing from repo / schema drift).
-- Verbatim from pg_get_functiondef on the production Supabase DB.
CREATE OR REPLACE FUNCTION public.get_best_habits(p_user_id uuid, p_timeframe text)
 RETURNS TABLE(goal_id uuid, rate numeric, streak integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH user_goals AS (
        SELECT g.id as u_goal_id
        FROM public.goals g
        WHERE g.user_id = p_user_id
    ),
    filtered_logs AS (
        SELECT
            gl.goal_id as l_goal_id,
            gl.date as l_date,
            gl.status as l_status
        FROM public.goal_logs gl
        WHERE gl.user_id = p_user_id
          AND (
            (p_timeframe = 'week' AND gl.date >= (CURRENT_DATE - INTERVAL '7 days')::date) OR
            (p_timeframe = 'month' AND gl.date >= (CURRENT_DATE - INTERVAL '30 days')::date) OR
            (p_timeframe = 'year' AND gl.date >= (CURRENT_DATE - INTERVAL '365 days')::date) OR
            (p_timeframe = 'all')
          )
    ),
    stats AS (
        SELECT
            ug.u_goal_id as s_goal_id,
            COUNT(fl.l_date) FILTER (WHERE fl.l_status = 'done')::numeric as done_count,
            COUNT(fl.l_date)::numeric as total_count
        FROM user_goals ug
        LEFT JOIN filtered_logs fl ON ug.u_goal_id = fl.l_goal_id
        GROUP BY ug.u_goal_id
    ),
    streaks AS (
        SELECT
            ug.u_goal_id as s_goal_id,
            COALESCE(
                (SELECT COUNT(*)::integer
                 FROM public.goal_logs gl2
                 WHERE gl2.goal_id = ug.u_goal_id
                   AND gl2.status = 'done'
                   AND gl2.date > COALESCE(
                       (SELECT MAX(gl3.date) FROM public.goal_logs gl3 WHERE gl3.goal_id = ug.u_goal_id AND gl3.status != 'done'),
                       '1970-01-01'::date
                   )
                ),
                0
            ) as calculated_streak
        FROM user_goals ug
    )
    SELECT
        ug.u_goal_id as goal_id,
        COALESCE(CASE WHEN s.total_count > 0 THEN (s.done_count / s.total_count) * 100 ELSE 0 END, 0)::numeric as rate,
        st.calculated_streak as streak
    FROM user_goals ug
    JOIN stats s ON ug.u_goal_id = s.s_goal_id
    JOIN streaks st ON ug.u_goal_id = st.s_goal_id
    ORDER BY rate DESC, streak DESC
    LIMIT 5;
END;
$function$;
