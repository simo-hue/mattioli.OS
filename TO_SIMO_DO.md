# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] 
- [ ] Macro goals still need a numeric target + progress bar (status already cycles active/completed/failed). Habits are DONE — the Checkbox / Number / Automatic picker and quantitative targets are live; MacroTargetsConfig.enabled is still false on both apps.

---

# TO DOUBLE CHECK:

- [ ]

## Arabic device QA — auto-verified habit line (2026-07-29)

Only a real Arabic-locale device can settle these two. Set the app to العربية, open a
day with an auto-verified habit, and look at the line under the habit name.

- [ ] **Does `≥` render mirrored (looking like `≤`)?** U+2264/U+2265 are
  `Bidi_Mirrored=Yes`, and in an RTL run a conforming shaper (HarfBuzz, which Flutter
  uses) may flip the glyph. It is Unicode-correct, but `≥` (goal) and `≤` (limit) mean
  OPPOSITE things here, so a reader who scans math symbols Latin-first could read the
  rule backwards. If it does mirror and you dislike it, the fix is a locale-owned
  summary pattern using the words already in the file — `على الأقل` / `على الأكثر`,
  which in Arabic follow the quantity: `التمرين: 30 دقيقة على الأقل`. That costs a new
  pattern key per locale and is much longer, so decide from what you actually see.
- [ ] **Does 11pt SF Arabic clip dots or diacritics** in that single-line row? Arabic
  reads smaller than Latin at the same point size; may need +1pt or an explicit line
  height for `ar`.

## Arabic grammar defects found while reviewing (pre-existing, NOT from this change)

These are shipped bugs an Arabic native-speaker review surfaced. Numbers do not agree
with their unit words: Arabic needs the dual for 2 and the plural for 3–10, and the
`units` tokens are all singular. Concrete, reachable cases:

- [ ] `sleepHours` default **8** renders `≥ 8 ساعة` — must be `8 ساعات`. Typical sleep
  goals (6–9) sit entirely inside the broken band, so this is the DEFAULT state of a
  shipped template.
- [ ] `mindfulMinutes` default **10** renders `≥ 10 دقيقة` — must be `10 دقائق`.
- [ ] `activeEnergy` (`سعرة`) breaks the same way for 2–10.
- [ ] `screenTime.selectionSummary` (`"{count} محدد"`) has both the agreement bug and a
  gender bug — apps/categories are non-human plurals, so `محددة`.
- [ ] Unit/label stutter, all locales, worst in Arabic: the summary appends a unit to a
  label that already names it — `≥ 30 دقيقة دقائق التمرين`, `≥ 8 ساعة ساعات النوم`.
  English has it too (`≥ 30 min Exercise minutes`); Arabic repeats the same root twice.
- [ ] Three different verbs for "tap" across `ar.i18n.json` (`انقر` ×6, `اضغط` ×1,
  `المس` ×0) and none is the Apple-iOS-Arabic `المس`. `a11y.toggleHint` currently tells
  iPhone users to double-*click*. Wants one sweep, not per-string edits.
- [ ] `CouldNotVerifyChip` hardcodes ASCII `'?'`; Arabic is `؟` (U+061F).

Cheapest fix for the agreement family, if you want it: make the Arabic unit tokens
invariant abbreviations (`د`, `س`) the way `كم` already is — abbreviations don't
inflect. The thorough fix is slang plural categories for `ar`, which means
`verificationUnitSuffix` has to take the count.

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

## Cumulative numeric macro goals (feature #6) — foundation (2026-07-24)

### Deferred feature work (the macro-goal feature is NOT user-visible until these land)
- [ ] **UI (the bulk of remaining work)**: create/edit a numeric macro-goal target
      (amount + unit) + an optional "link a habit" picker + a progress bar, on both
      apps, gated by the flags. Mobile: `macro_goals_screen.dart` + `ui/widgets/macro_goals/`.
      Desktop: `create_goal_dialog.dart` + goals presentation. Will add the 5-locale
      i18n keys (+ Arabic native review).
- [ ] **Cloud-mode delete-snapshot**: in account mode, deleting a linked habit
      un-links the macro goal (ON DELETE SET NULL) but does NOT snapshot the
      accumulated derived value into progress_amount — implement a client
      fetch-sum-before-delete in `goal_provider.dart` (mobile) / `dashboard_controller.dart`
      (desktop) / cloud repo. (Private mode already snapshots.)
- [ ] **When the UI ships**: force-write the numeric columns on the Supabase UPDATE
      path (like the habit `target` column) so editing can actively CLEAR a target
      or break a link (today's conditional emit can't clear an omitted column).
- [ ] `get_macro_goals_stats` RPC + Dart twins unchanged (correct as-is — numeric
      completion flows through `status`); reflecting numeric progress in stats is a
      future enhancement, not a fix.

## Settings state hoist + pane split (2026-07-28)

- **Two timing nuances the widget suite cannot see.** The form state now lives in a keep-alive Riverpod controller rather than a per-mount `State`, which changes two things on a real machine: (1) the synced read-back applies one microtask after `initState` instead of inside it, so there is at most one frame of pre-hydration values when Settings opens; (2) the controller survives closing Settings, so re-opening re-arms the hydration latch and re-reads the appearance instead of rebuilding from SharedPreferences. Open Settings, change a preference on the iPhone, then close and re-open Settings on the Mac and confirm the Mac shows the iPhone's value.
- **Pre-existing, not introduced:** `settings_page.dart` `_deletePrivateData` opens its loading dialog after an `await` with no `mounted` check. If the page is disposed while the confirm dialog is open, it uses a defunct context. Worth fixing, but it is not a regression from this work.

