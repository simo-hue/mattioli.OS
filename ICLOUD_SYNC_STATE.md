# iCloud Sync — State of the World (2026-07-21, second pass)

Rewritten after closing Tier A and Tier C. The previous version of this document
described work that is now done, and — more importantly — several of its own
claims turned out to be wrong. That is recorded below rather than quietly
corrected, because the pattern is the point.

**Verdict: the sync core is production-grade and the app around it now tells the
truth about it.** What remains is hardware verification (Tier B), product/legal
decisions (Tier D), and a handful of residual items listed in `TO_SIMO_DO.md`.

---

## 0. The failure signature that keeps regenerating

Everything that went wrong in this codebase, over weeks, was one bug wearing
different clothes: **the system reported success while failing.**

The original six are listed in git history. This pass found **three more**, none
of which was on any list:

- **A pulled record that failed to apply wrote its error to a row that did not
  exist.** `markError` is a bare `UPDATE ... WHERE record_name = ?`, and a record
  arriving from another device has no `sync_state` row yet — `stateOf()` returned
  null moments earlier. The update matched zero rows and vanished. Meanwhile the
  pull held the change token for it. Net effect: `isFullySynced == true`, a clean
  diagnostics report, and a device re-downloading the entire delta on every sync,
  forever, without converging.
- **Un-parking destroyed unpushed local edits.** `clearUndecryptableParks` rewound
  `updated_at` to the epoch for every matching row with no `dirty` filter. A habit
  edited at `2020-01-01T10:00` came back stamped `1970-01-01` while still queued
  for push — after which any *older* remote copy wins LWW and overwrites it, and a
  pending deletion goes out dated 1970 and loses on every device while the sync
  reports success.
- **`applyUpsert` never subtracted `localOnlyColumns`.** The schema documents them
  as "stripped on push AND preserved on apply"; only the push half existed. It
  held solely because every *current* sender strips — a property of the fleet, not
  of this device. A field build predating `deviceLocalProfileColumns` still pushes
  `is_pro`, and a modern device wrote it. **A synced `is_pro = 1` is an
  in-app-purchase bypass.**

**How the third one was found is the lesson.** It was reported by an implementation
agent as an aside, in a section headed "things I did NOT fix", while it was fixing
something else. It was not on the defect list, and nothing in the test suite would
ever have surfaced it — the existing round-trip test cannot catch it, because its
sender is always a modern stripping engine.

### What this pass changed about how claims are treated

The previous document said "assume any 'this works' claim — including one in this
document — is worth re-verifying against behaviour." That was correct and it was
not strong enough. This pass ran every claim, and:

- **Three first-pass verdicts were wrong in the dangerous direction** (a real
  defect declared NOT_A_DEFECT). One of them, C1, was concealing the un-park
  data-loss bug above — the investigator correctly established that the *named*
  code was fine and stopped there.
- **A reviewer argued A1 was already handled**, on the grounds that the details row
  is gated on `isFullySynced`. It was. The status *headline* returned "Up to date"
  as its unconditional fallback in both apps. A widget test showed "Up to date"
  rendering over 5,000 stranded rows.
