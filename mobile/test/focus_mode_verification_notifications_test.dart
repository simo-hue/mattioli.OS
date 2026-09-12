// Focus Mode is documented as "Pauses all reminders and notifications", and the
// notification settings screen says it overrides every other switch. It was
// enforced in exactly one place — `_runNotificationSync`'s `cancelAll()` — which
// only clears PENDING SCHEDULED requests. The three verification banners
// (couldn't-verify nudge, celebration, end-of-day failure summary) are
// `show()`n immediately from `runVerificationReconcile`, so cancelAll can never
// reach them: with Focus Mode on, a foreground still fired a nudge — and
// `verificationNudges` defaults to true, so the user never opted in.
//
// The nudge's persisted "already nudged" marker must NOT be written while the
// banner is suppressed, otherwise the day would be silently consumed and never
// surface once Focus Mode goes off again.
import 'package:evolve_verification/evolve_verification.dart';
import 'package:evolve_verification/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/verification_providers.dart';
import 'package:mattioli_os/core/verification_wiring.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/settings_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _goalId = 'g-focus';

final _goal = Goal(
  id: _goalId,
  title: 'Walk 10k',
  color: const Color(0xFF3B82F6),
  startDate: DateTime(2020, 1, 1),
  verificationRule: VerificationCatalog.steps.ruleWith(10000),
  verifyEffectiveFrom: DateTime(2020, 1, 1),
);

class _Goals extends GoalsNotifier {
  @override
  List<Goal> build() => [_goal];
}

class _EmptyLogs extends HabitLogsNotifier {
  @override
  HabitLogsMap build() => const {};
}

/// Focus Mode ON with the nudge pref at its shipped default (true) — the exact
/// state the bug needs.
class _FocusOn extends AppSettingsNotifier {
  @override
  AppSettings build() => super
      .build()
      .copyWith(focusMode: true, verificationNudges: true);

  @override
  set state(AppSettings value) =>
      super.state = value.copyWith(focusMode: true, verificationNudges: true);
}

/// Focus Mode OFF — the control, proving the fix did not simply mute the nudge.
class _FocusOff extends AppSettingsNotifier {
  @override
  AppSettings build() => super
      .build()
      .copyWith(focusMode: false, verificationNudges: true);

  @override
  set state(AppSettings value) =>
      super.state = value.copyWith(focusMode: false, verificationNudges: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> notificationCalls;
  late FakeVerificationStateStore store;

  setUp(() {
    FlutterLocalNotificationsPlatform.instance =
        IOSFlutterLocalNotificationsPlugin();
    notificationCalls = <MethodCall>[];
    store = FakeVerificationStateStore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        notificationCalls.add(call);
        return null;
      },
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_data_mode': 'private',
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      null,
    );
  });

  /// Runs one reconcile pass through the real wiring, with no Health data at
  /// all — so every backfilled day is couldn't-verify and the report carries
  /// nudges.
  Future<void> runPass(WidgetTester tester, {required bool focusMode}) async {
    // Set inside the test body, not setUp: `testWidgets` asserts every
    // foundation debug variable is back to null before its own tearDowns run.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final prefs = await SharedPreferences.getInstance();
    late WidgetRef captured;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        goalsProvider.overrideWith(_Goals.new),
        habitLogsProvider.overrideWith(_EmptyLogs.new),
        settingsProvider
            .overrideWith(focusMode ? _FocusOn.new : _FocusOff.new),
        healthKitBridgeProvider.overrideWithValue(FakeHealthKitBridge()),
        screenTimeBridgeProvider.overrideWithValue(FakeScreenTimeBridge()),
        verificationStateStoreProvider.overrideWith((ref) async => store),
      ],
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        return const SizedBox();
      }),
    ));
    await tester.pump();
    await runVerificationReconcile(captured);
    await tester.pump();
    // Every notification call has already been made; clear it here so the
    // expectations below can fail without tripping the invariant check.
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('Focus Mode suppresses the couldn\'t-verify nudge', (t) async {
    await runPass(t, focusMode: true);

    expect(
      notificationCalls.where((c) => c.method == 'show'),
      isEmpty,
      reason: 'Focus Mode promises it pauses all notifications; an immediate '
          'show() is exactly what cancelAll() cannot reach',
    );
    expect(
      store.nudged[_goalId] ?? const <DateTime>{},
      isEmpty,
      reason: 'a suppressed nudge must not consume its day — it has to be '
          'able to surface once Focus Mode is off',
    );
  });

  testWidgets('with Focus Mode off the nudge still fires', (t) async {
    await runPass(t, focusMode: false);

    expect(
      notificationCalls.where((c) => c.method == 'show'),
      isNotEmpty,
      reason: 'the control: the fix must gate on Focus Mode, not mute the '
          'nudge outright',
    );
  });
}
