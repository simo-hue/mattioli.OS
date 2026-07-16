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

---

# 🚨 PRE-APP-STORE AUDIT (2026-07-16) — MANUAL ACTIONS REQUIRED

Deep multi-agent audit of `desktop/` + `mobile/` (23 dimensions, 87 candidate findings,
83 confirmed after adversarial verification, 4 refuted). Blockers + high-severity issues
fixed across 3 waves; every fix independently reviewed. **The items below are things ONLY
YOU can do — the code is inert or wrong until they are done.**

## ⛔ BLOCKING — do these BEFORE you submit, in this order

- [ ] **`REVENUECAT_WEBHOOK_SECRET` — FAIL-CLOSED, will break Pro sync if skipped.**
      The webhook previously accepted **unauthenticated** calls: anyone on the internet could
      grant or revoke Pro on any account. It is now fail-closed, so with the secret unset it
      returns 500 to EVERY request **including real RevenueCat ones**, and Pro entitlements
      silently stop syncing to `profiles.is_pro`. Steps:
      1. Generate a high-entropy secret.
      2. `supabase secrets set REVENUECAT_WEBHOOK_SECRET=<value>`
      3. RevenueCat dashboard → webhook → Authorization header = **exactly** `Bearer <value>`
         (the code compares the full header string, `Bearer ` prefix included).
      4. Smoke-test after deploy: a wrong/absent header must 401; a real event must land.

- [ ] **Deploy + configure `supabase/functions/revoke-apple-token`** (App Store Guideline
      5.1.1(v): a Sign in with Apple app MUST revoke the Apple token on account deletion —
      reviewers explicitly test this). **Until this is deployed AND configured, the mobile
      deletion flow is WORSE than before**: the user gets an Apple credential sheet, then a red
      error toast (the account still deletes — fail-safe by design — but it looks broken).
      1. Apple Developer → Certificates, IDs & Profiles → Keys → create a key with
         **Sign in with Apple** enabled. The `.p8` downloads **ONCE ONLY**.
      2. `supabase functions deploy revoke-apple-token`
      3. `supabase secrets set` all four (nothing is hardcoded; nothing ships in the binary):
         - `APPLE_TEAM_ID` — 10-char Team ID (Membership)
         - `APPLE_KEY_ID` — 10-char Key ID of that SIWA key
         - `APPLE_PRIVATE_KEY` — full `.p8` contents, BEGIN/END lines included (literal `\n` ok)
         - `APPLE_CLIENT_ID` — **the iOS bundle id `com.simo.evolve`, NOT the Service ID**
           (mobile uses native SIWA, so the authorizationCode is bound to the bundle id; a
           Service ID here makes Apple reject with `invalid_client`). **Confirm the bundle id.**
      4. Do **NOT** add a `[functions.revoke-apple-token]` block to `supabase/config.toml` —
         edge functions default to `verify_jwt = true`, which is what this function needs.
         Setting `verify_jwt = false` would let anyone revoke anyone's Apple grant.
      - NOTE: this function has **never been executed** (`deno` is not installed on this Mac).
        The ES256/djwt signing + Apple `/auth/token` exchange are reasoned from docs only.
        **Test it on a throwaway account before relying on it.**

## 🔎 New-code review (2026-07-16, follow-up) — one item is YOURS to decide

After committing the fixes, I audited the code the fix-waves themselves wrote (the two edge
functions, the migrations, BYOK) — since that code never went through the original audit. The
revoke-apple-token function and mobile BYOK came back CLEAN. Six smaller issues surfaced; I'm
fixing the four that are in-scope. This one is web-adjacent, so I left it for you:

