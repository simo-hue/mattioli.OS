import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../i18n/translations.g.dart';
import '../providers/auth_provider.dart';
import '../providers/consent_provider.dart';
import '../providers/goal_provider.dart';
import 'data_mode.dart';
import 'navigator_key.dart';
import 'private_local_database.dart';
import 'secure_local_storage.dart';
import 'streak_utils.dart';
import 'supabase_config.dart';
import 'targets_config.dart';
import 'verification_config.dart';
import 'verification_state_store.dart';
import 'verification_wiring.dart';
import 'app_logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      final dynamic timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo is String
          ? timeZoneInfo
          : timeZoneInfo.identifier;

      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e, stack) {
        AppLogger.error(
          'Failed to set local location, falling back to UTC',
          e,
          stack,
        );
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Define iOS category with actions
      final List<DarwinNotificationCategory> darwinCategories = [
        DarwinNotificationCategory(
          'habit_actions',
          actions: <DarwinNotificationAction>[
            // Done/Skip write to the data store. iOS only guarantees enough
            // background runtime for a notification action when it's marked
            // .foreground, so these bring the app forward to persist reliably
            // (NOTIF-2). The NOTIF-1 queue still covers any background path.
            DarwinNotificationAction.plain(
              'action_done',
              t.notifications.actionDone,
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            // Snooze only reschedules a local notification — no write, so it
            // stays a background action and doesn't launch the app.
            DarwinNotificationAction.plain(
              'action_snooze',
              t.notifications.actionSnooze,
            ),
            DarwinNotificationAction.plain(
              'action_skip',
              t.notifications.actionSkip,
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.customDismissAction,
          },
        ),
      ];

      final DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            // Defer the permission prompt: don't ask at app launch. Permission
            // is requested contextually when the user actually enables a
            // reminder (see requestPermissions() calls in the schedule* methods
            // and the notification settings toggles) — NOTIF-3.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            notificationCategories: darwinCategories,
          );

      final InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
    } catch (e, stack) {
      AppLogger.error('Error initializing NotificationService', e, stack);
    }
  }

  void _onNotificationResponse(NotificationResponse response) async {
    // Never log the payload: it carries the habit title, which is free-text
    // user content. Console output only in debug (SEC-8).
    if (kDebugMode) {
      debugPrint('[Notifications] Response action: ${response.actionId}');
    }

    final payload = response.payload;
    if (payload == null) return;

    final parts = payload.split('|');
    if (parts.length < 2) return;

    final type = parts[0];
    final habitId = parts[1];

    if (type != 'habit') return;

    if (response.actionId == 'action_done') {
      await _markHabitAsDone(habitId);
      _refreshHabitProvidersAfterWrite();
    } else if (response.actionId == 'action_snooze') {
      // Snooze only reschedules a notification — no data write, no refresh.
      await _snoozeHabit(
        habitId,
        parts.length > 2 ? parts[2] : t.notifications.habitFallbackTitle,
      );
    } else if (response.actionId == 'action_skip') {
      await _skipHabit(habitId);
      _refreshHabitProvidersAfterWrite();
    }
  }

  /// After a notification-driven habit write, refresh the in-memory providers
  /// so the foreground dashboard reflects the change immediately rather than
  /// staying stale until the next rebuild. Mirrors the invalidation
  /// `goal_provider.cycleStatus` performs. Runs only when a foreground UI
  /// exists: in the background isolate and on a cold-start tap the global
  /// navigator context is null, so this no-ops and the providers load fresh.
  void _refreshHabitProvidersAfterWrite() {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    container.invalidate(habitLogsProvider);
    container.invalidate(habitStatsProvider);
    // A Done/Skip from a reminder also writes the D9 manual freeze
    // (`_freezeManualForToday`), so the day's "set by you" marker has just
    // become true. Without this the chip does not appear until something else
    // happens to invalidate its provider — the freeze would be exactly as
    // invisible as it was before the marker existed, for the one write path
    // that creates it outside the UI.
    container.invalidate(manuallyResolvedDaysProvider);
    container.invalidate(couldNotVerifyDaysProvider);
  }

  Future<void> _markHabitAsDone(String habitId) async {
    await _writeHabitLogFromNotification(habitId, 'done');
  }

  Future<void> _snoozeHabit(String habitId, String title) async {
    final now = DateTime.now();
    final scheduledDate = now.add(const Duration(minutes: 10));

    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      t.notifications.habitChannelName,
      channelDescription: t.notifications.habitChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('action_done', t.notifications.actionDone),
        AndroidNotificationAction(
          'action_snooze',
          t.notifications.actionSnooze,
        ),
        AndroidNotificationAction('action_skip', t.notifications.actionSkip),
      ],
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(categoryIdentifier: 'habit_actions'),
    );

    await _notifications.zonedSchedule(
      id: habitId.hashCode + 1000,
      title: 'Evolve • $title',
      body: _getHabitMessage(title),
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'habit|$habitId|$title',
    );
    if (kDebugMode) {
      debugPrint('[Notifications] Habit $habitId snoozed for 10 minutes');
    }
  }

  /// Skip only dismisses the current occurrence — the OS already clears the
  /// delivered banner when an action is tapped. Never cancel `habitId.hashCode`
  /// here: that is the id of the *recurring* reminder registered by
  /// [scheduleHabitReminder], and cancelling it removes the whole repeating
  /// request (iOS) / the alarm and its restore-on-boot record (Android).
  Future<void> _skipHabit(String habitId) async {
    await _writeHabitLogFromNotification(habitId, 'missed');
  }

  /// Persist a habit log triggered by a notification action.
  ///
  /// Private Mode writes locally (always available). Cloud mode writes to
  /// Supabase; if there's no restored session yet (cold background isolate) or
  /// the write fails (e.g. offline), the action is queued and replayed on the
  /// next foreground via [replayPendingHabitLogs] (NOTIF-1).
  Future<void> _writeHabitLogFromNotification(
    String habitId,
    String status,
  ) async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // A notification Done/Skip is a MANUAL resolution — record the same D9
    // manual freeze that goal_provider.cycleStatus does, so a later foreground
    // reconcile leaves it alone instead of overwriting it with an auto verdict
    // for an auto-verified habit (NOTIF/verification-provenance bug). Done first
    // and awaited so the freeze survives even a cold background isolate being
    // torn down right after the log write.
    await _freezeManualForToday(habitId, status);

    if (await _isPrivateMode()) {
      try {
        // Compute the streak from history so a notification Done/Skip matches
        // the foreground toggle (Private analytics read the stored streak).
        await PrivateLocalDatabase().setHabitLogWithStreak(
          goalId: habitId,
          date: dateKey,
          status: status,
        );
        if (kDebugMode) {
          debugPrint('[Notifications] Private habit $habitId set to $status');
        }
      } catch (e, stack) {
        AppLogger.error(
          '[Notifications] Error writing private habit log',
          e,
          stack,
        );
      }
      return;
    }

    // Read through the seam, not `Supabase.instance` directly: the default is
    // exactly that, but without it nothing below is reachable from a test.
    final userId = currentUserId();
    if (userId == null) {
      // No restored session yet — queue and replay when the app foregrounds.
      await _enqueuePendingLog(habitId, dateKey, status);
      return;
    }

    // DURABLE FIRST. The queue entry is written BEFORE any network call and
    // removed only once the server has the row.
    //
    // The order matters because this runs in a notification-action background
    // isolate the OS may reclaim at any moment, and the write is no longer a
    // single round trip: resolving the streak reads the goal and its history
    // first. If the isolate died during that, a version that queued only from
    // the catch below would leave NO server row and NO queue entry — the user's
    // tap gone, having tapped Done and watched the banner dismiss. A redundant
    // queue entry costs one idempotent re-upsert on the next foreground; a lost
    // one cannot be recovered at all.
    await _enqueuePendingLog(habitId, dateKey, status);

    try {
      final streak = await _boundedStreak(habitId, dateKey, status);
      if (streak == null) {
        // Never a silent cap: the replay logs its skipped count, and so does
        // this path. A null here means the resolution timed out or could not be
        // established, so the row lands on the column's default.
        AppLogger.warning(
          '[Notifications] $habitId/$dateKey written without a recomputed '
          'streak (timed out or unresolvable)',
        );
      }
      await logUpserter(
        goalLogUpsertPayload(
          userId: userId,
          goalId: habitId,
          dateKey: dateKey,
          status: status,
          streak: streak,
        ),
      );
      await _dequeuePendingLog(habitId, dateKey, status);
      if (kDebugMode) {
        debugPrint('[Notifications] Habit $habitId set to $status');
      }
    } catch (e, stack) {
      // Deliberately no re-queue: the entry is already there, and it stays.
      AppLogger.error('[Notifications] Error writing habit log', e, stack);
    }
  }

  /// Test seam for [_freezeManualForToday]: opens the local verification store.
  /// Defaults to the shared, key-free opener (usable in any isolate); tests
  /// override it with an in-memory store.
  @visibleForTesting
  static Future<VerificationStateStore> Function() verificationStoreOpener =
      SqfliteVerificationStateStore.open;

  /// Freezes TODAY as a manual resolution in the local verification store, so a
  /// later foreground reconcile treats a notification-driven Done/Skip exactly
  /// like an in-app check-in and never overwrites it (D9 parity with
  /// `goal_provider.cycleStatus`).
  ///
  /// The freeze is recorded for every check-in regardless of the habit's own
  /// verified flag: the reconcile only ever queries manual days for the CURRENT
  /// verifiable goals (see `VerificationController.reconcile`), so a freeze on a
  /// plain habit is harmless dead data — which lets this path skip loading the
  /// goal (a Supabase round-trip) just to read `isVerified`. Gated on
  /// [VerificationConfig.enabled] so it is inert when the feature is dark, and
  /// fully try-caught so a store failure can never break the habit-log write.
  Future<void> _freezeManualForToday(String habitId, String status) async {
    if (!VerificationConfig.enabled) return;
    try {
      final store = await verificationStoreOpener();
      final now = DateTime.now();
      // Carry the status. This path is exactly the one that made a bare freeze
      // dangerous: on success it upserts STRAIGHT TO THE SERVER and queues
      // nothing, so a stale in-memory map presents identically to a write that
      // never landed. With the verdict recorded, reconcile restores the user's
      // answer instead of having to tell those two apart.
      await store.markManual(
        habitId,
        DateTime(now.year, now.month, now.day),
        status: status,
      );
    } catch (e, stack) {
      AppLogger.error('[Notifications] manual-freeze write failed', e, stack);
    }
  }

  /// Test seam for the queue replay's server write, mirroring
  /// [verificationStoreOpener].
  ///
  /// Without it the cloud branch of `_replayPendingHabitLogs` is unreachable
  /// from any test — every case stops at the Private-mode short-circuit or the
  /// null-session return. That mattered: the 23503 drop decides whether a
  /// user's tapped Done is retried or discarded forever, and inverting the
  /// branch (dropping the RETRYABLE errors instead) would have shipped green.
  @visibleForTesting
  static Future<void> Function(Map<String, Object?> row) logUpserter =
      _defaultLogUpsert;

  static Future<void> _defaultLogUpsert(Map<String, Object?> row) => Supabase
      .instance
      .client
      .from('goal_logs')
      .upsert(row, onConflict: 'goal_id, date');

  /// How long a single streak resolution may take before the write proceeds
  /// without it. This runs inside the notification-action background isolate,
  /// where the OS budget is short and finite: an unbounded read could consume
  /// the whole of it and the isolate be suspended before `logUpserter` is ever
  /// reached — leaving no server row AND no queue entry, which loses the user's
  /// tap outright. Degrading to a missing streak is the strictly safer failure.
  /// Mutable so a test can pin the degrade-on-stall behaviour without a
  /// six-second test. Note the replay's overall budget is checked BEFORE a
  /// resolution starts, so the true worst case there is that budget plus one
  /// of these.
  @visibleForTesting
  static Duration kStreakResolveTimeout = const Duration(seconds: 6);

  /// Total time one [replayPendingHabitLogs] run may spend recomputing
  /// streaks, across all its entries. See the loop for why. Mutable so a test
  /// can drive the exhausted-budget branch, which is otherwise unreachable
  /// without a 15-second test.
  @visibleForTesting
  static Duration kReplayStreakBudget = const Duration(seconds: 15);

  /// The `goal_logs.streak` value a notification-driven cloud write should
  /// carry, or null when it cannot be established.
  ///
  /// The Private branch of [_writeHabitLogFromNotification] computes this
  /// (`PrivateLocalDatabase.setHabitLogWithStreak`) so a notification Done/Skip
  /// matches the foreground toggle — since `ee6777e` (2026-06-23), which fixed
  /// exactly this bug on that side: "a notification action could zero out a
  /// user's visible streak". The cloud branch was not fixed with it, and the
  /// column it left unset is the one the `habit_stats` view reads
  /// (schema.sql) — while `runStreakRepairOnce` (main.dart) is Private-mode
  /// only, so nothing ever recomputed it for an account. Answering a reminder
  /// from the lock screen therefore degraded that habit's statistics
  /// permanently. Same seam shape as [logUpserter], and for the same reason:
  /// without it this branch is unreachable from any test.
  @visibleForTesting
  static Future<int?> Function(String goalId, String dateKey, String status)
  cloudStreakResolver = _defaultCloudStreak;

  /// [cloudStreakResolver], bounded by [kStreakResolveTimeout].
  ///
  /// The re-wrap is load-bearing, not style. A resolver whose body returns a
  /// non-null int hands back a `Future<int>` at RUNTIME even though the seam's
  /// static type is `Future<int?>`, and `Future.timeout` type-checks its
  /// `onTimeout` callback against that runtime type argument — so calling
  /// `.timeout(..., onTimeout: () => null)` on it throws a TypeError, which the
  /// replay then treats as a failed write. Constructing a genuine `Future<int?>`
  /// first is what makes the timeout applicable at all.
  ///
  /// A THROW still propagates: the caller decides what a failure means, and for
  /// the replay that is "keep the entry queued and retry".
  static Future<int?> _boundedStreak(
    String goalId,
    String dateKey,
    String status,
  ) => Future<int?>(
    () => cloudStreakResolver(goalId, dateKey, status),
  ).timeout(kStreakResolveTimeout, onTimeout: () => null);

  /// Mirrors `PrivateLocalDatabase.setHabitLogWithStreak` step for step: load
  /// the habit's history, apply the day being written in-memory so
  /// [computeStreak] sees the toggled status, then score it.
  ///
  /// ABSENCE IS NOT EVIDENCE — the same rule the Private writer states. Any
  /// failure (missing goal, unreadable history, offline) returns null, and
  /// [goalLogUpsertPayload] omits the column rather than sending it. On the
  /// ON CONFLICT path that PRESERVES a stored streak instead of overwriting a
  /// correct value with a fabrication. On a fresh INSERT the column takes its
  /// schema default of 0 (schema.sql) — no worse than before this resolver
  /// existed, which is the honest claim: a failure here restores the old
  /// behaviour, it does not improve on it. The status write itself must never
  /// be lost to a failure in this cache.
  static Future<int?> _defaultCloudStreak(
    String goalId,
    String dateKey,
    String status,
  ) async {
    try {
      final client = Supabase.instance.client;
      final goal = await client
          .from('goals')
          .select('start_date, frequency_days')
          .eq('id', goalId)
          .maybeSingle();
      if (goal == null) return null;
      final startDate = DateTime.tryParse('${goal['start_date']}');
      if (startDate == null) return null;

      // The habit's ENTIRE history, through the same helper `_syncFromSupabase`
      // uses. A streak computed from a truncated history is wrong in the one
      // direction that matters — too short — and would then be written back
      // over the correct value.
      //
      // ORDERED, for the reason every other paged read in this repo states:
      // LIMIT/OFFSET over an unordered relation has no stability guarantee, so
      // page 2 may repeat rows from page 1 and skip others. A skipped day
      // inside the current run reads as pending, breaks computeStreak's
      // backward walk, and the too-short value is written back OVER the correct
      // one. `(goal_id, date)` is UNIQUE (schema.sql), and this read is already
      // filtered to one goal, so `date` alone is a total order here.
      final logs = await fetchGoalLogsPaginated((offset, limit) async {
        final page = await client
            .from('goal_logs')
            .select('goal_id, date, status')
            .eq('goal_id', goalId)
            .order('date', ascending: true)
            .range(offset, offset + limit - 1);
        return List<Map<String, dynamic>>.from(page);
      });
      // The day being written is not on the server yet (or still holds its old
      // status), so apply it before scoring.
      (logs[dateKey] ??= <String, String>{})[goalId] = status;

      final parsedDate = DateTime.tryParse(dateKey);
      if (parsedDate == null) return null;

      return computeStreak(
        habitId: goalId,
        date: parsedDate,
        logs: logs,
        startDate: startDate,
        frequencyDays: _frequencyDaysFrom(goal['frequency_days']),
      );
    } catch (e, stack) {
      AppLogger.warning(
        '[Notifications] streak not resolved for $goalId/$dateKey — the '
        'status is still written and the stored streak left alone',
        e,
        stack,
      );
      return null;
    }
  }

  /// `frequency_days` arrives as a JSON list from PostgREST (the column is
  /// `integer[]`). Absent, null or empty means "every day" — the same encoding
  /// `Goal.fromJson` and `computeStreak` agree on. It diverges from
  /// `Goal.fromJson` in one unreachable case: a non-int element is dropped here
  /// and throws there. Dropping a weekday would make it transparent to
  /// `computeStreak` and over-count the run, so if that ever becomes reachable
  /// this must throw too rather than guess.
  static List<int>? _frequencyDaysFrom(Object? raw) {
    if (raw is! List) return null;
    final days = <int>[];
    for (final d in raw) {
      final n = d is int ? d : int.tryParse('$d');
      if (n != null) days.add(n);
    }
    return days.isEmpty ? null : days;
  }

  /// Test seam for the session check that gates the replay's cloud branch.
  /// Paired with [logUpserter]: without both, the branch cannot be entered at
  /// all from a test, because reaching for `Supabase.instance` throws when the
  /// SDK was never initialised.
  @visibleForTesting
  static String? Function() currentUserId = _defaultCurrentUserId;

  static String? _defaultCurrentUserId() =>
      // "Not initialised" is a real, reachable state now that startup defers the
      // SDK until consent is answered — and the honest answer to "who is signed
      // in?" is nobody. Reading `Supabase.instance` regardless would throw out of
      // an `async void` notification handler, escape to the global
      // `PlatformDispatcher.onError`, and pop the "something went wrong" modal
      // over the consent screen. Returning null instead queues the tap, which is
      // what the no-session path already does.
      isSupabaseInitialized
      ? Supabase.instance.client.auth.currentUser?.id
      : null;

  /// Restores the notification write seams to their production
  /// implementations. [cloudStreakResolver] serves the direct write too,
  /// not only the replay.
  @visibleForTesting
  static void resetTestSeams() {
    logUpserter = _defaultLogUpsert;
    currentUserId = _defaultCurrentUserId;
    cloudStreakResolver = _defaultCloudStreak;
    kReplayStreakBudget = const Duration(seconds: 15);
    kStreakResolveTimeout = const Duration(seconds: 6);
  }

  static const String _pendingLogsKey = 'pending_habit_logs';

  /// Queue a cloud habit-log action that couldn't be written, encoded as
  /// `goalId|date|status`. The latest action for a given (goalId, date) wins.
  Future<void> _enqueuePendingLog(
    String habitId,
    String date,
    String status,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_pendingLogsKey) ?? <String>[];
      final deduped = existing.where((e) {
        final parts = e.split('|');
        return !(parts.length >= 2 && parts[0] == habitId && parts[1] == date);
      }).toList();
      deduped.add('$habitId|$date|$status');
      await prefs.setStringList(_pendingLogsKey, deduped);
      if (kDebugMode) {
        debugPrint('[Notifications] Queued pending log $habitId/$date=$status');
      }
    } catch (e, stack) {
      AppLogger.error('[Notifications] Failed to queue pending log', e, stack);
    }
  }

  /// Drops the queued entry for [habitId] on [date] whose verdict is [status],
  /// once the server has exactly that.
  ///
  /// The status is part of the key, and that is the whole point. Matching on
  /// habit+date alone looks equivalent — [_enqueuePendingLog] dedupes to one
  /// entry per habit-day — but the entry present at DEQUEUE time need not be
  /// the one this call wrote: everything between the two is network work, and
  /// a second tap lands inside that window. Done is tapped and its write is
  /// slow; Skip is tapped, replacing the queued entry; Skip's write fails, so
  /// it relies on the queue; Done's write then completes and a status-blind
  /// delete removes the QUEUED SKIP. The server has `done`, the queue is empty,
  /// and the user's Skip is gone with nothing left to replay it.
  Future<void> _dequeuePendingLog(
    String habitId,
    String date,
    String status,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_pendingLogsKey);
      if (existing == null || existing.isEmpty) return;
      final remaining = existing
          .where((e) => e != '$habitId|$date|$status')
          .toList();
      if (remaining.length == existing.length) return;
      await prefs.setStringList(_pendingLogsKey, remaining);
    } catch (e, stack) {
      // Harmless: the entry survives and the next replay re-upserts the same
      // row. Idempotent by `onConflict: 'goal_id, date'`.
      AppLogger.warning(
        '[Notifications] Failed to drop a written pending log',
        e,
        stack,
      );
    }
  }

  /// Shared in-flight replay, so two callers on the same foreground run ONE.
  /// Both the lifecycle observer and the manual-target sweep replay on resume —
  /// the sweep must, because a queued Done is a verdict it would otherwise read
  /// as an untouched day. Without this they raced on `_pendingLogsKey`: harmless
  /// (the upserts are idempotent) but doubled every network call, and a loser
  /// writing its own `remaining` could resurrect an entry the winner had already
  /// applied.
  Future<
    ({int written, bool drained, Map<String, Map<String, String>>? pending})
  >?
  _replayInFlight;

  /// Replay queued habit-log actions accumulated while the app was terminated
  /// or offline. Safe to call on every foreground: no-ops when the queue is
  /// empty or there's still no session. Entries that fail are kept for retry.
  ///
  /// Reports what happened, because two different callers need two different
  /// facts about it:
  ///
  ///  * **written** — how many entries actually landed. Reloading the verdict
  ///    map is only worth its cost when this is > 0. (Returning void made the
  ///    only honest reaction "assume it wrote something", i.e. invalidate on
  ///    every single foreground.)
  ///  * **drained** — whether the queue is now EMPTY.
  ///  * **pending** — the verdicts STILL queued, as `dateKey → goalId → status`,
  ///    or **null** when the queue could not be read at all.
  ///
  /// The two differ exactly when every upsert fails — offline, or a 5xx — which
  /// is precisely when a naive `written > 0` check says "nothing happened, carry
  /// on".
  ///
  /// [pending] exists because [drained] alone was too blunt an instrument, in a
  /// way that disabled a feature permanently. A queue that still holds entries
  /// is a set of habit-days whose verdict the user has decided and the server
  /// has not been told about, so the in-memory map does not show them, and
  /// auto-fail must not read those days as untouched and write 'missed' over the
  /// user's own Done. That reasoning is right — but the response was to switch
  /// auto-fail off for EVERY habit and EVERY day for as long as the queue was
  /// non-empty, and some entries never drain. `goal_logs.goal_id` is a foreign
  /// key onto `goals`, so a queued Done for a habit the user later DELETED is
  /// rejected on every replay, for the life of the install, with no retry cap
  /// and no expiry. One such entry meant no untouched count day was ever
  /// auto-failed again on that device.
  ///
  /// So the queue is now handed over as DATA rather than as a veto: it carries
  /// the (goal, day, verdict) triples themselves, the sweep overlays them on its
  /// verdict map, and its existing "auto-fail only ever FILLS an empty verdict"
  /// rule then protects exactly the decided days and nothing else. Same
  /// invariant, enforced per-day instead of globally — and no way for one stuck
  /// entry to park the feature.
  Future<
    ({int written, bool drained, Map<String, Map<String, String>>? pending})
  >
  replayPendingHabitLogs() => _replayInFlight ??= _replayPendingHabitLogs()
      .whenComplete(() => _replayInFlight = null);

  /// Parses queue entries (`goalId|date|status`) into the verdict map shape the
  /// sweep reads. Malformed entries are skipped, exactly as the replay skips
  /// them — a line that cannot be parsed is not a decided day.
  static Map<String, Map<String, String>> _verdictsFrom(List<String> entries) {
    final out = <String, Map<String, String>>{};
    for (final entry in entries) {
      final parts = entry.split('|');
      if (parts.length < 3) continue;
      (out[parts[1]] ??= <String, String>{})[parts[0]] = parts[2];
    }
    return out;
  }

  Future<
    ({int written, bool drained, Map<String, Map<String, String>>? pending})
  >
  _replayPendingHabitLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingLogsKey);
      if (pending == null || pending.isEmpty) {
        return (
          written: 0,
          drained: true,
          pending: const <String, Map<String, String>>{},
        );
      }

      // The queue is a CLOUD mechanism — `_writeHabitLogFromNotification`
      // returns before enqueuing in Private mode. So in Private mode there is
      // nothing here to replay, and reaching for `Supabase.instance.client`
      // would THROW: a private-only install never calls `Supabase.initialize`.
      // That throw landed in the catch below and reported the queue as
      // unreadable, which (before this) disabled auto-fail permanently for
      // anyone who queued something in cloud mode and then moved to Private.
      // The entries are still surfaced, so the days they name stay protected.
      if (await _isPrivateMode()) {
        return (written: 0, drained: false, pending: _verdictsFrom(pending));
      }

      final userId = currentUserId();
      if (userId == null) {
        // No session yet; retry next foreground. The queue still holds decided
        // days, so it is NOT drained.
        return (written: 0, drained: false, pending: _verdictsFrom(pending));
      }

      final remaining = <String>[];
      // The entries this run FINISHED with — written, or dropped as
      // unlandable. Used at the end to subtract from whatever the key holds
      // THEN, rather than overwriting it with a list computed from a stale
      // snapshot. See the write below.
      final handled = <String>{};
      // Entries a newer write replaced while this run was in flight. Neither
      // written nor retryable — the newer verdict already owns that habit-day.
      var superseded = 0;
      // Counted separately from `remaining`, because a dropped entry is neither
      // written nor retryable. Folding it into `written` (as `pending.length -
      // remaining.length` alone does) would report a server write that never
      // happened and force a full `goal_logs` re-download for nothing.
      var dropped = 0;
      // Streak resolution costs a `goals` read plus the habit's history, per
      // entry. The queue is normally tiny — it only fills while offline or
      // signed out — but a fortnight of unsent taps across ten habits is
      // hundreds of round trips, and main.dart AWAITS this replay before the
      // reconcile sweeps. So the run gets one shared budget: past it, entries
      // are written WITHOUT a streak, which is exactly what they did before the
      // resolver existed. Never silently — the skipped count is logged.
      // Started and stopped around the streak work ONLY. Left running across the
      // whole loop it would charge every upsert's round trip to the streak
      // budget, so a slow connection would strip streaks from rows for a reason
      // that has nothing to do with what streaks cost.
      final streakBudget = Stopwatch();
      var streaksSkipped = 0;
      for (final entry in pending) {
        final parts = entry.split('|');
        if (parts.length < 3) {
          // Dropped, and COUNTED as dropped — it is not in `remaining` either,
          // so without this it would inflate `written` and trigger a full
          // `goal_logs` re-download for a server write that never happened.
          dropped++;
          handled.add(entry);
          continue;
        }
        try {
          // The entry may have been SUPERSEDED since `pending` was snapshotted.
          // A direct notification write inside that window can land a newer
          // verdict for the same habit-day and dequeue itself; upserting the
          // stale snapshot afterwards would overwrite the user's newer tap and
          // leave nothing queued to undo it — the same loss the status-keyed
          // dequeue exists to prevent, arrived at from the replay side.
          //
          // Checked twice on purpose. Once here, to skip the round trips
          // entirely; and again immediately before the write, because the
          // widest window is the network work BETWEEN the two — a `goals` read
          // plus the habit's full paginated history. The second check is the
          // one that matters; the first only makes it cheaper.
          //
          // NARROWED, not closed. A direct write that enqueues, resolves,
          // upserts and dequeues entirely inside the replay's own in-flight
          // upsert still loses to the stale snapshot. That needs the direct
          // write to finish more work than the replay has left, so it is
          // improbable — but it is a window, not an absence of one.
          if (!(prefs.getStringList(_pendingLogsKey) ?? const []).contains(
            entry,
          )) {
            superseded++;
            continue;
          }

          int? streak;
          if (streakBudget.elapsed < kReplayStreakBudget) {
            streakBudget.start();
            try {
              streak = await _boundedStreak(parts[0], parts[1], parts[2]);
            } finally {
              streakBudget.stop();
            }
          }
          // The check that counts — see above.
          if (!(prefs.getStringList(_pendingLogsKey) ?? const []).contains(
            entry,
          )) {
            superseded++;
            continue;
          }
          await logUpserter(
            goalLogUpsertPayload(
              userId: userId,
              goalId: parts[0],
              dateKey: parts[1],
              status: parts[2],
              streak: streak,
            ),
          );
          handled.add(entry);
          // Counted AFTER the write, so the number names rows that really
          // landed — budget-exhausted, timed out and unresolvable alike.
          if (streak == null) streaksSkipped++;
        } on PostgrestException catch (e, stack) {
          // 23503 = foreign_key_violation: `goal_logs.goal_id` references
          // `goals(id)`, so this is a queued verdict for a habit that no longer
          // exists. It can never land, on any future replay — keeping it would
          // grow the queue without bound and protect a day for a goal nobody
          // can see. Dropped rather than retried; nothing recoverable is lost,
          // because the habit and its history are already gone.
          if (e.code == '23503') {
            AppLogger.warning(
              '[Notifications] dropping a queued log for a deleted habit '
              '(${parts[0]}/${parts[1]}): $e',
            );
            dropped++;
            handled.add(entry);
            continue;
          }
          AppLogger.error(
            '[Notifications] Replay failed, will retry',
            e,
            stack,
          );
          remaining.add(entry);
        } catch (e, stack) {
          AppLogger.error(
            '[Notifications] Replay failed, will retry',
            e,
            stack,
          );
          remaining.add(entry);
        }
      }
      if (streaksSkipped > 0) {
        AppLogger.warning(
          '[Notifications] $streaksSkipped queued log(s) written without a '
          'recomputed streak (budget exhausted, timed out, or unresolvable)',
        );
      }
      // SUBTRACT what this run handled from the key as it stands NOW, rather
      // than writing `remaining` over it.
      //
      // `pending` is a snapshot taken before the loop, and the loop does
      // network I/O. A direct notification write running in that same window
      // enqueues its verdict BEFORE issuing its request — that ordering is what
      // makes the tap survivable at all — and a blind
      // `setStringList(remaining)` would delete that entry, losing the very tap
      // the enqueue exists to protect. `_replayInFlight` does not help here: it
      // dedupes replay against replay and says nothing about a direct write.
      //
      // Anything this run did not finish is left exactly as the key has it, so
      // an entry enqueued (or dequeued) concurrently is respected.
      //
      // SAME-ISOLATE only, and that is a pre-existing property of the queue
      // rather than something this subtract can fix: SharedPreferences caches
      // the whole map per isolate and nothing here calls `reload()`, so a tap
      // handled by the background isolate is invisible to a main-isolate run
      // and vice versa. Within one isolate the read-modify-write is genuinely
      // atomic — the cache read and the cache update have no await between
      // them.
      final latest = prefs.getStringList(_pendingLogsKey) ?? const <String>[];
      final survivors = latest.where((e) => !handled.contains(e)).toList();
      await prefs.setStringList(_pendingLogsKey, survivors);
      if (kDebugMode) {
        debugPrint(
          '[Notifications] Replayed pending logs; ${survivors.length} remaining',
        );
      }
      // `drained`/`pending` describe THE QUEUE, not this run's leftovers, so
      // they are built from `survivors` — what the key actually holds now.
      //
      // Reporting `remaining` alone was a real data-loss path. The caller uses
      // `pending` to know which days the user has already DECIDED, and
      // withholds auto-fail for them. A tap enqueued mid-replay is a survivor
      // but not in `remaining`; omit it and, once the clock passes midnight,
      // that day is closed, its verdict is absent from both the server and
      // `pending`, and `reconcileManualTargets` writes `missed` over the Done
      // the user tapped. Over-reporting the queue only ever WITHHOLDS a write;
      // under-reporting grants one. Only one of those is recoverable.
      //
      // Only entries that actually landed count as written: a retry-kept or
      // superseded entry changed nothing this run put on the server, so it must
      // not make the caller reload.
      return (
        written: pending.length - remaining.length - dropped - superseded,
        drained: survivors.isEmpty,
        pending: _verdictsFrom(survivors),
      );
    } catch (e, stack) {
      AppLogger.error('[Notifications] replayPendingHabitLogs error', e, stack);
      // The queue could not be READ, so we cannot say which days are decided.
      // `pending: null` is that admission, and the caller withholds auto-fail
      // wholesale — the direction that refuses permission to write rather than
      // granting it. This is now the ONLY path that still does so.
      return (written: 0, drained: false, pending: null);
    }
  }

  Future<void> requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleDailyHabitReminder({String timeStr = '09:00'}) async {
    await requestPermissions();
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'habit_reminders',
          t.notifications.habitChannelName,
          channelDescription: t.notifications.dailyHabitChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
        );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      id: 0,
      title: 'Evolve • ${t.notifications.morningBrief}',
      body: t.notifications.morningBriefBody,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleEveningReview({String timeStr = '21:00'}) async {
    await requestPermissions();
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final NotificationDetails platformDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'system_reviews',
        t.notifications.systemReviewsChannelName,
        importance: Importance.low,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      id: 1,
      title: 'Evolve • ${t.notifications.eveningReview}',
      body: t.notifications.eveningReviewBody,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedules the recurring reminder(s) for a habit.
  ///
  /// [frequencyDays] are the ISO weekdays the habit is scheduled on (1=Mon…
  /// 7=Sun); `null`/empty means every day. An every-day habit registers a single
  /// daily repeat (keeping the iOS pending count at 1 for the common case); a
  /// day-restricted habit registers one weekly repeat per selected weekday, so a
  /// reminder never fires on an off-day the UI now hides.
  Future<void> scheduleHabitReminder(
    String id,
    String title,
    String? reminderTime, {
    List<int>? frequencyDays,
    bool isLimit = false,
  }) async {
    if (reminderTime == null) return;

    // The user is enabling a reminder — request permission now (NOTIF-3).
    await requestPermissions();

    final parts = reminderTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final platformDetails = _habitReminderDetails();
    final payload = 'habit|$id|$title';

    // Clamp to valid ISO weekdays (1-7): a corrupt/legacy row carrying e.g. [0]
    // or [8] must not reach the weekday-seek loop, which would spin forever.
    final valid = frequencyDays?.where((d) => d >= 1 && d <= 7).toSet().toList()
      ?..sort();
    final freq = (valid == null || valid.isEmpty) ? null : valid;

    if (freq == null) {
      await _scheduleReminderInstance(
        notificationId: id.hashCode,
        scheduledDate: _nextInstanceOfTime(hour, minute),
        match: DateTimeComponents.time,
        title: title,
        payload: payload,
        details: platformDetails,
        isLimit: isLimit,
      );
      return;
    }

    for (final weekday in freq) {
      await _scheduleReminderInstance(
        notificationId: _weekdayReminderId(id, weekday),
        scheduledDate: _nextInstanceOfWeekdayTime(weekday, hour, minute),
        match: DateTimeComponents.dayOfWeekAndTime,
        title: title,
        payload: payload,
        details: platformDetails,
        isLimit: isLimit,
      );
    }
  }

  /// Notification-channel + action config shared by every habit reminder
  /// instance (the daily one and the per-weekday ones).
  NotificationDetails _habitReminderDetails() {
    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      t.notifications.habitChannelName,
      channelDescription: t.notifications.specificHabitChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('action_done', t.notifications.actionDone),
        AndroidNotificationAction(
          'action_snooze',
          t.notifications.actionSnooze,
        ),
        AndroidNotificationAction('action_skip', t.notifications.actionSkip),
      ],
    );
    return NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(categoryIdentifier: 'habit_actions'),
    );
  }

  /// Schedules one recurring reminder instance, honoring the iOS 64 pending-cap
  /// guard (NOTIF-4): if there's no headroom and this id isn't already pending,
  /// skip rather than let iOS silently drop it.
  Future<void> _scheduleReminderInstance({
    required int notificationId,
    required tz.TZDateTime scheduledDate,
    required DateTimeComponents match,
    required String title,
    required String payload,
    required NotificationDetails details,
    bool isLimit = false,
  }) async {
    if (!await _canSchedule(notificationId)) {
      AppLogger.warning(
        '[Notifications] iOS pending cap reached; skipping reminder $notificationId',
      );
      return;
    }

    await _notifications.zonedSchedule(
      id: notificationId,
      title: 'Evolve • $title',
      body: _getHabitMessage(title, isLimit: isLimit),
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: match,
      payload: payload,
    );
  }

  /// Stable per-(habit, weekday) notification id, distinct from the every-day
  /// id (`id.hashCode`) and from other habits' ids.
  int _weekdayReminderId(String id, int weekday) => '$id#wd$weekday'.hashCode;

  /// Immediate "couldn't-verify — did you keep it?" nudge for an auto-verified
  /// habit whose day ended without a definitive signal (D6/D11). The id is
  /// stable per goal so re-firing on a later reconcile replaces the banner
  /// rather than stacking a new one. Cross-foreground de-dup (so it doesn't
  /// re-alert the same day) is handled by the caller via the store's nudged
  /// marker.
  Future<void> showVerificationNudge({
    required String goalId,
    required String title,
  }) async {
    await _notifications.show(
      id: 'verify_nudge_$goalId'.hashCode,
      title: t.verification.nudgeTitle,
      body: t.verification.nudgeBody(title: title),
      notificationDetails: _verificationDetails,
      payload: 'verify_nudge|$goalId',
    );
  }

  /// Shared notification details for the auto-verification channel (D11).
  NotificationDetails get _verificationDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      'verification_nudges',
      t.verification.channelName,
      channelDescription: t.verification.channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  /// Opt-in "goal reached" celebration for an auto-verified habit that passed
  /// today (D11 — OFF by default). Id keyed to goal + day so a re-fire replaces
  /// rather than stacks; the caller only fires it on a fresh verdict write, so
  /// it can't repeat.
  Future<void> showVerificationCelebration({
    required String goalId,
    required String dateKey,
    required String title,
  }) async {
    await _notifications.show(
      id: 'verify_celebrate_${goalId}_$dateKey'.hashCode,
      title: t.verification.celebrationTitle,
      body: t.verification.celebrationBody(title: title),
      notificationDetails: _verificationDetails,
      payload: 'verify_celebrate|$goalId',
    );
  }

  /// Opt-in summary when auto-verified habits ended a past day missed (D11 — OFF
  /// by default). [count] is the number of fresh `missed` verdicts this pass;
  /// [title] names a representative habit (used when [count] == 1).
  Future<void> showVerificationFailureSummary({
    required int count,
    required String title,
  }) async {
    await _notifications.show(
      id: 'verify_fail_summary'.hashCode,
      title: t.verification.failureSummaryTitle,
      body: count == 1
          ? t.verification.failureSummaryBodyOne(title: title)
          : t.verification.failureSummaryBodyMany(count: count),
      notificationDetails: _verificationDetails,
      payload: 'verify_fail_summary',
    );
  }

  /// iOS silently drops scheduled notifications beyond 64 pending (NOTIF-4).
  /// Allow scheduling when there's headroom, or when [id] is already pending
  /// (a re-schedule replaces in place and doesn't grow the count). Fails open.
  Future<bool> _canSchedule(int id) async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      if (pending.any((p) => p.id == id)) return true;
      return pending.length < 64;
    } catch (e, stack) {
      AppLogger.error('[Notifications] pending-cap check failed', e, stack);
      return true;
    }
  }

  Future<void> cancelHabitReminder(String id) async {
    // Clear the every-day instance and every possible per-weekday instance: the
    // previously-scheduled day set isn't known here, and cancelling an id that
    // was never scheduled is a harmless no-op.
    await _notifications.cancel(id: id.hashCode);
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _notifications.cancel(id: _weekdayReminderId(id, weekday));
    }
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  String _getHabitMessage(String title, {bool isLimit = false}) {
    final now = DateTime.now();
    return reminderBody(
      title,
      isLimit: isLimit,
      rotationSeed: title.hashCode + now.minute + now.hour,
    );
  }

  /// Picks the (recurring) reminder body for a habit, target-aware and pure.
  ///
  /// A LIMIT target ("at most N") must NOT get achievement / "do it!" copy: on a
  /// day the user is succeeding by consuming nothing, a motivational "time to act
  /// on {title}" nudge inverts the goal. When the targets feature is live
  /// ([TargetsConfig.enabled]) and [isLimit] is true we use restraint-framed copy
  /// instead. While the feature is dark — or for a count/duration target — every
  /// habit keeps the existing motivational rotation, so behaviour is unchanged.
  ///
  /// The body is fixed at schedule time (the reminder is one OS-level recurring
  /// registration with no per-fire hook), so [rotationSeed] — a time+title hash —
  /// just picks which line of the rotation is frozen in. Extracted as a pure
  /// static so the target-aware branch is unit-testable without a real schedule.
  ///
  /// [featureEnabled] defaults to the compile-time [TargetsConfig.enabled] flag,
  /// so production stays dark (the const default lets the limit branch
  /// tree-shake); tests pass `true` to exercise the restraint branch directly.
  @visibleForTesting
  static String reminderBody(
    String title, {
    required bool isLimit,
    required int rotationSeed,
    bool featureEnabled = TargetsConfig.enabled,
  }) {
    final messages = (featureEnabled && isLimit)
        ? <String>[
            t.notifications.limitReminderMessage1(title: title),
            t.notifications.limitReminderMessage2(title: title),
            t.notifications.limitReminderMessage3(title: title),
          ]
        : <String>[
            t.notifications.habitReminderMessage1(title: title),
            t.notifications.habitReminderMessage2(title: title),
            t.notifications.habitReminderMessage3(title: title),
            t.notifications.habitReminderMessage4(title: title),
            t.notifications.habitReminderMessage5(title: title),
            t.notifications.habitReminderMessage6(title: title),
            t.notifications.habitReminderMessage7(title: title),
            t.notifications.habitReminderMessage8(title: title),
            t.notifications.habitReminderMessage9(title: title),
            t.notifications.habitReminderMessage10(title: title),
            t.notifications.habitReminderMessage11(title: title),
            t.notifications.habitReminderMessage12(title: title),
            t.notifications.habitReminderMessage13(title: title),
            t.notifications.habitReminderMessage14(title: title),
            t.notifications.habitReminderMessage15(title: title),
          ];
    return messages[rotationSeed.abs() % messages.length];
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) =>
      nextInstanceOfTimeFrom(tz.TZDateTime.now(tz.local), hour, minute);

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) =>
      nextInstanceOfWeekdayTimeFrom(
        tz.TZDateTime.now(tz.local),
        weekday,
        hour,
        minute,
      );

  Future<bool> _isPrivateMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_data_mode') == AppDataMode.private.name;
  }
}