## Screen Time on-device test checklist (2026-07-28)

Code audit of the Screen Time verification stack found 5 blockers to fix **before**
installing a test build (see the session report). These are the tests only a real
iPhone can settle, ordered by how much they change:

- **T1 — does re-registering reset the day's counter?** (Now also the acceptance test for the monitoring diff: with the diff in place an unchanged goal should NOT be re-registered at all, so its counter should survive a relaunch. Verify via `screen_time_monitor_specs` in the App Group — an unchanged goal must still have an entry after a sync that touched a different goal.)
  Original steps: Register a 5-min limit, burn 6 min so the threshold fires, force-quit, relaunch, background→foreground (this forces `stopMonitoring()` + re-register), burn 6 more min. *If the counter restarts at zero*, every app launch forgives the day's accumulated usage and `atMost` habits become unreachable — the whole sync strategy has to change from "stop everything and re-add" to a diff against `DeviceActivityCenter().activities`. Highest-value test.
- **T2 — does `stopMonitoring()` deliver `intervalDidEnd`?** With monitoring live mid-day, edit a threshold so the sync runs, then check the App Group buffer (`group.com.simo.evolve.verification`, key `pending_screen_time_signals`) for any `stayedUnder` row. **Assert on the row's `y`/`m`/`d` fields, not on "today"** — signals are now dated by the interval they describe, so a stop-induced row would carry neither today nor yesterday but be dropped entirely by the mid-day guard. Seeing *no* row is the pass. Seeing one means the guard's window needs widening.
  Also test the **23:55–23:59 band specifically**: edit a threshold in that window. If `stopMonitoring()` raises `intervalDidEnd`, a sync there is classified as "today's interval closing" and banks a spurious *pass* for today — the one five-minute hole the mid-day drop guard cannot cover.
- **T3 — what does the appex actually link?** After archiving: `otool -L …/PlugIns/DeviceActivityMonitorExtension.appex/DeviceActivityMonitorExtension`. Expect system frameworks only. Any `@rpath/Flutter.framework` or `@rpath/SQLCipher.framework` confirms the extension is inheriting the app's Pods xcconfig and will likely be jetsammed at its 6 MB cap.
- **T4 — midnight attribution.** PRECONDITION: after the first sync, confirm the App Group key `screen_time_monitor_thresholds` actually holds `{goalId: minutes}`. Without it the extension takes the no-correction fallback and this test proves nothing. Then cross a limit at ~23:58 with the app closed and check which day the verdict lands on — it should be the day you crossed it, not the fresh one. A late `reachedThreshold` stamped on the fresh day is made *unflippable* by the permanence guard.
- **T4b — DST fall-back.** Set the date to a DST fall-back Sunday, register a 150-minute limit and burn usage across the repeated 01:00–02:00 hour. The crossing must land on that day. This is the case where wall-clock arithmetic silently mis-dates and only elapsed-time arithmetic is correct.
- **T5 — web-only picks.** In the picker select only websites and tap Done. Currently the app reports that as "empty" and refuses to save, even though native monitoring does handle web domains.
- **T6 — concurrent appends.** With 2+ Screen Time habits, check the App Group buffer after 23:59: expect one entry per goal. Missing entries confirm the unsynchronised read-modify-write race.
- **T7 — revoke and return.** Revoke Screen Time for Evolve in iOS Settings, reopen the app, and note where the FamilyControls toggle actually lives and what `authorizationStatus` reports. The in-app "Open Settings" button currently opens Settings › Evolve, not the Screen Time pane its own copy describes.
- **T9 — power-off overnight replay.** Let the phone die before 23:59 (charge to ~5% in the evening) and boot it in the morning. Does DeviceActivity replay the missed `intervalDidEnd`? If it does, that delivery is hours late but is a *genuine* report of yesterday — and the extension currently DROPS anything more than four hours after midnight. A replayed row appearing in the buffer means `lateDeliveryWindowMinutes` is discarding real passes and must be widened.
- **T10 — spring-forward.** Set the date to a spring-forward Sunday and let 23:59 pass. The App Group buffer must gain a `stayedUnder` row. This is the mirror of T4b: the day is 23 hours long, and any logic that measures the interval end in *elapsed* rather than *wall-clock* minutes silently drops every goal's pass that day.

---


When I build the macOS version on my mac mini I receive this warnings here even though the build is successfull.
Here is the output that I want you to fix: 
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
    export FLUTTER_BUILD_NAME\=1.1.6
    export FLUTTER_BUILD_NUMBER\=24
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

warning: Code asset "package:objective_c/objective_c.dylib" has different framework names for different architectures. Picking "objective_c.framework" and ignoring "objective_c1.framework". This is likely an issue in the package providing the asset. Please report this to the package maintainers and ensure the "build.dart" hook produces consistent filenames.
Project /Users/simo/Developer/mattioli.OS/desktop built and packaged successfully.

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
    export FLUTTER_BUILD_NAME\=1.1.6
    export FLUTTER_BUILD_NUMBER\=24
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

