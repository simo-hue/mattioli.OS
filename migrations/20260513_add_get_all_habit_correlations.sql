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
            gl.goal_id,
            gl.date
        FROM public.goal_logs gl
        WHERE gl.user_id = p_user_id AND gl.status = 'done'
    ),
    habit_counts AS (
        -- Count total completions for each habit
        SELECT 
            hd.goal_id,
            count(*)::integer as total_count
        FROM habit_dates hd
        GROUP BY hd.goal_id
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
        p.source_id,
        p.target_id,
        CASE 
            WHEN hc.total_count > 0 THEN ((p.common_count::numeric / hc.total_count) * 100)::integer
            ELSE 0
        END,
        p.common_count
    FROM pairs p
    JOIN habit_counts hc ON p.source_id = hc.goal_id
    ORDER BY 3 DESC; -- Order by percentage (3rd column)
END;
$$;
