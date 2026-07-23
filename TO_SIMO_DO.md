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

## AI Coach Pro-gating + desktop paywall (2026-07-22)

### A. Blocking — verify the Mac can actually transact (I could not check this from code)
- [ ] The desktop paywall's "Activate Evolve Pro" button calls RevenueCat macOS (`purchase`). Confirm the
      **macOS subscription product is live in App Store Connect + RevenueCat** and the Mac app ships via the
      **Mac App Store**. If it is NOT set up, the button compiles but FAILS at runtime — in that case tell me
      and I'll switch the desktop paywall surface to "Subscribe on your iPhone → unlocks here automatically"
      + a Restore button instead of an in-app purchase.
- [ ] Product ids the code expects: `com.simo.evolve.pro.monthly` / `com.simo.evolve.pro.yearly`;
      entitlement `Evolve Pro`. These are shared with mobile (same RevenueCat project), so if mobile sells
      fine the entitlement side is already correct — only the macOS **StoreKit product availability** is the
      open question.

### B. On-device QA (no Xcode on this Mac, so I could not run either app)
- [ ] Mobile: in **account mode**, a non-pro user tapping the AI Coach tile now gets the paywall funnel
      (ProFeaturesModal → SubscriptionScreen); with a stored OpenRouter key they should STILL be blocked
      (BYOK no longer works while signed in). In **Private mode** the coach stays free (BYOK).
- [ ] Desktop: in **account mode**, non-pro → sidebar/⌘5 opens ProFeaturesModal; "View plans" now opens the
      real **paywall dialog** (plans/prices/purchase/restore), NOT the old redirect to Settings→Profile.
      Buy → success dialog → coach unlocks live. In **Private mode** the coach stays free (BYOK/Local).
- [ ] Desktop coach Settings: in account mode the picker shows Standard only (+ a note pointing to Private
      mode for BYOK/Local); in Private mode it shows Your-OpenRouter-account + Local.

### C. Release-note / support heads-up (behaviour change for existing users)
- [ ] Existing **signed-in** users who used the coach for free via their own OpenRouter key (or a local
      server) will now meet the paywall in account mode. Their stored key / local-server config is
      PRESERVED (nothing is deleted) and still works the moment they switch to Private mode. Worth a line in
      the release notes so it doesn't read as a silent takeaway.

---

When I build the flutter mobile ios implementation I receive this warnings here from Xcode: Runner
/Users/simo/Developer/mattioli.OS/mobile/ios/Runner/Assets.xcassets
/Users/simo/Developer/mattioli.OS/mobile/ios/Runner/Assets.xcassets:./AppIcon.appiconset/(null)[2d][Icon-App-50x50@1x.png] The app icon set "AppIcon" has 6 unassigned children.

/Users/simo/Developer/mattioli.OS/mobile/ios/Runner/AppDelegate.swift
/Users/simo/Developer/mattioli.OS/mobile/ios/Runner/AppDelegate.swift:1059:50 'asleep' was deprecated in iOS 16.0: renamed to 'HKCategoryValueSleepAnalysis.asleepUnspecified'

permission_handler_apple
/Users/simo/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.7/ios/Classes/strategies/PhonePermissionStrategy.m
/Users/simo/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.7/ios/Classes/strategies/PhonePermissionStrategy.m:39:30 'CTCarrier' is deprecated: first deprecated in iOS 16.0 - Deprecated with no replacement

/Users/simo/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.7/ios/Classes/strategies/PhonePermissionStrategy.m:39:65 'serviceSubscriberCellularProviders' is deprecated: first deprecated in iOS 16.0 - Deprecated with no replacement

/Users/simo/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.7/ios/Classes/strategies/PhonePermissionStrategy.m:41:7 'CTCarrier' is deprecated: first deprecated in iOS 16.0 - Deprecated with no replacement

/Users/simo/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.7/ios/Classes/strategies/PhonePermissionStrategy.m:49:5 'CTCarrier' is deprecated: first deprecated in iOS 16.0 - Deprecated with no replacement

/Users/simo/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.7/ios/Classes/strategies/PhonePermissionStrategy.m:49:35 'subscriberCellularProvider' is deprecated: first deprecated in iOS 12.0

/Users/simo/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.7/ios/Classes/strategies/PhonePermissionStrategy.m:54:38 'CTCarrier' is deprecated: first deprecated in iOS 16.0 - Deprecated with no replacement

/Users/simo/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.7/ios/Classes/strategies/PhonePermissionStrategy.m:56:28 'mobileNetworkCode' is deprecated: first deprecated in iOS 16.0 - Deprecated; returns '65535' at some point in the future

