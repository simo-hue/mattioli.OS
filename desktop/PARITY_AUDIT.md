# Desktop ↔ Mobile Under-the-Hood Parity Audit

_Generated 2026-07-14 by a 44-agent parity audit (13 subsystems, per-finding adversarial verification). Mobile (iOS) is the reference; desktop (macOS) must match its behavior/reasoning._

## Overall assessment

The desktop (macOS) app is broadly at parity with mobile at the reasoning/formula level — streak logic is byte-identical, private analytics formulas are faithfully ported, and the core sync engine is shared-package-by-construction. However, the two clients diverge materially at the edges in ways that cause real data loss, privacy leaks, and monetization holes: desktop silently drops the goal_logs.value column across import/export, ships no PII scrubbing before sending logs to Sentry, and leaves three Pro gates entirely unenforced. Several safety nets mobile relies on (owner self-heal, on-disk mode recovery, DB-ready gating, notification cleanup, biometric re-lock) are absent on desktop. None of the confirmed divergences are macOS-capability-limited — they are missing or diverged app-level code that is directly portable from mobile.

## Confirmed divergences (ranked by impact)

### #1 — [HIGH] backup-import / sync — goal_logs.value dropped end-to-end on desktop

- **Differs:** Desktop silently drops the goal_logs.value (REAL) column in three import stages and in export: parse (_processData rebuilds the log without value), private-merge INSERT and LWW UPDATE, and exportSnapshot's habitLogs projection. Mobile carries value through all of these. This is the root cause of the failing 1.0.10 round-trip test (expects value 2.5, gets null).
- **Why it matters:** Any quantitative habit value (steps, minutes, reps — including HealthKit auto-verified measured quantities) synced from mobile is destroyed when desktop imports OR exports a backup. Silent, permanent data loss on a column both platforms' schema defines and mobile populates.
- **Fix:** Add 'value': l['value'] to _processData's processed-log map (desktop_backup_import_service.dart ~285), to both the applyImport INSERT (~885) and UPDATE (~899) in desktop_private_db.dart, and to the exportSnapshot habitLogs list-comprehension (desktop_private_db.dart:216-227). Fixing only the parse will NOT make the test pass — the INSERT must also write value.
- **Mobile:** `mobile/lib/core/import_merge.dart:208,126,789,802; mobile/lib/core/private_local_database.dart:835 (export)`
- **Desktop:** `desktop/lib/core/desktop_backup_import_service.dart:278-286; desktop/lib/core/desktop_private_db.dart:878-887, 896-901 (import), 216-227 (export)`

### #2 — [HIGH] sentry-privacy — no PII scrubbing before events leave the device

- **Differs:** Desktop ships no PrivacyUtils. AppLogger.info()/warning() pass the raw message and raw extras straight into Sentry.addBreadcrumb(data:), captureMessage, and setContexts. Mobile scrubs inline via PrivacyUtils.sanitizeString (emails, JWTs, password/token/secret/refresh_token pairs) and sanitizeMap before anything leaves the device. Desktop's beforeSend only nulls event.user.email and cannot reach breadcrumb text, message bodies, or context maps.
- **Why it matters:** In Supabase mode with consent granted, a warning like 'Login failed for user test@example.com' or a sync breadcrumb carrying a JWT/refresh_token is transmitted to Sentry verbatim on desktop, where mobile sends [EMAIL_REDACTED]/[REDACTED]. Real cross-device privacy regression; also stored raw in the in-app log viewer's ring buffer.
- **Fix:** Port PrivacyUtils (ideally into a shared package) and apply sanitizeString to the message and sanitizeMap to extras/breadcrumb-data in desktop AppLogger.info() and warning(), mirroring mobile. error() is unsanitized on both, so it is already at parity.
- **Mobile:** `mobile/lib/core/privacy_utils.dart:1-55; mobile/lib/core/app_logger.dart:250,258,268,281,289,304`
- **Desktop:** `desktop/lib/core/app_logger.dart:136-164 (warning), 168-183 (info); PrivacyUtils absent`

### #3 — [HIGH] auth-biometric — session-persist can call storage.deleteAll(), wiping the Private-Mode DB key (SEC-6)

- **Differs:** Desktop SecureLocalStorage.persistSession writes with clearAllOnDuplicateFailure:true; on an unrecoverable -25299 the write falls back to storage.deleteAll(). The default store and the device-local store share one macOS keychain service (differing only by accessibility, which deleteAll ignores), and macOS never applies kSecAttrAccessGroup — so deleteAll on the session store also wipes the device-local Private-Mode SQLCipher key. Mobile documents this exact scenario and deliberately NEVER calls deleteAll, scoping recovery to the offending key.
- **Why it matters:** A rare unrecoverable duplicate-item error on the session key can permanently, unrecoverably destroy the local Private database (key gone → DB undecryptable). This is a data-loss hazard introduced only on desktop, on the very tier holding the most critical secret.
- **Fix:** Drop clearAllOnDuplicateFailure for the Supabase session key (scope duplicate recovery to that key only, as mobile does). The suggested access-group mitigation will NOT work on this macOS plugin (accessGroup ignored); alternatively give _deviceLocalStorage a distinct accountName/service so deleteAll on the default store cannot reach it.
- **Mobile:** `mobile/lib/core/secure_storage_utils.dart:162-177`
- **Desktop:** `desktop/lib/core/secure_local_storage.dart:39; desktop/lib/core/secure_storage_utils.dart:55-59`

### #4 — [HIGH] private-db — orphaned-owner self-heal absent on desktop