/// The next occurrence of [hour]:[minute] at or after [now] — the seed date for
/// a daily repeat.
///
/// [now] is a parameter rather than read inside, so the DST behaviour can be
/// tested at all: the transition dates are fixed points in the calendar and the
/// bug only shows on the eve of one. The result is built in `now.location`, NOT
/// `tz.local` — otherwise a test could set up a transition in one zone and be
/// silently answered in another (UTC, which has no transitions, would pass
/// against the very arithmetic this replaced).
@visibleForTesting
tz.TZDateTime nextInstanceOfTimeFrom(tz.TZDateTime now, int hour, int minute) {
  tz.TZDateTime scheduledDate = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (scheduledDate.isBefore(now)) {
    // CALENDAR arithmetic, not `add(Duration(days: 1))`. A Duration day is a
    // fixed 24 hours; a calendar day across a DST transition is 23 or 25. So
    // adding one to a 09:00 seed on the eve of a spring-forward lands at
    // 10:00, and the first firing of that reminder is an hour late.
    // `matchDateTimeComponents` re-matches wall clock on every LATER firing,
    // which is exactly why only the seed was ever wrong — and why it was easy
    // to miss. Rebuilding through the constructor re-resolves the zone offset
    // for the target date, which is what makes the wall-clock time hold.
    scheduledDate = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }
  return scheduledDate;
}