- [ ] **`public/schema.sql` is served on the public internet.** It sits in the Vite `public/`
      dir, so `vite build` copies it into `dist/` and `.github/workflows/deploy.yml` publishes it to
      GitHub Pages — it's fetchable at `https://simo-hue.github.io/mattioli.OS/schema.sql` (robots
      `Allow: /`). It's a full DB schema dump (table/column names + RLS policy definitions) of the
      SAME Supabase backend the mobile/desktop apps use. No secrets or data rows — it's information
      disclosure, LOW severity, and the same content is already public in your source repo. But a
      DB DDL dump has no reason to be a shipped static web asset. You told me to leave the web app
      alone, so I did not touch it. Fix when convenient: remove `schema.sql` from `public/` (the
      root-level `schema.sql` copy is not served and can stay). The `schema.sql` at the repo root
      and in `public/` are not identical — the public one is actually a staler subset.

## ✅ Webhook out-of-order guard — now IMPLEMENTED (adds one migration to your list)

The deferred item from the new-code review is done in code (independently reviewed GOOD, all
ordering cases traced). It makes the RevenueCat webhook reject stale/reordered redeliveries (an
EXPIRATION redelivered after a RENEWAL can no longer wrongly revoke a paying user).

- [ ] **Apply the new migration** `migrations/20260716_add_revenuecat_event_timestamp.sql`
      (alongside the other two 2026-07-16 migrations). It adds a nullable
      `profiles.revenuecat_event_timestamp_ms` column and pins it (only the service-role webhook
      may write it — a user who could set it would be able to freeze their own `is_pro=true`).
- **Deploy order does NOT matter.** The webhook is deploy-order-safe: if you deploy the function
      before applying the migration, it silently behaves as it did before (idempotency only) and
      starts enforcing ordering automatically once the column exists — no redeploy needed.
- Still no runnable test harness here (no `deno`/`tsc`), so the webhook change is verified by
      review + static inspection, not execution — worth a staging check of a reordered event if you
      have one, but it degrades safely either way.

## 🍏 PREVIOUS APP REVIEW REJECTION (Submission 4a3fcd37, macOS v1.0(1), July 15 2026)

Two guidelines were cited. The CODE side of both is now addressed & verified, but each has a
MANUAL App Store Connect half that code cannot do. **Do NOT resubmit without the manual steps.**

### Guideline 3.1.2(c) — subscription disclosures
CODE (verified in the current desktop paywall, Settings → Evolve Pro): plan titles (Monthly/Annual),
length, real StoreKit price (`storeProduct.priceString`, never the plan name), auto-renewal
disclaimer, functional Privacy Policy link (https://simo-hue.github.io/evolve/privacy.html — confirmed
live, 200), functional Terms/EULA link (Apple standard EULA), Restore Purchases, Manage Subscription.
Mobile paywall has the same. **This half is done.**

- [ ] **MANUAL (required — the code fix alone does NOT clear this):** in App Store Connect, add the
      **Terms of Use (EULA) link to the App Description** (or the custom-EULA field), and the
      **Privacy Policy URL to the Privacy Policy field**. The reviewer explicitly required the links
      in the *metadata*, not just the app. Use the same two URLs the app uses.

### Guideline 2.1(b) — "cannot locate the In-App Purchases"
Most likely CODE cause is now fixed: macOS OAuth sign-in was DEAD in release builds (the missing
`com.apple.security.network.server` entitlement), and the paywall sits behind the login gate in
Supabase mode — so the reviewer couldn't sign in → couldn't reach Settings → couldn't find the IAP.
That entitlement is now present, and the paywall loads real products (public RevenueCat key committed,
`isConfigured` = true). **But 2.1(b) is mostly manual/config + a required reply:**

- [ ] **Accept the Paid Apps Agreement** (App Store Connect → Business). IAP will not function at all
      until the Account Holder accepts it — a prime suspect for "cannot locate the IAP."
- [ ] **Confirm the IAP products are submitted & in a review-ready state** and configured for the
      Apple sandbox (the monthly + yearly subscriptions).
- [ ] **Reply to the reviewer with the navigation steps**, e.g.: "Launch app → complete onboarding →
      sign in → open **Settings** → **Evolve Pro** section → the Monthly/Annual plans and prices are
      shown there, with Restore Purchases." Put this in the App Review Information → Notes field too.
- [ ] Provide a **screen recording** of the paywall (the reviewer asked for one to confirm).