- **Differs:** Mobile runs _reconcileOrphanedOwner on every DB open: if the current owner id owns zero rows but exactly one other user_id owns all rows, it adopts that id so owner-filtered queries find the data. Desktop's _open() only seeds the profile and returns — no equivalent recovery anywhere.
- **Why it matters:** Two silent-loss preconditions genuinely exist on desktop: (a) ownerId mints a fresh UUID on a transient Keychain null read (no fail-closed guard), and (b) a second-device iCloud re-key can move all rows to the canonical owner while the best-effort adoptOwner write fails. Either leaves the user's habit data permanently invisible with no self-heal path.
- **Fix:** Port _reconcileOrphanedOwner to DesktopPrivateDb and call it from _open() right after seedProfile, using the same five data tables (goals, goal_logs, daily_moods, long_term_goals, macro_goal_categories) and single-foreign-owner guard as mobile.
- **Mobile:** `mobile/lib/core/private_local_database.dart:149, 168-252`
- **Desktop:** `desktop/lib/core/desktop_private_db.dart:1070-1092 (no reconcile); ownerId 84-91; adoptOwner 70-72`

### #5 — [HIGH] subscription-pro — free-tier 5-habit limit unenforced on desktop

- **Differs:** Mobile blocks a non-Pro user from creating a 6th habit ('if (!isPro && count >= 5)' → paywall). All three desktop habit-creation paths (dashboard_controller.addHabit, habits_page._openHabitEditor, create_habit_dialog._save) have no isPro/count check. Desktop already gates goals at 100 for non-Pro, proving the toolkit exists and was simply omitted for habits.
- **Why it matters:** A free cloud-mode desktop user can create unlimited habits — a monetized limit desktop's own paywall advertises as 'Unlimited Habits'. Revenue leak and cross-platform inconsistency.
- **Fix:** Add a Pro gate before persisting a new habit in dashboard_controller.addHabit (the shared entry point): when !desktopIsProProvider and count >= 5, call showProFeaturesDialog and abort, mirroring habit_management_modal.dart.
- **Mobile:** `mobile/lib/ui/widgets/habit_management_modal.dart:108-119`
- **Desktop:** `desktop/lib/features/dashboard/application/dashboard_controller.dart:116-135; habits_page.dart:141-165; create_habit_dialog.dart:59-78`

### #6 — [HIGH] subscription-pro — per-habit statistics free on desktop, Pro-gated on mobile

- **Differs:** Mobile Pro-gates the individual-habit stats drill-down at three points (lock icon, _selectGoal bail to ProFeaturesModal, post-frame reset). Desktop's _HabitSelectorCard.onHabitChanged switches scope to a specific habit with no entitlement check; the Statistics nav item is ungated. Desktop advertises this as 'Habit-Specific Statistics' Pro.
- **Why it matters:** Free desktop users get full per-habit analytics that mobile blocks and desktop itself markets as Pro. Revenue leak plus feature-parity inconsistency.
- **Fix:** Gate the habit scope switch in statistics_page.dart: when a specific habit is chosen and !desktopIsProProvider, invoke showProFeaturesDialog and keep scope global, matching statistics_screen.dart:406.
- **Mobile:** `mobile/lib/ui/screens/statistics_screen.dart:404-425, 435, 713-726`
- **Desktop:** `desktop/lib/features/statistics/presentation/statistics_page.dart:213-230`

### #7 — [HIGH] notifications — per-goal reminders suppressed by the global Habit Reminders toggle on desktop

- **Differs:** On mobile the 'Habit Reminders' toggle controls only the 09:00 Morning Brief; per-goal reminders are scheduled independently and keep firing with the toggle off. On desktop the per-goal reminder loop is nested inside 'if (habitReminders)', so turning off a toggle the UI presents as controlling only the Morning Brief silences every per-goal reminder.
- **Why it matters:** A user who disables 'Habit Reminders' but keeps per-goal reminder times has all reminders fire on mobile but NONE on desktop. reminder_time syncs cross-platform, so this hits goals authored on either device — reminders silently never fire.
- **Fix:** Move the desktop per-goal reminder loop out of the 'if (habitReminders)' block so it runs whenever notifications are enabled and Focus Mode is off; keep only the Morning Brief (id=0) gated by habitReminders.
- **Mobile:** `mobile/lib/providers/settings_provider.dart:791-802; mobile/lib/providers/goal_provider.dart:173-181,219-227`
- **Desktop:** `desktop/lib/features/settings/data/desktop_notification_service.dart:127-146`

### #8 — [HIGH] auth-biometric — biometric lock never re-arms after first unlock

- **Differs:** Mobile's BiometricLockGate is a WidgetsBindingObserver: re-arms (unlocked=false) on background/pause and re-prompts on resume. Desktop's DesktopBiometricGate is a stateless ConsumerWidget with no lifecycle observer; once unlock() succeeds it stays unlocked for the whole process lifetime. Hiding/blurring the window, Mission Control, or sleep never re-locks.
- **Why it matters:** The lock protects only the very first app open, defeating the walk-away protection that is the feature's entire purpose. Not platform-limited — DesktopSyncLifecycle proves macOS delivers these lifecycle transitions.
- **Fix:** Make DesktopBiometricGate stateful with an AppLifecycleListener/WidgetsBindingObserver that sets unlocked=false on inactive/hidden/paused and re-prompts on resumed when biometric.enabled. The opaque app-switcher privacy cover is optional on macOS; the re-arm-on-background behavior is not.
- **Mobile:** `mobile/lib/ui/widgets/biometric_lock_gate.dart:106-127, 196-217`
- **Desktop:** `desktop/lib/features/settings/application/desktop_biometric_controller.dart:162-211; desktop/lib/app/evolve_desktop_app.dart:79`