/// Next occurrence of [hour]:[minute] falling on ISO [weekday] (1=Mon…7=Sun),
/// the seed date for a `dayOfWeekAndTime` weekly repeat. See
/// [nextInstanceOfTimeFrom] for why [now] is a parameter.
@visibleForTesting
tz.TZDateTime nextInstanceOfWeekdayTimeFrom(
  tz.TZDateTime now,
  int weekday,
  int hour,
  int minute,
) {
  tz.TZDateTime scheduledDate = nextInstanceOfTimeFrom(now, hour, minute);
  // Same calendar-day rule as above. NOT a wrong-weekday bug, despite how it
  // looks: this loop exits only when the weekday already matches, so the result
  // is always the requested day. What a Duration walk got wrong is the HOUR —
  // and for a reminder set near midnight, an hour of drift is a ~23-hour
  // displacement of when it actually fires within that correct day.
  while (scheduledDate.weekday != weekday) {
    scheduledDate = tz.TZDateTime(
      now.location,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day + 1,
      hour,
      minute,
    );
  }
  return scheduledDate;
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezones for this isolate
  tz.initializeTimeZones();
  try {
    final dynamic timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = timeZoneInfo is String
        ? timeZoneInfo
        : timeZoneInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  final prefs = await SharedPreferences.getInstance();
  final isPrivateMode =
      prefs.getString('active_data_mode') == AppDataMode.private.name;
  AppLogger.setExternalReportingDisabled(isPrivateMode);

  // The SAME gate as `main()`, not just `!isPrivateMode`. This isolate restores
  // the Keychain session exactly as a cold start does, so leaving it on the old
  // predicate would keep the pre-consent hole open here after closing it there:
  // a device that loses `NSUserDefaults` without losing its app container has
  // scheduled notifications that survive, and tapping one would refresh the
  // token before the user had answered anything.
  if (shouldInitialiseSupabaseAtStartup(
    hasCompletedConsent: prefs.getBool(kHasCompletedConsentPrefKey) ?? false,
    isPrivateMode: isPrivateMode,
  )) {
    // Use SecureLocalStorage so the persisted auth session is restored in this
    // background isolate — without it currentUser is null and Done/Skip silently
    // no-op when the app is terminated (NOTIF-1). Mirrors main.dart.
    try {
      Supabase.instance.client;
    } catch (e) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureLocalStorage(),
        ),
      );
    }
  }

  NotificationService()._onNotificationResponse(response);
}
