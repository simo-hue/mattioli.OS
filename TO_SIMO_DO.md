# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Paywall and subs from macOS must be coherent and real
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

When I build the flutter mobile macOS implementation I receive this warnings here from Xcode that I want you to fix: Flutter Assemble
Code asset "package:objective_c/objective_c.dylib" has different framework names for different architectures. Picking "objective_c.framework" and ignoring "objective_c1.framework". This is likely an issue in the package providing the asset. Please report this to the package maintainers and ensure the "build.dart" hook produces consistent filenames.

Showing Recent Issues

Build target Flutter Assemble of project Runner with configuration Release

PhaseScriptExecution Run\ Script /Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Script-33CC111E2044C6BF0003C045.sh (in target 'Flutter Assemble' from project 'Runner')
    cd /Users/simo/Developer/mattioli.OS/desktop/macos
    export ACTION\=install
    export AD_HOC_CODE_SIGNING_ALLOWED\=YES
    export ALLOW_BUILD_REQUEST_OVERRIDES\=NO
    export ALLOW_TARGET_PLATFORM_SPECIALIZATION\=NO
    export ALTERNATE_GROUP\=staff
    export ALTERNATE_MODE\=u+w,go-w,a+rX
    export ALTERNATE_OWNER\=simo
    export ALTERNATIVE_DISTRIBUTION_WEB\=NO
    export ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES\=YES
    export ALWAYS_SEARCH_USER_PATHS\=NO
    export ALWAYS_USE_SEPARATE_HEADERMAPS\=NO
    export APPLICATION_EXTENSION_API_ONLY\=NO
    export APPLY_RULES_IN_COPY_FILES\=NO
    export APPLY_RULES_IN_COPY_HEADERS\=NO
    export APP_SHORTCUTS_ENABLE_FLEXIBLE_MATCHING\=YES
    export ARCHS\=arm64\ x86_64
    export ARCHS_BASE\=arm64\ x86_64
    export ARCHS_STANDARD\=arm64\ x86_64
    export ARCHS_STANDARD_32_64_BIT\=arm64\ x86_64\ i386
    export ARCHS_STANDARD_32_BIT\=i386
    export ARCHS_STANDARD_64_BIT\=arm64\ x86_64
    export ARCHS_STANDARD_INCLUDING_64_BIT\=arm64\ x86_64
    export ASSETCATALOG_COMPILER_FLATTENED_APP_ICON_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/ProductIcon.png
    export ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS\=YES
    export ASSET_PACK_FOLDER_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/InstallationBuildProductsLocation/OnDemandResources
    export AUTOMATICALLY_MERGE_DEPENDENCIES\=NO
    export AUTOMATION_APPLE_EVENTS\=NO
    export AVAILABLE_PLATFORMS\=android\ appletvos\ appletvsimulator\ driverkit\ freebsd\ iphoneos\ iphonesimulator\ linux\ macosx\ none\ openbsd\ qnx\ watchos\ watchsimulator\ webassembly\ xros\ xrsimulator
    export BUILD_ACTIVE_RESOURCES_ONLY\=NO
    export BUILD_COMPONENTS\=headers\ build
    export BUILD_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath
    export BUILD_LIBRARY_FOR_DISTRIBUTION\=NO
    export BUILD_ONLY_KNOWN_LOCALIZATIONS\=NO
    export BUILD_ROOT\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath
    export BUILD_STYLE\=
    export BUILD_VARIANTS\=normal
    export BUILT_PRODUCTS_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release
    export BUNDLE_CONTENTS_FOLDER_PATH\=Contents/
    export BUNDLE_CONTENTS_FOLDER_PATH_deep\=Contents/
    export BUNDLE_EXECUTABLE_FOLDER_NAME_deep\=MacOS
    export BUNDLE_EXECUTABLE_FOLDER_PATH\=Contents/MacOS
    export BUNDLE_EXTENSIONS_FOLDER_PATH\=Contents/Extensions
    export BUNDLE_FORMAT\=deep
    export BUNDLE_FRAMEWORKS_FOLDER_PATH\=Contents/Frameworks
    export BUNDLE_PLUGINS_FOLDER_PATH\=Contents/PlugIns
    export BUNDLE_PRIVATE_HEADERS_FOLDER_PATH\=Contents/PrivateHeaders
    export BUNDLE_PUBLIC_HEADERS_FOLDER_PATH\=Contents/Headers
    export CACHE_ROOT\=/var/folders/2x/rg935sbj6v92jx45t10drscm0000gn/C/com.apple.DeveloperTools/26.6-17F113/Xcode
    export CCHROOT\=/var/folders/2x/rg935sbj6v92jx45t10drscm0000gn/C/com.apple.DeveloperTools/26.6-17F113/Xcode
    export CHMOD\=/bin/chmod
    export CHOWN\=chown
    export CLANG_ANALYZER_NONNULL\=YES
    export CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION\=YES_AGGRESSIVE
    export CLANG_CACHE_FINE_GRAINED_OUTPUTS\=YES
    export CLANG_CXX_LANGUAGE_STANDARD\=gnu++14
    export CLANG_CXX_LIBRARY\=libc++
    export CLANG_ENABLE_EXPLICIT_MODULES\=YES
    export CLANG_ENABLE_MODULES\=YES
    export CLANG_ENABLE_OBJC_ARC\=YES
    export CLANG_MODULES_BUILD_SESSION_FILE\=/Users/simo/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Session.modulevalidation
    export CLANG_UNDEFINED_BEHAVIOR_SANITIZER_NULLABILITY\=YES
    export CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING\=YES
    export CLANG_WARN_BOOL_CONVERSION\=YES
    export CLANG_WARN_COMMA\=YES
    export CLANG_WARN_CONSTANT_CONVERSION\=YES
    export CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS\=YES
    export CLANG_WARN_DIRECT_OBJC_ISA_USAGE\=YES_ERROR
    export CLANG_WARN_DOCUMENTATION_COMMENTS\=YES
    export CLANG_WARN_EMPTY_BODY\=YES
    export CLANG_WARN_ENUM_CONVERSION\=YES
    export CLANG_WARN_INFINITE_RECURSION\=YES
    export CLANG_WARN_INT_CONVERSION\=YES
    export CLANG_WARN_NON_LITERAL_NULL_CONVERSION\=YES
    export CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF\=YES
    export CLANG_WARN_OBJC_LITERAL_CONVERSION\=YES
    export CLANG_WARN_OBJC_REPEATED_USE_OF_WEAK\=YES
    export CLANG_WARN_OBJC_ROOT_CLASS\=YES_ERROR
    export CLANG_WARN_PRAGMA_PACK\=YES
    export CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER\=NO
    export CLANG_WARN_RANGE_LOOP_ANALYSIS\=YES
    export CLANG_WARN_STRICT_PROTOTYPES\=YES
    export CLANG_WARN_SUSPICIOUS_MOVE\=YES
    export CLANG_WARN_UNGUARDED_AVAILABILITY\=YES_AGGRESSIVE
    export CLANG_WARN_UNREACHABLE_CODE\=YES
    export CLANG_WARN__DUPLICATE_METHOD_MATCH\=YES
    export CLASS_FILE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/JavaClasses
    export CLEAN_PRECOMPS\=YES
    export CLONE_HEADERS\=NO
    export COCOAPODS_PARALLEL_CODE_SIGN\=true
    export CODESIGNING_FOLDER_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/UninstalledProducts/macosx/
    export CODE_SIGNING_ALLOWED\=NO
    export CODE_SIGNING_REQUIRED\=YES
    export CODE_SIGN_IDENTITY\=-
    export CODE_SIGN_IDENTITY_NO\=Apple\ Development
    export CODE_SIGN_IDENTITY_YES\=-
    export CODE_SIGN_INJECT_BASE_ENTITLEMENTS\=YES
    export CODE_SIGN_STYLE\=Automatic
    export COLOR_DIAGNOSTICS\=NO
    export COMBINE_HIDPI_IMAGES\=NO
    export COMPILATION_CACHE_CAS_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/CompilationCache.noindex
    export COMPILATION_CACHE_KEEP_CAS_DIRECTORY\=YES
    export COMPILER_INDEX_STORE_ENABLE\=Default
    export COMPOSITE_SDK_DIRS\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/CompositeSDKs
    export COMPRESS_PNG_FILES\=NO
    export CONFIGURATION\=Release
    export CONFIGURATION_BUILD_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release
    export CONFIGURATION_TEMP_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release
    export COPYING_PRESERVES_HFS_DATA\=NO
    export COPY_HEADERS_RUN_UNIFDEF\=NO
    export COPY_PHASE_STRIP\=NO
    export CP\=/bin/cp
    export CREATE_INFOPLIST_SECTION_IN_BINARY\=NO
    export CURRENT_ARCH\=undefined_arch
    export CURRENT_VARIANT\=normal
    export DART_DEFINES\=RVZPTFZFX1NVUEFCQVNFX1VSTD1odHRwczovL3JheGl6dHRsbXNvZml4cXlhbndjLnN1cGFiYXNlLmNv,RVZPTFZFX1NVUEFCQVNFX1BVQkxJU0hBQkxFX0tFWT1zYl9wdWJsaXNoYWJsZV9MR0xUVlRiLVdxTmlFNWtWZDdJX2lRX3RxcnNWOFBG,RVZPTFZFX0RFU0tUT1BfT0FVVEhfUkVESVJFQ1RfVVJMPWh0dHA6Ly8xMjcuMC4wLjE6Mzk4NzYvYXV0aC9jYWxsYmFjaw\=\=,RVZPTFZFX0RFU0tUT1BfTkFUSVZFX0FQUExFX1NJR05fSU49dHJ1ZQ\=\=,RkxVVFRFUl9WRVJTSU9OPTMuNDQuNg\=\=,RkxVVFRFUl9DSEFOTkVMPXN0YWJsZQ\=\=,RkxVVFRFUl9HSVRfVVJMPWh0dHBzOi8vZ2l0aHViLmNvbS9mbHV0dGVyL2ZsdXR0ZXIuZ2l0,RkxVVFRFUl9GUkFNRVdPUktfUkVWSVNJT049ZWU4MGYwOGJiZg\=\=,RkxVVFRFUl9FTkdJTkVfUkVWSVNJT049ODM2NzVlZDI3Ng\=\=,RkxVVFRFUl9EQVJUX1ZFUlNJT049My4xMi4y
    export DART_OBFUSCATION\=false
    export DEAD_CODE_STRIPPING\=YES
    export DEBUGGING_SYMBOLS\=YES
    export DEBUG_INFORMATION_FORMAT\=dwarf-with-dsym
    export DEBUG_INFORMATION_VERSION\=compiler-default
    export DEFAULT_COMPILER\=com.apple.compilers.llvm.clang.1_0
    export DEFAULT_DEXT_INSTALL_PATH\=/System/Library/DriverExtensions
    export DEFAULT_KEXT_INSTALL_PATH\=/System/Library/Extensions
    export DEFINES_MODULE\=NO
    export DEPLOYMENT_LOCATION\=YES
    export DEPLOYMENT_POSTPROCESSING\=YES
    export DEPLOYMENT_TARGET_SETTING_NAME\=MACOSX_DEPLOYMENT_TARGET
    export DEPLOYMENT_TARGET_SUGGESTED_VALUES\=10.13\ 10.14\ 10.15\ 11.0\ 11.1\ 11.2\ 11.3\ 11.4\ 11.5\ 12.0\ 12.2\ 12.3\ 12.4\ 13.0\ 13.1\ 13.2\ 13.3\ 13.4\ 13.5\ 14.0\ 14.1\ 14.2\ 14.3\ 14.4\ 14.5\ 14.6\ 15.0\ 15.1\ 15.2\ 15.3\ 15.4\ 15.5\ 15.6\ 26.0\ 26.1\ 26.2\ 26.3\ 26.4\ 26.5
    export DERIVED_FILES_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/DerivedSources
    export DERIVED_FILE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/DerivedSources
    export DERIVED_SOURCES_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/DerivedSources
    export DEVELOPER_APPLICATIONS_DIR\=/Applications/Xcode.app/Contents/Developer/Applications
    export DEVELOPER_BIN_DIR\=/Applications/Xcode.app/Contents/Developer/usr/bin
    export DEVELOPER_DIR\=/Applications/Xcode.app/Contents/Developer
    export DEVELOPER_FRAMEWORKS_DIR\=/Applications/Xcode.app/Contents/Developer/Library/Frameworks
    export DEVELOPER_FRAMEWORKS_DIR_QUOTED\=/Applications/Xcode.app/Contents/Developer/Library/Frameworks
    export DEVELOPER_LIBRARY_DIR\=/Applications/Xcode.app/Contents/Developer/Library
    export DEVELOPER_SDK_DIR\=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
    export DEVELOPER_TOOLS_DIR\=/Applications/Xcode.app/Contents/Developer/Tools
    export DEVELOPER_USR_DIR\=/Applications/Xcode.app/Contents/Developer/usr
    export DEVELOPMENT_LANGUAGE\=en
    export DIAGNOSE_MISSING_TARGET_DEPENDENCIES\=YES
    export DIFF\=/usr/bin/diff
    export DONT_GENERATE_INFOPLIST_FILE\=NO
    export DSTROOT\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/InstallationBuildProductsLocation
    export DT_TOOLCHAIN_DIR\=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain
    export DUMP_DEPENDENCIES\=NO
    export DUMP_DEPENDENCIES_OUTPUT_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Flutter\ Assemble-BuildDependencyInfo.json
    export DWARF_DSYM_FILE_NAME\=.dSYM
    export DWARF_DSYM_FILE_SHOULD_ACCOMPANY_PRODUCT\=NO
    export DWARF_DSYM_FOLDER_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release
    export DYNAMIC_LIBRARY_EXTENSION\=dylib
    export EAGER_COMPILATION_ALLOW_SCRIPTS\=NO
    export EAGER_LINKING\=NO
    export EMBEDDED_CONTENT_CONTAINS_SWIFT\=NO
    export EMBEDDED_PROFILE_NAME\=embedded.provisionprofile
    export EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE\=NO
    export ENABLE_APP_SANDBOX\=NO
    export ENABLE_CODE_COVERAGE\=YES
    export ENABLE_COHORT_ARCHS\=NO
    export ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS\=NO
    export ENABLE_C_BOUNDS_SAFETY\=NO
    export ENABLE_DEBUG_DYLIB\=NO
    export ENABLE_DEFAULT_HEADER_SEARCH_PATHS\=YES
    export ENABLE_DEFAULT_SEARCH_PATHS\=YES
    export ENABLE_ENHANCED_SECURITY\=NO
    export ENABLE_HARDENED_RUNTIME\=NO
    export ENABLE_HEADER_DEPENDENCIES\=YES
    export ENABLE_INCOMING_NETWORK_CONNECTIONS\=NO
    export ENABLE_NS_ASSERTIONS\=NO
    export ENABLE_ON_DEMAND_RESOURCES\=NO
    export ENABLE_OUTGOING_NETWORK_CONNECTIONS\=NO
    export ENABLE_POINTER_AUTHENTICATION\=NO
    export ENABLE_PREVIEWS\=NO
    export ENABLE_RESOURCE_ACCESS_AUDIO_INPUT\=NO
    export ENABLE_RESOURCE_ACCESS_BLUETOOTH\=NO
    export ENABLE_RESOURCE_ACCESS_CALENDARS\=NO
    export ENABLE_RESOURCE_ACCESS_CAMERA\=NO
    export ENABLE_RESOURCE_ACCESS_CONTACTS\=NO
    export ENABLE_RESOURCE_ACCESS_LOCATION\=NO
    export ENABLE_RESOURCE_ACCESS_PHOTO_LIBRARY\=NO
    export ENABLE_RESOURCE_ACCESS_PRINTING\=NO
    export ENABLE_RESOURCE_ACCESS_USB\=NO
    export ENABLE_SDK_IMPORTS\=NO
    export ENABLE_SECURITY_COMPILER_WARNINGS\=NO
    export ENABLE_SIGNATURE_AGGREGATION\=YES
    export ENABLE_STRICT_OBJC_MSGSEND\=YES
    export ENABLE_TESTABILITY\=NO
    export ENABLE_TESTING_SEARCH_PATHS\=NO
    export ENABLE_USER_SCRIPT_SANDBOXING\=NO
    export ENABLE_XOJIT_PREVIEWS\=NO
    export ENFORCE_VALID_ARCHS\=YES
    export ENTITLEMENTS_DESTINATION\=Signature
    export ENTITLEMENTS_REQUIRED\=YES
    export EXCLUDED_INSTALLSRC_SUBDIRECTORY_PATTERNS\=.DS_Store\ .svn\ .git\ .hg\ CVS
    export EXCLUDED_RECURSIVE_SEARCH_PATH_SUBDIRECTORIES\=\*.nib\ \*.lproj\ \*.framework\ \*.gch\ \*.xcode\*\ \*.xcassets\ \*.icon\ \(\*\)\ .DS_Store\ CVS\ .svn\ .git\ .hg\ \*.pbproj\ \*.pbxproj
    export FILE_LIST\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects/LinkFileList
    export FIXED_FILES_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/FixedFiles
    export FLUTTER_APPLICATION_PATH\=/Users/simo/Developer/mattioli.OS/desktop
    export FLUTTER_BUILD_DIR\=build
    export FLUTTER_BUILD_NAME\=1.1.4
    export FLUTTER_BUILD_NUMBER\=22
    export FLUTTER_FRAMEWORK_SWIFT_PACKAGE_PATH\=/Users/simo/Developer/mattioli.OS/desktop/macos/Flutter/ephemeral/Packages/.packages/FlutterFramework
    export FLUTTER_ROOT\=/opt/homebrew/share/flutter
    export FLUTTER_TARGET\=lib/main.dart
    export FRAMEWORK_SEARCH_PATHS\=\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/FMDB\"\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/SQLCipher\"\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sign_in_with_apple\"\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sqflite_sqlcipher\"
    export FRAMEWORK_VERSION\=A
    export FUSE_BUILD_PHASES\=YES
    export FUSE_BUILD_SCRIPT_PHASES\=NO
    export GCC3_VERSION\=3.3
    export GCC_C_LANGUAGE_STANDARD\=gnu11
    export GCC_NO_COMMON_BLOCKS\=YES
    export GCC_PFE_FILE_C_DIALECTS\=c\ objective-c\ c++\ objective-c++
    export GCC_PREPROCESSOR_DEFINITIONS\=\ COCOAPODS\=1\ SQLITE_HAS_CODEC\=1\ _SQLITE3_H_\=1\ _FTS5_H\=1\ _SQLITE3RTREE_H_\=1
    export GCC_TREAT_WARNINGS_AS_ERRORS\=NO
    export GCC_VERSION\=com.apple.compilers.llvm.clang.1_0
    export GCC_VERSION_IDENTIFIER\=com_apple_compilers_llvm_clang_1_0
    export GCC_WARN_64_TO_32_BIT_CONVERSION\=YES
    export GCC_WARN_ABOUT_RETURN_TYPE\=YES_ERROR
    export GCC_WARN_SHADOW\=YES
    export GCC_WARN_STRICT_SELECTOR_MATCH\=YES
    export GCC_WARN_UNDECLARED_SELECTOR\=YES
    export GCC_WARN_UNINITIALIZED_AUTOS\=YES_AGGRESSIVE
    export GCC_WARN_UNUSED_FUNCTION\=YES
    export GCC_WARN_UNUSED_VARIABLE\=YES
    export GENERATED_MODULEMAP_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/GeneratedModuleMaps
    export GENERATE_INFOPLIST_FILE\=NO
    export GENERATE_INTERMEDIATE_TEXT_BASED_STUBS\=YES
    export GENERATE_PKGINFO_FILE\=NO
    export GENERATE_PRELINK_OBJECT_FILE\=NO
    export GENERATE_PROFILING_CODE\=NO
    export GENERATE_TEXT_BASED_STUBS\=NO
    export GID\=20
    export GROUP\=staff
    export HEADERMAP_INCLUDES_FLAT_ENTRIES_FOR_TARGET_BEING_BUILT\=YES
    export HEADERMAP_INCLUDES_FRAMEWORK_ENTRIES_FOR_ALL_PRODUCT_TYPES\=YES
    export HEADERMAP_INCLUDES_FRAMEWORK_ENTRIES_FOR_TARGETS_NOT_BEING_BUILT\=YES
    export HEADERMAP_INCLUDES_NONPUBLIC_NONPRIVATE_HEADERS\=YES
    export HEADERMAP_INCLUDES_PROJECT_HEADERS\=YES
    export HEADERMAP_USES_FRAMEWORK_PREFIX_ENTRIES\=YES
    export HEADERMAP_USES_VFS\=NO
    export HEADER_SEARCH_PATHS\=\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/FMDB/FMDB.framework/Headers\"\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/SQLCipher/SQLCipher.framework/Headers\"\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sign_in_with_apple/sign_in_with_apple.framework/Headers\"\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sqflite_sqlcipher/sqflite_sqlcipher.framework/Headers\"\ SQLCipher\ /Users/simo/Developer/mattioli.OS/desktop/macos/Pods/SQLCipher
    export HOME\=/Users/simo
    export HOST_ARCH\=arm64
    export HOST_PLATFORM\=macosx
    export ICONV\=/usr/bin/iconv
    export IMPLICIT_DEPENDENCY_DOMAIN\=default
    export INDEX_ENABLE_DATA_STORE\=NO
    export INDEX_STORE_COMPRESS\=NO
    export INDEX_STORE_ONLY_PROJECT_FILES\=NO
    export INFOPLIST_ENABLE_CFBUNDLEICONS_MERGE\=YES
    export INFOPLIST_EXPAND_BUILD_SETTINGS\=YES
    export INFOPLIST_OUTPUT_FORMAT\=same-as-input
    export INFOPLIST_PREPROCESS\=NO
    export INLINE_PRIVATE_FRAMEWORKS\=NO
    export INSTALLAPI_IGNORE_SKIP_INSTALL\=YES
    export INSTALLHDRS_COPY_PHASE\=NO
    export INSTALLHDRS_SCRIPT_PHASE\=NO
    export INSTALL_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/InstallationBuildProductsLocation
    export INSTALL_GROUP\=staff
    export INSTALL_MODE_FLAG\=u+w,go-w,a+rX
    export INSTALL_OWNER\=simo
    export INSTALL_ROOT\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/InstallationBuildProductsLocation
    export IOS_UNZIPPERED_TWIN_PREFIX_PATH\=/System/iOSSupport
    export IS_MACCATALYST\=NO
    export IS_UNOPTIMIZED_BUILD\=NO
    export JAVAC_DEFAULT_FLAGS\=-J-Xms64m\ -J-XX:NewSize\=4M\ -J-Dfile.encoding\=UTF8
    export JAVA_APP_STUB\=/System/Library/Frameworks/JavaVM.framework/Resources/MacOS/JavaApplicationStub
    export JAVA_ARCHIVE_CLASSES\=YES
    export JAVA_ARCHIVE_TYPE\=JAR
    export JAVA_COMPILER\=/usr/bin/javac
    export JAVA_FRAMEWORK_RESOURCES_DIRS\=Resources
    export JAVA_JAR_FLAGS\=cv
    export JAVA_SOURCE_SUBDIR\=.
    export JAVA_USE_DEPENDENCIES\=YES
    export JAVA_ZIP_FLAGS\=-urg
    export JIKES_DEFAULT_FLAGS\=+E\ +OLDCSO
    export KASAN_CFLAGS_CLASSIC\=-DKASAN\=1\ -DKASAN_CLASSIC\=1\ -fsanitize\=address\ -mllvm\ -asan-globals-live-support\ -mllvm\ -asan-force-dynamic-shadow
    export KASAN_CFLAGS_TBI\=-DKASAN\=1\ -DKASAN_TBI\=1\ -fsanitize\=kernel-hwaddress\ -mllvm\ -hwasan-recover\=0\ -mllvm\ -hwasan-instrument-atomics\=0\ -mllvm\ -hwasan-instrument-stack\=1\ -mllvm\ -hwasan-generate-tags-with-calls\=1\ -mllvm\ -hwasan-instrument-with-calls\=1\ -mllvm\ -hwasan-use-short-granules\=0\ -mllvm\ -hwasan-memory-access-callback-prefix\=__asan_
    export KASAN_DEFAULT_CFLAGS\=-DKASAN\=1\ -DKASAN_CLASSIC\=1\ -fsanitize\=address\ -mllvm\ -asan-globals-live-support\ -mllvm\ -asan-force-dynamic-shadow
    export KEEP_PRIVATE_EXTERNS\=NO
    export LD_DEPENDENCY_INFO_FILE\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/undefined_arch/Flutter\ Assemble_dependency_info.dat
    export LD_EXPORT_SYMBOLS\=YES
    export LD_GENERATE_MAP_FILE\=NO
    export LD_MAP_FILE_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Flutter\ Assemble-LinkMap-normal-undefined_arch.txt
    export LD_NO_PIE\=NO
    export LD_QUOTE_LINKER_ARGUMENTS_FOR_COMPILER_DRIVER\=YES
    export LD_RUNPATH_SEARCH_PATHS\=\ /usr/lib/swift\ \'@executable_path/../Frameworks\'\ \'@loader_path/Frameworks\'\ \"/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx\"
    export LD_SHARED_CACHE_ELIGIBLE\=Automatic
    export LD_WARN_DUPLICATE_LIBRARIES\=NO
    export LD_WARN_UNUSED_DYLIBS\=NO
    export LEGACY_DEVELOPER_DIR\=/Applications/Xcode.app/Contents/PlugIns/Xcode3Core.ideplugin/Contents/SharedSupport/Developer
    export LEX\=lex
    export LIBRARY_DEXT_INSTALL_PATH\=/Library/DriverExtensions
    export LIBRARY_FLAG_NOSPACE\=YES
    export LIBRARY_KEXT_INSTALL_PATH\=/Library/Extensions
    export LIBRARY_SEARCH_PATHS\=\ \"/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx\"\ /usr/lib/swift
    export LINKER_DISPLAYS_MANGLED_NAMES\=NO
    export LINK_FILE_LIST_normal_arm64\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/arm64/Flutter\ Assemble.LinkFileList
    export LINK_FILE_LIST_normal_x86_64\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/x86_64/Flutter\ Assemble.LinkFileList
    export LINK_OBJC_RUNTIME\=YES
    export LINK_WITH_STANDARD_LIBRARIES\=YES
    export LLVM_TARGET_TRIPLE_OS_VERSION\=macos12.3
    export LLVM_TARGET_TRIPLE_OS_VERSION_NO\=macos12.3
    export LLVM_TARGET_TRIPLE_OS_VERSION_YES\=macos26.5
    export LLVM_TARGET_TRIPLE_VENDOR\=apple
    export LM_AUX_CONST_METADATA_LIST_PATH_normal_arm64\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/arm64/Flutter\ Assemble.SwiftConstValuesFileList
    export LM_AUX_CONST_METADATA_LIST_PATH_normal_x86_64\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/x86_64/Flutter\ Assemble.SwiftConstValuesFileList
    export LOCALIZATION_EXPORT_SUPPORTED\=YES
    export LOCALIZATION_PREFERS_STRING_CATALOGS\=NO
    export LOCALIZED_STRING_CODE_COMMENTS\=NO
    export LOCALIZED_STRING_MACRO_NAMES\=NSLocalizedString\ CFCopyLocalizedString
    export LOCALIZED_STRING_SWIFTUI_SUPPORT\=YES
    export LOCAL_ADMIN_APPS_DIR\=/Applications/Utilities
    export LOCAL_APPS_DIR\=/Applications
    export LOCAL_DEVELOPER_DIR\=/Library/Developer
    export LOCAL_LIBRARY_DIR\=/Library
    export LOCROOT\=/Users/simo/Developer/mattioli.OS/desktop/macos
    export LOCSYMROOT\=/Users/simo/Developer/mattioli.OS/desktop/macos
    export MACOSX_DEPLOYMENT_TARGET\=12.3
    export MAC_OS_X_PRODUCT_BUILD_VERSION\=25F84
    export MAC_OS_X_VERSION_ACTUAL\=260502
    export MAC_OS_X_VERSION_MAJOR\=260000
    export MAC_OS_X_VERSION_MINOR\=260500
    export MAKE_MERGEABLE\=NO
    export MERGEABLE_LIBRARY\=NO
    export MERGED_BINARY_TYPE\=none
    export MERGE_LINKED_LIBRARIES\=NO
    export MESSAGES_APPLICATION_EXTENSION_SUPPORT_FOLDER_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/MessagesApplicationExtensionSupport
    export MESSAGES_APPLICATION_SUPPORT_FOLDER_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/MessagesApplicationSupport
    export METAL_LIBRARY_FILE_BASE\=default
    export METAL_LIBRARY_OUTPUT_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/UninstalledProducts/macosx/
    export MODULE_CACHE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
    export MTL_ENABLE_DEBUG_INFO\=NO
    export NATIVE_ARCH\=arm64
    export NATIVE_ARCH_32_BIT\=arm
    export NATIVE_ARCH_64_BIT\=arm64
    export NATIVE_ARCH_ACTUAL\=arm64
    export NO_COMMON\=YES
    export OBJECT_FILE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects
    export OBJECT_FILE_DIR_normal\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal
    export OBJROOT\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath
    export ONLY_ACTIVE_ARCH\=NO
    export OS\=MACOS
    export OSAC\=/usr/bin/osacompile
    export OTHER_CFLAGS\=\ -isystem\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/FMDB/FMDB.framework/Headers\"\ -isystem\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/SQLCipher/SQLCipher.framework/Headers\"\ -isystem\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sign_in_with_apple/sign_in_with_apple.framework/Headers\"\ -isystem\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sqflite_sqlcipher/sqflite_sqlcipher.framework/Headers\"\ -iframework\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/FMDB\"\ -iframework\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/SQLCipher\"\ -iframework\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sign_in_with_apple\"\ -iframework\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sqflite_sqlcipher\"\ \ -DSQLITE_HAS_CODEC\ -DHAVE_USLEEP\=1\ -DSQLCIPHER_CRYPTO\ \ -DSQLITE_HAS_CODEC\ -DSQLITE_TEMP_STORE\=2\ -DSQLITE_SOUNDEX\ -DSQLITE_THREADSAFE\ -DSQLITE_ENABLE_RTREE\ -DSQLITE_ENABLE_STAT3\ -DSQLITE_ENABLE_STAT4\ -DSQLITE_ENABLE_COLUMN_METADATA\ -DSQLITE_ENABLE_MEMORY_MANAGEMENT\ -DSQLITE_ENABLE_LOAD_EXTENSION\ -DSQLITE_ENABLE_FTS4\ -DSQLITE_ENABLE_FTS4_UNICODE61\ -DSQLITE_ENABLE_FTS3_PARENTHESIS\ -DSQLITE_ENABLE_UNLOCK_NOTIFY\ -DSQLITE_ENABLE_JSON1\ -DSQLITE_ENABLE_FTS5\ -DSQLCIPHER_CRYPTO_CC\ -DHAVE_USLEEP\=1\ -DSQLITE_MAX_VARIABLE_NUMBER\=99999\ -DSQLITE_EXTRA_INIT\=sqlcipher_extra_init\ -DSQLITE_EXTRA_SHUTDOWN\=sqlcipher_extra_shutdown
    export OTHER_CPLUSPLUSFLAGS\=\ -isystem\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/FMDB/FMDB.framework/Headers\"\ -isystem\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/SQLCipher/SQLCipher.framework/Headers\"\ -isystem\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sign_in_with_apple/sign_in_with_apple.framework/Headers\"\ -isystem\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sqflite_sqlcipher/sqflite_sqlcipher.framework/Headers\"\ -iframework\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/FMDB\"\ -iframework\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/SQLCipher\"\ -iframework\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sign_in_with_apple\"\ -iframework\ \"/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sqflite_sqlcipher\"\ \ -DSQLITE_HAS_CODEC\ -DHAVE_USLEEP\=1\ -DSQLCIPHER_CRYPTO\ \ -DSQLITE_HAS_CODEC\ -DSQLITE_TEMP_STORE\=2\ -DSQLITE_SOUNDEX\ -DSQLITE_THREADSAFE\ -DSQLITE_ENABLE_RTREE\ -DSQLITE_ENABLE_STAT3\ -DSQLITE_ENABLE_STAT4\ -DSQLITE_ENABLE_COLUMN_METADATA\ -DSQLITE_ENABLE_MEMORY_MANAGEMENT\ -DSQLITE_ENABLE_LOAD_EXTENSION\ -DSQLITE_ENABLE_FTS4\ -DSQLITE_ENABLE_FTS4_UNICODE61\ -DSQLITE_ENABLE_FTS3_PARENTHESIS\ -DSQLITE_ENABLE_UNLOCK_NOTIFY\ -DSQLITE_ENABLE_JSON1\ -DSQLITE_ENABLE_FTS5\ -DSQLCIPHER_CRYPTO_CC\ -DHAVE_USLEEP\=1\ -DSQLITE_MAX_VARIABLE_NUMBER\=99999\ -DSQLITE_EXTRA_INIT\=sqlcipher_extra_init\ -DSQLITE_EXTRA_SHUTDOWN\=sqlcipher_extra_shutdown
    export OTHER_LDFLAGS\=\ -framework\ \"FMDB\"\ -framework\ \"Foundation\"\ -framework\ \"SQLCipher\"\ -framework\ \"Security\"\ -framework\ \"sign_in_with_apple\"\ -framework\ \"sqflite_sqlcipher\"
    export OTHER_MODULE_VERIFIER_FLAGS\=\ \"-F/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/FMDB\"\ \"-F/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/FlutterMacOS\"\ \"-F/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/SQLCipher\"\ \"-F/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sign_in_with_apple\"\ \"-F/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/sqflite_sqlcipher\"
    export OTHER_SWIFT_FLAGS\=\ -D\ COCOAPODS
    export PACKAGE_CONFIG\=/Users/simo/Developer/mattioli.OS/desktop/.dart_tool/package_config.json
    export PASCAL_STRINGS\=YES
    export PATH\=/Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBUniversalPlatformPlugin.bundle/Contents/Frameworks/SWBUniversalPlatform.framework/Resources:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/local/bin:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/libexec:/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/usr/bin:/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/usr/local/bin:/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin:/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/local/bin:/Applications/Xcode.app/Contents/Developer/usr/bin:/Applications/Xcode.app/Contents/Developer/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
    export PATH_PREFIXES_EXCLUDED_FROM_HEADER_DEPENDENCIES\=/usr/include\ /usr/local/include\ /System/Library/Frameworks\ /System/Library/PrivateFrameworks\ /Applications/Xcode.app/Contents/Developer/Headers\ /Applications/Xcode.app/Contents/Developer/SDKs\ /Applications/Xcode.app/Contents/Developer/Platforms
    export PER_ARCH_MODULE_FILE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/undefined_arch
    export PER_ARCH_OBJECT_FILE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/undefined_arch
    export PER_VARIANT_OBJECT_FILE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal
    export PKGINFO_FILE_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/PkgInfo
    export PLATFORM_DEVELOPER_APPLICATIONS_DIR\=/Applications/Xcode.app/Contents/Developer/Applications
    export PLATFORM_DEVELOPER_BIN_DIR\=/Applications/Xcode.app/Contents/Developer/usr/bin
    export PLATFORM_DEVELOPER_LIBRARY_DIR\=/Applications/Xcode.app/Contents/Developer/Library
    export PLATFORM_DEVELOPER_SDK_DIR\=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
    export PLATFORM_DEVELOPER_TOOLS_DIR\=/Applications/Xcode.app/Contents/Developer/Tools
    export PLATFORM_DEVELOPER_USR_DIR\=/Applications/Xcode.app/Contents/Developer/usr
    export PLATFORM_DIR\=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform
    export PLATFORM_DISPLAY_NAME\=macOS
    export PLATFORM_FAMILY_NAME\=macOS
    export PLATFORM_NAME\=macosx
    export PLATFORM_PREFERRED_ARCH\=x86_64
    export PLATFORM_PRODUCT_BUILD_VERSION\=25F70
    export PLATFORM_REQUIRES_SWIFT_AUTOLINK_EXTRACT\=NO
    export PLATFORM_REQUIRES_SWIFT_MODULEWRAP\=NO
    export PLATFORM_USES_DSYMS\=YES
    export PLIST_FILE_OUTPUT_FORMAT\=same-as-input
    export PODS_BUILD_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath
    export PODS_CONFIGURATION_BUILD_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release
    export PODS_PODFILE_DIR_PATH\=/Users/simo/Developer/mattioli.OS/desktop/macos/.
    export PODS_ROOT\=/Users/simo/Developer/mattioli.OS/desktop/macos/Pods
    export PODS_XCFRAMEWORKS_BUILD_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/XCFrameworkIntermediates
    export PRECOMPS_INCLUDE_HEADERS_FROM_BUILT_PRODUCTS_DIR\=YES
    export PRECOMP_DESTINATION_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/PrefixHeaders
    export PROCESSED_INFOPLIST_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/undefined_arch/Processed-Info.plist
    export PRODUCT_MODULE_NAME\=Flutter_Assemble
    export PRODUCT_NAME\=Flutter\ Assemble
    export PRODUCT_SETTINGS_PATH\=
    export PROFILING_CODE\=NO
    export PROJECT\=Runner
    export PROJECT_DERIVED_FILE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/DerivedSources
    export PROJECT_DIR\=/Users/simo/Developer/mattioli.OS/desktop/macos
    export PROJECT_FILE_PATH\=/Users/simo/Developer/mattioli.OS/desktop/macos/Runner.xcodeproj
    export PROJECT_GUID\=18c1723432283e0cc55f10a6dcfd9e02
    export PROJECT_NAME\=Runner
    export PROJECT_TEMP_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build
    export PROJECT_TEMP_ROOT\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath
    export RECOMMENDED_MACOSX_DEPLOYMENT_TARGET\=11.0
    export RECURSIVE_SEARCH_PATHS_FOLLOW_SYMLINKS\=YES
    export REMOVE_CVS_FROM_RESOURCES\=YES
    export REMOVE_GIT_FROM_RESOURCES\=YES
    export REMOVE_HEADERS_FROM_EMBEDDED_BUNDLES\=YES
    export REMOVE_HG_FROM_RESOURCES\=YES
    export REMOVE_STATIC_EXECUTABLES_FROM_EMBEDDED_BUNDLES\=YES
    export REMOVE_SVN_FROM_RESOURCES\=YES
    export RESCHEDULE_INDEPENDENT_HEADERS_PHASES\=YES
    export REZ_COLLECTOR_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/ResourceManagerResources
    export REZ_OBJECTS_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/ResourceManagerResources/Objects
    export RPATH_ORIGIN\=@loader_path
    export RUNTIME_EXCEPTION_ALLOW_DYLD_ENVIRONMENT_VARIABLES\=NO
    export RUNTIME_EXCEPTION_ALLOW_JIT\=NO
    export RUNTIME_EXCEPTION_ALLOW_UNSIGNED_EXECUTABLE_MEMORY\=NO
    export RUNTIME_EXCEPTION_DEBUGGING_TOOL\=NO
    export RUNTIME_EXCEPTION_DISABLE_EXECUTABLE_PAGE_PROTECTION\=NO
    export RUNTIME_EXCEPTION_DISABLE_LIBRARY_VALIDATION\=NO
    export SCANNING_PCM_KEEP_CACHE_DIRECTORY\=YES
    export SCAN_ALL_SOURCE_FILES_FOR_INCLUDES\=NO
    export SCRIPT_INPUT_FILE_0\=/Users/simo/Developer/mattioli.OS/desktop/macos/Flutter/ephemeral/tripwire
    export SCRIPT_INPUT_FILE_COUNT\=1
    export SCRIPT_INPUT_FILE_LIST_0\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/InputFileList-33CC111E2044C6BF0003C045-FlutterInputs-89a16cb8285fece7374bee757c7f67b3-resolved.xcfilelist
    export SCRIPT_INPUT_FILE_LIST_COUNT\=1
    export SCRIPT_OUTPUT_FILE_COUNT\=0
    export SCRIPT_OUTPUT_FILE_LIST_0\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/OutputFileList-33CC111E2044C6BF0003C045-FlutterOutputs-7f6598edd250efc6eefe9f6cb6021788-resolved.xcfilelist
    export SCRIPT_OUTPUT_FILE_LIST_COUNT\=1
    export SDKROOT\=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk
    export SDK_DIR\=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk
    export SDK_DIR_macosx\=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk
    export SDK_DIR_macosx26_5\=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk
    export SDK_NAME\=macosx26.5
    export SDK_NAMES\=macosx26.5
    export SDK_PRODUCT_BUILD_VERSION\=25F70
    export SDK_STAT_CACHE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData
    export SDK_STAT_CACHE_ENABLE\=YES
    export SDK_STAT_CACHE_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex/macosx26.5-25F70-e082c4a02f00227109f4ed75e425c832.sdkstatcache
    export SDK_VERSION\=26.5
    export SDK_VERSION_ACTUAL\=260500
    export SDK_VERSION_MAJOR\=260000
    export SDK_VERSION_MINOR\=260500
    export SED\=/usr/bin/sed
    export SEPARATE_STRIP\=NO
    export SEPARATE_SYMBOL_EDIT\=NO
    export SET_DIR_MODE_OWNER_GROUP\=YES
    export SET_FILE_MODE_OWNER_GROUP\=NO
    export SHALLOW_BUNDLE\=NO
    export SHARED_DERIVED_FILE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release/DerivedSources
    export SHARED_PRECOMPS_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/PrecompiledHeaders
    export SIGNATURE_METADATA_FOLDER_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Signatures
    export SKIP_INSTALL\=YES
    export SKIP_MERGEABLE_LIBRARY_BUNDLE_HOOK\=NO
    export SOURCE_ROOT\=/Users/simo/Developer/mattioli.OS/desktop/macos
    export SRCROOT\=/Users/simo/Developer/mattioli.OS/desktop/macos
    export STRINGSDATA_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/undefined_arch
    export STRINGSDATA_ROOT\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build
    export STRINGS_FILE_INFOPLIST_RENAME\=YES
    export STRINGS_FILE_OUTPUT_ENCODING\=UTF-16
    export STRING_CATALOG_GENERATE_SYMBOLS\=NO
    export STRIP_BITCODE_FROM_COPIED_FILES\=NO
    export STRIP_INSTALLED_PRODUCT\=YES
    export STRIP_PNG_TEXT\=NO
    export STRIP_STYLE\=all
    export STRIP_SWIFT_SYMBOLS\=YES
    export SUPPORTED_PLATFORMS\=macosx
    export SUPPORTS_TEXT_BASED_API\=NO
    export SUPPRESS_WARNINGS\=NO
    export SWIFT_COMPILATION_MODE\=wholemodule
    export SWIFT_EMIT_CONST_VALUE_PROTOCOLS\=AnyResolverProviding\ AppEntity\ AppEnum\ AppExtension\ AppIntent\ AppIntentsPackage\ AppShortcutProviding\ AppShortcutsProvider\ AppUnionValue\ AppUnionValueCasesProviding\ DynamicOptionsProvider\ EntityQuery\ ExtensionPointDefining\ IntentValueQuery\ Resolver\ TransientEntity\ _AssistantIntentsProvider\ _GenerativeFunctionExtractable\ _IntentValueRepresentable
    export SWIFT_EMIT_LOC_STRINGS\=NO
    export SWIFT_ENABLE_EXPLICIT_MODULES\=YES
    export SWIFT_OPTIMIZATION_LEVEL\=-O
    export SWIFT_PLATFORM_TARGET_PREFIX\=macos
    export SWIFT_RESPONSE_FILE_PATH_normal_arm64\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/arm64/Flutter\ Assemble.SwiftFileList
    export SWIFT_RESPONSE_FILE_PATH_normal_x86_64\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build/Objects-normal/x86_64/Flutter\ Assemble.SwiftFileList
    export SWIFT_STDLIB_TOOL_UNSIGNED_DESTINATION_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/SwiftSupport
    export SYMROOT\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath
    export SYSTEM_ADMIN_APPS_DIR\=/Applications/Utilities
    export SYSTEM_APPS_DIR\=/Applications
    export SYSTEM_CORE_SERVICES_DIR\=/System/Library/CoreServices
    export SYSTEM_DEMOS_DIR\=/Applications/Extras
    export SYSTEM_DEVELOPER_APPS_DIR\=/Applications/Xcode.app/Contents/Developer/Applications
    export SYSTEM_DEVELOPER_BIN_DIR\=/Applications/Xcode.app/Contents/Developer/usr/bin
    export SYSTEM_DEVELOPER_DEMOS_DIR\=/Applications/Xcode.app/Contents/Developer/Applications/Utilities/Built\ Examples
    export SYSTEM_DEVELOPER_DIR\=/Applications/Xcode.app/Contents/Developer
    export SYSTEM_DEVELOPER_DOC_DIR\=/Applications/Xcode.app/Contents/Developer/ADC\ Reference\ Library
    export SYSTEM_DEVELOPER_GRAPHICS_TOOLS_DIR\=/Applications/Xcode.app/Contents/Developer/Applications/Graphics\ Tools
    export SYSTEM_DEVELOPER_JAVA_TOOLS_DIR\=/Applications/Xcode.app/Contents/Developer/Applications/Java\ Tools
    export SYSTEM_DEVELOPER_PERFORMANCE_TOOLS_DIR\=/Applications/Xcode.app/Contents/Developer/Applications/Performance\ Tools
    export SYSTEM_DEVELOPER_RELEASENOTES_DIR\=/Applications/Xcode.app/Contents/Developer/ADC\ Reference\ Library/releasenotes
    export SYSTEM_DEVELOPER_TOOLS\=/Applications/Xcode.app/Contents/Developer/Tools
    export SYSTEM_DEVELOPER_TOOLS_DOC_DIR\=/Applications/Xcode.app/Contents/Developer/ADC\ Reference\ Library/documentation/DeveloperTools
    export SYSTEM_DEVELOPER_TOOLS_RELEASENOTES_DIR\=/Applications/Xcode.app/Contents/Developer/ADC\ Reference\ Library/releasenotes/DeveloperTools
    export SYSTEM_DEVELOPER_USR_DIR\=/Applications/Xcode.app/Contents/Developer/usr
    export SYSTEM_DEVELOPER_UTILITIES_DIR\=/Applications/Xcode.app/Contents/Developer/Applications/Utilities
    export SYSTEM_DEXT_INSTALL_PATH\=/System/Library/DriverExtensions
    export SYSTEM_DOCUMENTATION_DIR\=/Library/Documentation
    export SYSTEM_KEXT_INSTALL_PATH\=/System/Library/Extensions
    export SYSTEM_LIBRARY_DIR\=/System/Library
    export TAPI_DEMANGLE\=YES
    export TAPI_ENABLE_PROJECT_HEADERS\=NO
    export TAPI_LANGUAGE\=objective-c
    export TAPI_LANGUAGE_STANDARD\=compiler-default
    export TAPI_USE_SRCROOT\=YES
    export TAPI_VERIFY_MODE\=Pedantic
    export TARGETNAME\=Flutter\ Assemble
    export TARGET_BUILD_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/UninstalledProducts/macosx
    export TARGET_NAME\=Flutter\ Assemble
    export TARGET_TEMP_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build
    export TEMP_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build
    export TEMP_FILES_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build
    export TEMP_FILE_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\ Assemble.build
    export TEMP_ROOT\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath
    export TEMP_SANDBOX_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/TemporaryTaskSandboxes
    export TEST_FRAMEWORK_SEARCH_PATHS\=\ /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks
    export TEST_LIBRARY_SEARCH_PATHS\=\ /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib
    export TOOLCHAINS\=com.apple.dt.toolchain.XcodeDefault
    export TOOLCHAIN_DIR\=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain
    export TRACK_WIDGET_CREATION\=true
    export TREAT_MISSING_BASELINES_AS_TEST_FAILURES\=NO
    export TREAT_MISSING_SCRIPT_PHASE_OUTPUTS_AS_ERRORS\=NO
    export TREE_SHAKE_ICONS\=true
    export UID\=501
    export UNINSTALLED_PRODUCTS_DIR\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/UninstalledProducts
    export UNSTRIPPED_PRODUCT\=NO
    export USER\=simo
    export USER_APPS_DIR\=/Users/simo/Applications
    export USER_LIBRARY_DIR\=/Users/simo/Library
    export USE_DYNAMIC_NO_PIC\=YES
    export USE_HEADERMAP\=YES
    export USE_HEADER_SYMLINKS\=NO
    export USE_RECURSIVE_SCRIPT_INPUTS_IN_SCRIPT_PHASES\=YES
    export VALIDATE_DEVELOPMENT_ASSET_PATHS\=YES_ERROR
    export VALIDATE_PRODUCT\=NO
    export VALID_ARCHS\=arm64\ arm64e\ i386\ x86_64
    export VERBOSE_PBXCP\=NO
    export VERSION_INFO_BUILDER\=simo
    export VERSION_INFO_FILE\=Flutter\ Assemble_vers.c
    export VERSION_INFO_STRING\=\"@\(\#\)PROGRAM:Flutter\ Assemble\ \ PROJECT:Runner-\"
    export WARNING_CFLAGS\=-Wall\ -Wconditional-uninitialized\ -Wnullable-to-nonnull-conversion\ -Wmissing-method-return-type\ -Woverlength-strings
    export WATCHKIT_2_SUPPORT_FOLDER_PATH\=/Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/WatchKitSupport2
    export WORKSPACE_DIR\=/Users/simo/Developer/mattioli.OS/desktop/macos
    export WRAP_ASSET_PACKS_IN_SEPARATE_DIRECTORIES\=NO
    export XCODE_APP_SUPPORT_DIR\=/Applications/Xcode.app/Contents/Developer/Library/Xcode
    export XCODE_PRODUCT_BUILD_VERSION\=17F113
    export XCODE_VERSION_ACTUAL\=2660
    export XCODE_VERSION_MAJOR\=2600
    export XCODE_VERSION_MINOR\=2660
    export XPCSERVICES_FOLDER_PATH\=/XPCServices
    export YACC\=yacc
    export _BOOL_\=NO
    export _BOOL_NO\=NO
    export _BOOL_YES\=YES
    export _DEVELOPMENT_TEAM_IS_EMPTY\=YES
    export _DISCOVER_COMMAND_LINE_LINKER_INPUTS\=YES
    export _DISCOVER_COMMAND_LINE_LINKER_INPUTS_INCLUDE_WL\=YES
    export _IS_EMPTY_\=YES
    export _LD_MULTIARCH\=YES
    export _MACOSX_DEPLOYMENT_TARGET_IS_EMPTY\=NO
    export __DIAGNOSE_DEPRECATED_ARCHS\=YES
    export __ORIGINAL_SDK_DEFINED_LLVM_TARGET_TRIPLE_SYS\=macos
    export arch\=undefined_arch
    export variant\=normal
    /bin/sh -c /Users/simo/Library/Developer/Xcode/DerivedData/Runner-dafpgmuyizprxoecpgkrryneutkx/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/Runner.build/Release/Flutter\\\ Assemble.build/Script-33CC111E2044C6BF0003C045.sh

