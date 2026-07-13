// Auto-verified habits — native half of the HealthKit bridge (`evolve/healthkit`).
//
// ⚠️ UNVERIFIED ON THIS DEV MACHINE (no iOS SDK). Compile + fix in Xcode.
// See TO_SIMO_DO.md. Requires the HealthKit capability + NSHealthShareUsageDescription.
//
// Contract mirrors mobile/lib/core/method_channel_health_kit_bridge.dart:
//   isHealthDataAvailable() -> Bool
//   requestAuthorization({types:[String]}) -> void
//   dailyQuantity({type,aggregation,startMs,endMs}) -> Double?   (nil = no data)
//   hasRecentData({type,withinDays}) -> Bool
//
// Read-only: we never call requestAuthorization(toShare:). A verdict must never
// be fabricated — when data is absent/ambiguous we return nil, which the Dart
// engine maps to couldn't-verify/pending, never a false "missed".

import Flutter
import Foundation
import HealthKit

enum HealthKitBridge {
  private static let store = HKHealthStore()

  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "evolve/healthkit", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in handle(call, result) }
  }

  private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "isHealthDataAvailable":
      result(HKHealthStore.isHealthDataAvailable())
    case "requestAuthorization":
      requestAuthorization(args, result)
    case "dailyQuantity":
      dailyQuantity(args, result)
    case "hasRecentData":
      hasRecentData(args, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Type mapping (wire identifier -> HK types)

  private static func objectType(_ id: String) -> HKObjectType? {
    switch id {
    case "stepCount": return HKQuantityType.quantityType(forIdentifier: .stepCount)
    case "appleExerciseTime": return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
    case "activeEnergyBurned": return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
    case "distanceWalkingRunning": return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
    case "appleStandHour": return HKCategoryType.categoryType(forIdentifier: .appleStandHour)
    case "mindfulSession": return HKCategoryType.categoryType(forIdentifier: .mindfulSession)
    case "sleepAnalysis": return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
    case "workout": return HKObjectType.workoutType()
    default: return nil
    }
  }

  /// The unit each metric is returned in — MUST match the Dart template's
  /// VerificationUnit so the threshold comparison is apples-to-apples.
  private static func unit(_ id: String) -> HKUnit? {
    switch id {
    case "stepCount": return .count()
    case "appleExerciseTime": return .minute()
    case "activeEnergyBurned": return .kilocalorie()
    case "distanceWalkingRunning": return .meterUnit(with: .kilo)
    default: return nil // category / workout handled separately
    }
  }

  // MARK: - Authorization

  private static func requestAuthorization(_ args: [String: Any]?, _ result: @escaping FlutterResult) {
    let ids = (args?["types"] as? [String]) ?? []
    let readTypes = Set(ids.compactMap { objectType($0) })
    guard !readTypes.isEmpty else { result(nil); return }
    store.requestAuthorization(toShare: nil, read: readTypes) { _, _ in
      // HealthKit deliberately never reports read denial, so we ignore the
      // outcome and let a run of couldn't-verify days infer it later (D9).
      main { result(nil) }
    }
  }

  // MARK: - Daily aggregate

  private static func dailyQuantity(_ args: [String: Any]?, _ result: @escaping FlutterResult) {
    guard
      let id = args?["type"] as? String,
      let startMs = (args?["startMs"] as? NSNumber)?.doubleValue,
      let endMs = (args?["endMs"] as? NSNumber)?.doubleValue,
      let type = objectType(id)
    else { result(nil); return }

    let aggregation = (args?["aggregation"] as? String) ?? "sum"
    let start = Date(timeIntervalSince1970: startMs / 1000.0)
    let end = Date(timeIntervalSince1970: endMs / 1000.0)
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

    if let quantityType = type as? HKQuantityType, let hkUnit = unit(id) {
      let q = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
        let value = stats?.sumQuantity()?.doubleValue(for: hkUnit)
        main { result(value) } // nil when there is no data
      }
      store.execute(q)
      return
    }

    // Category types (sleep/mindful/stand) + workouts: run a sample query and
    // aggregate ourselves (sum of minutes/hours, or a count).
    let sampleType = (type as? HKSampleType) ?? HKObjectType.workoutType()
    let q = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
      main { result(aggregate(id: id, aggregation: aggregation, samples: samples)) }
    }
    store.execute(q)
  }

  private static func aggregate(id: String, aggregation: String, samples: [HKSample]?) -> Double? {
    guard let samples = samples else { return nil }
    switch id {
    case "sleepAnalysis":
      // Sum "asleep" durations, in hours. (Night-window attribution is a known
      // follow-up; for now we sum asleep samples overlapping the day window.)
      let asleep = samples.compactMap { $0 as? HKCategorySample }.filter { isAsleep($0.value) }
      if asleep.isEmpty { return nil }
      let seconds = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
      return seconds / 3600.0
    case "mindfulSession":
      let mindful = samples.compactMap { $0 as? HKCategorySample }
      if mindful.isEmpty { return nil }
      let seconds = mindful.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
      return seconds / 60.0
    case "appleStandHour":
      // Count hours the user stood (value == .stood).
      let stood = samples.compactMap { $0 as? HKCategorySample }
        .filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
      return Double(stood.count)
    case "workout":
      return aggregation == "count" ? Double(samples.count) : nil
    default:
      return nil
    }
  }

  private static func isAsleep(_ value: Int) -> Bool {
    if #available(iOS 16.0, *) {
      return value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
        || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
        || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        || value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
    }
    return value == HKCategoryValueSleepAnalysis.asleep.rawValue
  }

  // MARK: - Recent-data probe (Watch-dependency warning)

  private static func hasRecentData(_ args: [String: Any]?, _ result: @escaping FlutterResult) {
    guard
      let id = args?["type"] as? String,
      let withinDays = (args?["withinDays"] as? NSNumber)?.intValue,
      let type = objectType(id),
      let sampleType = type as? HKSampleType
    else { result(false); return }

    let start = Calendar.current.date(byAdding: .day, value: -withinDays, to: Date())
    let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
    let q = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
      main { result((samples?.isEmpty == false)) }
    }
    store.execute(q)
  }

  private static func main(_ work: @escaping () -> Void) {
    DispatchQueue.main.async(execute: work)
  }
}
