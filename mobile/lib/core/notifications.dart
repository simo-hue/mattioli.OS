import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/generated/app_localizations.dart';
import 'data_mode.dart';
import 'private_local_database.dart';
import 'supabase_config.dart';
import 'app_logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  AppLocalizations get _l10n {
    final locale = ui.PlatformDispatcher.instance.locale;
    try {
      return lookupAppLocalizations(locale);
    } catch (_) {
      return lookupAppLocalizations(const ui.Locale('en'));
    }
  }

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
      final l10n = _l10n;
      final List<DarwinNotificationCategory> darwinCategories = [
        DarwinNotificationCategory(
          'habit_actions',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              'action_done',
              l10n.notificationActionDone,
            ),
            DarwinNotificationAction.plain(
              'action_snooze',
              l10n.notificationActionSnooze,
            ),
            DarwinNotificationAction.plain(
              'action_skip',
              l10n.notificationActionSkip,
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.customDismissAction,
          },
        ),
      ];

      final DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
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
    } else if (response.actionId == 'action_snooze') {
      await _snoozeHabit(habitId, parts.length > 2 ? parts[2] : 'Abitudine');
    } else if (response.actionId == 'action_skip') {
      await _skipHabit(habitId);
    }
  }

  Future<void> _markHabitAsDone(String habitId) async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      if (await _isPrivateMode()) {
        await PrivateLocalDatabase().setHabitLog(
          goalId: habitId,
          date: dateKey,
          status: 'done',
        );
        debugPrint('[Notifications] Private habit $habitId marked as done');
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('goal_logs').upsert({
        'user_id': user.id,
        'goal_id': habitId,
        'date': dateKey,
        'status': 'done',
      }, onConflict: 'goal_id, date');
      debugPrint('[Notifications] Habit $habitId marked as done');
    } catch (e, stack) {
      AppLogger.error('[Notifications] Error marking habit as done', e, stack);
    }
  }

  Future<void> _snoozeHabit(String habitId, String title) async {
    final now = DateTime.now();
    final scheduledDate = now.add(const Duration(minutes: 10));
    final l10n = _l10n;

    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      l10n.notificationHabitChannelName,
      channelDescription: l10n.notificationHabitChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('action_done', l10n.notificationActionDone),
        AndroidNotificationAction(
          'action_snooze',
          l10n.notificationActionSnooze,
        ),
        AndroidNotificationAction('action_skip', l10n.notificationActionSkip),
      ],
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(categoryIdentifier: 'habit_actions'),
    );

    await _notifications.zonedSchedule(
      id: habitId.hashCode + 1000,
      title: 'Evolve • $title',
      body: _getHabitMessage(title, l10n),
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'habit|$habitId|$title',
    );
    debugPrint('[Notifications] Habit $habitId snoozed for 10 minutes');
  }

  Future<void> _skipHabit(String habitId) async {
    await _notifications.cancel(id: habitId.hashCode);

    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      if (await _isPrivateMode()) {
        await PrivateLocalDatabase().setHabitLog(
          goalId: habitId,
          date: dateKey,
          status: 'missed',
        );
        debugPrint('[Notifications] Private habit $habitId marked as missed');
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('goal_logs').upsert({
        'user_id': user.id,
        'goal_id': habitId,
        'date': dateKey,
        'status': 'missed',
      }, onConflict: 'goal_id, date');
      debugPrint('[Notifications] Habit $habitId marked as missed/skipped');
    } catch (e, stack) {
      AppLogger.error(
        '[Notifications] Error marking habit as missed',
        e,
        stack,
      );
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
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final l10n = _l10n;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'habit_reminders',
          l10n.notificationHabitChannelName,
          channelDescription: l10n.notificationDailyHabitChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
        );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      id: 0,
      title: 'Evolve • ${l10n.morningBrief}',
      body: l10n.notificationMorningBriefBody,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleEveningReview({String timeStr = '21:00'}) async {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final l10n = _l10n;

    final NotificationDetails platformDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'system_reviews',
        l10n.notificationSystemReviewsChannelName,
        importance: Importance.low,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      id: 1,
      title: 'Evolve • ${l10n.reviewSerale}',
      body: l10n.notificationEveningReviewBody,
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

    final parts = reminderTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final l10n = _l10n;

    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      l10n.notificationHabitChannelName,
      channelDescription: l10n.notificationSpecificHabitChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('action_done', l10n.notificationActionDone),
        AndroidNotificationAction(
          'action_snooze',
          l10n.notificationActionSnooze,
        ),
        AndroidNotificationAction('action_skip', l10n.notificationActionSkip),
      ],
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(categoryIdentifier: 'habit_actions'),
    );

    final notificationId = id.hashCode;

    await _notifications.zonedSchedule(
      id: notificationId,
      title: 'Evolve • $title',
      body: _getHabitMessage(title, l10n),
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'habit|$id|$title',
    );
  }

  Future<void> cancelHabitReminder(String id) async {
    await _notifications.cancel(id: id.hashCode);
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  String _getHabitMessage(String title, AppLocalizations l10n) {
    final messages = [
      l10n.habitReminderMessage1(title),
      l10n.habitReminderMessage2(title),
      l10n.habitReminderMessage3(title),
      l10n.habitReminderMessage4(title),
      l10n.habitReminderMessage5(title),
      l10n.habitReminderMessage6(title),
      l10n.habitReminderMessage7(title),
      l10n.habitReminderMessage8(title),
      l10n.habitReminderMessage9(title),
      l10n.habitReminderMessage10(title),
      l10n.habitReminderMessage11(title),
      l10n.habitReminderMessage12(title),
      l10n.habitReminderMessage13(title),
      l10n.habitReminderMessage14(title),
      l10n.habitReminderMessage15(title),
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
    // Initialize Supabase if needed
    try {
      Supabase.instance.client;
    } catch (e) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    }
  }

  NotificationService()._onNotificationResponse(response);
}
