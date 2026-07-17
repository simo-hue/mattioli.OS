# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Update for the habits to decide the day of the week to decide when it should be completed and obviously when it should appear on the day's pop up calendar view. The desktop UI element is already in place but from mobile is totally missing
- [ ] In the habits protocol tab view I want to see only the current habits and not also the past ones
- [ ] MacOS app doesn't have the log in phase, I want to have the same logic of the mobile iOS app as it's professional and complete
- [ ] Cloud mode for AI, in both mobile and desktop implementation, we need to implement the fact that they need to insert their API Keys, we can also give a possibility to add two of them so they can have a back up in case the first one is not working ( if you think it does make sense )
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] Curor of AI Coach Response
- [ ] From mobile implementation, in the settings the "App logs" field has to few bottom margin from the button "Go to login", I want you to increase it.
- [ ] mobile animation between lateral scroll on the goals page? Improve it

## Repo reorganisation (2026-07-17) — web client moved into `web-app/`

- [ ] **Next web deploy must run from `web-app/`, not the repo root**: `cd web-app && npm run deploy`. The build is verified, but the deploy itself is NOT — proving it would have meant publishing to the live site (https://simo-hue.github.io/mattioli.OS/), which I did not do uninvited. The reasoning is sound (git resolves from any subdirectory, `gh-pages -d dist` resolves `dist/` relative to cwd), but it is reasoning, not evidence. First deploy after this change: watch it.
- [ ] Dev/CI habit change: `npm install` / `npm run dev` / `npm run build` / `npm run lint` all now run from `web-app/`. The repo root has no `package.json`.
- [ ] `npm run lint` is red — 96 problems (83 errors, 13 warnings) in `web-app/src`. **Pre-existing**, verified identical before and after the move. Worth a cleanup pass at some point; it means lint can never gate anything today.
- [ ] `npm ci` reports 14 vulnerabilities (7 moderate, 7 high). Pre-existing, untouched. Needs a deliberate `npm audit` review.
- [ ] Decide the fate of the web tracker. You said you don't use it and only care about the website. It stayed in this move (deleting a live, publicly-marketed surface that strangers may hold Supabase accounts on is a product decision, not a refactor). The code already splits cleanly — 9 public marketing routes vs everything under `/sw` behind `ProtectedRoute` — so removing it later is cheap. Check the Supabase dashboard for active non-you accounts before deciding.
- [ ] Related: root `README.md` still markets the tracker as "Free Forever" and `/get-started` still onboards strangers into signing up. If the tracker is effectively abandoned, that's a truthfulness problem independent of the code.

---