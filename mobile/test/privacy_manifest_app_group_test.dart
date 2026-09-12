// F58 — the Runner privacy manifest declared a reason that does not describe
// what the binary does.
//
// `NSPrivacyAccessedAPICategoryUserDefaults` listed CA92.1 alone: "access
// information from the app itself, app extensions or App Clips with the SAME
// Team ID and app group"… no — CA92.1 is the app-internal case, which is what
// `shared_preferences` needs. But the Runner target ALSO touches
// `UserDefaults(suiteName: "group.com.simo.evolve.verification")`, the suite it
// shares with the DeviceActivityMonitor extension:
// `syncMonitoredGoals` writes the monitored-spec record and the scheduled
// weekdays, `setLocalizedNotificationCopy` writes the notification strings, and
// `drainSignals` reads and clears the pending-signal buffer. That is 1C8F.1,
// App Group members.
//
// The extension's own manifest already states the distinction in prose — it was
// only the app target's that was missing the code. `Runner.entitlements` carries
// `com.apple.security.application-groups`, so the access is real, not
// theoretical.
//
// Asserted rather than eyeballed because the manifest is read at submission
// time, not at build time: nothing else in this repo fails when the two drift.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
  final manifest = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();

  test('the app target really does touch the App Group suite', () {
    // The premise. If this ever stops being true, the assertion below is the one
    // to revisit — not to delete quietly.
    expect(appDelegate, contains('VerificationAppGroup.defaults'));
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('com.apple.security.application-groups'),
    );
  });

  test('the UserDefaults reasons cover the App Group access', () {
    final userDefaultsBlock = RegExp(
      r'NSPrivacyAccessedAPICategoryUserDefaults.*?</array>',
      dotAll: true,
    ).firstMatch(manifest);

    expect(userDefaultsBlock, isNotNull,
        reason: 'the manifest must still declare the UserDefaults category');

    final reasons = userDefaultsBlock!.group(0)!;
    expect(reasons, contains('CA92.1'),
        reason: 'shared_preferences still writes the app-internal suite');
    expect(
      reasons,
      contains('1C8F.1'),
      reason: 'ScreenTimeBridge reads and writes '
          'UserDefaults(suiteName: group.com.simo.evolve.verification), which '
          'is App Group access, not app-internal access',
    );
  });
}
