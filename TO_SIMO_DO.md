# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] From iOS I cannot understand the difference between a classic habits and an automatic one
- [ ] Protocol from desktop only the current habits not all ( the removed one should not be visible )
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

```bash
flutter build ipa --release
```

---

### Still outstanding (not yet fixed)
- [ ] `applyDelete` runs with foreign keys ON — a pulled `profiles` tombstone CASCADE-deletes
      every synced table. **Still live.** Next commit; it matters more than usual during a reset,
      which is exactly when tombstone traffic happens.
- [ ] `syncNow` still stamps `last_full_sync_at` and reports success even when every record failed.
- [ ] Mobile still has no launch sync and no periodic timer.
- [ ] No retry/backoff or `qualityOfService` on any CloudKit operation.
- [ ] `quarantineRecord`'s ON CONFLICT branch does not apply the quarantine stamp.

---
---

## CloudKit Push Subscriptions — build prerequisites (2026-07-21)

### DONE BY YOU
- [x] Push Notifications capability enabled on App ID `com.simo.evolve`.

### BEFORE THE FIRST BUILD — refresh provisioning profiles
The apps now declare `aps-environment` in their entitlements. If the profile on
disk predates the capability, the build fails at the **SIGNING** step, not at compile.
- Xcode → Settings → Accounts → your team → **Download Manual Profiles** (automatic signing),
  or regenerate + re-download both apps' profiles in the portal (manual signing).
- If you see an error mentioning a missing `aps-environment` entitlement: it is the
  PROFILE, not the code.
- You do NOT need an APNs certificate. CloudKit sends subscription pushes itself;
  the portal's "Certificates (0)" is for pushing from your own server.

### ON-DEVICE VERIFICATION
1. Build BOTH apps. Watch the logs for `[CloudKit] Zone change subscription registered`.
   Absent ⇒ registration failed; sync still works on the 3-minute poll (by design).
2. Change the accent colour on the iPhone. The Mac should update in **seconds**, without
   Cmd+Q and without switching away and back.
3. Change a setting on the Mac. Same, in reverse.
4. If it takes ~3 minutes instead of seconds, push is not being delivered but polling is
   covering — check step 1's log line first.

### KNOWN LIMITS (by design, not bugs)
- Apple does NOT guarantee silent-push delivery; iOS throttles them by battery, usage and
  thermal state. The 3-minute poll is deliberately kept as the backstop, so the worst case
  is exactly today's behaviour.
- iOS `aps-environment` is committed as `development`; Xcode rewrites it to `production` on
  distribution export. **Verify push still works on a TestFlight build** — that is the one
  step that cannot be checked from a local build.
- None of the native push code has been executed. It is unit-tested only where Dart can
  reach it (registration is idempotent, a failure never breaks sync, the poll alone still
  converges).
