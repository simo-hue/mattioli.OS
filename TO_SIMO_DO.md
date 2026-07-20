# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] what happens if I modify manually an automatic habits?
- [ ] Different habits & goals types, not only checkboxes like status,progress bar
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported

## prompt

/grill-me we are working inside the flutter implementations on both desktop and mobile versions. What I was thinking about was to Add the "mixture" of habits to make it one ( for example 10 mins of workout OR 10000 steps ). Could exclusive ( OR ) or inclusive ( AND ). What do you think? How we can implement it in the most professional and user friendly way?

## prompt

/grill-me I was thinking about making some updates to the goals and habits. Right now in the flutter implementations, both desktop and mobile are only checkbox marked as pending, completed, failed. What I was thinking is to add a different type like habits or goals that aren't boolean but for example needs to be done more times. For example a push up daily habits that I want to do 20 push ups for four time a day and right now I have to create four different habit for each push up session, but what I would love to reach is to have the single "push up" habit that I can click on it and see the advancement of the habit to reach the 100% ( full completion ) only when I've completed all the steps.

This was only a single idea of new type but I want you to propose me something even more useful and cooler. 

## prompt to run 3
/grill-me  The current desktop AI coach implementation is almost perfect: 

* privacy mode: the user needs his own open router's API KEY;
* standard mode ( user connected with supabase ) uses my API KEY so the user doesn't need to care about that. The thing that needs to be implemented is that the user must have the pro subscription to access to the AI Coach. And in addition to that I see that inside the desktop app the paywall is not implemented  ( or at least it seems as when the pop up came out and I clicked on the button to see the plans it has redirected me to the settings in the profile page ). successfully ( as the mobile, where is fully working and professional ).

