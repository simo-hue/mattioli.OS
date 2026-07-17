import 'dart:async';
import 'dart:io';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/streak_utils.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class DesktopNotificationService {
  DesktopNotificationService._();

  static final instance = DesktopNotificationService._();

  /// macOS notification category that carries the Done/Skip/Snooze actions.
  static const _habitCategoryId = 'evolve_habit_actions';

  /// Set by the app so a notification-driven write can refresh the UI providers.
  static void Function()? onLocalWrite;

  final _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get canScheduleDaily => Platform.isMacOS || Platform.isWindows;

  String get platformSummary {
    if (Platform.isMacOS) return t.notif.macScheduling;
    if (Platform.isWindows) {
      return t.notif.windowsScheduling;
    }
    return t.notif.linuxImmediate;
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      final timezone = await FlutterTimezone.getLocalTimezone();
      try {
        tz.setLocalLocation(tz.getLocation(timezone.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      // macOS actionable-notification category (Done/Skip/Snooze). Only habit
      // reminders reference it; the morning/evening briefs stay action-less.
      final habitCategory = DarwinNotificationCategory(
        _habitCategoryId,
        actions: [
          DarwinNotificationAction.plain('done', t.notifications.actionDone),
          DarwinNotificationAction.plain('skip', t.notifications.actionSkip),
          DarwinNotificationAction.plain(
            'snooze',
            t.notifications.actionSnooze,
          ),
        ],
      );
      final darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [habitCategory],
      );
      final linux = LinuxInitializationSettings(
        defaultActionName: t.notif.openEvolve,
      );
      const windows = WindowsInitializationSettings(
        appName: 'Evolve',
        appUserModelId: 'com.simo.evolve.desktop',
        guid: 'b989933a-4c53-4c37-843d-7a86cc207bc4',
      );
      await _notifications.initialize(
        settings: InitializationSettings(
          macOS: darwin,
          linux: linux,
          windows: windows,
        ),
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      _initialized = true;
    } catch (error, stack) {
      AppLogger.error(
        'Unable to initialize desktop notifications',
        error,
        stack,
      );
    }
  }

  Future<bool> requestPermissions() async {
    await init();
    if (Platform.isMacOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  Future<void> sync({
    required bool habitReminders,
    required bool eveningReview,
    required String morningBriefTime,
    required String eveningReviewTime,
    required List<DashboardHabit> habits,
    bool focusMode = false,
  }) async {
    await init();
    if (!_initialized) return;
    await _notifications.cancelAll();
    // Focus Mode (mobile parity): everything scheduled was just cancelled and
    // nothing is rescheduled while it is on — mirrors mobile's
    // AppSettingsNotifier.syncNotifications, which returns right after
    // cancelAll() when focusMode is set.
    if (focusMode) return;
    if (!canScheduleDaily) return;

    // Request notification permission before scheduling — covers the habit
    // add/edit path (mobile requests it in scheduleHabitReminder). macOS only
    // shows the dialog when authorization is notDetermined; otherwise this is a
    // no-op returning the current status.
    final willSchedule =
        habitReminders ||
        eveningReview ||
        habits.any((h) => h.reminderTime != null);
    if (willSchedule) {
      await requestPermissions();
    }

    // The 'Habit Reminders' toggle controls ONLY the Morning Brief (mobile
    // parity gates just the 09:00 brief on this flag).
    if (habitReminders) {
      await _scheduleDaily(
        id: 0,
        time: morningBriefTime,
        title: 'Evolve - ${t.notifications.morningBrief}',
        body: t.notif.morningBody,
      );
    }

    // Per-goal reminders schedule INDEPENDENTLY of the Morning Brief toggle —
    // turning off 'Habit Reminders' must not silence them (mobile parity).
    // Guarded by the macOS 64 pending-notification cap so overflow is
    // deterministic + logged instead of silently dropped by the OS. A
    // day-restricted habit fans out to one weekly reminder per selected weekday
    // so it never fires on an off-day the UI now hides; an every-day habit keeps
    // a single daily entry (holding the pending count at 1 for the common case).
    for (final habit in habits) {
      final reminderTime = habit.reminderTime;
      if (reminderTime == null) continue;
      await _scheduleHabitReminders(habit, reminderTime);
    }

    if (eveningReview) {
      await _scheduleDaily(
        id: 1,
        time: eveningReviewTime,
        title: 'Evolve - ${t.notifications.eveningReview}',
        body: t.notif.eveningBody,
      );
    }
  }

  /// Registers the recurring reminder(s) for one habit, honoring its weekly
  /// schedule. Every-day habits (`frequencyDays` null/empty) get a single daily
  /// repeat; day-restricted habits get one weekly repeat per selected weekday.
  Future<void> _scheduleHabitReminders(
    DashboardHabit habit,
    String reminderTime,
  ) async {
    // Clamp to valid ISO weekdays (1-7): a corrupt/imported row carrying e.g.
    // [0] or [8] must not reach the weekday-seek loop, which would spin forever.
    final valid = habit.frequencyDays
        ?.where((d) => d >= 1 && d <= 7)
        .toSet()
        .toList()
      ?..sort();
    final freq = (valid == null || valid.isEmpty) ? null : valid;
    final title = 'Evolve - ${habit.title}';
    final payload = 'habit|${habit.id}|${habit.title}';

    if (freq == null) {
      final id = habit.id.hashCode;
      if (!await _canSchedule(id)) {
        AppLogger.warning(
          '[Notifications] pending cap reached; skipping reminder for '
          '${habit.id}',
        );
        return;
      }
      await _scheduleDaily(
        id: id,
        time: reminderTime,
        title: title,
        body: t.notif.habitReminderBody,
        payload: payload,
        categoryId: _habitCategoryId,
      );
      return;
    }

    for (final weekday in freq) {
      final id = _weekdayReminderId(habit.id, weekday);
      if (!await _canSchedule(id)) {
        AppLogger.warning(
          '[Notifications] pending cap reached; skipping reminder for '
          '${habit.id} (weekday $weekday)',
        );
        continue;
      }
      await _scheduleWeekly(
        id: id,
        weekday: weekday,
        time: reminderTime,
        title: title,
        body: t.notif.habitReminderBody,
        payload: payload,
        categoryId: _habitCategoryId,
      );
    }
  }

  /// Stable per-(habit, weekday) notification id, distinct from the every-day id
  /// (`id.hashCode`) and from other habits'. Mirrors mobile's `_weekdayReminderId`.
  int _weekdayReminderId(String id, int weekday) => '$id#wd$weekday'.hashCode;

  Future<void> _scheduleDaily({
    required int id,
    required String time,
    required String title,
    required String body,
    String? payload,
    String? categoryId,
  }) async {
    final scheduledDate = _nextInstance(time);
    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        macOS: DarwinNotificationDetails(categoryIdentifier: categoryId),
        windows: const WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Recur daily at the same time on macOS AND Windows. (Linux has no
      // scheduling and fires immediately — disclosed in [platformSummary].)
      matchDateTimeComponents: Platform.isMacOS || Platform.isWindows
          ? DateTimeComponents.time
          : null,
      payload: payload,
    );
  }

  /// Like [_scheduleDaily] but recurs weekly on a single ISO [weekday]
  /// (1=Mon…7=Sun) — used for a day-restricted habit's reminder.
  Future<void> _scheduleWeekly({
    required int id,
    required int weekday,
    required String time,
    required String title,
    required String body,
    String? payload,
    String? categoryId,
  }) async {
    final scheduledDate = _nextInstanceOnWeekday(time, weekday);
    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        macOS: DarwinNotificationDetails(categoryIdentifier: categoryId),
        windows: const WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Recur weekly on this weekday at this time on macOS AND Windows. (Linux
      // has no scheduling and fires immediately — disclosed in [platformSummary].)
      matchDateTimeComponents: Platform.isMacOS || Platform.isWindows
          ? DateTimeComponents.dayOfWeekAndTime
          : null,
      payload: payload,
    );
  }

  /// macOS silently drops scheduled notifications beyond 64 pending. Allow
  /// scheduling when there's headroom, or when [id] is already pending (a
  /// re-schedule replaces in place, not growing the count). Fails open. Mirrors
  /// mobile's `_canSchedule`.
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

  /// Foreground handler for notification actions (macOS Done/Skip/Snooze). Runs
  /// in the app isolate (the desktop app is a long-lived process), so a straight
  /// local write + UI refresh is enough; Snooze re-fires the reminder in 10 min.
  void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    if (actionId == null || payload == null) return;
    final parts = payload.split('|');
    if (parts.length < 2 || parts.first != 'habit') return;
    final goalId = parts[1];
    final title = parts.length > 2 ? parts[2] : '';

    if (actionId == 'snooze') {
      unawaited(_snoozeHabit(goalId, title));
      return;
    }

    final status = switch (actionId) {
      'done' => 'done',
      'skip' => 'missed',
      _ => null,
    };
    if (status == null) return;
    unawaited(_handleHabitAction(goalId, status));
  }

  /// Re-fires the habit reminder ~10 minutes from now (mobile parity). Uses a
  /// distinct id (daily id + 1000) so it can't collide with the daily schedule.
  Future<void> _snoozeHabit(String goalId, String title) async {
    try {
      await init();
      if (!_initialized || !canScheduleDaily) return;
      final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
      await _notifications.zonedSchedule(
        id: goalId.hashCode + 1000,
        title: 'Evolve - $title',
        body: t.notif.habitReminderBody,
        scheduledDate: when,
        notificationDetails: NotificationDetails(
          macOS: DarwinNotificationDetails(categoryIdentifier: _habitCategoryId),
          windows: const WindowsNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'habit|$goalId|$title',
      );
    } catch (error, stack) {
      AppLogger.error('Notification snooze failed', error, stack);
    }
  }

  Future<void> _handleHabitAction(String goalId, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPrivate = prefs.getString('active_data_mode') == 'private';
      if (isPrivate) {
        // Private mode: write the log to the encrypted local DB.
        await DesktopPrivateDb.instance.setHabitLogFromNotification(
          goalId: goalId,
          status: status,
        );
      } else {
        // Cloud mode: write to Supabase. This runs in the foreground/main-isolate
        // notification callback (the app is running when a desktop notification
        // action fires), so the authenticated client is available.
        await _writeCloudHabitLog(goalId, status);
      }
      onLocalWrite?.call();
    } catch (error, stack) {
      AppLogger.error('Notification habit action failed', error, stack);
    }
  }

  /// Upserts a habit log to Supabase from a notification action, computing the
  /// signed streak from the habit's history — the cloud counterpart of
  /// [DesktopPrivateDb.setHabitLogFromNotification]. No-op if Supabase isn't
  /// initialized or no user is signed in.
  Future<void> _writeCloudHabitLog(String goalId, String status) async {
    final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      return; // Supabase not initialized (e.g. a background isolate) — skip.
    }
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now();
    final dayKey = dashboardDateKey(now);

    // Load the habit's logs keyed the way computeStreak reads them, then apply
    // the new status for today so the toggled day is visible to the algorithm.
    final rows = await client
        .from('goal_logs')
        .select('date, status')
        .eq('user_id', userId)
        .eq('goal_id', goalId)
        // Newest first so the recent days the streak walk needs are always
        // within PostgREST's default row cap.
        .order('date', ascending: false);
    final logs = <String, Map<String, String>>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final date = row['date'] as String?;
      final rowStatus = row['status'] as String?;
      if (date != null && rowStatus != null) {
        (logs[date] ??= <String, String>{})[goalId] = rowStatus;
      }
    }
    (logs[dayKey] ??= <String, String>{})[goalId] = status;

    // Resolve the habit's start_date (so the run can't walk before it) and its
    // weekly schedule (so off-days are transparent to the streak).
    final goalRows = await client
        .from('goals')
        .select('start_date, frequency_days')
        .eq('id', goalId)
        .limit(1);
    final goalList = List<Map<String, dynamic>>.from(goalRows);
    final startDate =
        (goalList.isEmpty
            ? null
            : DateTime.tryParse(
                goalList.first['start_date'] as String? ?? '',
              )) ??
        DateTime(now.year, now.month, now.day);
    final frequencyDays = goalList.isEmpty
        ? null
        : DesktopPrivateDb.frequencyDaysList(goalList.first['frequency_days']);

    final streak = computeStreak(
      habitId: goalId,
      date: now,
      logs: logs,
      startDate: startDate,
      frequencyDays: frequencyDays,
    );

    await client.from('goal_logs').upsert({
      'user_id': userId,
      'goal_id': goalId,
      'date': dayKey,
      'status': status,
      'streak': streak,
    }, onConflict: 'goal_id,date');
  }

  tz.TZDateTime _nextInstance(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Next occurrence of [time] falling on ISO [weekday] (1=Mon…7=Sun) — the seed
  /// date for a `dayOfWeekAndTime` weekly repeat.
  tz.TZDateTime _nextInstanceOnWeekday(String time, int weekday) {
    var scheduled = _nextInstance(time);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
