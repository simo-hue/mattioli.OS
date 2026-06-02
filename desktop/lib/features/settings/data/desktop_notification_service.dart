import 'dart:io';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class DesktopNotificationService {
  DesktopNotificationService._();

  static final instance = DesktopNotificationService._();

  final _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get canScheduleDaily => Platform.isMacOS || Platform.isWindows;

  String get platformSummary {
    if (Platform.isMacOS) return 'Scheduling giornaliero attivo su macOS.';
    if (Platform.isWindows) {
      return 'Windows pianifica la prossima occorrenza a ogni avvio.';
    }
    return 'Linux mostra notifiche immediate, ma non supporta lo scheduling.';
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

      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linux = LinuxInitializationSettings(
        defaultActionName: 'Apri Evolve',
      );
      const windows = WindowsInitializationSettings(
        appName: 'Evolve',
        appUserModelId: 'com.simo.evolve.desktop',
        guid: 'b989933a-4c53-4c37-843d-7a86cc207bc4',
      );
      await _notifications.initialize(
        settings: const InitializationSettings(
          macOS: darwin,
          linux: linux,
          windows: windows,
        ),
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
        title: 'Evolve - Morning Brief',
        body: 'Rivedi le abitudini di oggi e scegli da dove iniziare.',
      );
      for (final habit in habits) {
        final reminderTime = habit.reminderTime;
        if (reminderTime == null) continue;
        await _scheduleDaily(
          id: habit.id.hashCode,
          time: reminderTime,
          title: 'Evolve - ${habit.title}',
          body: 'E il momento di completare la tua abitudine.',
          payload: 'habit|${habit.id}|${habit.title}',
        );
      }
    }

    if (eveningReview) {
      await _scheduleDaily(
        id: 1,
        time: eveningReviewTime,
        title: 'Evolve - Review serale',
        body: 'Consolida la giornata e aggiorna i progressi.',
      );
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required String time,
    required String title,
    required String body,
    String? payload,
  }) async {
    final scheduledDate = _nextInstance(time);
    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: Platform.isMacOS
          ? DateTimeComponents.time
          : null,
      payload: payload,
    );
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
