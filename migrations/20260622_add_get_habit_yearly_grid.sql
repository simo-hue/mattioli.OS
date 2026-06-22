-- Capture of live function get_habit_yearly_grid (was missing from repo / schema drift).
-- Verbatim from pg_get_functiondef on the production Supabase DB.
-- status_code: done = 1, missed = 2, otherwise 0. Window = last 365 days, ascending.
CREATE OR REPLACE FUNCTION public.get_habit_yearly_grid(p_user_id uuid, p_goal_id uuid)
 RETURNS TABLE(status_code integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH date_range AS (
        SELECT
            (CURRENT_DATE - i * INTERVAL '1 day')::date as date
        FROM generate_series(0, 364) i
    )
    SELECT
        COALESCE(
            CASE
                WHEN gl.status = 'done' THEN 1
                WHEN gl.status = 'missed' THEN 2
                ELSE 0
            END,
            0
        )::integer as status_code
    FROM date_range dr
    LEFT JOIN public.goal_logs gl ON dr.date = gl.date AND gl.user_id = p_user_id AND gl.goal_id = p_goal_id
    ORDER BY dr.date ASC;
END;
$function$;
