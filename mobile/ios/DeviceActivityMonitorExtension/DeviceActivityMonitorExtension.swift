// Auto-verified habits — the DeviceActivityMonitor app-extension principal class.
//
// ⚠️ UNVERIFIED ON THIS DEV MACHINE (no iOS SDK). This file is a member of the
// existing `DeviceActivityMonitorExtension` target (a synchronized-folder group
// in Runner.xcodeproj). It is SELF-CONTAINED (its own App Group constants below).
// Keep it tiny — it runs under a ~6 MB memory cap.
//
// It is woken by the system (surviving app force-quit / reboot, though not
// perfectly reliably — the Dart engine tolerates missed/duplicate/late signals):
//   • eventDidReachThreshold → usage crossed the limit  → "reachedThreshold" (fail)
//   • intervalDidEnd         → the day ended (23:59)     → "stayedUnder" (pass)
// The DeviceActivityName IS the goalId (set app-side), so `activity.rawValue`
// identifies the goal. A reachedThreshold is authoritative and permanent — the
// Dart engine makes it win over a later stayedUnder (D2 / finding #4).
//
// A signal is dated by the INTERVAL IT DESCRIBES wherever that can be deduced,
// rather than by the instant the system happened to wake us. Delivery latency is
// not guaranteed and the schedule closes at 23:59, so a wake that slips past
// midnight would otherwise stamp the fresh day — writing a verdict onto a day the
// user has not lived, and for a crossing an unflippable one. Where the interval
// cannot be deduced, `dayForCrossing` falls back to the wake instant (a `fail` on
// a lived day beats no record) and `dayThatEnded` drops the signal (a `pass` on
// the wrong settled day is permanent and invisible; a dropped one is neither).

import DeviceActivity
import Foundation
import UserNotifications

