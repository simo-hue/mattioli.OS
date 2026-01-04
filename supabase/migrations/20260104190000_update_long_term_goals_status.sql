-- Add status column
ALTER TABLE public.long_term_goals 
ADD COLUMN status text NOT NULL DEFAULT 'active';

-- Migrate existing data
UPDATE public.long_term_goals 
SET status = 'completed' 
WHERE is_completed = true;

-- Drop old column
ALTER TABLE public.long_term_goals 
DROP COLUMN is_completed;

-- Add check constraint
ALTER TABLE public.long_term_goals 
ADD CONSTRAINT long_term_goals_status_check 
CHECK (status IN ('active', 'completed', 'failed'));
