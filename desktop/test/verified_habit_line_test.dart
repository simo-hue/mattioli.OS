import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/verified_habit_line.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Widget _app(Widget child) => MaterialApp(
      theme: EvolveTheme.dark(EvolveColors.primaryStrong),
      home: Scaffold(body: child),
    );

DashboardHabit _habit({
  String title = 'Morning walk',
  VerificationRule? rule,
  List<VerificationRule>? extra,
  VerificationJoin? join,
  DateTime? startDate,
  DateTime? verifyEffectiveFrom,
}) =>
    DashboardHabit(
      id: 'h',
      title: title,
      color: const Color(0xFF3B82F6),
      streak: 0,
      weeklyProgress: const [],
      state: HabitState.pending,
      startDate: startDate,
      verificationRule: rule,
      additionalConditions: extra,
      verificationJoin: join,
      verifyEffectiveFrom: verifyEffectiveFrom,
    );

void main() {
  final steps = VerificationCatalog.steps.ruleWith(10000);
  final workout = VerificationCatalog.workout.ruleWith(30);

  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  group('habitVerificationLabel', () {
    test('names the rule a habit is measured against', () {
      expect(
        habitVerificationLabel(
            conditions: [steps], join: null, habitTitle: 'Morning walk'),
        '≥ 10,000 Steps',
      );
    });

    test('drops the metric label when it only echoes the habit name', () {
      // The common case — creating the rule on iPhone auto-fills the name from
      // this very label.
      expect(
        habitVerificationLabel(
            conditions: [steps], join: null, habitTitle: ' steps '),
        '≥ 10,000',
      );
    });

    test('a compound habit reads as its join and condition count', () {
      expect(
        habitVerificationLabel(
          conditions: [steps, workout],
          join: VerificationJoin.and,
          habitTitle: 'Full training',
        ),
        'All 2 conditions',
      );
      expect(
        habitVerificationLabel(
          conditions: [steps, workout],
          join: VerificationJoin.or,
          habitTitle: 'Movement',
        ),
        'Any of 2 conditions',
      );
    });

    test('a compound with no join reads as "any", like the engine treats it',
        () {
      // The iPhone's engine coerces a null join to OR before evaluating, so the
      // label must not claim a stricter rule than the one actually run.
      expect(
        habitVerificationLabel(
            conditions: [steps, workout], join: null, habitTitle: 'Movement'),
        'Any of 2 conditions',
      );
    });

    test('a manual habit has no label', () {
      expect(
        habitVerificationLabel(
            conditions: const [], join: null, habitTitle: 'Read'),
        '',
      );
    });
  });

  group('helper edges', () {
    test('an unknown metric key falls back to the key itself', () {
      // A rule written by a newer iPhone: better to show the raw key than blank.
      expect(verificationTemplateLabel('teleportation_minutes'),
          'teleportation_minutes');
      expect(
        habitVerificationLabel(
          conditions: [
            const VerificationRule(
              provider: VerificationProvider.healthKit,
              metricKey: 'teleportation_minutes',
              comparator: VerificationComparator.atLeast,
              threshold: 5,
              unit: VerificationUnit.minutes,
            ),
          ],
          join: null,
          habitTitle: 'Beam up',
        ),
        '≥ 5 min teleportation_minutes',
      );
    });

    test('a plain count emits no unit token', () {
      expect(verificationUnitSuffix(VerificationUnit.count), '');
      expect(verificationUnitSuffix(VerificationUnit.minutes), isNotEmpty);
      expect(verificationUnitSuffix(VerificationUnit.hours), isNotEmpty);
      expect(verificationUnitSuffix(VerificationUnit.kilocalories), isNotEmpty);
      expect(verificationUnitSuffix(VerificationUnit.kilometers), isNotEmpty);
    });

    test('omits the metric label when asked', () {
      expect(verificationRuleSummary(steps, includeMetricLabel: false),
          '≥ 10,000');
    });

    test('an atMost rule reads as a ceiling', () {
      expect(
        verificationRuleSummary(VerificationCatalog.screenTimeTotal.ruleWith(120)),
        startsWith('≤ 120 '),
      );
    });
  });

  group('threshold formatting', () {
    test('groups thousands in the active locale\'s own convention', () async {
      // Non-base locales are deferred, so they must be loaded, not built sync.
      await LocaleSettings.setLocale(AppLocale.it);
      addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));
      expect(verificationRuleSummary(steps), '≥ 10.000 Passi');
    });

    test('a fractional threshold uses the locale decimal separator', () async {
      await LocaleSettings.setLocale(AppLocale.it);
      addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));
      expect(
        verificationRuleSummary(VerificationCatalog.distance.ruleWith(2.5)),
        startsWith('≥ 2,5 '),
      );
    });
  });

  group('VerifiedHabitLine', () {
    testWidgets('shows a shield and the rule', (tester) async {
      await tester.pumpWidget(_app(VerifiedHabitLine(
        conditions: [steps],
        join: null,
        habitTitle: 'Morning walk',
      )));

      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      expect(find.text('≥ 10,000 Steps'), findsOneWidget);
    });

    testWidgets('falls back to the generic label when the rule post-dates the day',
        (tester) async {
      await tester.pumpWidget(_app(VerifiedHabitLine(
        conditions: [steps],
        join: null,
        habitTitle: 'Morning walk',
        ruleInEffect: false,
      )));

      expect(find.text('≥ 10,000 Steps'), findsNothing);
      expect(find.text('Auto-verified'), findsOneWidget);
    });

    testWidgets('renders nothing for a manual habit', (tester) async {
      await tester.pumpWidget(_app(const VerifiedHabitLine(
        conditions: [],
        join: null,
        habitTitle: 'Read',
      )));

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('keeps to one line when the label cannot fit', (tester) async {
      await tester.pumpWidget(_app(SizedBox(
        width: 90,
        child: VerifiedHabitLine(
          conditions: [VerificationCatalog.screenTimeTotal.ruleWith(120)],
          join: null,
          habitTitle: 'Detox',
        ),
      )));

      final text =
          tester.widget<Text>(find.text('≤ 120 min Total device usage'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });

  group('Habit.verificationRuleAppliesOn', () {
    test('a day before a rule edit is not governed by the current rule', () {
      final h = _habit(
        rule: steps,
        startDate: DateTime(2026, 1, 1),
        verifyEffectiveFrom: DateTime(2026, 6, 10),
      );
      expect(h.verificationRuleAppliesOn(DateTime(2026, 6, 9)), isFalse);
      expect(h.verificationRuleAppliesOn(DateTime(2026, 6, 10)), isTrue);
      expect(h.verificationRuleAppliesOn(DateTime(2026, 6, 10, 18)), isTrue);
    });

    test('a null anchor falls back to startDate', () {
      final h = _habit(rule: steps, startDate: DateTime(2026, 3, 5));
      expect(h.verificationRuleAppliesOn(DateTime(2026, 3, 4)), isFalse);
      expect(h.verificationRuleAppliesOn(DateTime(2026, 3, 5)), isTrue);
    });

    test('an anchor before startDate cannot pull the rule earlier', () {
      final h = _habit(
        rule: steps,
        startDate: DateTime(2026, 3, 5),
        verifyEffectiveFrom: DateTime(2026, 1, 1),
      );
      expect(h.verificationRuleAppliesOn(DateTime(2026, 3, 4)), isFalse);
      expect(h.verificationRuleAppliesOn(DateTime(2026, 3, 5)), isTrue);
    });

    test('with no dates at all the rule reads as in effect', () {
      // Nothing known to contradict it; the pre-line badge showed unconditionally.
      expect(
        _habit(rule: steps).verificationRuleAppliesOn(DateTime(2026, 6, 1)),
        isTrue,
      );
    });

    test('a manual habit has no rule in effect on any day', () {
      expect(
        _habit().verificationRuleAppliesOn(DateTime(2026, 6, 1)),
        isFalse,
      );
    });
  });

  test('every locale defines the verification namespace en defines', () {
    // The namespace was copied wholesale from mobile; this stops a locale drifting
    // out of parity, which `fallback_strategy: base_locale` would otherwise hide
    // by silently rendering English.
    Map<String, Object?> read(String locale) => (jsonDecode(
          File('lib/i18n/$locale.i18n.json').readAsStringSync(),
        ) as Map<String, Object?>)['verification']! as Map<String, Object?>;

    Set<String> leaves(Map<String, Object?> m, [String prefix = '']) => {
          for (final e in m.entries)
            if (e.value is Map<String, Object?>)
              ...leaves(e.value! as Map<String, Object?>, '$prefix${e.key}.')
            else
              '$prefix${e.key}',
        };

    final base = leaves(read('en'));
    expect(base, contains('templates.steps'));
    expect(base, contains('compound.summaryAll'));
    for (final locale in ['it', 'de', 'es', 'ar']) {
      expect(leaves(read(locale)), base, reason: '$locale is out of parity');
    }

    // Placeholder parity too. slang derives each locale's parameter list from
    // THAT locale's placeholders, so a locale writing {n} where en writes
    // {count} emits an illegal override of the base method — a build break, not
    // a typo. Guard it here rather than discovering it at codegen time.
    Set<String> placeholders(Object? value) =>
        RegExp(r'\{(\w+)\}')
            .allMatches(value! as String)
            .map((m) => m.group(1)!)
            .toSet();

    final enCompound =
        read('en')['compound']! as Map<String, Object?>;
    for (final key in ['summaryAll', 'summaryAny']) {
      expect(placeholders(enCompound[key]), {'count'},
          reason: 'en.$key should interpolate {count}');
      for (final locale in ['it', 'de', 'es', 'ar']) {
        final other = read(locale)['compound']! as Map<String, Object?>;
        expect(placeholders(other[key]), placeholders(enCompound[key]),
            reason: '$locale.$key placeholders differ from en');
      }
    }
  });
}
