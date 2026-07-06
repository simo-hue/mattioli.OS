// The shared red→green performance scale used by the home monthly-view cells
// and the yearly-view month bars (they must stay in sync, hence one helper).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/performance_color.dart';

void main() {
  group('performanceHue', () {
    test('0% completion is red (hue 0), 100% is green (hue 142)', () {
      expect(performanceHue(0), 0);
      expect(performanceHue(1), 142);
      expect(performanceHue(0.5), 71);
    });

    test('clamps out-of-range ratios', () {
      expect(performanceHue(-0.5), 0);
      expect(performanceHue(2), 142);
    });
  });

  group('performanceColor', () {
    test('carries the requested alpha (subtle background tint)', () {
      final tint = performanceColor(0.5, lightness: 0.1, alpha: 0.3);
      expect(tint.a, closeTo(0.3, 0.01));
    });

    test('a solid bar is fully opaque by default', () {
      expect(performanceColor(1.0).a, closeTo(1.0, 0.01));
    });

    test('reproduces the monthly-view cell background exactly', () {
      // Guards the refactor: the shared helper must equal the old inline formula
      // HSLColor.fromAHSL(1, hue, 0.7, 0.1).toColor().withValues(alpha: 0.3).
      const pct = 0.42;
      final old = const HSLColor.fromAHSL(1.0, pct * 142.0, 0.7, 0.1)
          .toColor()
          .withValues(alpha: 0.3);
      final shared =
          performanceColor(pct, saturation: 0.7, lightness: 0.1, alpha: 0.3);
      expect(shared, old);
    });
  });
}