### #9 — [MEDIUM] backup-import — verify_* verification config dropped by mobile's cloud import plan

- **Differs:** Mobile's planCloudImport goalsToWrite omits all five verify_* columns (provider/metric/comparator/threshold/unit); desktop's cloud plan includes them, and mobile's own private merge preserves them. Here desktop is the more-correct side.
- **Why it matters:** Importing a backup into CLOUD mode on mobile silently discards a habit's auto-verification rule (a verified goal becomes manual), while the same file on desktop preserves it. Divergent data handling on the verifiable-habits feature.
- **Fix:** Add the five verify_* fields to mobile planCloudImport's goalsToWrite to match desktop and mobile's own private path. (This is a mobile-side fix to reach parity.)
- **Mobile:** `mobile/lib/core/import_merge.dart:1090-1104`
- **Desktop:** `desktop/lib/core/import_merge.dart:528-532`

### #10 — [MEDIUM] data-mode / private-db — no on-disk recovery of Private mode when the mode pref is lost

- **Differs:** Mobile: if active_data_mode is absent but the encrypted private DB exists on disk, it restores active_data_mode=private (with a warning) so intact local data is queried. Desktop computes isPrivateMode = savedMode == private.name and, when null, silently falls through to Supabase with no databaseFileExists() fallback.
- **Why it matters:** A desktop Private-mode user whose NSUserDefaults entry is cleared (plist removed, migration) launches into a logged-out Supabase view; their intact encrypted habits appear gone with no in-app hint, until they manually re-switch in Settings.
- **Fix:** Add a static DesktopPrivateDb.databaseFileExists() (File(evolve_private_v2.db) under Application Support) and, in desktop/lib/main.dart before computing isPrivateMode, restore active_data_mode=private (with a warning log) when the pref is null but the DB file exists — mirroring mobile main.dart:58-64.
- **Mobile:** `mobile/lib/main.dart:58-64; mobile/lib/core/private_local_database.dart:47-54`
- **Desktop:** `desktop/lib/main.dart:24-25; desktop/lib/core/desktop_data_mode.dart:29-37`

### #11 — [MEDIUM] sync-service — automatic refresh-after-pull omits profile & goal-category providers

- **Differs:** Mobile's single invalidatePrivateDataProviders refreshes the full private surface (incl. userProfileProvider, settingsProvider, macroGoalCategoriesProvider) after every pull. Desktop's automatic pull paths refresh only dashboard + analytics; they never invalidate privateProfileProvider or desktopGoalCategoriesControllerProvider — yet desktop's OWN manual 'Sync now' button does, proving it's an unintended gap.
- **Why it matters:** After a launch/resume/periodic/after-write auto-pull, a cross-device edit to the user's name/DOB/avatar (shell header) or a goal category won't appear until the user hits 'Sync now' or restarts, whereas mobile surfaces them automatically.
- **Fix:** Extract one refreshPrivateAfterPull(ref) helper mirroring mobile's invalidatePrivateDataProviders and call it from every desktop pull path (DesktopSyncLifecycle._sync and the onLocalWrite hook), adding privateProfileProvider + desktopGoalCategoriesControllerProvider so the paths can't drift.
- **Mobile:** `mobile/lib/providers/sync_refresh.dart:15-35; mobile/lib/main.dart:386-393`
- **Desktop:** `desktop/lib/core/desktop_sync_lifecycle.dart:86-89; desktop/lib/main.dart:54-57; desktop/lib/features/settings/presentation/settings_page.dart:1487-1492 (manual path superset)`

### #12 — [MEDIUM] backup-import — profile/settings block restored on desktop import but ignored on mobile

- **Differs:** Desktop import overwrites the owner's profile + app settings (full_name, date_of_birth, theme_mode, language, etc. under an allow-list), including on MERGE imports. Mobile strips the profile block at normalization and never re-applies it (though it still exports one — a lossy round-trip).
- **Why it matters:** Importing the same backup behaves differently: a desktop merge-import can silently flip the active user's theme/language/name to the backup's values, which never happens on mobile. The desktop test even asserts theme_mode flips to 'dark' and full_name to 'Bob Mobile'.
- **Fix:** Pick one canonical behavior and align both: either add allow-listed profile/settings restore to mobile's import, or gate desktop's restore so a backup can't silently overwrite the active profile/theme on a merge import.
- **Mobile:** `mobile/lib/core/import_merge.dart:52-54; applyPrivateImportMerge (never touches profiles)`
- **Desktop:** `desktop/lib/core/desktop_private_db.dart:987-1002; desktop/lib/core/desktop_backup_import_service.dart:604-614`

### #13 — [MEDIUM] data-mode — enters Private mode without ensuring the DB is ready, no rollback on failure

- **Differs:** Mobile's startPrivateMode() sets loading state, calls ensureReady() (opens+seeds SQLCipher) BEFORE flipping the mode, and on any exception leaves the mode unchanged and surfaces an error. Desktop's enterPrivateMode() just flips the mode via setMode (persisted first) with no ensureReady, no try/catch, no loading state; the DB opens lazily on first access.
- **Why it matters:** If the lazy open fails (e.g. fail-closed key guard throws when the SQLCipher key is missing but the DB file exists), the app is already in Private mode — persisted across restarts — stuck on an empty dashboard showing only a generic sync-failed message, with no rollback and no explanation.
- **Fix:** In DesktopAuthController.enterPrivateMode, await DesktopPrivateDb.instance.database inside a try/catch and only enter Private mode on success; on failure stay in Supabase mode and show an error, mirroring mobile startPrivateMode.
- **Mobile:** `mobile/lib/providers/auth_provider.dart:296-313`
- **Desktop:** `desktop/lib/features/auth/application/auth_controller.dart:204-206; desktop/lib/features/auth/presentation/auth_page.dart:370-372`

