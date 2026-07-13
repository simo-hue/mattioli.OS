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
    debugPrint(
      'Notification response: ${response.payload}, action: ${response.actionId}',
    );

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
    debugPrint('[Notifications] Habit $habitId snoozed for 10 minutes');
  }

  Future<void> _skipHabit(String habitId) async {
    await _notifications.cancel(id: habitId.hashCode);
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

    if (await _isPrivateMode()) {
      try {
        // Compute the streak from history so a notification Done/Skip matches
        // the foreground toggle (Private analytics read the stored streak).
        await PrivateLocalDatabase().setHabitLogWithStreak(
          goalId: habitId,
          date: dateKey,
          status: status,
        );
        debugPrint('[Notifications] Private habit $habitId set to $status');
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
      debugPrint('[Notifications] Habit $habitId set to $status');
    } catch (e, stack) {
      AppLogger.error('[Notifications] Error writing habit log', e, stack);
      await _enqueuePendingLog(habitId, dateKey, status);
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
      debugPrint('[Notifications] Queued pending log $habitId/$date=$status');
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
      debugPrint(
        '[Notifications] Replayed pending logs; ${remaining.length} remaining',
      );
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

  Future<void> scheduleHabitReminder(
    String id,
    String title,
    String? reminderTime,
  ) async {
    if (reminderTime == null) return;

    // The user is enabling a reminder — request permission now (NOTIF-3).
    await requestPermissions();

    final parts = reminderTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

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

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(categoryIdentifier: 'habit_actions'),
    );

    final notificationId = id.hashCode;

    // Respect the iOS 64 pending-notification cap (NOTIF-4): if there's no
    // headroom and this reminder isn't already scheduled, skip rather than let
    // iOS silently drop it.
    if (!await _canSchedule(notificationId)) {
      AppLogger.warning(
        '[Notifications] iOS pending cap reached; skipping reminder for $id',
      );
      return;
    }

    await _notifications.zonedSchedule(
      id: notificationId,
      title: 'Evolve • $title',
      body: _getHabitMessage(title),
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'habit|$id|$title',
    );
  }

  /// Immediate "couldn't-verify — did you keep it?" nudge for an auto-verified
  /// habit whose day ended without a definitive signal (D6/D11). The id is
  /// stable per goal so re-firing on a later reconcile replaces the banner
  /// rather than stacking a new one. (i18n of the copy + a dedicated settings
  /// toggle are follow-ups — see TO_SIMO_DO; the feature is dark until then.)
  Future<void> showVerificationNudge({
    required String goalId,
    required String title,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'verification_nudges',
      'Habit verification',
      channelDescription: 'Prompts to resolve habits we could not auto-verify.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _notifications.show(
      id: 'verify_nudge_$goalId'.hashCode,
      title: 'Evolve',
      body: "Couldn't verify \"$title\" — did you keep it?",
      notificationDetails: platformDetails,
      payload: 'verify_nudge|$goalId',
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
    await _notifications.cancel(id: id.hashCode);
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  String _getHabitMessage(String title) {
    final messages = [
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

    final index =
        (title.hashCode + DateTime.now().minute + DateTime.now().hour) %
        messages.length;
    return messages[index.abs()];
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
