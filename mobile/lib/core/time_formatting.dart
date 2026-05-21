import 'package:flutter/material.dart';

class AppTimeFormatting {
  const AppTimeFormatting._();

  static TimeOfDay parseTimeOfDay(String time) {
    final parts = time.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid time format', time);
    }

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw FormatException('Invalid time value', time);
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  static String serializeTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  static String serializeDateTime(DateTime dateTime) {
    return serializeTimeOfDay(
      TimeOfDay(hour: dateTime.hour, minute: dateTime.minute),
    );
  }

  static DateTime dateTimeForToday(String time) {
    final parsedTime = parseTimeOfDay(time);
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  static String formatStoredTime(String time, {required bool use24hFormat}) {
    return formatTimeOfDay(parseTimeOfDay(time), use24hFormat: use24hFormat);
  }

  static String formatTimeOfDay(TimeOfDay time, {required bool use24hFormat}) {
    if (use24hFormat) {
      return serializeTimeOfDay(time);
    }

    final period = time.hour >= 12 ? 'PM' : 'AM';
    final twelveHour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;

    return '$twelveHour:${time.minute.toString().padLeft(2, '0')} $period';
  }
}
