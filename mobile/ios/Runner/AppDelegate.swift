import CloudKit
import DeviceActivity
import FamilyControls
import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let registrar = self.registrar(forPlugin: "EvolvePlugin") {
      Self.registerPrivateStorageChannel(registrar.messenger())
      CloudKitSyncBridge.register(registrar.messenger())
      // Auto-verified habits (compile-pending; see TO_SIMO_DO). Registering the
      // channels is harmless — the Dart side only invokes them when the feature
      // flag is on. Requires HealthKit + Family Controls capabilities to build.
      HealthKitBridge.register(registrar.messenger())
      ScreenTimeBridge.register(registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  static func registerPrivateStorageChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "evolve/private_storage",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Missing path", details: nil))
        return
      }

      var url = URL(fileURLWithPath: path)
      do {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try url.setResourceValues(resourceValues)
        result(nil)
      } catch {
        result(FlutterError(
          code: "exclude_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }
}

/// Native half of the iCloud sync feature: a thin MethodChannel
/// (`evolve/cloudkit`) over CloudKit's private database + a custom zone. It only
/// transports the contract — all sync logic (encryption, LWW, merge) lives in
/// the Dart engine, and payloads cross as already-encrypted bytes.
///
/// Requires the iCloud (CloudKit) capability + the `iCloud.com.simo.evolve`
/// container in the Apple Developer portal / Xcode (see Runner.entitlements).
/// Kept in this file (already a Runner target member) so it builds without
/// editing the Xcode project.
enum CloudKitSyncBridge {
  static let containerId = "iCloud.com.simo.evolve"
  static let zoneName = "PrivateZone"
  static let recordType = "PrivateRecord"

  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "evolve/cloudkit",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      handle(call, result)
    }
  }

  private static var container: CKContainer { CKContainer(identifier: containerId) }
  private static var database: CKDatabase { container.privateCloudDatabase }
  private static var zoneID: CKRecordZone.ID {
    CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
  }

  private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "accountStatus": accountStatus(result)
    case "ensureZone": ensureZone(result)
    case "saveRecords": saveRecords(args, result)
    case "fetchChanges": fetchChanges(args, result)
    case "deleteRecords": deleteRecords(args, result)
    case "deleteZone": deleteZone(result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Account

  private static func accountStatus(_ result: @escaping FlutterResult) {
    container.accountStatus { status, _ in
      let mapped: String
      switch status {
      case .available: mapped = "available"
      case .noAccount: mapped = "noAccount"
      case .restricted: mapped = "restricted"
      case .temporarilyUnavailable: mapped = "temporarilyUnavailable"
      default: mapped = "couldNotDetermine"
      }
      main { result(mapped) }
    }
  }

  // MARK: - Zone

  private static func ensureZone(_ result: @escaping FlutterResult) {
    let zone = CKRecordZone(zoneID: zoneID)
    let op = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
    op.modifyRecordZonesResultBlock = { res in
      main {
        switch res {
        case .success: result(nil)
        case .failure(let error): result(flutterError(error))
        }
      }
    }
    database.add(op)
  }

  private static func deleteZone(_ result: @escaping FlutterResult) {
    let op = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: [zoneID])
    op.modifyRecordZonesResultBlock = { res in
      main {
        switch res {
        case .success: result(nil)
        case .failure(let error):
          if let ck = error as? CKError, ck.code == .zoneNotFound || ck.code == .userDeletedZone {
            result(nil) // already gone — a no-op success
          } else {
            result(flutterError(error))
          }
        }
      }
    }
    database.add(op)
  }

  // MARK: - Save

  private static func saveRecords(_ args: [String: Any]?, _ result: @escaping FlutterResult) {
    guard let rawRecords = args?["records"] as? [[String: Any]] else {
      result(flutterBadArgs); return
    }
    let toSave: [CKRecord] = rawRecords.map { encodeToRecord($0) }
    let op = CKModifyRecordsOperation(recordsToSave: toSave, recordIDsToDelete: nil)
    // .allKeys (overwrite), NOT .ifServerRecordUnchanged: each push builds a
    // fresh CKRecord with no server change tag, so .ifServerRecordUnchanged
    // would reject EVERY update to an already-synced record as
    // serverRecordChanged and the edit would never propagate. The Dart engine
    // does authoritative last-write-wins itself (pull-before-push + updatedAt),
    // so server-side change-tag gating is both redundant and harmful here.
    op.savePolicy = .allKeys

    var saved: [String] = []
    var conflicts: [[String: Any]] = []
    var errors: [[String: Any]] = []

    op.perRecordSaveBlock = { recordID, res in
      switch res {
      case .success:
        saved.append(recordID.recordName)
      case .failure(let error):
        if let ck = error as? CKError, ck.code == .serverRecordChanged {
          let serverMs = (ck.serverRecord?["updatedAt"] as? NSNumber)?.int64Value ?? 0
          conflicts.append(["recordName": recordID.recordName, "serverUpdatedAtMs": serverMs])
        } else {
          let code = (error as? CKError)?.code.rawValue ?? -1
          errors.append(["recordName": recordID.recordName, "code": "\(code)"])
        }
      }
    }
    op.modifyRecordsResultBlock = { _ in
      main { result(["saved": saved, "conflicts": conflicts, "errors": errors]) }
    }
    database.add(op)
  }

  private static func encodeToRecord(_ map: [String: Any]) -> CKRecord {
    let recordName = map["recordName"] as? String ?? UUID().uuidString
    let record = CKRecord(
      recordType: recordType,
      recordID: CKRecord.ID(recordName: recordName, zoneID: zoneID)
    )
    if let table = map["tableName"] as? String {
      record["tableName"] = table as NSString
    }
    if let updatedAt = map["updatedAtMs"] as? NSNumber {
      record["updatedAt"] = updatedAt
    }
    record["deleted"] = NSNumber(value: (map["deleted"] as? Bool ?? false) ? 1 : 0)
    if let payload = map["payload"] as? FlutterStandardTypedData {
      record["payload"] = payload.data as NSData
    }
    if let assetPath = map["assetPath"] as? String {
      record["asset"] = CKAsset(fileURL: URL(fileURLWithPath: assetPath))
    }
    return record
  }

  // MARK: - Delete records

  private static func deleteRecords(_ args: [String: Any]?, _ result: @escaping FlutterResult) {
    let names = args?["recordNames"] as? [String] ?? []
    let ids = names.map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
    let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
    var deleted: [String] = []
    var errors: [[String: Any]] = []
    op.perRecordDeleteBlock = { recordID, res in
      switch res {
      case .success: deleted.append(recordID.recordName)
      case .failure(let error):
        let code = (error as? CKError)?.code.rawValue ?? -1
        errors.append(["recordName": recordID.recordName, "code": "\(code)"])
      }
    }
    op.modifyRecordsResultBlock = { _ in
      main { result(["deleted": deleted, "errors": errors]) }
    }
    database.add(op)
  }

  // MARK: - Fetch changes

  private static func fetchChanges(_ args: [String: Any]?, _ result: @escaping FlutterResult) {
    let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
    config.previousServerChangeToken = decodeToken(args?["token"] as? String)
    let op = CKFetchRecordZoneChangesOperation(
      recordZoneIDs: [zoneID],
      configurationsByRecordZoneID: [zoneID: config]
    )

    var records: [[String: Any]] = []
    var newToken: CKServerChangeToken?
    var moreComing = false

    op.recordWasChangedBlock = { _, res in
      if case .success(let record) = res {
        records.append(encodeFromRecord(record))
      }
    }
    op.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
      newToken = token
    }
    op.recordZoneFetchResultBlock = { _, res in
      if case .success(let info) = res {
        newToken = info.serverChangeToken
        moreComing = info.moreComing
      }
    }
    op.fetchRecordZoneChangesResultBlock = { res in
      main {
        switch res {
        case .success:
          result([
            "records": records,
            "newToken": encodeToken(newToken) as Any,
            "moreComing": moreComing,
          ])
        case .failure(let error):
          if let ck = error as? CKError, ck.code == .zoneNotFound || ck.code == .userDeletedZone {
            result(["records": [], "newToken": nil as Any?, "moreComing": false])
          } else {
            result(flutterError(error))
          }
        }
      }
    }
    database.add(op)
  }

  private static func encodeFromRecord(_ record: CKRecord) -> [String: Any] {
    var map: [String: Any] = [
      "recordName": record.recordID.recordName,
      "tableName": (record["tableName"] as? String) ?? "",
      "updatedAtMs": (record["updatedAt"] as? NSNumber)?.int64Value ?? 0,
      "deleted": ((record["deleted"] as? NSNumber)?.intValue ?? 0) == 1,
    ]
    if let payload = record["payload"] as? Data {
      map["payload"] = FlutterStandardTypedData(bytes: payload)
    }
    if let asset = record["asset"] as? CKAsset, let url = asset.fileURL {
      map["assetPath"] = url.path
    }
    return map
  }

  // MARK: - Token (base64 of the archived CKServerChangeToken)

  private static func encodeToken(_ token: CKServerChangeToken?) -> String? {
    guard let token = token else { return nil }
    let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    return data?.base64EncodedString()
  }

  private static func decodeToken(_ value: String?) -> CKServerChangeToken? {
    guard let value = value, let data = Data(base64Encoded: value) else { return nil }
    return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
  }

  // MARK: - Helpers

  private static func main(_ work: @escaping () -> Void) {
    DispatchQueue.main.async(execute: work)
  }

  private static var flutterBadArgs: FlutterError {
    FlutterError(code: "bad_args", message: "Missing or malformed arguments", details: nil)
  }

  private static func flutterError(_ error: Error) -> FlutterError {
    let code = (error as? CKError)?.code.rawValue ?? -1
    return FlutterError(code: "cloudkit_\(code)", message: error.localizedDescription, details: nil)
  }
}

// ── Auto-verified habits — native bridges (kept in this file, a Runner
// target member, so they build without editing the Xcode project — mirrors
// CloudKitSyncBridge). UNVERIFIED on the dev machine (no iOS SDK).

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
