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
  }) async {
    await init();
    if (!_initialized) return;
    await _notifications.cancelAll();
    if (!canScheduleDaily) return;

    if (habitReminders) {
      await _scheduleDaily(
        id: 0,
        time: morningBriefTime,
        title: 'Evolve - ${t.notifications.morningBrief}',
        body: t.notif.morningBody,
      );
      for (final habit in habits) {
        final reminderTime = habit.reminderTime;
        if (reminderTime == null) continue;
        await _scheduleDaily(
          id: habit.id.hashCode,
          time: reminderTime,
          title: 'Evolve - ${habit.title}',
          body: t.notif.habitReminderBody,
          payload: 'habit|${habit.id}|${habit.title}',
          categoryId: _habitCategoryId,
        );
      }
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

  /// Foreground handler for notification actions (macOS Done/Skip). Snooze /
  /// dismiss carry no write. Runs in the app isolate (the desktop app is a
  /// long-lived process), so a straight local write + UI refresh is enough.
  void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    if (actionId == null || payload == null) return;
    final parts = payload.split('|');
    if (parts.length < 2 || parts.first != 'habit') return;
    final goalId = parts[1];
    final status = switch (actionId) {
      'done' => 'done',
      'skip' => 'missed',
      _ => null, // 'snooze' / default -> no write
    };
    if (status == null) return;
    unawaited(_handleHabitAction(goalId, status));
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

    // Resolve the habit's start_date so the run can't walk before it.
    final goalRows = await client
        .from('goals')
        .select('start_date')
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

    final streak = computeStreak(
      habitId: goalId,
      date: now,
      logs: logs,
      startDate: startDate,
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
}
