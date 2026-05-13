# PROSSIME AZIONI MANUALI (SIMO)

## Configurazione Backend & Store
- [ ] Creare account **Apple Developer Program** ($99/anno).
- [ ] Creare account **Google Play Console** ($25 una tantum).
- [ ] Creare progetto su **Supabase** e attivare il **Pro Plan** ($25/mese) per evitare ibernazione e avere backup.
- [ ] Configurare le **Row Level Security (RLS)** su Supabase seguendo la guida in `BACKEND_ARCHITECTURE.md`.
- [ ] Recuperare le API Key di **OpenAI** o **Anthropic** per l'AI Coach.
- [ ] Configurare **Google Sign-In**: creare Web e iOS Client ID su Google Cloud Console e incollarli in `lib/providers/auth_provider.dart`.
- [ ] Configurare **Sign in with Apple**: abilitare Apple Provider su Supabase e la Capability in Xcode.
- [x] Inserire `SUPABASE_URL` e `SUPABASE_ANON_KEY` nel file `lib/core/supabase_config.dart` per l'integrazione reale. (Configurato automaticamente dal file .env)
- [ ] **Abilitare Registrazioni su Supabase**: Nella dashboard di Supabase, vai su **Authentication** -> **Providers** -> **Email** e assicurati che l'opzione **"Enable Signups"** sia ATTIVA. Attualmente le registrazioni sono disabilitate per questa istanza.
- [ ] **Eseguire Migrazione Statistiche (Supporto Categorie)**: Eseguire nuovamente il file `migrations/20260513_add_get_macro_goals_stats.sql` nel SQL Editor di Supabase per supportare le categorie personalizzate.

## Strategia Business & Revenue
- [ ] Decidere se lanciare l'offerta **Lifetime Access** (€99) per i primi 500 utenti.
- [ ] Verificare i requisiti per l'**Apple Small Business Program** (commissione al 15% invece di 30%).
- [ ] Definire i limiti di utilizzo AI per i vari piani (Basic, Premium, Elite).
- [ ] Valutare l'implementazione di **RevenueCat** o **Glassfy** per gestire gli abbonamenti in modo semplice.

## Verifica White Mode (Post-Implementazione)
- [ ] Verificare che tutte le pagine siano correttamente in modalità chiara quando lo switch è attivo.
- [ ] Controllare la leggibilità del testo (evitare testo bianco su sfondo bianco) in:
  - Schermata di Login/Registrazione (AuthScreen).
  - Impostazioni > Informazioni Personali / Privacy / Notifiche.
  - Modali di gestione abitudini e check-in.
  - Tutte le schede delle Statistiche (Trend, Mood, Performance, etc.).
- [ ] Verificare che i grafici (fl_chart) abbiano legende e assi leggibili sia in Light che in Dark Mode.
- [ ] Confermare che il colore accento cambi automaticamente se quello selezionato è troppo chiaro per lo sfondo bianco (gestito da `SettingsProvider`).

## Icona Notifiche (iOS)
- [ ] Risolvere problema icona di default su dispositivo fisico:
  1. Disinstallare l'app dall'iPhone.
  2. Riavviare l'iPhone (pulisce la cache delle icone).
  3. Eseguire `flutter clean` e poi `flutter run` sul dispositivo.

## Verifica Animazioni Premium (Post-Implementazione)

- [ ] Verificare che lo switch tra le schede (Home, Statistiche, Obiettivi) sia fluido.
- [ ] Testare lo swipe orizzontale tra le schede principali.
- [ ] Verificare che lo stato (es. scroll o filtri selezionati) venga mantenuto quando si cambia tab e si torna indietro.
- [ ] Confermare che il feedback aptico (vibrazione leggera) sia piacevole al cambio tab.
active_count,
                COUNT(gl.id) FILTER (WHERE gl.status = 'done') as done_count
            FROM active_goals ag
            LEFT JOIN public.goal_logs gl ON ag.goal_id = gl.goal_id AND ag.date = gl.date::date
            GROUP BY ag.point_index, ag.date
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
              AND (g.frequency_days IS NULL OR EXTRACT(ISODOW FROM dr.date) = ANY(g.frequency_days))
        ),
        day_stats AS (
            SELECT
                ag.point_index,
                ag.date,
                COUNT(ag.goal_id) as active_count,
                COUNT(gl.id) FILTER (WHERE gl.status = 'done') as done_count
            FROM active_goals ag
            LEFT JOIN public.goal_logs gl ON ag.goal_id = gl.goal_id AND ag.date = gl.date::date
            GROUP BY ag.point_index, ag.date
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
              AND (g.frequency_days IS NULL OR EXTRACT(ISODOW FROM dr.date) = ANY(g.frequency_days))
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
              AND (g.frequency_days IS NULL OR EXTRACT(ISODOW FROM dr.date) = ANY(g.frequency_days))
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
$$;
```

### 2. Fix get_critical_habits (Risolve ambiguità goal_id)
```sql
CREATE OR REPLACE FUNCTION public.get_critical_habits(p_user_id uuid)
RETURNS TABLE (
    goal_id uuid,
    drop numeric,
    neg_streak integer
)
LANGUAGE plpgsql
AS $$
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
$$;
```

### 3. Fix get_best_habits (Risolve ambiguità goal_id)
```sql
CREATE OR REPLACE FUNCTION public.get_best_habits(p_user_id uuid, p_timeframe text)
RETURNS TABLE (
    goal_id uuid,
    rate numeric,
    streak integer
)
LANGUAGE plpgsql
AS $$
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
$$;
```