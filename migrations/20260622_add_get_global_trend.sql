-- Capture of live function get_global_trend (was missing from repo / schema drift).
-- Verbatim from pg_get_functiondef on the production Supabase DB.
CREATE OR REPLACE FUNCTION public.get_global_trend(p_user_id uuid, p_timeframe text)
 RETURNS TABLE(point_index integer, date date, rate numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_timeframe = 'timeframe_week_short' THEN
        RETURN QUERY
        WITH date_range AS (
            SELECT
                i as point_index,
                (CURRENT_DATE - (13 - i) * INTERVAL '1 day')::date as date
            FROM generate_series(0, 13) i
        ),
        active_goals AS (
            SELECT
                g.id as goal_id,
                dr.point_index,
                dr.date
            FROM date_range dr
            CROSS JOIN public.goals g
            WHERE g.user_id = p_user_id
              AND dr.date >= g.start_date::date
              AND (g.end_date IS NULL OR dr.date <= g.end_date::date)
              AND (g.frequency_days IS NULL OR EXTRACT(ISODOW FROM dr.date)::integer = ANY(g.frequency_days))
        ),
        day_stats AS (
            SELECT
                dr.point_index,
                dr.date,
                COUNT(ag.goal_id) FILTER (WHERE gl.status IS NULL OR gl.status != 'skipped') as active_count,
                COUNT(gl.id) FILTER (WHERE gl.status = 'done') as done_count
            FROM date_range dr
            LEFT JOIN active_goals ag ON dr.point_index = ag.point_index
            LEFT JOIN public.goal_logs gl ON ag.goal_id = gl.goal_id AND ag.date = gl.date::date
            GROUP BY dr.point_index, dr.date
        )
        SELECT
            ds.point_index,
            ds.date,
            COALESCE(CASE WHEN ds.active_count > 0 THEN (ds.done_count::numeric / ds.active_count) * 100 ELSE 100.0 END, 100.0) as rate
        FROM day_stats ds
        ORDER BY ds.point_index;

    ELSIF p_timeframe = 'timeframe_month_short' THEN
        RETURN QUERY
        WITH date_range AS (
            SELECT
                i as point_index,
                (CURRENT_DATE - (59 - i) * INTERVAL '1 day')::date as date
            FROM generate_series(0, 59) i
        ),
        active_goals AS (
            SELECT
                g.id as goal_id,
                dr.point_index,
                dr.date
            FROM date_range dr
            CROSS JOIN public.goals g
            WHERE g.user_id = p_user_id
              AND dr.date >= g.start_date::date
              AND (g.end_date IS NULL OR dr.date <= g.end_date::date)
              AND (g.frequency_days IS NULL OR EXTRACT(ISODOW FROM dr.date)::integer = ANY(g.frequency_days))
        ),
        day_stats AS (
            SELECT
                dr.point_index,
                dr.date,
                COUNT(ag.goal_id) FILTER (WHERE gl.status IS NULL OR gl.status != 'skipped') as active_count,
                COUNT(gl.id) FILTER (WHERE gl.status = 'done') as done_count
            FROM date_range dr
            LEFT JOIN active_goals ag ON dr.point_index = ag.point_index
            LEFT JOIN public.goal_logs gl ON ag.goal_id = gl.goal_id AND ag.date = gl.date::date
            GROUP BY dr.point_index, dr.date
        )
        SELECT
            ds.point_index,
            ds.date,
            COALESCE(CASE WHEN ds.active_count > 0 THEN (ds.done_count::numeric / ds.active_count) * 100 ELSE 100.0 END, 100.0) as rate
        FROM day_stats ds
        ORDER BY ds.point_index;

    ELSIF p_timeframe = 'timeframe_year_short' THEN
        RETURN QUERY
        WITH month_range AS (
            SELECT
                i as point_index,
                (DATE_TRUNC('month', CURRENT_DATE) - (23 - i) * INTERVAL '1 month')::date as month_start
            FROM generate_series(0, 23) i
        ),
        day_range AS (
            SELECT
                mr.point_index,
                mr.month_start,
                generate_series(
                    mr.month_start,
                    LEAST(CURRENT_DATE, (mr.month_start + INTERVAL '1 month' - INTERVAL '1 day')::date),
                    INTERVAL '1 day'
                )::date as date
            FROM month_range mr
        ),
        active_goals AS (
            SELECT
                g.id as goal_id,
                dr.point_index,
                dr.date
            FROM day_range dr
            CROSS JOIN public.goals g
            WHERE g.user_id = p_user_id
              AND dr.date >= g.start_date::date
              AND (g.end_date IS NULL OR dr.date <= g.end_date::date)
              AND (g.frequency_days IS NULL OR EXTRACT(ISODOW FROM dr.date)::integer = ANY(g.frequency_days))
        ),
        day_stats AS (
            SELECT
                ag.point_index,
                ag.date,
                COUNT(ag.goal_id) FILTER (WHERE gl.status IS NULL OR gl.status != 'skipped') as active_count,
                COUNT(gl.id) FILTER (WHERE gl.status = 'done') as done_count
            FROM active_goals ag
            LEFT JOIN public.goal_logs gl ON ag.goal_id = gl.goal_id AND ag.date = gl.date::date
            GROUP BY ag.point_index, ag.date
        ),
        day_rates AS (
            SELECT
                ds.point_index,
                ds.date,
                CASE WHEN ds.active_count > 0 THEN (ds.done_count::numeric / ds.active_count) * 100 ELSE 100.0 END as rate
            FROM day_stats ds
        )
        SELECT
            dr.point_index,
            DATE_TRUNC('month', MIN(dr.date))::date as date,
            AVG(dr.rate)::numeric as rate
        FROM day_rates dr
        GROUP BY dr.point_index
        ORDER BY dr.point_index;

    ELSE -- 'timeframe_all'
        RETURN QUERY
        WITH earliest_date AS (
            SELECT COALESCE(MIN(start_date)::date, (CURRENT_DATE - INTERVAL '30 days')::date) as edate
            FROM public.goals
            WHERE user_id = p_user_id
        ),
        total_days AS (
            SELECT (CURRENT_DATE - edate) as days FROM earliest_date
        ),
        interval_calc AS (
            SELECT
                CASE WHEN days > 10 THEN CEIL(days::float / 10)::integer ELSE 1 END as interval,
                CASE WHEN days > 10 THEN 10 ELSE days + 1 END as points_count
            FROM total_days
        ),
        points AS (
            SELECT
                i as point_index,
                (ed.edate + i * ic.interval * INTERVAL '1 day')::date as start_date,
                (ed.edate + (i + 1) * ic.interval * INTERVAL '1 day' - INTERVAL '1 day')::date as end_date
            FROM generate_series(0, (SELECT points_count - 1 FROM interval_calc)) i
            CROSS JOIN earliest_date ed
            CROSS JOIN interval_calc ic
        ),
        day_range AS (
            SELECT
                p.point_index,
                generate_series(p.start_date, LEAST(CURRENT_DATE, p.end_date), INTERVAL '1 day')::date as date
            FROM points p
        ),
        active_goals AS (
            SELECT
                g.id as goal_id,
                dr.point_index,
                dr.date
            FROM day_range dr
            CROSS JOIN public.goals g
            WHERE g.user_id = p_user_id
              AND dr.date >= g.start_date::date
              AND (g.end_date IS NULL OR dr.date <= g.end_date::date)
              AND (g.frequency_days IS NULL OR EXTRACT(ISODOW FROM dr.date)::integer = ANY(g.frequency_days))
        ),
        day_stats AS (
            SELECT
                ag.point_index,
                ag.date,
                COUNT(ag.goal_id) FILTER (WHERE gl.status IS NULL OR gl.status != 'skipped') as active_count,
                COUNT(gl.id) FILTER (WHERE gl.status = 'done') as done_count
            FROM active_goals ag
            LEFT JOIN public.goal_logs gl ON ag.goal_id = gl.goal_id AND ag.date = gl.date::date
            GROUP BY ag.point_index, ag.date
        ),
        day_rates AS (
            SELECT
                ds.point_index,
                ds.date,
                CASE WHEN ds.active_count > 0 THEN (ds.done_count::numeric / ds.active_count) * 100 ELSE 100.0 END as rate
            FROM day_stats ds
        )
        SELECT
            dr.point_index,
            MIN(dr.date) as date,
            AVG(dr.rate)::numeric as rate
        FROM day_rates dr
        GROUP BY dr.point_index
        ORDER BY dr.point_index;
    END IF;
END;
$function$;
