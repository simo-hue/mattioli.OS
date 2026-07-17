# TO_SIMO_DO.md

## 🔴 SECURITY — act before anything else (found 2026-07-17)

- [ ] **ROTATE the App Store review test account password. It is public right now.**
  `mobile/app_store_connect_guide.md` shipped the review test account's email **and its password in plain text**. That file is committed and **already on `origin/main`** (commit `b69e325`, "ultime modifiche pre review") — so the credential has been publicly readable on GitHub for as long as that commit has existed. This is a **working login to your production Supabase**, on an account you deliberately set `is_pro = true`, so anyone who read the repo has a free, fully-unlocked Pro account. (The plaintext is now redacted from the working tree — see commit below — but that only stops it spreading further; it is still in the pushed history. The password itself is deliberately not repeated here.)
  **Why deleting the line is NOT enough:** the repo is public and the commit is pushed. It's in the history, in GitHub's API, and possibly in forks, clones and caches. The only fix that actually closes it is:
  1. Change the password in Supabase (Auth → Users → `apple-tester@evolve.com`).
  2. Update the Review Notes in App Store Connect with the new password.
  3. Then remove the plaintext from the guide (say "see App Store Connect → Review Notes" instead). Ask me and I'll do step 3.
  **Blast radius is limited** — RLS is correctly enforced on all 8 tables, so that account can only reach its own rows, not other users' data. But check whether the AI Coach in cloud mode bills a server-side key: if so, a free Pro account is a budget-drain vector.

- [ ] **Stop pasting raw Apple Transporter / altool logs into tracked files.** `TO_SIMO_DO.md` history (commits `d84fe5f`, `63db5e8`, `c828849`) contains a ~1200-line verbose upload log with a live `dqsid` session cookie for `contentdelivery.itunes.apple.com`. It expired 2026-07-16 23:06 UTC so there's no action needed — but you got lucky: Apple's logger happened to redact `X-Apple-GS-Token` itself. A different tool, or a different day, and that's a real Apple session in a public repo. Dump those logs to an ignored path.

- [x] ~~**Mobile CI had NEVER passed — 0 successes in 60 runs since 2026-06-22.**~~ The 17 analyzer lints are fixed (commit `c19e527`): 10 curly-braces, 2 prefer-final-locals, 1 unawaited-future, and the 4 `Radio.groupValue`/`onChanged` deprecations migrated to a `RadioGroup` ancestor. `flutter analyze --fatal-infos` is clean and `flutter test` is at 302 passing.

- [ ] **The CI cause is still unfixed — only the symptom is.** `.github/workflows/mobile-ci.yml` still uses `subosito/flutter-action@v2` with `channel: stable` (**unpinned**) plus `--fatal-infos`. That combination is what let CI rot with no code change on your side: Flutter shipped 3.32, deprecated `Radio.groupValue`, and your build went red on its own. **It will happen again on the next Flutter release that adds any lint.** Pin `flutter-version:` to the version you actually develop against (currently 3.44.4) and bump it deliberately. One line — ask and I'll do it. Without this, today's green is temporary.

- [ ] **On-device check of the backup-import dialog.** I migrated the Merge/Replace radios in `privacy_settings_screen.dart` to `RadioGroup`. That dialog had zero widget coverage, and Replace deletes every record not in the backup — so I added `test/import_mode_radio_test.dart` pinning the contract (Merge preselected; selection propagates both ways). That test mirrors the dialog's widget structure but cannot pump the dialog itself, since the tree is declared inline inside `_handleImport`. So: tap through one real import once and confirm Merge is preselected and Replace actually selects. If you'd rather, I can extract the dialog into its own widget so it becomes directly testable.

- [ ] **Consider adding secret scanning to CI** — GitHub's free push protection (Settings → Code security → Secret scanning), or a `gitleaks` step. Nothing would have caught a hand-written password like that one automatically, but push protection catches the classes that matter (cloud keys, tokens) before they land.

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
- [ ] Related: `/get-started` on the website still onboards strangers into signing up for the tracker. (The root README's "Free Forever" claim is now fixed — see below.)

## README rewrite (2026-07-17) — things only you can answer

- [ ] **Is the macOS app live on the Mac App Store?** I found no link anywhere in the repo and you only gave me the iOS one, so the README says the desktop client is "build from source" and carries NO Mac App Store link. If it's live, send me the URL and I'll add it — I would not invent one.
- [ ] **Your English App Store screenshots show Italian UI.** Every shot under `mobile/assets/multilingua_images/apple/English (en-US)/` renders the app in Italian ("Buongiorno, apple", "Gestione Abitudini", "Evoluzione Performance") with only the marketing captions in English. Same likely applies to the German/Spanish/Arabic sets. Worth a re-capture with the app's locale switched — it directly affects App Store conversion.
- [ ] **The store has Chinese Traditional screenshots but the app ships no Chinese translation.** `multilingua_images/apple/Chinese Traditional (zh-Hant)/` exists; `mobile/lib/i18n/` has only ar, de, en, es, it. Either the zh listing is misleading or a translation is missing.
- [ ] **Brand split is now explicit**: the README + native apps + App Store all say **Evolve**; the website (`web-app/index.html` `<title>`, `og:title`, landing copy) still says **Mattioli.OS**. That's a deliberate state, not a bug — but decide whether the site should become Evolve too, or whether they're genuinely separate products.
- [ ] **"Free Forever" was false and is now removed.** The old README claimed it while both clients ship a RevenueCat paywall. Replaced with the verified two-mode model (Private = free + fully unlocked, Cloud = free core + Evolve Pro). If any marketing copy elsewhere — the website, the App Store description, `docs/APP_DESCRIPTION.md` — still says "free forever", it has the same problem.

---