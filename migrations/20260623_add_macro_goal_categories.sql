-- Capture of live table macro_goal_categories (referenced by the app via
-- from('macro_goal_categories') but previously missing from schema.sql /
-- migrations). Reconstructed from the production DB catalog.
CREATE TABLE public.macro_goal_categories (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    name text NOT NULL,
    color text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    archived_at timestamp with time zone,
    UNIQUE (user_id, name),
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Partial index for fetching a user's active (non-archived) categories.
CREATE INDEX macro_goal_categories_active_idx
    ON public.macro_goal_categories USING btree (user_id, created_at)
    WHERE (archived_at IS NULL);
