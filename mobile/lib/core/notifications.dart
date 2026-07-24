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
import '../providers/goal_provider.dart';
import 'data_mode.dart';
import 'navigator_key.dart';
import 'private_local_database.dart';
import 'secure_local_storage.dart';
import 'supabase_config.dart';
import 'targets_config.dart';
import 'verification_config.dart';
import 'verification_state_store.dart';
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
    await _freezeManualForToday(habitId);

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

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // No restored session yet — queue and replay when the app foregrounds.
      await _enqueuePendingLog(habitId, dateKey, status);
      return;
    }

    try {
      await Supabase.instance.client.from('goal_logs').upsert({
        'user_id': user.id,
        'goal_id': habitId,
        'date': dateKey,
        'status': status,
      }, onConflict: 'goal_id, date');
      if (kDebugMode) {
        debugPrint('[Notifications] Habit $habitId set to $status');
      }
    } catch (e, stack) {
      AppLogger.error('[Notifications] Error writing habit log', e, stack);
      await _enqueuePendingLog(habitId, dateKey, status);
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
  Future<void> _freezeManualForToday(String habitId) async {
    if (!VerificationConfig.enabled) return;
    try {
      final store = await verificationStoreOpener();
      final now = DateTime.now();
      await store.markManual(habitId, DateTime(now.year, now.month, now.day));
    } catch (e, stack) {
      AppLogger.error('[Notifications] manual-freeze write failed', e, stack);
    }
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

  /// Replay queued habit-log actions accumulated while the app was terminated
  /// or offline. Safe to call on every foreground: no-ops when the queue is
  /// empty or there's still no session. Entries that fail are kept for retry.
  Future<void> replayPendingHabitLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingLogsKey);
      if (pending == null || pending.isEmpty) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return; // no session yet; retry next foreground

      final remaining = <String>[];
      for (final entry in pending) {
        final parts = entry.split('|');
        if (parts.length < 3) continue; // drop malformed entries
        try {
          await Supabase.instance.client.from('goal_logs').upsert({
            'user_id': user.id,
            'goal_id': parts[0],
            'date': parts[1],
            'status': parts[2],
          }, onConflict: 'goal_id, date');
        } catch (e, stack) {
          AppLogger.error('[Notifications] Replay failed, will retry', e, stack);
          remaining.add(entry);
        }
      }
      await prefs.setStringList(_pendingLogsKey, remaining);
      if (kDebugMode) {
        debugPrint(
          '[Notifications] Replayed pending logs; ${remaining.length} remaining',
        );
      }
    } catch (e, stack) {
      AppLogger.error('[Notifications] replayPendingHabitLogs error', e, stack);
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
    final valid = frequencyDays
        ?.where((d) => d >= 1 && d <= 7)
        .toSet()
        .toList()
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
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Next occurrence of [hour]:[minute] falling on ISO [weekday] (1=Mon…7=Sun),
  /// the seed date for a `dayOfWeekAndTime` weekly repeat.
  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<bool> _isPrivateMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_data_mode') == AppDataMode.private.name;
  }
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

  if (!isPrivateMode) {
    // Initialize Supabase if needed. Crucially, use SecureLocalStorage so the
    // persisted auth session is restored in this background isolate — without
    // it currentUser is null and Done/Skip silently no-op when the app is
    // terminated (NOTIF-1). Must mirror main.dart's initialization.
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
