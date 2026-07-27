# Handoff Prompt — iCloud Sync hardening, final pass

> Give the agent everything below the line. It is written to be pasted as-is.

---

You are picking up an iCloud-sync hardening effort in the Flutter monorepo at
`/Users/simone.mattioli/Developer/mattioli.OS`. A previous agent did the bulk of
the work across a long session; you are finishing it.

**Read `ICLOUD_SYNC_STATE.md` in the repo root FIRST, in full, before touching
anything.** It contains the architecture, what was verified on real hardware,
and the complete defect list with file references. This prompt gives you the
mandate, the order, and the rules. That document gives you the facts.

## Your mandate

Close **Tier A** (3 correctness gaps) and **Tier C** (17 known defects) from
`ICLOUD_SYNC_STATE.md`.

**Explicitly NOT yours:**
- **Tier B** (untested paths) — verification on physical devices. The owner does
  this. There is no Xcode on the development machine; you cannot build or run
  anything native.
- **Tier D** (HealthKit-in-iCloud, the dead push capability, the coverage gaps) —
  these are product/legal decisions. **Do not decide them. Do not implement
  around them.** If your work touches one, stop and report.

## The one thing you must internalise

This codebase has a single recurring failure: **it reports success while
failing.** Read §0 of `ICLOUD_SYNC_STATE.md`. Six distinct instances are listed,
and one of them was *introduced by the agent that was fixing the other five*,
about an hour before it was caught.

Two implementation agents in the previous session finished with fully green test
suites, and adversarial reviewers found user-visible bugs unfixed in **both**
cases. **Green tests are not evidence in this repository.** Neither is your own
confidence.

## Order of work — do not reorder

1. **A1 — stop reporting success on failure.** Everything else is easier to trust
   once the system stops lying. `sync_engine.dart:307` stamps
   `last_full_sync_at` unconditionally after the push. Make it conditional on the
   push having actually succeeded, carry a failure count on `SyncResult`, and
   make the UI reflect it. There is already a precedent to follow:
   `SyncDiagnostics.isFullySynced` is documented as *the only condition under
   which a UI may claim "up to date"*.
2. **A2 — retry, backoff, `retryAfter`.** Handle `CKError.requestRateLimited`,
   `.serviceUnavailable`, `.zoneBusy` and the server's `retryAfterSeconds` in both
   Swift bridges. This is the gap most likely to bite a NEW user with a large
   first push — the exact profile of the original reported bug.
3. **A3 — `qualityOfService`** on every CKOperation, not just the subscription op.
4. **C1–C3** — sync engine/store defects. Shared package; highest blast radius.
5. **C4–C8** — mobile.
6. **C9–C17** — desktop. **Start with C9**: the confirmed root cause of the
   original user-visible symptom has zero test coverage.

## Definition of done — per item, non-negotiable

For **every** item you fix:

1. **A regression test named after the failure**, asserting the *behaviour*, not
   that the code runs. It must fail before your fix and pass after. Verify that
   ordering explicitly — write the test first, watch it fail, then fix.
2. **An adversarial review pass before you report back.** Re-read your own diff
   against the original claim and try to refute that it is fixed. The previous
   session's misses would both have been caught this way: a test asserting *"the
   same stored accent renders identically on two devices"* would have failed
   while `applyProfile` still coerced it.
3. If you **cannot** fix something, say so plainly. **Do not reframe an unfixed
   item as "working as intended" or "not reproducible" without evidence.** That
   is the same failure signature wearing a different hat, and it is worse than
   leaving the item open.

State, per item: fixed / not fixed / not-a-defect-and-here-is-why.

## Hard rules

- **Do not commit.** The owner commits. Do not run `git stash`, `checkout`,
  `reset`, or `commit`.
- **`packages/evolve_sync/` is a shared contract.** Both apps must agree with it,
  and devices in the field run older builds. A change there is a wire-format
  change — treat it as such.
- **Schema is v11.** Any migration must be idempotent AND must not assume its
  predecessor's side effects (see `createSyncTriggers`, which skips
  not-yet-existing tables for exactly that reason).
- **`goals` is HABITS. `long_term_goals` is macro GOALS.** Every grep for
  `'goals'` hits the habits table. This inverts the meaning of most bug reports.
- **Never widen `localOnlyColumns` or `syncedSettingKeys` without saying so
  loudly.** Those two lists encode product decisions the owner made explicitly
  (entitlement and consent stay device-local; `biometric_lock` stays local
  because device capability differs).
- Follow each app's existing style, UI kit, and i18n workflow (edit
  `lib/i18n/*.i18n.json`, then `dart run slang`; all five locales: en, it, es,
  de, ar).

## Verification commands

```bash
# shared package
cd packages/evolve_sync && flutter test            # currently 157

# mobile
cd mobile && flutter analyze lib/ && flutter test  # currently 431, 0 errors

# desktop — dart-defines are REQUIRED
cd desktop && flutter analyze lib/ && flutter test \
  --dart-define=EVOLVE_SUPABASE_URL=https://dummy.supabase.co \
  --dart-define=EVOLVE_SUPABASE_PUBLISHABLE_KEY=dummy       # currently 462, 0 errors
```

A bare `flutter test` on desktop reports **one** failure **by design** — a
security test asserting that Supabase config comes from build-time defines. Do
not "fix" it by weakening the assertion.

Both apps' `flutter analyze` are clean as of 2026-07-27 — the findings that used
to be pre-existing here (the `unused_element_parameter` in
`desktop/lib/features/auth/presentation/auth_page.dart` among them) were cleared
when CI started gating desktop. Treat any analyzer output as yours.

## Project conventions

- Append a dated summary to `DOCUMENTATION.md` after each change (format is
  established there).
- Append anything requiring a manual/owner action to `TO_SIMO_DO.md`.
- Do **not** add `Co-Authored-By` or "Generated with" trailers anywhere.

## What good looks like when you are finished

- All three suites green, with the desktop dart-defines.
- Every Tier A and Tier C item explicitly accounted for: fixed with a named
  regression test, or reported unfixed with a reason.
- No new instance of the report-success-on-failure pattern. Before you report
  back, grep your own diff for places you swallow an error, return a default on
  failure, or treat an error code as success — and justify each one that remains.
- `ICLOUD_SYNC_STATE.md` updated to reflect the new reality, so the next reader
  inherits an accurate document rather than this one.
