-- Fix function_search_path_mutable warning
-- Set a fixed search_path for the function to prevent malicious code from executing with the privileges of the function owner
ALTER FUNCTION public.update_updated_at_column() SET search_path = public, pg_temp;
