# Habit Classes — Compound (OR/AND) + Quantitative Targets — Implementation & Go‑Live Plan

_Agreed via grilling session, 2026‑07‑24. Scope: bring the two dark "new habit"
features live, professionally and fully working, across BOTH platforms (iOS +
macOS) and BOTH sync modes (Account/Cloud + Private)._

---

## 1. Verified current state
- All three "new habit" features are **built, committed (`main` == `origin/main`), and DARK** behind `const false` flags. That is the entire reason the creation UI is invisible — the flags tree‑shake the widgets out.
- Committed private‑DB schema = **v10**. Last **deployed** build on devices = **v6**; the v7→v10 legs pass unit tests (evolve_sync 229 green) but have **never executed on a real SQLCipher file with real data**.
- Flags today: `healthKitEnabled=true`, `screenTimeAppsEnabled=true` (verification LIVE); `compoundVerificationEnabled=false`, `TargetsConfig.enabled=false`, `MacroTargetsConfig.enabled=false` (dark).

## 2. Scope (locked)
- **IN:** compound OR/AND (condition‑level, HealthKit‑only); quantitative targets (count / duration / limit).
- **OUT (accepted deferrals):** macro numeric goals (migration applied, flag stays off); Screen‑Time‑as‑compound‑operand; weekly‑quota targets; live duration timer; progress rings on the 5 read‑only surfaces.

### 2a. Weekly quota ("gym 4×/week") — PERMANENTLY deferred (decided 2026‑07‑27)

Closed, not backlogged. Recorded here so the analysis is not re‑derived.

The cheap part is real: `TargetPeriod.week` already round‑trips, and
`daysInPeriod` / `periodIsOver` already handle a week correctly
(`packages/evolve_targets/lib/src/target_axes.dart`). So the *preset* is one
entry. That is also the trap — the earlier note concluded "one preset entry, not
a rewrite", which contradicted its own premise.

What actually blocks it is that a quota is a **second completion semantics**, not
a second period:

- A quota habit has **no fixed days**. "Gym 4×/week" means `frequency_days` must
  be all‑7, so `computeStreak` (`streak_utils.dart:42`) walks seven days, sees
  three non‑done days every week, and kills the streak weekly. Streaks would be
  permanently wrong for every quota habit.
- **Completion‑rate denominators** break the same way: 3 of 7 days would count as
  misses instead of "not needed".
- It contradicts desktop's documented **"off‑day habits are HIDDEN"** invariant —
  a quota has no off‑days until the quota is met, at which point the *remaining*
  days should go quiet, and nothing in the stack knows that.
- No SQL surface buckets `goal_logs` by week, so the analytics layer would score
  it wrong even if the client were right.

A preset the streak engine and the stats cannot score is a lie to the user, so it
stays out. Revisit only as a deliberate "quota habit type" project with its own
streak rule — never as a preset.

## 3. Locked design decisions
| # | Decision |
|---|---|
| Q1 | Compound = **condition‑level** — combine HealthKit *measurements* inside ONE habit ("10k steps OR 30 min exercise"). NOT chaining separate habits. |
| Q2 | Scope = compound + targets. Macro deferred (migration applied anyway). |
| Q3/Q4 | UI = mutually‑exclusive **class picker**: **Checkbox / Number / Automatic**. Compound nested under Automatic. **Class is DERIVED** (`verificationRule != null`→Automatic, `target != null`→Number, else Checkbox) — **no new class column**. Default = Checkbox; one‑tap fast‑add preserved. |
| — | Desktop authors **Checkbox / Number only**. A synced **Automatic** habit shows read‑only ("Verified — edit on iPhone") with class **locked**, so a Mac can never wipe an iPhone‑authored HealthKit rule. |
| Q5 | **Forward‑only freeze for targets**: new `target_effective_from` (schema **v11**), mirroring `verify_effective_from` (D10). Past is frozen; edits apply forward. |
| Q6 | Gating: Checkbox / Number / single‑metric Automatic = **FREE**; compound = **PRO**; existing 5‑habit cap unchanged. |
| Q7 | Deploy: migrations first → single **dual‑platform v11 build** → QA the v6→v11 chain → **simultaneous** iOS+macOS release → **no rollback**. Full parity in **both** Cloud and Private modes. |

## 4. Work breakdown (phased)

### Phase 0 — Adversarial audit of the existing foundation (audit‑first)
Multi‑agent Workflow; each finding adversarially verified; fix confirmed bugs **before** Phase 1. Dimensions:
- **Reconcile conflict** — the never‑exercised **both‑flags‑on** world: a habit carrying both a target and a verification rule → manual‑target sweep vs verification pipeline both writing `goal_logs.status`.
- **Cloud/Private parity** — every new column + the `goal_progress` table round‑trips through **Supabase AND** the private‑DB/CloudKit path; import/backup allowlists on both apps.
- **Migration chain** — v6→v10 correctness on a real encrypted file (idempotency, downgrade guards, the three‑legs‑in‑one‑open case).
- **Import/backup round‑trips** — `target`, `goal_progress`, `verify_conditions`, `verify_effective_from`.
- Add a one‑line debug log of `PrivateDbSchema.version` + the DB's actual `user_version` at open, so Simone can read the real on‑device schema version from the device console.

