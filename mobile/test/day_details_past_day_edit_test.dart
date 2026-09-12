// The day sheet on a day older than yesterday.
//
// Those days used to be locked outright: a tap showed "You can only edit today
// and yesterday!" and wrote nothing, so a mis-scored day from last week could
// never be corrected. They are now editable through an explicit Edit → Save
// flow, while today and yesterday keep the one-tap check-in. These pin the
// contract of that flow against the REAL notifier over a fake private store:
//
//   * outside edit mode a tap on an older day writes nothing and says why;
//   * edit mode stages the same cycle a tap performs, and nothing reaches the
//     store until Save;
//   * Save writes exactly the staged rows, then recomputes the streaks of the
//     habits it changed (the single-day write leaves every later row stale);
//   * closing a dirty sheet asks first, and Discard throws the staging away;
//   * a failed write keeps the sheet in edit mode with the row still staged;
//   * a quick-log day (today) still writes on the tap and offers no pencil.
import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mattioli_os/core/calendar_days.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/widgets/day_details_modal.dart';
import 'package:mattioli_os/ui/widgets/target_entry_sheet.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_private_data_store.dart';

/// Seeds the day under test with a persisted status and records every log
/// write, so a test can assert what reached the store — not just what the
/// in-memory map shows.
class _SeededStore extends FakePrivateDataStore {
  _SeededStore(this.seed);

  final Map<String, Map<String, String>> seed;
  final List<Map<String, Object?>> logWrites = <Map<String, Object?>>[];
  final List<String> logDeletes = <String>[];

  @override
  Future<Map<String, Map<String, String>>> loadHabitLogs() async => {
        for (final e in seed.entries) e.key: Map<String, String>.from(e.value),
      };

  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int? streak,
    double? value,
  }) async {
    logWrites.add({'goalId': goalId, 'date': date, 'status': status});
    await super.setHabitLog(
      goalId: goalId,
      date: date,
      status: status,
      streak: streak,
      value: value,
    );
  }

  @override
  Future<void> deleteHabitLog({
    required String goalId,
    required String date,
  }) async {
    logDeletes.add('$goalId@$date');
    await super.deleteHabitLog(goalId: goalId, date: date);
  }
}