/// Self-contained App Group bridge — the extension is a separate target and can't
/// see the app's copy. `suiteName` + `pendingSignalsKey` MUST match
/// `VerificationAppGroup` in Runner/AppDelegate.swift.
private enum AppGroup {
  static let suiteName = "group.com.simo.evolve.verification"
  static let pendingSignalsKey = "pending_screen_time_signals"
  /// `["title": String, "body": String]` written by the app in the current
  /// locale (the extension can't read Flutter's translations). MUST match
  /// `VerificationAppGroup.notificationCopyKey` in Runner/AppDelegate.swift.
  static let notificationCopyKey = "screen_time_notification_copy"
  /// `["<goalId>": ["minutes": Int, …]]` — the specs of every goal currently
  /// monitored, rewritten by the app after each sync. This extension reads only
  /// `minutes`. MUST match `VerificationAppGroup.monitorSpecsKey` in
  /// Runner/AppDelegate.swift.
  static let monitorSpecsKey = "screen_time_monitor_specs"
}

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
    // One clock read for both decisions below. Two separate `Date()` calls would
    // straddle midnight once a day, and the banner would then be suppressed for a
    // genuine crossing because the two reads disagreed about what "today" is.
    let now = Date()
    let defaults = UserDefaults(suiteName: AppGroup.suiteName)
    let day = Self.dayForCrossing(
      goalId: activity.rawValue, defaults: defaults, now: now)
    appendSignal(goalId: activity.rawValue, kind: "reachedThreshold", day: day)
    // Accountability-forward: alert the moment the limit is crossed (D11), in
    // real time — this is the feature's highest-value notification and doesn't
    // depend on the flaky interval-end callback. Requires the app to have
    // requested notification permission.
    //
    // Only when the crossing is TODAY'S. The copy says "your screen time limit
    // for today", and a wake we have just concluded is reporting yesterday's
    // crossing would be telling the user something both wrong and stale.
    if let day = day, let today = Self.components(of: now), day == today {
      postLimitReachedNotification(defaults)
    }
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    appendSignal(
      goalId: activity.rawValue,
      kind: "stayedUnder",
      day: Self.dayThatEnded()
    )
  }

  private func postLimitReachedNotification(_ defaults: UserDefaults?) {
    let content = UNMutableNotificationContent()
    // Localized copy the app wrote for the current locale; English fallback if
    // the app hasn't run a reconcile yet (mirrors en.i18n.json).
    let copy = defaults?.dictionary(forKey: AppGroup.notificationCopyKey)
    content.title = (copy?["title"] as? String) ?? "Screen time limit reached"
    content.body =
      (copy?["body"] as? String) ?? "You've reached your screen time limit for today."
    content.sound = .default
    // nil trigger ⇒ deliver immediately. Unique id per fire so it isn't coalesced.
    let request = UNNotificationRequest(
      identifier: "screentime_limit_\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  private func appendSignal(
    goalId: String,
    kind: String,
    day: (year: Int, month: Int, day: Int)?
  ) {
    guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return }
    // A day we cannot determine costs nothing. Writing a placeholder would append
    // a row the app is guaranteed to reject and report.
    guard let day = day else { return }
    var pending = defaults.array(forKey: AppGroup.pendingSignalsKey) as? [[String: Any]] ?? []
    pending.append([
      "goalId": goalId,
      "kind": kind,
      // Integer components are the AUTHORITATIVE day. They cannot be misread the
      // way a formatted string can: there is no calendar, locale, era or digit
      // shaping left to get wrong, so the app never has to guess whether a year
      // it was handed is Gregorian.
      "y": day.year,
      "m": day.month,
      "d": day.day,
      // The string stays for one release for the reverse direction: a NEWER app
      // reading rows an OLDER extension left in the App Group, which survives an
      // update because the bundle is replaced atomically but the buffer is not.
      // The app prefers the integers whenever they are present.
      "date": Self.key(day),
    ])
    defaults.set(pending, forKey: AppGroup.pendingSignalsKey)
  }

  /// Explicitly Gregorian, explicitly local.
  ///
  /// `Calendar.current` is deliberately NOT used, and this was a real shipped
  /// bug: the day key used to come from a `DateFormatter` configured with it, and
  /// an explicitly assigned `DateFormatter.calendar` overrides the one the locale
  /// supplies — so on a device whose region default is a non-Gregorian calendar
  /// `"yyyy"` rendered that calendar's era year (Buddhist `2569`, Ethiopic
  /// `2018`, Japanese `0008`). `en_US_POSIX` still pinned ASCII digits, so the
  /// app parsed those without error and filed the signal years from the reconcile
  /// window, *after* the destructive drain had cleared the buffer. Every Screen
  /// Time habit then sat on "?" forever with no error anywhere, while the
  /// real-time "limit reached" push kept firing — so the feature looked alive.
  ///
  /// The time zone is local and explicit: every day named here is bounded by the
  /// user's own midnight, which is what the DeviceActivity schedule is anchored
  /// to.
  private static func calendar() -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone.current
    return cal
  }

  /// The Gregorian y/m/d of [date] in the user's own time zone. Nil only if the
  /// calendar cannot resolve the components, in which case no signal is written
  /// at all rather than a placeholder the app is guaranteed to reject.
  private static func components(
    of date: Date,
    _ cal: Calendar = calendar()
  ) -> (year: Int, month: Int, day: Int)? {
    let c = cal.dateComponents([.year, .month, .day], from: date)
    guard let y = c.year, let m = c.month, let d = c.day else { return nil }
    return (y, m, d)
  }

  /// The day whose monitoring interval just closed, or nil if this wake cannot be
  /// attributed to one confidently.
  ///
  /// The wake instant is NOT the answer. The schedule (`AppDelegate.swift`,
  /// `ScreenTimeBridge.syncMonitoredGoals`) runs 00:00–23:59, so `intervalDidEnd`
  /// is raised in the last minute of a day — but DeviceActivity gives no
  /// delivery-latency guarantee, and a wake that slips past midnight would
  /// otherwise stamp the FRESH day: a `pass` on a day the user has not lived,
  /// while the day they actually completed gets nothing and lands on
  /// couldn't-verify.
  ///
  /// Three windows, and the third is the important one:
  ///  - late in the evening → the interval closing now is today's;
  ///  - shortly after midnight → a late delivery of the interval that just
  ///    closed, i.e. yesterday's;
  ///  - anywhere else → **nil, drop it.** This callback produces a `pass`, and
  ///    the two ways of being wrong are not symmetric. Dropping costs a
  ///    couldn't-verify: visible, and the user can resolve it. Guessing writes a
  ///    false green onto a settled day whose real signals were already drained
  ///    and destroyed — permanent, and invisible. A mid-afternoon `intervalDidEnd`
  ///    is not a late delivery of anything; the likeliest source is a
  ///    `stopMonitoring()`, and attributing that to yesterday would be worse than
  ///    ignoring it.
  ///
  /// Note that the app now DIFFS its monitoring rather than tearing it all down
  /// on every sync, so `stopMonitoring()` runs only for genuinely removed or
  /// changed goals and affects one activity rather than all of them. That makes
  /// the third window less necessary than it was, and argues for widening
  /// `lateDeliveryWindowMinutes` — but only once T2 says whether `stopMonitoring`
  /// raises this callback at all.
  /// The two windows deliberately read DIFFERENT clocks, because they ask
  /// different questions:
  ///
  ///  - Window 1 matches a **schedule bound**. `intervalEnd` is declared as
  ///    `DateComponents(hour: 23, minute: 59)` — wall clock — so the test for "is
  ///    the interval closing about now" must be wall clock too. Measuring elapsed
  ///    minutes here breaks on a spring-forward day: the local day is 23 hours,
  ///    so an on-time 23:59 firing reads as 1379 elapsed, misses a 1435 threshold,
  ///    and every goal's `pass` is dropped.
  ///  - Window 2 measures **latency**, which is a real-time quantity, so it uses
  ///    elapsed minutes. On a fall-back night that is the difference between
  ///    reading a 01:30 wake as 90 minutes late (wrong) and 150 (right).
  private static func dayThatEnded(
    now: Date = Date(),
    cal: Calendar = calendar()
  ) -> (year: Int, month: Int, day: Int)? {
    let wall = cal.dateComponents([.hour, .minute], from: now)
    // A few minutes of slack rather than the single 23:59 minute: the premise of
    // this whole function is that the callback's timing is not guaranteed, so
    // demanding exactness from it would be inconsistent.
    if wall.hour == 23, (wall.minute ?? 0) >= 55 { return components(of: now, cal) }
    guard minutesSinceMidnight(now, cal) <= lateDeliveryWindowMinutes else {
      return nil
    }
    guard let yesterday = cal.date(byAdding: .day, value: -1, to: now) else {
      return nil
    }
    return components(of: yesterday, cal)
  }

  /// How long after midnight a callback can still be read as a late delivery of
  /// the interval that just closed.
  ///
  /// A CHOSEN bound, not a measured one — nothing in this feature has run on a
  /// device yet. It trades away any delivery later than four hours, on the
  /// assumption that the likelier source of a mid-day `intervalDidEnd` is the
  /// `stopMonitoring()` a sync performs than a genuinely late system delivery.
  ///
  /// That assumption is exactly what device test T2 settles, and the answer
  /// should come back here. If `stopMonitoring()` does NOT deliver
  /// `intervalDidEnd`, then a late delivery is the only thing that can produce
  /// one and this cutoff is discarding real passes for nothing — widen it or drop
  /// the window entirely. The power-off-overnight case (T9) bears on the same
  /// decision: a phone that dies before 23:59 and boots at 09:00 may replay a
  /// genuine interval end that this bound currently throws away.
  private static let lateDeliveryWindowMinutes = 4 * 60

  /// Real elapsed minutes since the start of [now]'s local day.
  ///
  /// `hour * 60 + minute` would be a WALL-CLOCK reading, and those differ on a
  /// DST day: after a fall-back the wall clock repeats an hour, so 160 real
  /// minutes past midnight reads as 100. `startOfDay` is DST-aware, and also
  /// correct in the zones whose midnight does not exist at all (Chile, Cuba,
  /// Iran, Lord Howe), where the wall-clock arithmetic is wrong every day.
  private static func minutesSinceMidnight(_ now: Date, _ cal: Calendar) -> Int {
    Int(now.timeIntervalSince(cal.startOfDay(for: now)) / 60)
  }

  /// The day a threshold crossing belongs to.
  ///
  /// A deduction, not a heuristic: usage accrues only from the interval start, so
  /// a T-minute threshold cannot be crossed earlier than T minutes into the day.
  /// If the extension is woken before that, the crossing it reports necessarily
  /// happened in the interval that just closed — yesterday. Dating it today would
  /// write an **unflippable** `missed` onto a fresh day, because the engine makes
  /// a Screen Time fail permanent and that day's own legitimate `stayedUnder` can
  /// never correct it.
  ///
  /// Re-registering monitoring mid-day only strengthens this: the counter then
  /// starts at registration rather than at 00:00 (`includesPastActivity` defaults
  /// to false and is not passed), so accrual start ≥ interval start and the bound
  /// stays conservative in the safe direction.
  ///
  /// A fixed post-midnight window would NOT do: the minimum threshold is one
  /// minute, so any window wider than a goal's own threshold would misfile a
  /// genuine early crossing.
  ///
  /// Two residuals, both narrow, neither silently assumed away:
  ///  - a time-zone change mid-interval moves the wall clock relative to an
  ///    interval that started at the old midnight, and nothing in the callback
  ///    carries the interval's true start instant;
  ///  - raising a limit in the minutes between a genuine crossing and the wake
  ///    that reports it makes the map's T larger than the T in force, which can
  ///    redate that crossing to yesterday.
  ///
  /// When the threshold is unknown — the app has not synced since this goal was
  /// registered — no correction is applied. That is the pre-existing behaviour
  /// rather than a guess, and it is also where this bug still lives: the window
  /// is the gap between installing an update and the first successful sync, while
  /// the previous build's registration is still live.
  private static func dayForCrossing(
    goalId: String,
    defaults: UserDefaults?,
    now: Date = Date(),
    cal: Calendar = calendar()
  ) -> (year: Int, month: Int, day: Int)? {
    guard
      let specs = defaults?.dictionary(forKey: AppGroup.monitorSpecsKey),
      let spec = specs[goalId] as? [String: Any],
      let minutes = (spec["minutes"] as? NSNumber)?.intValue,
      minutes > 0
    else { return components(of: now, cal) }

    // +1 so a report that arrives a fraction of a minute early — truncation, an
    // NTP correction — does not cost a whole day.
    guard minutesSinceMidnight(now, cal) + 1 < minutes else {
      return components(of: now, cal)
    }
    guard let yesterday = cal.date(byAdding: .day, value: -1, to: now) else {
      return components(of: now, cal)
    }
    return components(of: yesterday, cal)
  }

  /// `yyyy-MM-dd` for the legacy string field. `String(format:)` with no locale
  /// argument is POSIX-formatted, so ASCII digits are guaranteed by construction
  /// rather than by pinning a locale. `%ld` because Swift's `Int` is 64-bit.
  private static func key(_ d: (year: Int, month: Int, day: Int)) -> String {
    String(format: "%04ld-%02ld-%02ld", d.year, d.month, d.day)
  }
}