The mobile implementation is different ( and it's a problem ) as I want the implementations to be coherent as they are reppresenting the same app.

The mobile has already the paywall configured perfectly but the problem is the fact that the AI coach is accessible even from non pro users and it's a problem I want you to fix.

---

# TO DOUBLE CHECK:

- [ ]

## prompt to run 2
/grill-me We are working on the flutter implementation, so both desktop and mobile. And as we have connected the screen time option for the auto-verifiable habits, I want you to ask this question as obviously I set a timer of 10 minutes for example on a specific app but what I was thinking about as it's obviously true at the beginning of the day. The problem is that how is handled the fact that the number obviously increases during the day? Is the habits checked every time? Or whenever it gets it first state then it's fixed and never checked again?


---

```bash
flutter run -d macos --dart-define-from-file=.env
flutter build macos --release --dart-define-from-file=.env
```

---

## iCloud Sync Hardening — Manual Actions (2026-07-20)

### ACTION REQUIRED: run the new diagnostic on BOTH devices
Commit 1/7 adds a **"Sync details"** row under Settings → iCloud Sync (iPhone) and
Settings → Privacy → iCloud Sync (Mac). It has no behaviour change — it only shows what
was already being hidden.

1. Open it on the **iPhone**, tap **Copy report**.
2. Open it on the **Mac Mini**, tap **Copy report**.
3. Send me both.

The per-table `local` counts diffed between the two devices localise the stall exactly.
**Prediction to check:** if the push-stall diagnosis is right, the Mac will also be missing
`daily_moods` and `macro_goal_categories`, and its `goal_logs` count will be lower than the
iPhone's — those sit at or after `long_term_goals` in the upload queue. If the Mac's moods
came through intact, the diagnosis is wrong and the cause is Mac-side apply instead.

### Two data-integrity issues found during the audit (NOT yet fixed — commit 3)
- [ ] `applyDelete` runs with `PRAGMA foreign_keys = ON` while `applyUpsert` deliberately
      turns it OFF. A pulled `macro_goal_categories` tombstone silently `SET NULL`s
      `long_term_goals.category_id`, and a pulled `profiles` tombstone **CASCADE-deletes every
      synced table**. Live data-loss path — scheduled for commit 3, which is why commit 3 is
      ordered before the coverage work.
- [ ] `quarantineRecord`'s `ON CONFLICT` branch updates only `last_error`, so a record that
      already had a `sync_state` row is NOT parked at `quarantineStamp` as its doc comment
      claims. Worked around in diagnostics (splits on `dirty`); fix scheduled for commit 7.

### Known, accepted, unchanged
- 6 desktop tests fail on a clean tree, unrelated to sync (`desktop_supabase_config_security_test`
  needs real dart-defines; `habits_page_keyboard_test` and `widget_test` were already red).
- No Xcode on this machine — nothing here has been run on a real device or simulator.

--- NEW ---

## iCloud Sync — Root Cause CONFIRMED + commit 2 landed (2026-07-20)

### What your diagnostics proved
Your two reports refuted the push-stall theory and identified the real cause: **the iPhone and
the Mac are on two different E2E encryption keys.** The Mac enabled sync before the iPhone's key
had propagated through iCloud Keychain, so it minted its own. Neither device can read the other's
records; the ~6,238 records currently in iCloud are unreadable by both.

**Your data is safe** — all 6,234 rows are intact on the iPhone. The Mac has nothing to lose
(1 profile row + 1 settings row it created itself).

### ACTION REQUIRED: still do NOT enable/reset sync on either device
Commit 2 stops this happening *again*, but does **not** repair your current state: the guard only
fires when a device has no key, and both of yours have one (just different ones). Repair needs the
"Reset sync from this device" action — commit 3, not yet written.

### DO NOT rebuild-and-enable expecting a fix yet
If you install this build and enable sync on the Mac, it will now correctly refuse to mint a third
key, but you will still see no data, because the zone is full of records sealed with the iPhone's
key while the Mac holds its own.

### The recovery sequence (once commit 3 lands)
1. iPhone → Reset sync from this device (wipes the zone + both keychain secrets).
2. iPhone → enable sync → mints ONE key, re-uploads all 6,234 rows.
3. **Wait** for iCloud Keychain to carry the key to the Mac.
4. Mac → enable sync. If the key has not arrived, it now DEFERS ("waiting for iCloud Keychain")
   instead of minting a rival — the whole point of commit 2.

### Open design question for commit 3 (I will ask before implementing)
A device that reinstalls the app with iCloud Keychain **disabled** has no key and never will, so the
new guard defers forever with no escape. That case needs an explicit user-initiated override, or it
trades a data-loss bug for a lockout bug.

### Note
`flutter test` on desktop must be run as:
`flutter test --dart-define=EVOLVE_SUPABASE_URL=… --dart-define=EVOLVE_SUPABASE_PUBLISHABLE_KEY=…`

---

## iCloud Sync — RECOVERY PROCEDURE (commit 3 landed, 2026-07-20)

The repair path now exists. Follow this order exactly — the steps are ordered so a mistake
costs you nothing.

### Before you start
- Your 6,234 rows live ONLY on the iPhone. The Mac has nothing worth keeping.
- Therefore: **run the reset FROM THE IPHONE.** Running it from the Mac would upload the Mac's
  empty database and overwrite the iPhone's copy in iCloud. The confirmation text says this, but
  it is worth saying twice.
- Build and install BOTH apps first (iPhone and Mac). Do not start until both are on this build.

### Steps
1. **iPhone** → Settings → iCloud Sync. You should now see a red card:
   *"Some iCloud data can't be read"* with a count.
2. Tap **Reset sync from this device** → read the confirmation → confirm.
   This wipes the iCloud zone, mints a fresh key, and re-uploads all 6,234 rows.
   With ~6k records it will take a while; leave the app open and in the foreground.
3. Verify on the iPhone: **Sync details** should show `pending 0` on every table and
   `change token: present`.
4. **Wait for the key to reach the Mac.** iCloud Keychain propagation is not instant —
   give it several minutes. Both devices must be online and unlocked.
5. **Mac** → Settings → Privacy → iCloud Sync → turn sync on.
   - If the key has arrived: it adopts it and pulls everything.
   - If it has NOT: it now says *"Waiting for the encryption key from your other device"*
     and offers **Start fresh from this device**. **DO NOT tap Start fresh** — that would
     wipe the iPhone's freshly-uploaded copy. Cancel, wait, and try again later.
6. Verify on the Mac: **Sync details** should show the same per-table counts as the iPhone.

### If step 5 keeps deferring after a long wait
Check iCloud Keychain is enabled on both devices (Settings → Apple ID → iCloud → Passwords and
Keychain). The "Start fresh" override exists only for a device that can NEVER receive the key —
on your setup that is not the case, so deferring means "wait", not "override".

### Still outstanding (not yet fixed)
- [ ] `applyDelete` runs with foreign keys ON — a pulled `profiles` tombstone CASCADE-deletes
      every synced table. **Still live.** Next commit; it matters more than usual during a reset,
      which is exactly when tombstone traffic happens.
- [ ] `syncNow` still stamps `last_full_sync_at` and reports success even when every record failed.
- [ ] Mobile still has no launch sync and no periodic timer.
- [ ] No retry/backoff or `qualityOfService` on any CloudKit operation.
- [ ] `quarantineRecord`'s ON CONFLICT branch does not apply the quarantine stamp.

### Reminder
None of commits 1–3 has run against real CloudKit. The logic is unit-tested; the device behaviour
is not. Report what actually happens at each step above.
