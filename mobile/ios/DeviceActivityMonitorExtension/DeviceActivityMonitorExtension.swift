// Auto-verified habits — the DeviceActivityMonitor app-extension principal class.
//
// ⚠️ UNVERIFIED ON THIS DEV MACHINE (no iOS SDK). This file belongs to a SEPARATE
// Xcode target you must create (see TO_SIMO_DO.md). `VerificationAppGroup.swift`
// must be a member of BOTH the Runner and this extension target so the App Group
// constant is shared. Keep the extension tiny — it runs under a ~6 MB memory cap.
//
// It is woken by the system (surviving app force-quit / reboot, though not
// perfectly reliably — the Dart engine tolerates missed/duplicate/late signals):
//   • eventDidReachThreshold → usage crossed the limit  → "reachedThreshold" (fail)
//   • intervalDidEnd         → the day ended (23:59)     → "stayedUnder" (pass)
// The DeviceActivityName IS the goalId (set app-side), so `activity.rawValue`
// identifies the goal. A reachedThreshold is authoritative and permanent — the
// Dart engine makes it win over a later stayedUnder (D2 / finding #4).

import DeviceActivity
import Foundation
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
    appendSignal(goalId: activity.rawValue, kind: "reachedThreshold")
    // Accountability-forward: alert the moment the limit is crossed (D11), in
    // real time — this is the feature's highest-value notification and doesn't
    // depend on the flaky interval-end callback. Requires the app to have
    // requested notification permission.
    postLimitReachedNotification()
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    appendSignal(goalId: activity.rawValue, kind: "stayedUnder")
  }

  private func postLimitReachedNotification() {
    let content = UNMutableNotificationContent()
    content.title = "Screen time limit reached"
    content.body = "You've hit your screen time goal for today."
    content.sound = .default
    // nil trigger ⇒ deliver immediately. Unique id per fire so it isn't coalesced.
    let request = UNNotificationRequest(
      identifier: "screentime_limit_\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  private func appendSignal(goalId: String, kind: String) {
    guard let defaults = UserDefaults(suiteName: VerificationAppGroup.suiteName) else { return }
    var pending = defaults.array(forKey: VerificationAppGroup.pendingSignalsKey) as? [[String: Any]] ?? []
    pending.append(["goalId": goalId, "date": Self.todayKey(), "kind": kind])
    defaults.set(pending, forKey: VerificationAppGroup.pendingSignalsKey)
  }

  /// The local calendar day the signal is for. The interval ends at 23:59 (not
  /// 24:00), so this resolves to the correct day for both callbacks.
  private static func todayKey() -> String {
    let f = DateFormatter()
    f.calendar = Calendar.current
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
  }
}
