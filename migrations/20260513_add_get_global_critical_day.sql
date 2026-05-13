-- Create function to get global critical day
CREATE OR REPLACE FUNCTION public.get_global_critical_day(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_critical_day text;
BEGIN
    SELECT 
        CASE 
            WHEN extract(dow from date) = 0 THEN 'sun'
            WHEN extract(dow from date) = 1 THEN 'mon'
            WHEN extract(dow from date) = 2 THEN 'tue'
            WHEN extract(dow from date) = 3 THEN 'wed'
            WHEN extract(dow from date) = 4 THEN 'thu'
            WHEN extract(dow from date) = 5 THEN 'fri'
            WHEN extract(dow from date) = 6 THEN 'sat'
        END as day_of_week
    INTO v_critical_day
    FROM public.goal_logs
    WHERE user_id = p_user_id AND status IN ('done', 'missed')
    GROUP BY day_of_week
    HAVING count(*) > 0
    ORDER BY 
        (count(*) FILTER (WHERE status = 'done')::numeric / count(*)) ASC,
        day_of_week ASC
    LIMIT 1;

    RETURN COALESCE(v_critical_day, 'N/A');
END;
$$;