warning: Code asset "package:objective_c/objective_c.dylib" has different framework names for different architectures. Picking "objective_c.framework" and ignoring "objective_c1.framework". This is likely an issue in the package providing the asset. Please report this to the package maintainers and ensure the "build.dart" hook produces consistent filenames.
Project /Users/simo/Developer/mattioli.OS/desktop built and packaged successfully.
Project /Users/simo/Developer/mattioli.OS/desktop built and packaged successfully.

Code asset "package:objective_c/objective_c.dylib" has different framework names for different architectures. Picking "objective_c.framework" and ignoring "objective_c1.framework". This is likely an issue in the package providing the asset. Please report this to the package maintainers and ensure the "build.dart" hook produces consistent filenames.


---

When I build the flutter mobile ios implementation I receive this warnings here from Xcode that I want you to fix: Runner
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

---

## iCloud sync — Mac missing data: recovery + CloudKit env hardening (2026-07-23)

**Diagnosis (settled):** the Mac is not missing data because of a key-split — the shared E2E key decrypts fine (profile image + a few macro goals crossed). The iPhone's bulk (3,489 macro goals / 2,591 logs / 20 habits) was pushed to the **CloudKit *Development*** datastore during earlier **dev-build (Xcode `flutter run`) testing**; TestFlight uses **Production**. Those rows are all `dirty=0` locally and the engine only ever pushes `dirty=1` (no re-backfill), so the iPhone never re-uploaded them to Production. The Mac (Production) only ever pulled the handful of records edited after the TestFlight install. Dev→Prod is a developer-only artifact — real App Store users can't hit it.

