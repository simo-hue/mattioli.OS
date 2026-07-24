/// Compile-time feature flags for auto-verified habits (D12).
///
/// The whole feature ships **dark** until the native HealthKit / Screen Time
/// bridges and the `DeviceActivityMonitor` extension land AND the Family
/// Controls *distribution* entitlement is approved (see `TO_SIMO_DO.md`). While
/// [enabled] is false there is no verification UI, no reconcile-on-foreground,
/// and no DeviceActivity monitoring — mainline releases are unaffected.
///
/// HealthKit and Screen Time are gated independently so HealthKit-verified goals
/// can be switched on before Screen Time (HealthKit needs no Apple approval).
abstract final class VerificationConfig {
  /// HealthKit-verified goals (steps, sleep, exercise, mindful minutes, …).
  ///
  /// PREREQUISITE (Xcode): the Runner target needs the **HealthKit** capability
  /// and an **`NSHealthShareUsageDescription`** in Info.plist — without the
  /// usage string, the first authorization request CRASHES. No Apple approval
  /// is required, so this can go live before Screen Time.
  static const bool healthKitEnabled = true;

  /// Screen Time goals additionally need the `DeviceActivityMonitor` extension
  /// target + App Group + the **approved Family Controls distribution
  /// entitlement** (required even for TestFlight). Split per mode so Mode A can
  /// ship before Mode B's on-device semantics are confirmed.

  /// Mode A — verification against the apps/categories the user picks with
  /// `FamilyActivityPicker` (`screen_time_apps`). Ships **live**: the picked
  /// selection is stored device-local per goalId and the threshold measures the
  /// picked set as one DeviceActivity activity.
  static const bool screenTimeAppsEnabled = true;

  /// Mode B — total device usage (`screen_time_total`). Kept **dark** until the
  /// "empty selection = all activity" semantics are verified on a physical
  /// device (FamilyControls/DeviceActivity do not run in the Simulator). Flip to
  /// true only after that on-device test passes.
  static const bool screenTimeTotalEnabled = false;

  /// Any Screen Time mode on. The aggregate gate every reconcile / monitoring /
  /// lifecycle call site keys off; kept `const` so the dark path tree-shakes.
  static const bool screenTimeEnabled =
      screenTimeAppsEnabled || screenTimeTotalEnabled;

  /// Master switch — true when any provider is on. Gates the creation UI, the
  /// reconcile-on-foreground hook and the manual-freeze bookkeeping.
  static const bool enabled = healthKitEnabled || screenTimeEnabled;

  /// Compound verifiable habits (Q1–Q5): combine 2–3 HealthKit conditions with
  /// OR/AND ("10k steps OR 30 min exercise"). Ships **dark** until on-device QA;
  /// gated independently of [healthKitEnabled] so the single-metric feature is
  /// unaffected. When off: the "+ Add condition" UI is hidden and the reconcile
  /// wiring skips any compound goal synced from a device where it is on.
  /// Requires [healthKitEnabled] to do anything (every condition is HealthKit).
  static const bool compoundVerificationEnabled = false;
}
