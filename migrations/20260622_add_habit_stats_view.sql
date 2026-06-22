-- Capture of live view habit_stats (was missing from repo / schema drift).
-- Verbatim from pg_get_viewdef on the production Supabase DB.
-- rate = total 'done' completions * 100 / days since the goal's start_date (min 1 day).
CREATE OR REPLACE VIEW public.habit_stats AS
 WITH latest_logs AS (
         SELECT DISTINCT ON (goal_logs.goal_id) goal_logs.goal_id,
            goal_logs.streak,
            goal_logs.date
           FROM goal_logs
          ORDER BY goal_logs.goal_id, goal_logs.date DESC
        )
 SELECT g.id AS goal_id,
    g.user_id,
    g.title,
    COALESCE(ll.streak, 0) AS current_streak,
    COALESCE(( SELECT max(goal_logs.streak) AS max
           FROM goal_logs
          WHERE goal_logs.goal_id = g.id AND goal_logs.status = 'done'::text), 0) AS best_streak,
    COALESCE(( SELECT abs(min(goal_logs.streak)) AS abs
           FROM goal_logs
          WHERE goal_logs.goal_id = g.id AND goal_logs.status = 'missed'::text), 0) AS worst_streak,
    COALESCE(( SELECT count(*) AS count
           FROM goal_logs
          WHERE goal_logs.goal_id = g.id AND goal_logs.status = 'done'::text), 0::bigint) AS total_completions,
    COALESCE(( SELECT count(*) AS count
           FROM goal_logs
          WHERE goal_logs.goal_id = g.id AND goal_logs.status = 'missed'::text), 0::bigint) AS missed_days,
    GREATEST(CURRENT_DATE - g.start_date::date + 1, 1) AS total_active_days,
    COALESCE((( SELECT count(*) AS count
           FROM goal_logs
          WHERE goal_logs.goal_id = g.id AND goal_logs.status = 'done'::text))::numeric * 100.0 / NULLIF(GREATEST(CURRENT_DATE - g.start_date::date + 1, 1), 0)::numeric, 0::numeric) AS rate
   FROM goals g
     LEFT JOIN latest_logs ll ON g.id = ll.goal_id;
