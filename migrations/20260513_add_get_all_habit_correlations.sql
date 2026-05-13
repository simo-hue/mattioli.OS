-- Create function to get all habit correlations for a user
CREATE OR REPLACE FUNCTION public.get_all_habit_correlations(p_user_id uuid)
RETURNS TABLE (
    goal_id uuid,
    other_goal_id uuid,
    percentage integer,
    together_count integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH habit_dates AS (
        -- Get all dates where habits were completed
        SELECT 
            goal_id,
            date
        FROM public.goal_logs
        WHERE user_id = p_user_id AND status = 'done'
    ),
    habit_counts AS (
        -- Count total completions for each habit
        SELECT 
            goal_id,
            count(*)::integer as total_count
        FROM habit_dates
        GROUP BY goal_id
    ),
    pairs AS (
        -- Find pairs of habits completed on the same day
        SELECT 
            a.goal_id as source_id,
            b.goal_id as target_id,
            count(*)::integer as common_count
        FROM habit_dates a
        JOIN habit_dates b ON a.date = b.date AND a.goal_id != b.goal_id
        GROUP BY a.goal_id, b.goal_id
    )
    SELECT 
        p.source_id as goal_id,
        p.target_id as other_goal_id,
        CASE 
            WHEN hc.total_count > 0 THEN ((p.common_count::numeric / hc.total_count) * 100)::integer
            ELSE 0
        END as percentage,
        p.common_count as together_count
    FROM pairs p
    JOIN habit_counts hc ON p.source_id = hc.goal_id
    ORDER BY percentage DESC;
END;
$$;
