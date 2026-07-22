# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Organize better the selection of the LLM in the AI coach
- [ ] settings in desktop implementation is really weird and not intuitive as it is in the mobile app
- [ ] what happens if I modify manually an automatic habits?
- [ ] Different habits & goals types, not only checkboxes like status,progress bar
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

## 2026-07-21 — iCloud sync Tier A: native verification needed (Mac mini, Xcode)

The Swift changes below are the only part of this pass I could not execute. **There is no Xcode
on the dev machine**, so nothing native was built or run.

**What I could verify:** both bridges typecheck cleanly against the real CloudKit framework
(`swiftc -typecheck`, Swift 6.3, macOS SDK, Command Line Tools). That confirms the API surface
is right — `CKError.retryAfterSeconds` exists and is `Double?`, `.requestRateLimited` /
`.serviceUnavailable` / `.zoneBusy` are valid codes, `qualityOfService` is settable on every
operation type used. It does **not** confirm any runtime behaviour.

**What I could NOT verify — and what only the Mac mini can settle:**

- [ ] **Both apps still build and launch.** `flutter build macos --release` and
      `flutter build ipa --release`. The bridges are `Runner`-target members, so a compile error
      here surfaces only in Xcode.
- [ ] **A throttled push actually recovers.** The retry path has never run. The realistic way to
      hit it is a large first push: enable sync on a device with a full dataset and watch the log
      for `[CloudKit] saveRecords throttled by iCloud — retrying in Ns (attempt K of 4)`.
      If you never see that line, the path is simply untested — not proven good.
- [ ] **The retry does not double-apply anything.** After any retry, run the diagnostics report on
      both devices and confirm the per-table counts still match.
- [ ] **`qualityOfService` did not make sync feel slower.** Every operation is now `.utility`
      except `zoneHasRecords`, which is `.userInitiated` because it blocks the enable the user is
      watching. If enable or first sync feels sluggish, that trade is the thing to revisit.

Note both `AppDelegate.swift` files were patched from one script precisely so they stay
line-for-line ports of each other; every line changed is byte-identical between them. If you edit
one by hand, mirror it.

---

## 2026-07-21 — iCloud sync Tier C: residual items (none block the release)

These were found while closing Tier C and deliberately NOT bundled into it. Each is real; none
is reframed as working-as-intended.

### Needs a change of its own — both apps in the SAME release
- [ ] **The C2 root cause is still live: the backup import writes unvalidated timestamps.**
      `mobile/lib/core/import_merge.dart` routes `start_date`/`end_date` through a validating
      `_date` helper but routes `created_at`/`updated_at` through `_str`, and the insert sites
      write the raw string. `desktop/lib/core/desktop_private_db.dart` mirrors it. The dirty
      trigger COALESCEs only NULL, so a garbage string lands in `sync_state` verbatim.
      The shared package now SURVIVES that input (two unorderable stamps tie and the deterministic
      id tiebreak resolves them) but nothing stops it being written. Route both fields through
      `_date` so a null falls through to the existing `?? now`, and fix the doc comment at
      `import_merge.dart:452`, which currently promises the opposite. **Both apps must ship
      together** — otherwise a Mac import still seeds garbage the iPhone has to cope with.
- [ ] **C2 is only fully fixed between two UPDATED devices.** In a mixed fleet the old build's
      store still answers `-1` where the new one answers `0`, so the old device still concludes
      "remote wins" unconditionally. That converges about half the time instead of never — a
      strict improvement, complete once both devices update. No wire change can do better without
      stranding rows on old builds.

### Worth a ticket, not urgent
- [ ] `mobile/lib/providers/goal_provider.dart` calls `scheduleHabitReminder(...)` on habit
      add/update with no `settings.focusMode` check, so editing a habit while Focus Mode is ON
      re-arms that habit's reminder and defeats Focus Mode by a route C4 does not cover.
