# Manual Actions Required

- [2026-06-03 17:53 CEST]: Desktop Supabase credential follow-up
  - Configure desktop local/release builds with `EVOLVE_SUPABASE_URL` and `EVOLVE_SUPABASE_PUBLISHABLE_KEY` via local environment variables, CI secrets, or explicit Flutter `--dart-define`/`--dart-define-from-file` flags. Desktop compilation is now intentionally blocked without these values. Do not add them back into source code.
  - Because the old publishable key was already present in a public repository, rotate/regenerate the Supabase client key if you want the exposed value invalidated, then update local/CI build secrets.
  - If historical visibility is unacceptable, remove the old value from public git history with a dedicated history rewrite/secret-removal workflow and force-push after coordinating with anyone using the repository.
  - Recheck Supabase RLS, storage policies, and RPC permissions before public desktop distribution.
  - For Supabase CLI deploys, keep the real project ref in local CLI state or CI secrets and run/link deploy commands with the private project ref outside committed files.