### A. Blocking — recover the data (ON THE iPHONE ONLY; I cannot do on-device steps)
- [ ] ⚠️ **NEVER tap "Reset sync from this device" or "Delete all data" ON THE MAC.** Both fire a *synchronizable* Keychain/zone delete that propagates and would destroy the iPhone's only complete copy. If the Mac shows a sync-key/reset card, do NOT act on it — let it adopt, don't reset.
- [ ] Preconditions (confirmed 2026-07-23): both devices same Apple ID + iCloud Keychain ON.
- [ ] **Quit the Mac app entirely (⌘Q)** and leave it quit for the whole reset (avoids the empty-zone mint-race window; the native `tryClaimFirstMint` guard is not in the current TestFlight build).
- [ ] On the **iPhone** → iCloud sync settings → **"Reset sync from this device"** → confirm. This deletes the Production zone, mints a fresh shared key, re-dirties ALL local rows (`markAllDirty`), and re-uploads everything.
- [ ] **Wait** and watch the iPhone's sync diagnostics: `pending` spikes (re-dirtying ~6,000 rows) then drains to **0**, status "Up to date." This is the large-first-push path (retry/backoff A2 is unverified) — be patient; re-trigger sync (refocus/manual) until `pending` = 0.
- [ ] **Only after** the iPhone reads "Up to date" / pending 0, **reopen the Mac app**; give it a few 60s poll cycles (or relaunch once). It drops its stale token on the key-fingerprint change and full-refetches.
- [ ] Verify on the Mac: diagnostics counts climb to match the iPhone; habits/macro-goals/statistics populate.