### #14 — [MEDIUM] data-mode / notifications — 'delete private data' leaves per-habit reminders scheduled

- **Differs:** Mobile's private-data delete calls NotificationService().cancelAll() before wiping. Desktop's _deletePrivateData does requestFullReset + deleteAllPrivateData + dashboard refresh, none of which cancel or re-sync notifications, and startup never re-syncs either.
- **Why it matters:** After 'delete private data', previously-scheduled daily reminders for the now-deleted habits keep firing (with the deleted titles), even surviving restart, until the user next edits a habit or toggles a notification setting. Tapping their Done/Skip actions would re-write phantom logs.
- **Fix:** After deleteAllPrivateData() in _deletePrivateData, call _syncNotifications() with the now-empty habit list (or DesktopNotificationService.instance.sync / a cancelAll), matching mobile's cancelAll().
- **Mobile:** `mobile/lib/ui/screens/privacy_settings_screen.dart:1185`
- **Desktop:** `desktop/lib/features/settings/presentation/settings_page.dart:1560-1605`

### #15 — [MEDIUM] auth-biometric — no fail-open when biometrics are absent/unavailable (macOS lockout)

- **Differs:** Mobile checks getAvailableBiometrics().isNotEmpty and fail-opens (unlocked=true) when nothing is enrolled. Desktop only checks canCheckBiometrics || isDeviceSupported() then requires biometricOnly:true on macOS (device-credential fallback deliberately disabled), staying fail-closed on failure. applyProfile can even activate the gate from a synced cloud profile with no capability check.
- **Why it matters:** A Mac with no/unavailable Touch ID (Mac Mini/Studio, clamshell with external keyboard, hardware fault, or biometric_lock:true synced from the phone) gets stuck at a lock screen whose only control is an Unlock button that can never succeed — permanent lockout with no recourse.
- **Fix:** Before requiring biometricOnly auth, check getAvailableBiometrics and fail open when none exist (matching mobile), or allow device-credential fallback (biometricOnly:false) on macOS when biometrics are absent.
- **Mobile:** `mobile/lib/ui/widgets/biometric_lock_gate.dart:140-152`
- **Desktop:** `desktop/lib/features/settings/application/desktop_biometric_controller.dart:95-116`

### #16 — [MEDIUM] sync-secrets — synced-tier keychain writes lack the -25299 duplicate-item self-heal

- **Differs:** Mobile routes every synced-tier write (E2E key create/rotate, canonical owner publish) through _writeTo, which on a duplicate-item error (-25299) does a scoped delete(key)+rewrite. Desktop's DesktopSyncSecretStore.write is a bare _storage.write that logs and rethrows. Desktop already has this recovery for its default and device-local tiers — only the collision-prone synchronizable/shared-group store lacks it.
- **Why it matters:** A -25299 on the Mac (first-device key generation, or rotation) throws out of getOrCreateKeyReporting()/setCanonicalOwner() and aborts enabling sync, whereas mobile self-heals and continues.
- **Fix:** Add a writeSynced to desktop SecureStorageUtils mirroring mobile's _writeTo (scoped delete(key) then re-write on duplicate, never deleteAll) and have DesktopSyncSecretStore.write delegate to it.
- **Mobile:** `mobile/lib/core/secure_storage_utils.dart:125, 142-178`
- **Desktop:** `desktop/lib/core/desktop_sync_secret_store.dart:31-38`

### #17 — [MEDIUM] subscription-pro — no generic-entitlement fallback (post-purchase lockout risk)

- **Differs:** Mobile's evaluateProAccess resolves Pro over 4 tiers, ending in a fallback that grants Pro for ANY active entitlement (logging a warning). Desktop's _hasActiveProAccess implements only the first 3 and returns false otherwise. Whitelist constants are byte-identical on both.
- **Why it matters:** A user with an active-but-unwhitelisted RevenueCat entitlement (renamed/mis-whitelisted entitlement) is Pro on mobile but locked out on desktop after a legitimate purchase.
- **Fix:** Add the same final fallback (grant Pro if customerInfo.entitlements.active.isNotEmpty) with an equivalent warning log; ideally factor the shared evaluator into a package so both apps use one implementation.
- **Mobile:** `mobile/lib/core/subscription_service.dart:292-338, 400-412`
- **Desktop:** `desktop/lib/features/settings/application/desktop_subscription_controller.dart:214-222`

### #18 — [MEDIUM] subscription-pro — isPro never seeded from cache/server (offline cold-start lockout)

- **Differs:** Mobile hydrates isPro offline-first from cached pref_is_pro (secure storage + prefs mirror) and the Supabase profile is_pro column, seeded synchronously in build(). Desktop writes pref_is_pro but never reads it back and never consumes server is_pro; build() starts isPro=false and only flips it after an online Purchases.getCustomerInfo() succeeds.
- **Why it matters:** A paying desktop user who launches offline (or during a transient RevenueCat failure) is locked out of every Pro feature until a network round-trip succeeds. Self-heals once online, but real feature lockout in the meantime (Private mode is exempt).
- **Fix:** In build(), seed state.isPro from the persisted pref_is_pro (and/or synced profile is_pro) before the async refresh, so cached entitlement survives offline/cold starts like mobile.
- **Mobile:** `mobile/lib/providers/settings_provider.dart:269, 283, 444, 705`
- **Desktop:** `desktop/lib/features/settings/application/desktop_subscription_controller.dart:80-95, 224-227`

