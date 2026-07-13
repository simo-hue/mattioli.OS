import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerificationRule columns', () {
    test('round-trips through toColumns / fromColumns', () {
      final rule = VerificationCatalog.screenTimeTotal.ruleWith(90);
      final row = rule.toColumns();

      expect(row['verify_provider'], 'screentime');
      expect(row['verify_metric'], 'screen_time_total');
      expect(row['verify_comparator'], 'lte');
      expect(row['verify_threshold'], 90);
      expect(row['verify_unit'], 'minutes');

      expect(VerificationRule.fromColumns(row), rule);
    });

    test('fromColumns returns null for a manual habit (all null)', () {
      expect(VerificationRule.fromColumns(VerificationRule.nullColumns), isNull);
      expect(VerificationRule.fromColumns(const {}), isNull);
    });

    test('fromColumns returns null when any field is missing (no half-rule)', () {
      final partial = VerificationCatalog.steps.ruleWith(10000).toColumns()
        ..remove('verify_comparator');
      expect(VerificationRule.fromColumns(partial), isNull);
    });

    test('fromColumns tolerates int thresholds from the DB', () {
      final row = VerificationCatalog.steps.ruleWith(10000).toColumns();
      row['verify_threshold'] = 10000; // int, as SQLite may return
      final parsed = VerificationRule.fromColumns(row);
      expect(parsed, isNotNull);
      expect(parsed!.threshold, 10000.0);
    });

    test('copyWith changes only the threshold', () {
      final rule = VerificationCatalog.steps.ruleWith(10000);
      final edited = rule.copyWith(threshold: 12000);
      expect(edited.threshold, 12000);
      expect(edited.metricKey, rule.metricKey);
      expect(edited, isNot(rule));
    });

    test('value equality holds', () {
      expect(
        VerificationCatalog.steps.ruleWith(10000),
        VerificationCatalog.steps.ruleWith(10000),
      );
    });
  });
}
