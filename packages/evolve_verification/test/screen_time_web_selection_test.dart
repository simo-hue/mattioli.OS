// F45 — a websites-only Screen Time selection was thrown away as "empty".
//
// `FamilyActivitySelection` has three token sets: applications, categories and
// WEB DOMAINS. The native picker reported only the first two, and `isEmpty` was
// defined as `applicationCount == 0 && categoryCount == 0` — so a user who
// picked only web domains and tapped Done got a perfectly valid, non-empty
// selection blob back, which the habit editor then nulled out with
// "selectionEmpty".
//
// Not a hypothetical capability: `Runner.entitlements` declares
// `com.apple.developer.family-controls.app-and-website-usage`, and the
// monitoring path already feeds `selection.webDomainTokens` into the
// `DeviceActivityEvent` — so the selection would have been monitored correctly
// if it had ever got past the gate.
//
// No copy change is involved: the editor renders `selectionSummary(count:
// totalCount)`, which is the metric-agnostic "{count} selected".
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a websites-only selection is not empty', () {
    const result = ScreenTimeSelectionResult(
      blob: 'base64-blob',
      applicationCount: 0,
      categoryCount: 0,
      webDomainCount: 3,
    );

    expect(result.isEmpty, isFalse);
    expect(result.totalCount, 3);
  });

  test('a genuinely empty selection is still empty', () {
    // The gate exists for a real reason — an empty selection cannot be
    // monitored and must never be read as "watch everything".
    const result = ScreenTimeSelectionResult(
      blob: 'base64-blob',
      applicationCount: 0,
      categoryCount: 0,
      webDomainCount: 0,
    );

    expect(result.isEmpty, isTrue);
    expect(result.totalCount, 0);
  });

  test('the three metrics are summed, not ranked', () {
    const result = ScreenTimeSelectionResult(
      blob: 'base64-blob',
      applicationCount: 2,
      categoryCount: 1,
      webDomainCount: 4,
    );

    expect(result.totalCount, 7);
    expect(result.isEmpty, isFalse);
  });
}