### #19 — [MEDIUM] subscription-pro — purchase/restore lack sync/invalidate retry and already-purchased auto-restore

- **Differs:** Mobile hardens purchase (on a not-Pro result: syncPurchases + invalidateCustomerInfoCache + refetch; productAlreadyPurchasedError → restore) and restore (invalidate + refetch fallback). Desktop reads entitlement once per flow and surfaces a generic 'purchase incomplete'/'no active sub' with no retry, and doesn't auto-restore an already-purchased product. Same purchases_flutter SDK on both.
- **Why it matters:** Right after a real purchase, desktop is materially more likely to return a false-negative 'not Pro' outcome than mobile, given RevenueCat's eventually-consistent CustomerInfo cache.
- **Fix:** Mirror mobile's fallbacks: on a not-Pro result after purchase, run syncPurchases + invalidateCustomerInfoCache then re-evaluate; handle productAlreadyPurchasedError by calling restore(); add the invalidate+refetch retry to restore().
- **Mobile:** `mobile/lib/core/subscription_service.dart:154-207, 215-243`
- **Desktop:** `desktop/lib/features/settings/application/desktop_subscription_controller.dart:121-147, 149-173`

### #20 — [MEDIUM] subscription-pro — no CustomerInfo update listener (stale live entitlement)

- **Differs:** Mobile installs a persistent Purchases.addCustomerInfoUpdateListener that re-syncs isPro on any RevenueCat push (renewal, expiry, cross-device purchase, billing lapse). Desktop registers no listener; isPro is recomputed only on auth change or an explicit refresh/purchase/restore. Same SDK major version on both.
- **Why it matters:** A subscription that expires or is purchased/renewed on another device mid-session stays stale on desktop until the user re-triggers a flow or restarts.
- **Fix:** Register an addCustomerInfoUpdateListener in _configure that recomputes state.isPro via _hasActiveProAccess (and persists), matching mobile's listener semantics.
- **Mobile:** `mobile/lib/core/subscription_service.dart:356-363, 103`
- **Desktop:** `desktop/lib/features/settings/application/desktop_subscription_controller.dart:97-119, 198-212`

### #21 — [MEDIUM] notifications — Snooze action is a dead no-op on desktop

- **Differs:** Both register a Snooze action and show the button. Mobile's Snooze reschedules the identical reminder for now+10min (id offset). Desktop maps 'snooze' to a null status and early-returns — no write and no reschedule — so the notification just dismisses and never re-alerts. Desktop already uses zonedSchedule elsewhere, so the capability exists.
- **Why it matters:** The Snooze affordance appears actionable but is functionally broken relative to mobile; tapping it silently does nothing.
- **Fix:** In desktop _onNotificationResponse, handle 'snooze' by calling zonedSchedule for the same goal at now+10min (id offset to avoid colliding with the daily id), mirroring mobile's _snoozeHabit; or remove the Snooze action if intentionally unsupported.
- **Mobile:** `mobile/lib/core/notifications.dart:131-136, 161-197`
- **Desktop:** `desktop/lib/features/settings/data/desktop_notification_service.dart:196-201`

### #22 — [MEDIUM] notifications — no 64 pending-notification cap guard on desktop

- **Differs:** macOS UNUserNotificationCenter caps pending requests at 64. Mobile guards each per-goal schedule with _canSchedule (counts pending, fails open, logs a warning on overflow). Desktop cancelAll+reschedules every sync with no guard. pendingNotificationRequests() is available on macOS.
- **Why it matters:** A user with ~62+ reminder-bearing habits has an unpredictable tail of reminders silently dropped by macOS on desktop, nondeterministically — mobile makes overflow deterministic and observable.
- **Fix:** Add a pending-count guard in desktop _scheduleDaily (or the sync loop) equivalent to mobile's _canSchedule, skipping with a logged warning once pending >= 64.
- **Mobile:** `mobile/lib/core/notifications.dart:423-431, 512-524`
- **Desktop:** `desktop/lib/features/settings/data/desktop_notification_service.dart:134-145, 158-184`

### #23 — [MEDIUM] notifications — no contextual notification-permission request on the habit add/edit path

- **Differs:** Mobile's scheduleHabitReminder calls requestPermissions() first, so setting a reminder while permission is undetermined triggers a prompt. Desktop schedules via _rescheduleNotifications → sync without ever requesting permission on that path; only Settings toggles and onboarding consent request it. Capability is wired (MacOsFlutterLocalNotificationsPlugin.requestPermissions exists).
- **Why it matters:** A user who skipped onboarding permission and then sets a per-goal reminder from the habit editor gets a prompt on mobile but silence on desktop — the reminder is registered but macOS won't deliver it while authorization is notDetermined.
- **Fix:** Have desktop request notification permission when a reminder is first scheduled from the habit add/edit flow (call requestPermissions() within sync()/_rescheduleNotifications when habits with reminderTime are being scheduled).
- **Mobile:** `mobile/lib/core/notifications.dart:392-393, 329, 360`
- **Desktop:** `desktop/lib/features/settings/data/desktop_notification_service.dart:158-184; desktop/lib/features/dashboard/application/dashboard_controller.dart:217-238`