### B. Done in code (2026-07-23) — verify on your next archive
- [x] **Lever 1 — explicit CloudKit environment pin (macOS).** Added `com.apple.developer.icloud-container-environment` = **Production** to `desktop/macos/Runner/Release.entitlements` and = **Development** to `DebugProfile.entitlements`. `plutil -lint` OK on both. So the environment is deterministic per build config instead of signing-dependent; dev builds stay in Development, release builds in Production.
- [ ] **Verify once in Xcode:** archive the macOS app (Release) → Distribute → App Store Connect and confirm it still validates/signs with no entitlement error, and that CloudKit still works. The key is ignored for App Store distribution (Production is forced), so this should be transparent — but confirm. If automatic signing ever complains about the entitlement, removing the two added keys is a safe rollback.
- [ ] iOS was intentionally NOT pinned: it uses a single `Runner.entitlements` shared by Debug+Release, so a naive pin would force Debug iOS onto Production. iOS already selects the environment correctly by signing (dev→Development, App Store→Production). Optional future work: split iOS into RunnerDebug/Runner entitlements + per-config `CODE_SIGN_ENTITLEMENTS` if you want strict parity (needs an Xcode build to verify).

### C. Lever 2 — macOS release signing (yours, in Xcode; recommended before release)
- [ ] `desktop/macos/Runner.xcodeproj/project.pbxproj:788` signs the Release config with **"Apple Development"** and an empty provisioning-profile specifier. For an App Store Connect build the Distribute flow re-signs with a distribution profile (which is why your current Mac build correctly landed on Production), but confirm your Archive → Distribute → App Store Connect step is using an **Apple Distribution / Mac App Store** profile, not exporting a development-signed build. A development-signed Mac build would bind to **Development** CloudKit and permanently fail to sync with Production iPhones.

### D. Not fixing (agreed): the "no re-backfill" code path
- Real App Store users only ever use Production and get a full `markAllDirty` push at first-enable, so they can't reach the stranded state; `resetSyncFromThisDevice` already covers the developer dev→prod case. No automatic empty-zone re-upload was added (would guard a developer-only scenario).