- **Two prescribed fixes would have caused data loss** if applied as written (C1's
  proposed `dirty = 0`, C2's proposed align-on-`-1`).

The practice that caught all of these was the same one: **write the test, run it,
watch it fail — before writing the fix.** Reading the code and reasoning about it
produced the wrong answer repeatedly, in both directions, by careful readers.

---

## 1. What is genuinely solid

| Area | Evidence |
|---|---|
| **Data survived** | 3,487 macro goals, 2,549 logs, 170 moods, 20 habits — byte-identical on both devices, all owned by the active identity |
| **Key-split recovery** | Verified on the owner's iPhone + Mac Mini |
| **Cascade delete** | `applyDelete` runs FK-off; regression test uses 3,487 goals |
| **Identity hygiene** | Orphan shells reaped; re-key atomic w.r.t. the Keychain write |
| **Settings sync** | Per-key `user_settings` records (schema v6), confirmed both directions on device |
| **Diagnostics** | Per-table counts + a copyable report. This is what found each root cause |
| **Honest reporting** | `last_full_sync_at` is stamped only by a sync that moved everything it attempted; neither app claims "Up to date" unless `SyncDiagnostics.isFullySynced` licenses it |
| **Tests** | evolve_sync **183**, mobile **449**, desktop **491**. Zero analyze errors |

**Sync converges within ~60 seconds on both devices.**

---

## 2. Tier A — CLOSED in Dart, UNRUN in Swift

- **A1 — success reported on failure.** Fixed. `SyncResult` carries `pushFailed`,
  `pushConflicted`, `pullIncomplete` and `fullySynced`; `syncNow` stamps only when
  `fullySynced`. Both apps' status headline consults `isFullySynced`.
  `SyncDiagnostics` gained a third bucket (`heldByReason`) and `totalStuck`,
  because held and parked records need opposite advice and both apps had
  hand-summed the two they knew about.
- **A2 — retry/backoff/`retryAfter`.** Written in both Swift bridges:
  `.requestRateLimited`, `.serviceUnavailable`, `.zoneBusy`, honouring the server's
  `retryAfterSeconds` with 2s/4s/8s fallback, capped at 3 retries.
  **Never executed** — see below.
- **A3 — `qualityOfService`.** 1 operation per bridge → all 7.

> **The Swift is unverified.** There is no Xcode on the dev machine. Both bridges
> DO typecheck against the real CloudKit framework (`swiftc -typecheck`, Swift 6.3,
> macOS SDK — Command Line Tools ships a compiler even without Xcode), which
> confirms the API surface and nothing about runtime behaviour. Both files were
> patched from one script so they stay line-for-line ports; every changed line is
> byte-identical between them. On-device checklist in `TO_SIMO_DO.md`.

---

## 3. Tier B — untested paths (owner's, needs hardware)

**Not code. Verification.** Unchanged from the previous pass, and still the
largest real risk:

- **Clean install → first enable has never been tested.** Every test so far ran on
  devices that went through a reset *with existing data*. This is the most common
  real path and is entirely unexercised.
- **The v6 migration has never run on a database that was never v5.**
- **Second-device enable from scratch** (not the re-key path).
- **A TestFlight/App Store build** — `aps-environment` is committed as
  `development`.

---

## 4. Tier C — CLOSED

All 17 fixed with named regression tests, with these corrections to the list
itself:

- **C1 is not a defect as written.** `quarantineRecord`'s `ON CONFLICT` clause is
  specified verbatim in its own doc comment, and forcing `dirty = 0` there would
  drop pending local writes out of the push queue. The real bug was its
  counterpart, `clearUndecryptableParks` (§0).
- **C2's consequence was understated.** Not merely non-convergence:
  *annihilation*. Both devices concluded "remote wins", each deleted its own row,
  and the tombstones crossed. The row was destroyed on both machines.
- **C5, C7, C12, C13 were misdescribed** — something real was wrong at each, but
  not what the entry said. C12 was fixed by **narrowing** (`biometric_lock` removed
  from the desktop allow-list), never by widening.
- **C14 is not a defect**; the double-apply is idempotent and clobbers nothing.
- **C15/C16** are the accent bug a previous session "fixed" while the user-visible
  bug survived. The new `accent_parity_test.dart` was mutation-tested: reverting
  `defaultAccent` kills 4 tests, bypassing `normalizeAccentColor` kills 4 more.

`PrivateDbSchema.syncedSettingKeys` and `localOnlyColumns` were **not** widened —
`private_db_schema.dart` is untouched.

---

## 5. Tier D — owner's decisions (an agent must NOT decide these)

Unchanged and deliberately untouched by this pass.

- **D1. HealthKit measurements sync to iCloud.** `goal_logs.value` carries HealthKit
  data and is deliberately not in `localOnlyColumns`. Accepted risk against App
  Store guideline 5.1.3(ii). **A legal/product call.**
- **D2. A Push Notifications capability that does nothing.** Push has never been
  observed to deliver on either device. macOS fails APNs registration with OSStatus
  13 (signing/provisioning, outside the code). Options: fix the signing, remove the
  capability, or ship as-is.
- **D3. Coverage gaps — data that does not sync at all.** Screen Time app
  selections, manual freezes/couldn't-verify markers, AI coach configuration,
  tutorial state. The backup export omits all of it too. This is a design exercise
  and deserves its own session.

---

## 6. Things that will bite a fresh reader

- **`goals` is HABITS. `long_term_goals` is macro GOALS.** Every grep for `'goals'`
  hits the habits table. This inverts the meaning of most bug reports.
- **`packages/evolve_sync/` is the contract.** Both apps must agree; devices in the
  field run older builds. Note the pattern from §0: a guarantee that holds only
  because every current sender behaves is not a guarantee. Enforce it on the
  receiving side.
- **Schema is v11 in this repo; the field is behind it.** Devices still run
  builds at v6 or older, so the v6→v11 chain is unexecuted on real data.
  Migrations must be idempotent AND must not assume their predecessor's side
  effects.
- **`SyncEngine` takes an injectable `clock`** (production never passes it). The
  skew guard's correctness is entirely about the passage of time and is untestable
  against a clock that only reads "now".
- **`SyncResult.fullySynced` and `SyncDiagnostics.isFullySynced` are different
  questions** and must not be collapsed. The first describes THIS sync — did it
  move everything it attempted. The second describes the DEVICE — is anything
  stranded. A sync can complete perfectly while the device is still missing a
  parked record.
- **Desktop tests need dart-defines.** A bare `flutter test` reports one failure BY
  DESIGN (a security test asserting config comes from build-time defines).
- **No Xcode on the dev machine** — but `swiftc` IS available via Command Line
  Tools, so native code can at least be typechecked against the real frameworks.
  Anything beyond that is the owner's.
- **Settings currently dual-write** (per-key rows AND legacy `profiles` columns)
  for one release. Drop the legacy half once both apps are on v6 in the field.