### #24 — [MEDIUM] auth — no invalid/expired-session recovery on the auth-state subscription

- **Differs:** Mobile registers onError on onAuthStateChange and, on a stale persisted session (refresh_token_not_found / 'invalid refresh token' / 'session expired' / 'current session is missing data'), forces a local signOut and clears state so the app lands cleanly on /login. Desktop's .listen() passes only onData — no onError, no invalid-refresh-token detection.
- **Why it matters:** Note: the verify pass found the functional recovery still happens on desktop via gotrue's deterministic signedOut event, so this is NOT a broken-half-authenticated-state bug. The residual difference is that desktop leaves that stream's error to the zone and doesn't log it — a defensive/logging redundancy gap, not a functional divergence. Included as a low-priority hardening item; the auditor's 'broken state' framing was overstated.
- **Fix:** Optional hardening: add an onError handler to the desktop onAuthStateChange subscription mirroring mobile's _isInvalidPersistedSession (log + explicit signOut), so stale-session handling is defensive-in-depth rather than relying solely on the signedOut event.
- **Mobile:** `mobile/lib/providers/auth_provider.dart:151-181`
- **Desktop:** `desktop/lib/features/auth/application/auth_controller.dart:59-67`

### #25 — [MEDIUM] verification — verified habits are visually indistinguishable from manual ones on desktop

- **Differs:** A habit with a verificationRule syncs to desktop and is faithfully loaded (VerificationRule.fromColumns) but never read by any desktop presentation code. Mobile shows a VerificationBadge ('Auto-verified') and a distinct 'Couldn't verify' state; desktop renders a verified habit identically to a manual one — no badge, label, or explanation. The domain model's own comment even promises a read-only badge.
- **Why it matters:** A verified habit created on iPhone looks pixel-identical to a manual habit on macOS, with no indication of why it behaves differently. Affordance gap on the verifiable-habits feature (the data itself is preserved correctly).
- **Fix:** Add a read-only 'auto-verified' badge/label wherever habits render on desktop (dashboard_page, habits_page), gated on habit.verificationRule != null, with copy explaining verification happens on iPhone — fulfilling the promise already in the code comment.
- **Mobile:** `mobile/lib/ui/widgets/verification_rule_field.dart:121-138; mobile/lib/models/goal.dart:34`
- **Desktop:** `desktop/lib/features/dashboard/data/private_dashboard_repository.dart:464; desktop/lib/features/dashboard/domain/dashboard_models.dart:48-51 (no UI reads it)`

### #26 — [MEDIUM] private-db — seedProfile omits language, persisting 'it' vs mobile's 'system' in a synced table

- **Differs:** Mobile's _ensureProfile seeds language:'system'; desktop's seedProfile writes no preference columns so profiles.language falls to schema DEFAULT 'it'. profiles is a synced table with dirty-marking triggers, and the first-launch seed is queued for CloudKit push with no bookkeeping reset.
- **Why it matters:** A desktop-seeded 'it' can propagate via last-write-wins and flip a mobile user's language setting (which reads profiles.language directly) from system/auto to Italian. (The auditor's desktop-dropdown symptom was imprecise; the material symptom is on the mobile side via first-launch sync.)
- **Fix:** In DesktopPrivateDb.seedProfile, set language:'system' (and defensively the other preference columns mobile seeds) so the seeded/synced profile row matches mobile exactly.
- **Mobile:** `mobile/lib/core/private_local_database.dart:312`
- **Desktop:** `desktop/lib/core/desktop_private_db.dart:598-602; packages/evolve_sync/lib/src/private_db_schema.dart:195`

### #27 — [MEDIUM] avatar-store — ImageCache not evicted after replacing the avatar file

- **Differs:** Both write a picked avatar to the stable path private_profile/avatar.<ext>. Mobile calls FileImage(...).evict() before updating the profile so the UI re-reads the new bytes. Desktop's _pickAvatar performs no eviction, and both display sites key FileImage purely on the file path (cache key = path+scale, unchanged after in-place overwrite).
- **Why it matters:** Re-picking a same-extension avatar leaves the OLD decoded bytes in Flutter's global ImageCache; the settings avatar and shell header keep showing the previous photo until cache pressure or restart. Cosmetic staleness, not data loss.
- **Fix:** In desktop _pickAvatar, after copying into private_profile and before updateAvatar, call await FileImage(selectedFile).evict() (and evict the previous path if the extension differs), mirroring mobile profile_screen.dart:88.
- **Mobile:** `mobile/lib/ui/screens/profile_screen.dart:88`
- **Desktop:** `desktop/lib/features/settings/presentation/settings_page.dart:897`

### #28 — [LOW] verification — desktop manual check-in of a synced verified habit is not freeze-protected

