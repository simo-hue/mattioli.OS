// Auto-verified habits — native half of the Screen Time bridge (`evolve/screentime`).
//
// ⚠️ UNVERIFIED ON THIS DEV MACHINE (no iOS SDK). Compile + fix in Xcode.
// Requires: Family Controls capability (dev) + the approved DISTRIBUTION
// entitlement, iOS 16+, the App Group, and the DeviceActivityMonitor extension
// target. See TO_SIMO_DO.md.
//
// Contract mirrors mobile/lib/core/method_channel_screen_time_bridge.dart:
//   authorizationStatus() -> "approved"|"denied"|"notDetermined"
//   requestIndividualAuthorization() -> void
//   syncMonitoredGoals({goals:[{goalId,thresholdMinutes,weekdays}]}) -> void
//   drainSignals() -> [ {goalId,date,kind} ]
//
// v1 measures TOTAL device usage: an empty DeviceActivityEvent (includesAllActivity)
// with a per-day threshold. We never read raw minutes (impossible) — only the
// extension's threshold-crossed / interval-ended signals, drained from the App
// Group. `weekdays` is ignored natively (monitor daily; the Dart reconcile only
// visits scheduled days, so off-day signals are never consumed — D6).

import DeviceActivity
import FamilyControls
import Flutter
import Foundation

enum ScreenTimeBridge {
  /// Single event name per activity; the DeviceActivityName IS the goalId, so
  /// the extension maps signals back with `activity.rawValue`.
  private static let eventName = DeviceActivityEvent.Name("limit")

  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "evolve/screentime", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in handle(call, result) }
  }

  private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "authorizationStatus": authorizationStatus(result)
    case "requestIndividualAuthorization": requestIndividualAuthorization(result)
    case "syncMonitoredGoals": syncMonitoredGoals(args, result)
    case "drainSignals": drainSignals(result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Authorization

  private static func authorizationStatus(_ result: @escaping FlutterResult) {
    guard #available(iOS 16.0, *) else { result("notDetermined"); return }
    switch AuthorizationCenter.shared.authorizationStatus {
    case .approved: result("approved")
    case .denied: result("denied")
    default: result("notDetermined")
    }
  }

  private static func requestIndividualAuthorization(_ result: @escaping FlutterResult) {
    guard #available(iOS 16.0, *) else {
      result(FlutterError(code: "unsupported", message: "iOS 16+ required", details: nil)); return
    }
    Task {
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        main { result(nil) }
      } catch {
        main { result(FlutterError(code: "auth_failed", message: error.localizedDescription, details: nil)) }
      }
    }
  }

  // MARK: - Monitoring

  private static func syncMonitoredGoals(_ args: [String: Any]?, _ result: @escaping FlutterResult) {
    let goals = (args?["goals"] as? [[String: Any]]) ?? []
    let center = DeviceActivityCenter()
    // Reconcile by clearing everything and re-adding the current set (idempotent,
    // simplest correct approach for the small v1 goal count).
    center.stopMonitoring()
    guard !goals.isEmpty else { result(nil); return }

    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59),
      repeats: true
    )
    do {
      for goal in goals {
        guard
          let goalId = goal["goalId"] as? String,
          let minutes = (goal["thresholdMinutes"] as? NSNumber)?.intValue
        else { continue }
        let event = DeviceActivityEvent(
          applications: [],
          categories: [],
          webDomains: [],
          threshold: DateComponents(minute: minutes)
        )
        try center.startMonitoring(
          DeviceActivityName(goalId),
          during: schedule,
          events: [eventName: event]
        )
      }
      result(nil)
    } catch {
      // Surface Apple's 20-activity cap as the typed Dart exception; everything
      // else is a generic monitoring failure.
      if case DeviceActivityCenter.MonitoringError.excessiveActivities = error {
        result(FlutterError(code: "monitor_limit", message: "\(error)",
                            details: ["attempted": goals.count, "limit": 20]))
      } else {
        result(FlutterError(code: "monitoring_failed", message: "\(error)", details: nil))
      }
    }
  }

  // MARK: - Drain signals written by the extension

  private static func drainSignals(_ result: @escaping FlutterResult) {
    let defaults = VerificationAppGroup.defaults
    let signals = defaults?.array(forKey: VerificationAppGroup.pendingSignalsKey) as? [[String: Any]] ?? []
    defaults?.removeObject(forKey: VerificationAppGroup.pendingSignalsKey)
    result(signals)
  }

  private static func main(_ work: @escaping () -> Void) {
    DispatchQueue.main.async(execute: work)
  }
}
