-- Capture of live function get_critical_habits (was missing from repo / schema drift).
-- Verbatim from pg_get_functiondef on the production Supabase DB.
CREATE OR REPLACE FUNCTION public.get_critical_habits(p_user_id uuid)
 RETURNS TABLE(goal_id uuid, drop numeric, neg_streak integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH user_goals AS (
        SELECT g.id as u_goal_id
        FROM public.goals g
        WHERE g.user_id = p_user_id
    ),
    recent_logs AS (
        SELECT
            gl.goal_id as l_goal_id,
            gl.date as l_date,
            gl.status as l_status
        FROM public.goal_logs gl
        WHERE gl.user_id = p_user_id
          AND gl.date >= (CURRENT_DATE - INTERVAL '14 days')::date
    ),
    this_week AS (
        SELECT
            ug.u_goal_id as w_goal_id,
            COUNT(rl.l_date) FILTER (WHERE rl.l_date >= (CURRENT_DATE - INTERVAL '7 days')::date AND rl.l_status = 'done')::numeric as done_count,
            COUNT(rl.l_date) FILTER (WHERE rl.l_date >= (CURRENT_DATE - INTERVAL '7 days')::date)::numeric as total_count
        FROM user_goals ug
        LEFT JOIN recent_logs rl ON ug.u_goal_id = rl.l_goal_id
        GROUP BY ug.u_goal_id
    ),
    last_week AS (
        SELECT
            ug.u_goal_id as w_goal_id,
            COUNT(rl.l_date) FILTER (WHERE rl.l_date < (CURRENT_DATE - INTERVAL '7 days')::date AND rl.l_status = 'done')::numeric as done_count,
            COUNT(rl.l_date) FILTER (WHERE rl.l_date < (CURRENT_DATE - INTERVAL '7 days')::date)::numeric as total_count
        FROM user_goals ug
        LEFT JOIN recent_logs rl ON ug.u_goal_id = rl.l_goal_id
        GROUP BY ug.u_goal_id
    ),
    drops AS (
        SELECT
            tw.w_goal_id as d_goal_id,
            COALESCE(
                (CASE WHEN lw.total_count > 0 THEN (lw.done_count / lw.total_count) ELSE 0 END) -
                (CASE WHEN tw.total_count > 0 THEN (tw.done_count / tw.total_count) ELSE 0 END),
                0
            ) * 100 as calculated_drop
        FROM this_week tw
        LEFT JOIN last_week lw ON tw.w_goal_id = lw.w_goal_id
    ),
    neg_streaks AS (
        SELECT
            ug.u_goal_id as s_goal_id,
            COALESCE(
                CURRENT_DATE - MAX(rl.l_date) FILTER (WHERE rl.l_status = 'done'),
                14
            )::integer as calculated_neg_streak
        FROM user_goals ug
        LEFT JOIN recent_logs rl ON ug.u_goal_id = rl.l_goal_id
        GROUP BY ug.u_goal_id
    )
    SELECT
        tw.w_goal_id as goal_id,
        dr.calculated_drop as drop,
        ns.calculated_neg_streak as neg_streak
    FROM this_week tw
    JOIN drops dr ON tw.w_goal_id = dr.d_goal_id
    JOIN neg_streaks ns ON tw.w_goal_id = ns.s_goal_id
    WHERE dr.calculated_drop > 0 OR ns.calculated_neg_streak > 3
    ORDER BY dr.calculated_drop DESC, ns.calculated_neg_streak DESC;
END;
$function$;