- **Differs:** Mobile writes both the goal_log AND a device-local manual-freeze marker so its reconcile engine won't clobber the user's answer with HealthKit data. Desktop has no verification_state store, so it writes only the synced log. The verify pass ruled this platform-justified (the freeze store is unsynced by design D8, macOS genuinely can't verify, and the residual clobber risk is a property of the shared D8 store, existing mobile-to-mobile too).
- **Why it matters:** When a desktop-written log later syncs to an iPhone, the day arrives at the shared engine with manual:false and is eligible for re-evaluation — a desktop user's override of an auto-verified habit is durably weaker. But this is a shared-design limitation surfacing through a platform that correctly cannot verify, not a desktop implementation gap.
- **Fix:** Accept as a documented consequence of D8, OR for full coherence move the 'manual wins' invariant into synced data in the shared engine (not desktop-side). At minimum document that verified-habit overrides should be done on the iPhone. Included only for completeness; not a desktop parity fix.
- **Mobile:** `mobile/lib/providers/goal_provider.dart:586, 678-692`
- **Desktop:** `desktop/lib/features/dashboard/application/dashboard_controller.dart (setHabitStatus; no verification_state store)`

### #29 — [LOW] subscription-pro — custom accent color free on desktop, Pro-gated on mobile

- **Differs:** Mobile exposes only 3 free preset accents and Pro-locks the custom color cell. Desktop's accent picker offers all 7 presets plus a '+' swatch opening a full custom picker, with no isPro check. Not among desktop's four advertised Pro features, so lower monetization impact.
- **Why it matters:** Free desktop users get unlimited custom accents that mobile gates behind Pro — a mobile Pro gate absent on desktop.
- **Fix:** Decide the intended policy; if parity is desired, gate the custom '+' swatch (and extra presets) behind desktopIsProProvider with a showProFeaturesDialog fallback, matching app_settings_screen.dart:531-540.
- **Mobile:** `mobile/lib/ui/screens/app_settings_screen.dart:520-546`
- **Desktop:** `desktop/lib/features/settings/presentation/settings_page.dart:362-383, 2326-2401`

### #30 — [LOW] auth-biometric — cold-start lock requires a manual Unlock click; mobile auto-prompts

- **Differs:** Mobile fires the biometric prompt automatically on the first frame after cold start (and on resume). Desktop's DesktopBiometricGate only renders a lock screen with a button the user must click to invoke unlock() — no post-frame auto-prompt.
- **Why it matters:** Users see an extra manual step on every launch with the lock enabled, versus mobile's immediate Face/Touch ID sheet.
- **Fix:** Trigger unlock() automatically when the gate first renders in the locked state (stateful gate with addPostFrameCallback), matching mobile's auto-prompt-on-appear. Naturally folded into the re-arm fix (rank 8).
- **Mobile:** `mobile/lib/ui/widgets/biometric_lock_gate.dart:88-93, 116-121`
- **Desktop:** `desktop/lib/features/settings/application/desktop_biometric_controller.dart:168-211`

### #31 — [LOW] sentry-privacy — placeholder DSN treated as configured; tracesSampleRate defaults to 1.0

- **Differs:** Desktop's DSN falls back to a hardcoded placeholder (sentry.io/12345) and isConfigured returns true for it, so a non-private build with consent but no EVOLVE_SENTRY_DSN still calls SentryFlutter.init against a bogus project. tracesSampleRate defaults to 1.0 (100% sampling) vs mobile's 0.0 stub / 0.2 example.
- **Why it matters:** Config/robustness divergence — the placeholder can't deliver events (invalid project), and 100% transaction sampling if unset is a cost/behavior difference. Depends on build-time defines.
- **Fix:** Treat the placeholder DSN as unconfigured (isConfigured should reject the default_placeholder value) so Sentry stays off without a real DSN, and align the default tracesSampleRate with mobile's production value.
- **Mobile:** `mobile/lib/core/sentry_config.dart:6, 8`
- **Desktop:** `desktop/lib/core/desktop_sentry_service.dart:8-18, 22`

### #32 — [LOW] private-db — no re-seed-on-read safeguard for a missing profiles row

- **Differs:** Mobile's loadProfileRow recreates the owner profile row and retries if it's ever missing. Desktop's profile readers return defaults/empty when the row is absent, with seeding only in _open() and after a wipe.
- **Why it matters:** Defensive-only: the profiles row is seeded on every open and is the FK parent for all data, so it effectively always exists within a session. Not a live bug.
- **Fix:** Optional: have desktop profile reads fall back to seedProfile + re-read when the owner row is unexpectedly missing, matching mobile's self-healing read path.
- **Mobile:** `mobile/lib/core/private_local_database.dart:714-717`
- **Desktop:** `desktop/lib/core/desktop_private_db.dart:288-300, 426-435`

## Platform-justified differences (safe to leave as-is)

- **private-db lifecycle (wipe, fail-closed key guard, backup exclusion, FK PRAGMA, open serialization):** These are equivalent: children-before-parents wipe + re-seed + sync-bookkeeping reset preserving pending_zone_wipe, fail-closed key guard refusing to mint a new key when the DB file exists, whole-Application-Support backup exclusion, foreign_keys=ON per-connection, and serialized concurrent opens. Desktop's extra close()/isOpen guard and the differing local DB filename are appropriate and don't affect the shared sync format. No action needed.
- **sync-service core semantics (locking, account gating, zone-wipe, owner re-key, backoff/retry, error swallowing):** Parity by construction — both apps wire the shared CloudKitPrivateSyncService with equivalent dependencies. The only wiring differences are the correct platform gate (isIOS vs isMacOS) and desktop's extra prefs==null → NoOp guard for tests (safe: sync stays off). Desktop's added launch + 15-min periodic sync triggers are a justified superset: a Mac sits open-and-idle with few resume events, unlike a constantly-backgrounded phone. All triggers funnel through the same mode-gated _sync and no-op safely outside Private mode.
- **sync-secret store — no legacy tier on desktop; synced-tier keychain config:** Desktop correctly has no MigratingSyncSecretStore: mobile's legacy tier exists only to migrate mobile's own pre-1.0.10 secrets from its default keychain group, which no other app (including the iPhone) could read anyway. Cross-device sharing is unaffected — a 1.0.10+ iPhone heals its key into the shared kSyncKeychainAccessGroup that the Mac reads. The synced-tier config (shared access group 8528AN28A3.com.simo.evolve.sync, synchronizable:true, first_unlock, matching entitlements) is at full parity.
- **verification engine absence on desktop (reconcile, HealthKit/ScreenTime bridges, could-not-verify pipeline, nudge/celebration notifications, rule authoring):** Correctly absent — macOS has no HealthKit or ScreenTime/DeviceActivity, so there is genuinely nothing to auto-verify. VerificationRule round-trip preservation IS correctly implemented (a Mac edit cannot wipe an iOS-set rule), and rule creation is correctly omitted from desktop habit dialogs. Only the missing 'auto-verified' badge (ranked above) needs addressing so the silence is explained rather than looking broken.
- **streaks (streak_utils.dart) — byte-for-byte identical:** A literal diff returns IDENTICAL (both 99 lines): signed-streak handling, gap/miss break logic, local-calendar day boundaries, frequency_days intentionally unconsulted, pending-anchor look-back, startDate lower bound, and the safety cap all match. Every caller feeds computeStreak equivalently with the same zero-padded yyyy-MM-dd map keys. Only latent note: the file is hand-duplicated rather than shared — a CI diff-check would prevent future drift (process improvement, not a defect).
- **analytics-stats — private analytics formula parity:** The 9 core stat functions, habit/mood correlations, and macro-goal stats are faithfully ported with identical formulas, rounding, and enum-token mapping. The remaining asymmetries (canonicalBestHabitsTimeframe non-_short token mapping, mood/log date-key construction, habit_stats user_id='', mood/energy null-handling) are all currently unreachable given the actual UI tokens and NOT NULL constraints — latent robustness notes, not live divergences. Optional: align the two canonicalizers verbatim to prevent future drift.
- **auth — Sign in with Apple native path; session persistence; runtime Supabase→Private Sentry close:** Native Sign in with Apple is functionally identical (rawNonce → sha256 → getAppleIDCredential → signInWithIdToken → best-effort updateUser). Desktop's OAuth loopback fallback is a legitimate accommodation for environments without native Apple auth. Session token is stored under the same supabasePersistSessionKey (restore is parity by construction; the default keychain accessibility difference is a reasonable platform default). Desktop closing Sentry on runtime switch into Private mode is a privacy-POSITIVE divergence (stricter than mobile) — do not regress it.
- **notifications — background isolate / offline-queue is iOS-only by necessity:** iOS can deliver a notification action while the app is terminated (background isolate, no restored Supabase session), hence mobile's isolate bootstrap and enqueue/replay queue. macOS is a single long-lived process, so its action callback always runs in the app isolate with the authenticated client available — a direct foreground write + onLocalWrite refresh is the correct equivalent. Timezone init, payload format, Private-vs-Cloud routing, and streak recomputation are all at parity. Minor cosmetic differences (rotating reminder messages vs static body, '•' vs '-' separator, isBefore vs !isAfter equality boundary) are negligible.
- **subscription-pro — paywall & manage-subscription mechanism; aiSuggestions gate:** Mobile uses RevenueCat's cloud-configured native paywall/Customer Center (purchases_ui_flutter, iOS/Android only); desktop renders its own in-app paywall and routes management to the Apple account URL — same underlying purchases_flutter engine, product IDs, and appUserID. The aiSuggestions toggle is correctly Pro-gated on both. (The ungated desktop AI Coach page is a desktop-internal advertised-vs-ungated inconsistency with no mobile counterpart — worth confirming intent with the owner, but not a mobile→desktop parity gap.)

## Quick wins

- goal_logs.value: add 'value': l['value'] in desktop _processData (~285), applyImport INSERT (~885) and UPDATE (~899), and exportSnapshot habitLogs (216-227) — a faithful port fixing the failing round-trip test and the export loss (rank 1).
- seedProfile: set language:'system' in DesktopPrivateDb.seedProfile:598-602 to match mobile and stop 'it' propagating via sync (rank 26).
- delete-private-data: call _syncNotifications() with the empty habit list after deleteAllPrivateData() in settings_page.dart:1560-1605 to cancel orphaned reminders (rank 14).
- Per-goal reminders: move the desktop reminder loop out of the 'if (habitReminders)' block in desktop_notification_service.dart:127-146 so it fires like mobile (rank 7).
- Avatar cache: add await FileImage(selectedFile).evict() in desktop _pickAvatar before updateAvatar (settings_page.dart:897) (rank 27).
- On-disk Private-mode recovery: add static DesktopPrivateDb.databaseFileExists() + a null-pref-and-file-exists restore in desktop/lib/main.dart, mirroring mobile main.dart:58-64 (ranks 4-adjacent, rank 10).
- 5-habit gate: add the !desktopIsProProvider && count>=5 check + showProFeaturesDialog in dashboard_controller.addHabit, reusing the existing 100-goal gate pattern (rank 5).
- Per-habit stats gate: guard the scope switch in statistics_page.dart:213-230 with desktopIsProProvider + showProFeaturesDialog (rank 6).
- Generic-entitlement fallback: add the 4th-tier 'any active entitlement → Pro' branch (with warning log) to _hasActiveProAccess (rank 17).
- isPro cache seed: read the already-written pref_is_pro in desktop_subscription_controller.build() before the async refresh (rank 18).
- Placeholder DSN: make isConfigured reject the default_placeholder value and lower the default tracesSampleRate to match mobile (rank 31).
- Sync-secret self-heal: add a writeSynced with scoped -25299 delete(key)+rewrite to desktop SecureStorageUtils and delegate DesktopSyncSecretStore.write to it (rank 16).
