-- Add 'lifetime' to long_term_goal_type enum
ALTER TYPE public.long_term_goal_type ADD VALUE IF NOT EXISTS 'lifetime';

-- Make year nullable
ALTER TABLE public.long_term_goals ALTER COLUMN year DROP NOT NULL;
