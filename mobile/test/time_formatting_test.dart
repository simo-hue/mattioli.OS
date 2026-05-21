import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/time_formatting.dart';

void main() {
  group('AppTimeFormatting', () {
    test('formats stored times with 24 hour format', () {
      expect(
        AppTimeFormatting.formatStoredTime('00:05', use24hFormat: true),
        '00:05',
      );
      expect(
        AppTimeFormatting.formatStoredTime('13:30', use24hFormat: true),
        '13:30',
      );
    });

    test('formats stored times with 12 hour format', () {
      expect(
        AppTimeFormatting.formatStoredTime('00:05', use24hFormat: false),
        '12:05 AM',
      );
      expect(
        AppTimeFormatting.formatStoredTime('12:00', use24hFormat: false),
        '12:00 PM',
      );
      expect(
        AppTimeFormatting.formatStoredTime('21:30', use24hFormat: false),
        '9:30 PM',
      );
    });

    test('serializes TimeOfDay values for storage', () {
      expect(
        AppTimeFormatting.serializeTimeOfDay(
          const TimeOfDay(hour: 7, minute: 4),
        ),
        '07:04',
      );
    });

    test('rejects invalid stored times', () {
      expect(
        () => AppTimeFormatting.parseTimeOfDay('24:00'),
        throwsFormatException,
      );
      expect(
        () => AppTimeFormatting.parseTimeOfDay('09'),
        throwsFormatException,
      );
    });
  });
}
