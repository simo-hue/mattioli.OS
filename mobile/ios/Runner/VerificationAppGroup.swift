// Auto-verified habits — shared App Group bridge between the Runner app and the
// DeviceActivityMonitor extension.
//
// ⚠️ UNVERIFIED ON THIS DEV MACHINE: there is no iOS SDK here (Command Line
// Tools only), so none of the verification Swift can be compiled or typechecked
// locally. Compile + fix in Xcode on the machine with full Xcode. See
// TO_SIMO_DO.md ("Auto-Verified Habits — native / Xcode").

import Foundation

/// Shared constants for the App Group that carries screen-time signals from the
/// DeviceActivityMonitor extension back to the app.
///
/// `suiteName` MUST match the App Group you add to BOTH the Runner and the
/// extension in Signing & Capabilities (TO_SIMO_DO). Change it in this one place.
enum VerificationAppGroup {
  /// TODO(Simone): match the App Group id you create in Xcode.
  static let suiteName = "group.com.simo.evolve.verification"

  /// Key holding an array of pending signal dictionaries, each:
  /// `["goalId": String, "date": "yyyy-MM-dd", "kind": "reachedThreshold" | "stayedUnder"]`.
  static let pendingSignalsKey = "pending_screen_time_signals"

  /// Key holding the app-written monitor specs the extension reads to know which
  /// goal each DeviceActivity event maps to:
  /// `["<eventName>": ["goalId": String]]`.
  static let monitorSpecsKey = "screen_time_monitor_specs"

  static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }
}