SQLCipher
/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c
/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:32344:25 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:32477:60 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:32642:18 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:37460:14 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'VList' (aka 'int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:39105:8 "gethostuuid() is disabled."

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:40424:14 Implicit conversion loses integer precision: 'ssize_t' (aka 'long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:42149:42 Implicit conversion loses integer precision: 'unsigned long long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:42291:11 Implicit conversion loses integer precision: 'ssize_t' (aka 'long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:42358:35 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:43874:33 Implicit conversion loses integer precision: 'off_t' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:45805:17 Implicit conversion loses integer precision: 'ssize_t' (aka 'long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:46122:11 Implicit conversion loses integer precision: 'unsigned long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:46130:11 Implicit conversion loses integer precision: 'unsigned long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:46423:19 Implicit conversion loses integer precision: 'ssize_t' (aka 'long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:46586:37 Implicit conversion loses integer precision: 'unsigned long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:46801:53 Implicit conversion loses integer precision: 'unsigned long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:56804:16 Implicit conversion loses integer precision: 'u64' (aka 'unsigned long long') to 'unsigned int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:59747:57 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:59866:27 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:60464:27 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:60480:52 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:60590:47 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:60697:60 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:60702:58 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:60954:26 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:61100:31 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:61324:59 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:61329:56 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:61510:15 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:62095:24 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:62472:69 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:62765:54 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:62863:59 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:63980:51 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:64315:52 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:65134:5 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:65137:12 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:65144:10 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:65874:39 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:66039:36 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:67681:40 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:67685:19 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:73766:32 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:74475:43 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:77259:11 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:79729:16 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:81588:23 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:81622:18 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:83652:21 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:83955:18 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:85451:49 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:91135:22 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:91163:22 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:91371:12 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:93735:42 Implicit conversion loses integer precision: 'sqlite3_uint64' (aka 'unsigned long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:94571:19 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:95489:48 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:95512:50 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:98379:21 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:105031:28 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:105035:19 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:105312:25 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:105500:17 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:105501:28 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:106327:26 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:106331:33 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:106338:45 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:106349:26 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:106503:19 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:106957:21 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:107834:17 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:107874:40 Implicit conversion loses integer precision: 'sqlite_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:107941:22 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:108155:10 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:108807:42 Implicit conversion loses integer precision: 'volatile size_t' (aka 'volatile unsigned long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:108811:38 Implicit conversion loses integer precision: 'unsigned long' to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:108874:76 Implicit conversion loses integer precision: 'size_t' (aka 'unsigned long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:109187:31 A function declaration without a prototype is deprecated in all versions of C

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:109206:27 Implicit conversion loses integer precision: 'sqlite_uint64' (aka 'unsigned long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:109218:24 Implicit conversion loses integer precision: 'sqlite_uint64' (aka 'unsigned long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:109253:42 Implicit conversion loses integer precision: 'sqlite3_uint64' (aka 'unsigned long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:109262:23 Implicit conversion loses integer precision: 'sqlite3_uint64' (aka 'unsigned long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:109407:43 A function declaration without a prototype is deprecated in all versions of C

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:112020:27 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:112021:32 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:126835:18 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:133267:15 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:133533:20 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:136702:24 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:136703:44 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:137240:31 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:137316:11 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:137553:39 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:140384:75 Possible misuse of comma operator here

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:145464:36 Implicit conversion loses integer precision: 'u64' (aka 'unsigned long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:145505:34 Implicit conversion loses integer precision: 'u64' (aka 'unsigned long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:148747:28 Implicit conversion loses integer precision: 'const u64' (aka 'const unsigned long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:156879:29 Implicit conversion loses integer precision: 'u64' (aka 'unsigned long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:167352:19 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:167359:19 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:170732:43 Possible misuse of comma operator here

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:171415:14 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:172098:12 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:173015:25 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:173016:25 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:173024:25 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:173025:25 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:173369:10 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:176078:19 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:178457:28 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:180008:12 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:181286:61 Implicit conversion loses integer precision: 'sqlite3_uint64' (aka 'unsigned long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:184799:9 Code will never be executed

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:189305:19 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:189306:40 Implicit conversion loses integer precision: 'sqlite_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:189308:19 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:189309:40 Implicit conversion loses integer precision: 'sqlite_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:189313:19 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:196118:14 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:205220:56 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:206588:11 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:206737:27 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:207664:22 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:207998:24 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:209527:14 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:209675:11 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:209705:19 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:210283:37 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:210312:16 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:210312:20 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:211310:41 Implicit conversion loses integer precision: 'long' to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:211561:25 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:211791:20 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:212868:29 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:214594:28 Implicit conversion loses integer precision: 'u64' (aka 'unsigned long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:215828:20 Implicit conversion loses integer precision: 'u64' (aka 'unsigned long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:216372:43 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:218904:19 Implicit conversion loses integer precision: 'u64' (aka 'unsigned long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:221514:26 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:221515:28 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:221520:26 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:221521:28 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:221562:12 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:221563:12 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:222683:21 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:225578:20 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'u32' (aka 'unsigned int')

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:243437:9 Code will never be executed

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:245474:29 Implicit conversion loses integer precision: 'sqlite3_int64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:246517:23 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:246529:23 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:248558:18 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:249968:18 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:250922:10 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:251304:27 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:251986:23 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:251989:18 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:252060:28 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:252101:26 Implicit conversion loses integer precision: 'const i64' (aka 'const long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:252171:18 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:252211:50 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:252304:19 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:252333:17 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:252414:29 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:252687:19 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:252755:35 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:253562:18 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:253692:16 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:253692:46 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:253717:16 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:253814:32 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:253934:30 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:254061:14 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:254567:14 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:255042:38 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:255425:36 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:255519:17 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:255960:20 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:256625:18 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:256625:22 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:256626:18 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:256626:22 Implicit conversion loses integer precision: 'i64' (aka 'long long') to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:258075:22 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:258105:13 Ambiguous expansion of macro 'MAX'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:258612:53 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:260495:40 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:265479:19 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:265486:21 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:265536:17 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:265540:37 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:266367:24 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:266389:19 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:266399:36 Implicit conversion loses integer precision: 'long' to 'int'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:268053:18 Ambiguous expansion of macro 'MIN'

/Users/simo/Developer/mattioli.OS/mobile/ios/Pods/SQLCipher/sqlite3.c:268127:20 Ambiguous expansion of macro 'MIN'
