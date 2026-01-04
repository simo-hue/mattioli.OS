-- Fix security definer view error
ALTER VIEW IF EXISTS public.user_daily_stats SET (security_invoker = true);

-- Add user_id to reading_logs
ALTER TABLE public.reading_logs 
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) DEFAULT auth.uid();

-- Update reading_logs constraints
ALTER TABLE public.reading_logs DROP CONSTRAINT IF EXISTS reading_logs_date_key;
ALTER TABLE public.reading_logs DROP CONSTRAINT IF EXISTS reading_logs_user_date_key;
ALTER TABLE public.reading_logs ADD CONSTRAINT reading_logs_user_date_key UNIQUE (user_id, date);

-- Update reading_logs policies
DROP POLICY IF EXISTS "Allow all access to reading_logs" ON public.reading_logs;
DROP POLICY IF EXISTS "Users can view their own reading logs" ON public.reading_logs;
DROP POLICY IF EXISTS "Users can insert their own reading logs" ON public.reading_logs;
DROP POLICY IF EXISTS "Users can update their own reading logs" ON public.reading_logs;
DROP POLICY IF EXISTS "Users can delete their own reading logs" ON public.reading_logs;

CREATE POLICY "Users can view their own reading logs" ON public.reading_logs 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own reading logs" ON public.reading_logs 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own reading logs" ON public.reading_logs 
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reading logs" ON public.reading_logs 
  FOR DELETE USING (auth.uid() = user_id);


-- Add user_id to user_settings
ALTER TABLE public.user_settings 
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) DEFAULT auth.uid();

-- Update user_settings constraints
ALTER TABLE public.user_settings DROP CONSTRAINT IF EXISTS user_settings_key_key;
ALTER TABLE public.user_settings DROP CONSTRAINT IF EXISTS user_settings_user_key_key;
ALTER TABLE public.user_settings ADD CONSTRAINT user_settings_user_key_key UNIQUE (user_id, key);

-- Update user_settings policies
DROP POLICY IF EXISTS "Allow all access to user_settings" ON public.user_settings;
DROP POLICY IF EXISTS "Users can view their own settings" ON public.user_settings;
DROP POLICY IF EXISTS "Users can insert their own settings" ON public.user_settings;
DROP POLICY IF EXISTS "Users can update their own settings" ON public.user_settings;
DROP POLICY IF EXISTS "Users can delete their own settings" ON public.user_settings;

CREATE POLICY "Users can view their own settings" ON public.user_settings 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own settings" ON public.user_settings 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings" ON public.user_settings 
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own settings" ON public.user_settings 
  FOR DELETE USING (auth.uid() = user_id);
