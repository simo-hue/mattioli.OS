-- Soft-delete support for custom macro-goal categories.
-- Existing categories remain active because archived_at defaults to NULL.

ALTER TABLE public.macro_goal_categories
ADD COLUMN IF NOT EXISTS archived_at timestamp with time zone;

CREATE INDEX IF NOT EXISTS macro_goal_categories_active_idx
ON public.macro_goal_categories (user_id, created_at)
WHERE archived_at IS NULL;
