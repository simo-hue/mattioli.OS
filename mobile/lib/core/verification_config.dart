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
  /// Master switch. Flip to true only once the native layer is wired and tested.
  static const bool enabled = false;

  /// HealthKit-verified goals (steps, sleep, mindful minutes, …).
  static const bool healthKitEnabled = enabled;

  /// Screen Time goals — additionally requires the approved Family Controls
  /// distribution entitlement to function on TestFlight / the App Store.
  static const bool screenTimeEnabled = enabled;
}