### Phase 1 — `target_effective_from` (v11 forward‑only freeze)
- Private schema **v10→v11** `_upgradeToV11`: `ALTER TABLE goals ADD COLUMN target_effective_from TEXT` (nullable, idempotent guard, same pattern as `_upgradeToV7`).
- Supabase migration `migrations/20260724_add_goal_target_effective_from.sql` (additive, nullable).
- `Goal.targetEffectiveFrom` (mobile) + `DashboardHabit.targetEffectiveFrom` (desktop) + `goals.ts` type parity (web, minimal); desktop repo READ must populate the anchor (else a desktop edit wipes it).
- Pure `stampTargetEffectiveFrom(updated, previous, today)` in `goal.dart`: stamp **today** iff `HabitTarget` value‑equality changed or newly set; **preserve** prior anchor (incl. null) on non‑target edits; **clear** when the target is removed.
- Wire into `addHabit` / `updateHabit` on **both** platforms; ensure `updateHabit` runs **both** the verify and target stamps (composes correctly for class changes).
- `reconcileManualTargetDays` `start` = `max(startDate, targetEffectiveFrom)`.
- Backup / import round‑trip through **every** column allowlist in both apps.
- Tests: `evolve_targets`, `evolve_sync`, mobile, desktop.

### Phase 2 — Class picker UI (mobile + desktop)
**Mobile** (`habit_management_modal.dart`):
- Add a compact segmented **"How is this tracked?"** control: Checkbox / Number / Automatic. Default Checkbox.
- Selecting a mode **clears the others' state** (mutual exclusion): Number→clear rule+conditions; Automatic→clear target; Checkbox→clear both.
- Number → `TargetField`; Automatic → `VerificationRuleField` (+ compound `CompoundConditionsField`, Pro‑gated inside).
- On edit, derive the selected mode from the existing rule/target.
- Replace the additive "both fields show" layout (remove the "orthogonal" branch).

**Desktop** (`habits_page.dart` editor):
- Picker = **Checkbox / Number** only.
- A synced Automatic habit: render class **read‑only** and disabled ("Verified — edit on iPhone").
- Number → `TargetField`.

i18n for the picker labels across all 5 locales.

### Phase 3 — Flip flags (in the release build, after QA)
- `compoundVerificationEnabled = true`, `TargetsConfig.enabled = true`. Keep `MacroTargetsConfig = false`.

### Phase 4 — Rigor
- ~~Widen the CI paths filter so changes under `packages/evolve_sync`, `packages/evolve_targets`, `migrations/` run their tests + `schema_drift_test.dart`.~~ **DONE.** Extended again on 2026‑07‑27: `desktop/**` + `schema.sql` added to the paths filter, a **`desktop` job** added (84 test files that had been running on nothing), and `evolve_legal` added to the packages matrix. Phase 2 edits `desktop/lib/.../habits_page.dart`, so that surface is now guarded *before* the class‑picker work lands on it.
- Arabic native review of new i18n (`targets.*`, `verification.compound.*`, picker labels) — machine MSA now, flagged.

### Phase 5 — Ops (Simone's Mac; I have no Xcode here)
- Apply the **5** Supabase migrations, in order: `verify_effective_from`, `verify_conditions`, `goal_targets_and_progress`, `macro_goal_targets`, `target_effective_from`.
- Build v11 for both platforms with flags on.
- On‑device QA (§6), both modes.
- **Simultaneous** iOS + macOS release. **Never** publish a pre‑v11 build afterward (`onDowngrade` throws → brick).

## 5. Deploy sequence & hazards (must‑follow order)
1. Apply all Supabase migrations (additive/nullable → live v6 clients keep working).
2. Build the single v11 dual‑platform release (schema chain v6→v11 + class picker + flags on).
3. QA that exact build on a real iPhone + Mac: the encrypted v6→v11 migration opens cleanly; both platforms sync; both modes; no downgrade brick.
4. Release iOS + macOS together; no rollback.

**Hazard:** `onDowngrade` in `private_db_schema.dart` throws by design — once a device migrates up it cannot open an older‑schema build. Cross‑*device* skew is safe (sync strips/preserves unknown columns).

## 6. On‑device QA script (Simone) — run per mode: Account **and** Private
- **Migration:** fresh install over existing v6 data opens without error; confirm schema is 11 (debug log from Phase 0).
- **Number:** create count / duration / limit habits; log via ± stepper; confirm ring + streak. **Edit a target amount UP → PAST days must stay unchanged** (freeze), forward applies.
- **Compound:** create "10k steps OR 30 min exercise" as Pro; confirm verdict on a passing/failing day; confirm a non‑Pro user hits the paywall on "+ Add condition".
- **Class change:** Checkbox → Number → Automatic on one habit; confirm history is frozen at each switch.
- **Parity:** create on iPhone → appears on Mac read‑only (Automatic) / editable (Number); repeat in Private mode (CloudKit).

## 7. Division of labor
- **Me (no Xcode):** all Dart / SQL / TS, tests, migrations authored, CI config, i18n; Swift typecheck‑only if any is touched (none expected — features reuse existing bridges and the Dart sync engine).
- **Simone (Mac):** apply migrations, Xcode build, on‑device QA, simultaneous release.

## 8. Accepted v1 deferrals
Screen‑Time compound operand; live duration timer (± stepper for now); rings on the 5 read‑only surfaces; weekly‑quota targets (permanent); macro numeric goals (flag off).
