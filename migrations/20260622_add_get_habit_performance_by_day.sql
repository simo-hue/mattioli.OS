-- Capture of live function get_habit_performance_by_day (was missing from repo / schema drift).
-- Verbatim from pg_get_functiondef on the production Supabase DB.
-- NOTE: day_index uses ISODOW (1 = Monday .. 7 = Sunday).
CREATE OR REPLACE FUNCTION public.get_habit_performance_by_day(p_user_id uuid, p_goal_id uuid)
 RETURNS TABLE(day_index integer, done_count integer, total_count integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        EXTRACT(ISODOW FROM date)::integer as day_index,
        COUNT(id) FILTER (WHERE status = 'done')::integer as done_count,
        COUNT(id)::integer as total_count
    FROM public.goal_logs
    WHERE user_id = p_user_id AND goal_id = p_goal_id
    GROUP BY day_index
    ORDER BY day_index;
END;
$function$;
