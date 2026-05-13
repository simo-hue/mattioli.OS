-- Create function to get macro goals statistics
CREATE OR REPLACE FUNCTION public.get_macro_goals_stats(p_user_id uuid, p_year text)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_result jsonb;
BEGIN
    IF p_year = 'all' THEN
        -- Global stats
        WITH all_goals AS (
            SELECT * FROM public.long_term_goals WHERE user_id = p_user_id
        ),
        total_stats AS (
            SELECT 
                count(*)::integer as total_goals,
                count(*) FILTER (WHERE status = 'completed')::integer as completed_goals
            FROM all_goals
        ),
        year_stats AS (
            SELECT 
                year,
                count(*)::integer as total,
                count(*) FILTER (WHERE status = 'completed')::integer as completed,
                count(*) FILTER (WHERE status = 'active')::integer as active,
                count(*) FILTER (WHERE status = 'failed')::integer as failed
            FROM all_goals
            WHERE year IS NOT NULL
            GROUP BY year
        ),
        best_year_stat AS (
            SELECT 
                year,
                CASE WHEN total > 0 THEN (completed::numeric / total * 100)::integer ELSE 0 END as rate
            FROM year_stats
            ORDER BY rate DESC, total DESC
            LIMIT 1
        ),
        most_prod_year_stat AS (
            SELECT 
                year,
                total
            FROM year_stats
            ORDER BY total DESC
            LIMIT 1
        ),
        category_stats AS (
            SELECT 
                COALESCE(category_id::text, category_key) as category,
                count(*)::integer as total,
                count(*) FILTER (WHERE status = 'completed')::integer as completed
            FROM all_goals
            WHERE category_id IS NOT NULL OR category_key IS NOT NULL
            GROUP BY COALESCE(category_id::text, category_key)
        ),
        type_stats AS (
            SELECT 
                type,
                count(*)::integer as total
            FROM all_goals
            GROUP BY type
        ),
        seasonality_stats AS (
            SELECT 
                quarter,
                count(*) FILTER (WHERE status = 'active')::integer as active,
                count(*) FILTER (WHERE status = 'failed')::integer as failed,
                count(*) FILTER (WHERE status = 'completed')::integer as completed
            FROM all_goals
            WHERE quarter IS NOT NULL
            GROUP BY quarter
        ),
        monthly_stats AS (
            SELECT 
                month,
                count(*)::integer as total,
                count(*) FILTER (WHERE status = 'completed')::integer as completed
            FROM all_goals
            WHERE month IS NOT NULL
            GROUP BY month
        ),
        interest_evolution AS (
            SELECT 
                year,
                COALESCE(category_id::text, category_key) as category,
                count(*)::integer as total
            FROM all_goals
            WHERE year IS NOT NULL AND (category_id IS NOT NULL OR category_key IS NOT NULL)
            GROUP BY year, COALESCE(category_id::text, category_key)
        )
        SELECT jsonb_build_object(
            'total_goals', (SELECT total_goals FROM total_stats),
            'completed_goals', (SELECT completed_goals FROM total_stats),
            'best_year', (SELECT year FROM best_year_stat),
            'best_year_rate', (SELECT rate FROM best_year_stat),
            'most_productive_year', (SELECT year FROM most_prod_year_stat),
            'most_productive_count', (SELECT total FROM most_prod_year_stat),
            'year_progression', (
                SELECT jsonb_agg(jsonb_build_object(
                    'year', year,
                    'active', active,
                    'failed', failed,
                    'completed', completed,
                    'total', total
                ) ORDER BY year) FROM year_stats
            ),
            'category_performance', (
                SELECT jsonb_agg(jsonb_build_object(
                    'category', category,
                    'rate', CASE WHEN total > 0 THEN (completed::numeric / total * 100)::integer ELSE 0 END
                )) FROM category_stats
            ),
            'type_distribution', (
                SELECT jsonb_object_agg(type, total) FROM type_stats
            ),
            'seasonality', (
                SELECT jsonb_agg(jsonb_build_object(
                    'quarter', quarter,
                    'active', active,
                    'failed', failed,
                    'completed', completed
                ) ORDER BY quarter) FROM seasonality_stats
            ),
            'monthly_history', (
                SELECT jsonb_agg(jsonb_build_object(
                    'month', month,
                    'rate', CASE WHEN total > 0 THEN (completed::numeric / total * 100)::integer ELSE 0 END
                ) ORDER BY month) FROM monthly_stats
            ),
            'interest_evolution', (
                SELECT jsonb_agg(jsonb_build_object(
                    'year', year,
                    'categories', (
                        SELECT jsonb_object_agg(category, total) 
                        FROM interest_evolution ie2 
                        WHERE ie2.year = ie.year
                    )
                ) ORDER BY year) FROM (SELECT DISTINCT year FROM interest_evolution) ie
            )
        ) INTO v_result;
        
    ELSE
        -- Specific year stats
        DECLARE
            v_year_int integer;
        BEGIN
            v_year_int := p_year::integer;
            
            WITH year_goals AS (
                SELECT * FROM public.long_term_goals WHERE user_id = p_user_id AND year = v_year_int
            ),
            total_stats AS (
                SELECT 
                    count(*)::integer as total_goals,
                    count(*) FILTER (WHERE status = 'completed')::integer as completed_goals
                FROM year_goals
            ),
            category_stats AS (
                SELECT 
                    COALESCE(category_id::text, category_key) as category,
                    count(*)::integer as total,
                    count(*) FILTER (WHERE status = 'completed')::integer as completed
                FROM year_goals
                WHERE category_id IS NOT NULL OR category_key IS NOT NULL
                GROUP BY COALESCE(category_id::text, category_key)
            ),
            best_cat_stat AS (
                SELECT 
                    category,
                    CASE WHEN total > 0 THEN (completed::numeric / total * 100)::integer ELSE 0 END as rate
                FROM category_stats
                ORDER BY rate DESC, total DESC
                LIMIT 1
            ),
            month_stats AS (
                SELECT 
                    month,
                    count(*)::integer as total,
                    count(*) FILTER (WHERE status = 'completed')::integer as completed,
                    count(*) FILTER (WHERE status = 'active')::integer as active,
                    count(*) FILTER (WHERE status = 'failed')::integer as failed
                FROM year_goals
                WHERE month IS NOT NULL
                GROUP BY month
            ),
            best_month_stat AS (
                SELECT 
                    month,
                    CASE WHEN total > 0 THEN (completed::numeric / total * 100)::integer ELSE 0 END as rate
                FROM month_stats
                ORDER BY rate DESC, total DESC
                LIMIT 1
            ),
            type_stats AS (
                SELECT 
                    type,
                    count(*)::integer as total,
                    count(*) FILTER (WHERE status = 'completed')::integer as completed
                FROM year_goals
                GROUP BY type
            ),
            best_type_stat AS (
                SELECT 
                    type,
                    CASE WHEN total > 0 THEN (completed::numeric / total * 100)::integer ELSE 0 END as rate
                FROM type_stats
                ORDER BY rate DESC, total DESC
                LIMIT 1
            ),
            quarterly_stats AS (
                SELECT 
                    quarter,
                    count(*)::integer as total,
                    count(*) FILTER (WHERE status = 'completed')::integer as completed,
                    count(*) FILTER (WHERE status = 'active')::integer as active,
                    count(*) FILTER (WHERE status = 'failed')::integer as failed
                FROM year_goals
                WHERE quarter IS NOT NULL
                GROUP BY quarter
            ),
            monthly_composed AS (
                SELECT 
                    m.month,
                    COALESCE(s.total, 0) as total,
                    COALESCE(s.completed, 0) as completed,
                    COALESCE(s.active, 0) as active,
                    COALESCE(s.failed, 0) as failed
                FROM generate_series(1, 12) m(month)
                LEFT JOIN month_stats s ON m.month = s.month
            ),
            cumulative_monthly AS (
                SELECT 
                    mc.month,
                    sum(mc.total) OVER (ORDER BY mc.month)::integer as total,
                    sum(mc.completed) OVER (ORDER BY mc.month)::integer as completed
                FROM monthly_composed mc
            )
            SELECT jsonb_build_object(
                'total_goals', (SELECT total_goals FROM total_stats),
                'completed_goals', (SELECT completed_goals FROM total_stats),
                'success_rate', CASE WHEN (SELECT total_goals FROM total_stats) > 0 THEN ((SELECT completed_goals FROM total_stats)::numeric / (SELECT total_goals FROM total_stats) * 100)::integer ELSE 0 END,
                'best_category', (SELECT category FROM best_cat_stat),
                'best_category_rate', (SELECT rate FROM best_cat_stat),
                'best_month', (SELECT month FROM best_month_stat),
                'best_month_rate', (SELECT rate FROM best_month_stat),
                'best_type', (SELECT type FROM best_type_stat),
                'best_type_rate', (SELECT rate FROM best_type_stat),
                'cumulative_monthly', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'month', month,
                        'total', total,
                        'completed', completed
                    )) FROM cumulative_monthly
                ),
                'category_rates', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'category', category,
                        'rate', CASE WHEN total > 0 THEN (completed::numeric / total * 100)::integer ELSE 0 END
                    )) FROM category_stats
                ),
                'quarterly_activity', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'quarter', quarter,
                        'total', total,
                        'completed', completed,
                        'active', active,
                        'failed', failed
                    ) ORDER BY quarter) FROM quarterly_stats
                ),
                'monthly_composed', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'month', month,
                        'total', total,
                        'completed', completed,
                        'active', active,
                        'failed', failed
                    ) ORDER BY month) FROM monthly_composed
                ),
                'category_distribution', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'category', category,
                        'count', total
                    )) FROM category_stats
                )
            ) INTO v_result;
        END;
    END IF;
    
    RETURN v_result;
END;
$$;