- [ ] A row with an unparseable stamp still pushes at `0`, so on a peer that already holds that
      record with a real stamp it loses LWW and is skipped while the pushing device clears dirty
      and reports success. Nothing is destroyed and the local copy is intact, but the imported
      edit silently does not travel. Left open deliberately: the alternatives are to invent a
      stamp (which lets a stale backup clobber every peer's newer data) or to refuse the push.
      Best decided once the import fix above lands.
- [ ] Nothing clamps `updatedAtMs` on push, so a device with a forward-set clock can still author
      the poisoned records C3 now defends against. Clamping stops it at source but changes what
      goes on the wire and interacts with LWW ordering.
- [ ] `DesktopPrivateDb.wipeUserData` deletes `profiles` but not `user_settings`, so "erase
      everything" leaves the user's synced preferences on disk.
- [ ] Mobile `build()` reseeds settings to defaults on every rebuild, so each sync-triggered
      invalidate briefly flashes the app to dark / default accent / system language until the
      load resolves. Real and tap-free, but fixing it changes cold-start semantics.
- [ ] Desktop's settings RESET path (`_resetSettingsToDefaults`) publishes cross-device via
      `_syncProfile` and is still unguarded by any test — mutating its literals leaves the suite
      green. It is only reachable through `_resetData`, which needs a large fixture.

### Behaviour changes to mention in the changelog
- [ ] A REPLACE import on the Mac now emits `user_settings` rows that SYNC, so restoring a backup
      will overwrite the iPhone's settings on the next push. That is what "replace" means — but
      today it silently does not happen, so it will look new.
- [ ] The desktop appearance control is now a three-option select (System / Light / Dark) instead
      of a binary dark-mode switch, so "follow system" is finally expressible. **Wants on-device
      QA**: `ThemeMode.system` now reaches `MaterialApp`, and whether macOS Auto appearance is
      followed live has only been tested headless.
- [ ] Desktop's settings reset still writes an explicit `'dark'` rather than `'system'`, matching
      mobile. Now that `'system'` is expressible, you may want to revisit that.

---

## 2026-07-21 — LM Studio launch parity: IMPLEMENTED, on-device QA pending

The feature is built and green (`flutter analyze` clean, `flutter test` 512/512, `dart format`
clean on every touched file, AppKit surface `swiftc -typecheck`'d). See `desktop/DOCUMENTATION.md`
for the design and the implementation record.

**What could NOT be verified here**: the full macOS build (no Xcode on this Mac) and every runtime
behaviour — **neither LM Studio nor Ollama is installed on this machine**. Three facts remain
empirical. None of them blocks the build; each is a one-line fix if it comes back different.

### Do this first (cheapest, and the only one that could break the happy path)
- [ ] **Confirm the LM Studio bundle id on a live install.** The code uses
      `ai.elementlabs.lmstudio`, triangulated from the Homebrew cask's `uninstall quit:` stanza,
      the `brew` API JSON, and an independent Info.plist scrape of v0.2.6 — three independent
      sources, but none of them this machine. A wrong id degrades rather than breaks: the
      `/Applications/LM Studio.app` path fallback still resolves a default install, so Start works
      — but `localAppRunning` matches by bundle id ONLY, so the "your server isn't enabled"
      diagnosis would silently fall back to the generic timeout message.
      **If it differs, change one line**: `bundleIds` in
      `desktop/lib/features/ai_coach/domain/local_server_target.dart` (and the assertion in
      `desktop/test/local_server_target_test.dart`). That constant is in Dart precisely so it is
      one testable line and not a Swift constant no test can reach.
      ```bash
      osascript -e 'id of app "LM Studio"'
      # belt and braces:
      defaults read "/Applications/LM Studio.app/Contents/Info.plist" CFBundleIdentifier
      ```
      While you are there, grab the URL schemes — only `lmstudio://add_mcp` is documented, and
      confirming there is no server-start deep link would close the last open door on that idea:
      ```bash
      plutil -p "/Applications/LM Studio.app/Contents/Info.plist" | grep -A5 URLSchemes
      ```

### Non-blocking — one-line fixes if they come back different
- [ ] **Does LM Studio withhold response headers during a cold model load?** Ollama does, which is
      the entire reason `openai_compatible_client.dart:204` bounds `send()` by `firstTokenTimeout`
      rather than `connectTimeout`. No LM Studio doc, changelog or issue states this either way.
      If LM Studio flushes headers immediately, the 15s `connectTimeout` binds instead and raising
      `firstTokenTimeout` to 180s achieves nothing. Point this at a LARGE, currently-unloaded model:
      ```bash
      curl -N -w '\ntime_starttransfer: %{time_starttransfer}\n' \
        http://localhost:1234/v1/chat/completions \
        -H 'Content-Type: application/json' \
        -d '{"model":"<large-unloaded-model>","messages":[{"role":"user","content":"hi"}],"stream":true}'
      ```
- [ ] **What does LM Studio return when "Require Authentication" is on?** The design maps 401/403
      on a local backend to a "this server wants a token" message. LM Studio's official auth page
      never mentions the OpenAI-compat `/v1/*` surface and never names a status code — the
      `/v1/*`→401 claim is corroborated only by a generated wiki, not a primary source. If it
      returns 403, or a 200 with an error body, the mapping misses. Enable
      Developer → Server Settings → Require Authentication, then:
      ```bash
      curl -i -H 'Authorization: Bearer local' http://localhost:1234/v1/models
      ```

### On-device QA checklist (macOS, once LM Studio is installed)
- [ ] Settings → AI Coach → engine **Local** → preset **LM Studio**: the status pill, the
      **Start LM Studio** button, and the base-URL placeholder (`http://localhost:1234/v1`) all
      appear and name LM Studio, not Ollama.
- [ ] With LM Studio installed but **never started**: press Start, wait out the poll (~60s), and
      confirm you get *"LM Studio is open, but its local server is off…"* — NOT a generic failure.
      Then flip Developer → Start Server and confirm the banner **clears itself within ~3s** without
      touching Evolve.
- [ ] With LM Studio **not** installed: the button reads **Get LM Studio** and opens
      `https://lmstudio.ai/download`.
- [ ] With **Just-In-Time loading off** and no model loaded: the model picker shows the JIT
      explanation naming the toggle, not the generic "type a model id manually".
- [ ] Send a message to a **large, cold** model: the typing dots gain *"Still loading the model…"*
      after ~15s instead of sitting silent, and the reply lands rather than timing out.
- [ ] Ollama regression pass: Start / Get / Starting / offline banner / model discovery all behave
      exactly as before. This is the part most worth a careful look — it was working and I renamed
      through it.

### Process gap worth its own piece of work
- [ ] **Desktop has no CI.** `.github/workflows/mobile-ci.yml` is scoped `paths: ['mobile/**']`, so
      nothing runs `flutter analyze` or `flutter test` on a desktop change — the README sequence at
      `desktop/README.md:118` is manual and unenforced. This change touched ~11 files across domain,
      data, application, presentation, native and i18n. Consider a `desktop/**` job mirroring the
      mobile one (`flutter pub get` → `dart run slang` → `flutter analyze` → `flutter test`).
      Note the mobile job uses `--fatal-infos`; a desktop job at that bar would currently fail on
      the 4 pre-existing issues listed by `flutter analyze`.
- [ ] Related: `dart run slang` is manual and CI-unenforced, and the generated `translations_*.g.dart`
      files ARE committed — so the JSON and the generated Dart can silently drift.
- [ ] **Repo-wide `dart format` drift**: `dart format --output=none --set-exit-if-changed lib test`
      reports **90 files** as unformatted, almost all untouched by this change (a formatter-version
      bump, most likely). I formatted only the files I edited rather than sweeping 85 unrelated
      files into this diff. Worth one dedicated formatting commit so the README's
      `--set-exit-if-changed` step can actually pass.

---