/// A store whose log write fails, to exercise the partial-save path.
class _ThrowingStore extends _SeededStore {
  _ThrowingStore(super.seed);

  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int? streak,
    double? value,
  }) async =>
      throw StateError('disk full');
}

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The sheet formats its title with `DateFormat`, which needs the intl date
  // symbols that main.dart loads at startup; and the copy asserted below is
  // English, so pin the slang locale rather than inherit the host's.
  setUpAll(() => initializeDateFormatting());
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  // Relative to the real clock, because the sheet asks it: ten days back is
  // unambiguously past the quick-log window on either side of a DST change.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final oldDay = shiftDays(today, -10);

  Goal habit(String id, String title, {HabitTarget? target}) => Goal(
        id: id,
        title: title,
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2020, 1, 1),
        target: target,
      );

  // `tester.pump`, never `Future.delayed`: a widget test runs under FakeAsync,
  // where a timer only fires when the tester advances the clock — awaiting a
  // real delay would wait forever.
  Future<ProviderContainer> container(
    WidgetTester tester,
    FakePrivateDataStore store, {
    required List<Goal> goals,
  }) async {
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith((ref) => store),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
      ],
    );
    addTearDown(c.dispose);
    // Warm both notifiers and let their private-store loads land before any
    // write, or a first read after a write would overwrite it with the seed.
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier);
    await tester.pump();
    for (final g in goals) {
      await c.read(goalsProvider.notifier).addHabit(g);
    }
    await tester.pump();
    return c;
  }

  /// Pumps an app whose only button opens the sheet for [date] as the real
  /// modal route, so the X, the barrier and `Navigator.pop` behave as on device.
  Future<void> pumpSheet(
    WidgetTester tester,
    ProviderContainer c,
    DateTime date,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: TranslationProvider(
          child: MaterialApp(
            theme: AppTheme.darkTheme(null),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => DayDetailsModal(date: date),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder savePill() => find.ancestor(
        of: find.text('Save'),
        matching: find.byType(CupertinoButton),
      );

  testWidgets('an older day: a tap writes nothing and names the way in',
      (tester) async {
    final store = _SeededStore({
      _key(oldDay): {'g1': 'done'},
    });
    final c = await container(tester, store, goals: [habit('g1', 'Read')]);
    await pumpSheet(tester, c, oldDay);

    expect(find.byIcon(LucideIcons.pencil), findsOneWidget);
    await tester.tap(find.text('Read'));
    await tester.pump();

    expect(find.text('Tap Edit to change this day'), findsOneWidget);
    expect(store.logWrites, isEmpty);
    expect(store.logDeletes, isEmpty);
    expect(c.read(habitLogsProvider)[_key(oldDay)]?['g1'], 'done');
  });

  testWidgets('edit mode stages the cycle; Save writes the staged rows and '
      'recomputes the streaks of exactly those habits', (tester) async {
    final store = _SeededStore({
      _key(oldDay): {'g1': 'done'},
    });
    final c = await container(
      tester,
      store,
      goals: [habit('g1', 'Read'), habit('g2', 'Run')],
    );
    await pumpSheet(tester, c, oldDay);

    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.pumpAndSettle();
    // Save is offered but has nothing to save yet.
    expect(tester.widget<CupertinoButton>(savePill()).onPressed, isNull);

    // done → missed for Read; none → done for Run. Staged, not written.
    await tester.tap(find.text('Read'));
    await tester.pump();
    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(store.logWrites, isEmpty);
    expect(c.read(habitLogsProvider)[_key(oldDay)]?['g1'], 'done');
    expect(c.read(habitLogsProvider)[_key(oldDay)]?['g2'], isNull);
    expect(tester.widget<CupertinoButton>(savePill()).onPressed, isNotNull);

    await tester.tap(savePill());
    await tester.pumpAndSettle();

    final written = {
      for (final w in store.logWrites) w['goalId']: w['status'],
    };
    expect(written, {'g1': 'missed', 'g2': 'done'});
    expect(store.logWrites.every((w) => w['date'] == _key(oldDay)), isTrue);
    expect(c.read(habitLogsProvider)[_key(oldDay)], {
      'g1': 'missed',
      'g2': 'done',
    });
    // The forward repair ran once, for the two habits whose history changed.
    expect(store.streakRecomputes, [
      {'g1', 'g2'},
    ]);
    // Back in view mode, sheet still open, the batch acknowledged.
    expect(find.text('Changes saved'), findsOneWidget);
    expect(find.byIcon(LucideIcons.pencil), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('cycling a row back to its persisted state un-stages it',
      (tester) async {
    final store = _SeededStore({
      _key(oldDay): {'g1': 'done'},
    });
    final c = await container(tester, store, goals: [habit('g1', 'Read')]);
    await pumpSheet(tester, c, oldDay);
    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.pumpAndSettle();

    // done → missed → none → done: a full turn of the cycle.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Read'));
      await tester.pump();
    }
    expect(
      tester.widget<CupertinoButton>(savePill()).onPressed,
      isNull,
      reason: 'a row that reads exactly as persisted is not a change to save',
    );
    expect(store.logWrites, isEmpty);
  });

  testWidgets('closing a dirty sheet asks first; Keep editing keeps it, '
      'Discard closes it without writing', (tester) async {
    final store = _SeededStore({
      _key(oldDay): {'g1': 'done'},
    });
    final c = await container(tester, store, goals: [habit('g1', 'Read')]);
    await pumpSheet(tester, c, oldDay);
    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pump();

    // The X. Found by its tooltip: the staged 'missed' card now carries an X
    // glyph of its own, so the icon alone is ambiguous.
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Save'), findsOneWidget, reason: 'still editing');

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing, reason: 'the sheet is gone');
    expect(store.logWrites, isEmpty);
    expect(store.logDeletes, isEmpty);
    expect(c.read(habitLogsProvider)[_key(oldDay)]?['g1'], 'done');
  });

  testWidgets('a clean sheet closes at once, no question asked',
      (tester) async {
    final store = _SeededStore({
      _key(oldDay): {'g1': 'done'},
    });
    final c = await container(tester, store, goals: [habit('g1', 'Read')]);
    await pumpSheet(tester, c, oldDay);
    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('a failed write keeps the sheet in edit mode with the row '
      'still staged, and runs no streak repair', (tester) async {
    final store = _ThrowingStore({
      _key(oldDay): {'g1': 'done'},
    });
    final c = await container(tester, store, goals: [habit('g1', 'Read')]);
    await pumpSheet(tester, c, oldDay);
    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pump();

    await tester.tap(savePill());
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOneWidget, reason: 'still in edit mode');
    expect(
      tester.widget<CupertinoButton>(savePill()).onPressed,
      isNotNull,
      reason: 'the failed row is still staged, so a retry is one tap',
    );
    expect(find.text('Changes saved'), findsNothing);
    expect(store.streakRecomputes, isEmpty);
    // The optimistic update was rolled back with the write.
    expect(c.read(habitLogsProvider)[_key(oldDay)]?['g1'], 'done');
    // The failed write is logged, and the logger persists its buffer on a
    // debounce timer; let it fire so the test ends with no timer pending.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a quantitative habit: in edit mode the entry sheet runs in '
      'draft mode and the number is written only on Save', (tester) async {
    final target =
        TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);
    final store = _SeededStore({});
    final c = await container(
      tester,
      store,
      goals: [habit('g1', 'Push-ups', target: target)],
    );
    await pumpSheet(tester, c, oldDay);
    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Push-ups'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<TargetEntrySheet>(find.byType(TargetEntrySheet));
    expect(sheet.onChanged, isNotNull, reason: 'draft mode, not live');

    // Two steps of 20, then close the sheet: nothing reached the store, the
    // card previews 40 and Save is enabled.
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pump();
    Navigator.of(tester.element(find.byType(TargetEntrySheet))).pop();
    await tester.pumpAndSettle();
    expect(store.calls.where((c) => c == 'setHabitProgress'), isEmpty);
    expect(store.logWrites, isEmpty);
    expect(find.text('40 / 80'), findsOneWidget);
    expect(tester.widget<CupertinoButton>(savePill()).onPressed, isNotNull);

    await tester.tap(savePill());
    await tester.pumpAndSettle();

    expect(store.calls.where((c) => c == 'setHabitProgress'), hasLength(1));
    expect(c.read(habitProgressProvider)[_key(oldDay)]?['g1'], 40);
    // 40 of 80 on a closed day: the verdict the number derives is a miss, and
    // the forward streak repair ran for the habit.
    expect(c.read(habitLogsProvider)[_key(oldDay)]?['g1'], 'missed');
    expect(store.streakRecomputes, [
      {'g1'},
    ]);
    expect(find.text('Changes saved'), findsOneWidget);
    expect(find.byIcon(LucideIcons.pencil), findsOneWidget);
  });

  testWidgets('today is a quick-log day: the tap writes at once and there is '
      'no pencil', (tester) async {
    final store = _SeededStore({});
    final c = await container(tester, store, goals: [habit('g1', 'Read')]);
    await pumpSheet(tester, c, today);

    expect(find.byIcon(LucideIcons.pencil), findsNothing);
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    expect(store.logWrites, hasLength(1));
    expect(store.logWrites.single['status'], 'done');
    expect(store.logWrites.single['date'], _key(today));
    expect(find.text('Tap Edit to change this day'), findsNothing);
  });
}
