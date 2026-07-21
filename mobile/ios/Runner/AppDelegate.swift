import CloudKit
import DeviceActivity
import FamilyControls
import Flutter
import HealthKit
import SwiftUI
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
    // CloudKit zone-change pushes. This does NOT prompt the user: silent
    // (`content-available`) pushes need no notification authorization, which is
    // why sync can use them without asking for anything.
    CloudKitSyncBridge.logNative("info", "[APNs] Requesting registration...")
    application.registerForRemoteNotifications()
    CloudKitSyncBridge.scheduleRegistrationWatchdog()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// A silent push telling us the CloudKit zone changed.
  ///
  /// Runs the app's ORDINARY sync — the push carries no data and decides
  /// nothing. It only changes WHEN sync happens; what sync does stays in the one
  /// Dart path.
  ///
  /// The periodic poll is deliberately kept alongside this: iOS throttles and
  /// drops silent pushes at its own discretion, so a device that hears nothing
  /// must still converge on its timer.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
          notification.containerIdentifier == CloudKitSyncBridge.containerId
    else {
      // Not ours — hand it on rather than swallowing it.
      super.application(
        application,
        didReceiveRemoteNotification: userInfo,
        fetchCompletionHandler: completionHandler
      )
      return
    }
    CloudKitSyncBridge.notifyRemoteChange()
    // `.newData` even though the fetch is asynchronous and may find nothing:
    // reporting `.noData` teaches iOS this app's pushes are not worth waking for
    // and it throttles them harder.
    completionHandler(.newData)
  }

  /// APNs registration outcome. Logged because it is otherwise INVISIBLE:
  /// `registerForRemoteNotifications()` is fire-and-forget, and "subscription
  /// registered" only proves CloudKit accepted the subscription — it says
  /// nothing about whether this device can receive a push. Without these two
  /// callbacks a device with no push token looks identical to a working one.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Length only — the token itself is device-identifying and never logged.
    CloudKitSyncBridge.noteApnsCallback()
    CloudKitSyncBridge.logNative(
      "info",
      "[APNs] Registered for remote notifications (token \(deviceToken.count) bytes)"
    )
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    CloudKitSyncBridge.noteApnsCallback()
    CloudKitSyncBridge.logNative(
      "error",
      "[APNs] Registration FAILED: \(error.localizedDescription)"
    )
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
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

  /// Retained so a silent push can invoke BACK into Dart. It used to be a local
  /// `let`, which made the channel one-directional.
  private static var channel: FlutterMethodChannel?

  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "evolve/cloudkit",
      binaryMessenger: messenger
    )
    Self.channel = channel
    channel.setMethodCallHandler { call, result in
      handle(call, result)
    }
  }

  private static var container: CKContainer { CKContainer(identifier: containerId) }
  private static var database: CKDatabase { container.privateCloudDatabase }
  private static var zoneID: CKRecordZone.ID {
    CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
  }

  // MARK: - Retry / backoff

  /// How many times an operation is re-issued before the failure is handed to
  /// Dart. Four attempts in total.
  ///
  /// Bounded on purpose. The Dart engine leaves a failed record dirty and the
  /// app re-syncs on its own timer, so an operation still throttled after the
  /// whole backoff schedule is better reported than retried forever — the retry
  /// that matters is the next sync, not an unbounded loop holding this one open.
  private static let maxRetries = 3

  /// Seconds to wait before re-issuing an operation that failed with [error],
  /// or nil when the failure is not one CloudKit wants retried.
  ///
  /// The three codes are CloudKit's "come back later" family:
  ///  * `.requestRateLimited` — the client is over its budget. This is the one
  ///    that bites a NEW user, whose very first push is their entire history.
  ///  * `.serviceUnavailable` — CloudKit itself is degraded.
  ///  * `.zoneBusy` — another operation is already mutating the zone.
  ///
  /// `CKError.retryAfterSeconds` is the SERVER's own instruction and always
  /// wins when it supplies one: ignoring it and retrying sooner is precisely
  /// what turns a short throttle into a long one. Exponential backoff (2s, 4s,
  /// 8s) is only the fallback for when the server declines to say.
  private static func retryDelay(_ error: Error, attempt: Int) -> TimeInterval? {
    guard attempt < maxRetries, let ck = error as? CKError else { return nil }
    switch ck.code {
    case .requestRateLimited, .serviceUnavailable, .zoneBusy:
      if let serverHint = ck.retryAfterSeconds, serverHint > 0 { return serverHint }
      return pow(2.0, Double(attempt + 1))
    default:
      return nil
    }
  }

  /// Re-issues [work] after [delay], and says so in the app's own log.
  ///
  /// The log line is not decoration: a device that silently backs off is
  /// indistinguishable from one that is simply slow, and "sync seems to take
  /// ages on a new phone" is exactly the report this whole path exists to
  /// explain.
  private static func scheduleRetry(
    _ label: String,
    after delay: TimeInterval,
    attempt: Int,
    _ work: @escaping () -> Void
  ) {
    logNative(
      "info",
      "[CloudKit] \(label) throttled by iCloud — retrying in "
        + String(format: "%.1f", delay) + "s "
        + "(attempt \(attempt + 2) of \(maxRetries + 1))"
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
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
    case "zoneHasRecords": zoneHasRecords(result)
    case "ensureSubscription": ensureSubscription(result)
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

  private static func ensureZone(_ result: @escaping FlutterResult, attempt: Int = 0) {
    let zone = CKRecordZone(zoneID: zoneID)
    let op = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
    op.qualityOfService = .utility
    op.modifyRecordZonesResultBlock = { res in
      switch res {
      case .success:
        main { result(nil) }
      case .failure(let error):
        if let delay = retryDelay(error, attempt: attempt) {
          scheduleRetry("ensureZone", after: delay, attempt: attempt) {
            ensureZone(result, attempt: attempt + 1)
          }
          return
        }
        main { result(flutterError(error)) }
      }
    }
    database.add(op)
  }

  private static func deleteZone(_ result: @escaping FlutterResult, attempt: Int = 0) {
    let op = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: [zoneID])
    op.qualityOfService = .utility
    op.modifyRecordZonesResultBlock = { res in
      switch res {
      case .success:
        main { result(nil) }
      case .failure(let error):
        if let ck = error as? CKError, ck.code == .zoneNotFound || ck.code == .userDeletedZone {
          main { result(nil) } // already gone — a no-op success
          return
        }
        if let delay = retryDelay(error, attempt: attempt) {
          scheduleRetry("deleteZone", after: delay, attempt: attempt) {
            deleteZone(result, attempt: attempt + 1)
          }
          return
        }
        main { result(flutterError(error)) }
      }
    }
    database.add(op)
  }

  // MARK: - Save

  private static func saveRecords(
    _ args: [String: Any]?,
    _ result: @escaping FlutterResult,
    attempt: Int = 0
  ) {
    guard let rawRecords = args?["records"] as? [[String: Any]] else {
      result(flutterBadArgs); return
    }
    let toSave: [CKRecord] = rawRecords.map { encodeToRecord($0) }
    let op = CKModifyRecordsOperation(recordsToSave: toSave, recordIDsToDelete: nil)
    op.qualityOfService = .utility
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
    op.modifyRecordsResultBlock = { res in
      // Request-level throttling is handled BEFORE anything is reported, so a
      // rate-limited batch is re-sent rather than handed back as a failure.
      //
      // This is the single most likely thing to go wrong for a new user:
      // enable() marks their entire history dirty, so the first push is
      // thousands of records in 400-record batches. Without this, the first
      // batch to be throttled aborted the whole sync.
      //
      // A .partialFailure is deliberately NOT retryable (see retryDelay): its
      // per-record blocks already ran, the engine keeps exactly the failed
      // records dirty, and the next sync retries those rather than re-sending
      // the whole batch.
      if case .failure(let error) = res,
         let delay = retryDelay(error, attempt: attempt) {
        scheduleRetry("saveRecords", after: delay, attempt: attempt) {
          saveRecords(args, result, attempt: attempt + 1)
        }
        return
      }
      main {
        switch res {
        case .success:
          result(["saved": saved, "conflicts": conflicts, "errors": errors])
        case .failure(let error):
          // .partialFailure already fired perRecordSaveBlock for every record,
          // so the collected lists are authoritative and the engine can act on
          // them. Any other failure (limitExceeded, quotaExceeded, …) fires no
          // per-record block at all: reporting the empty lists as success would
          // be indistinguishable from "nothing to push".
          if let ck = error as? CKError, ck.code == .partialFailure {
            result(["saved": saved, "conflicts": conflicts, "errors": errors])
          } else {
            result(flutterError(error))
          }
        }
      }
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

  private static func deleteRecords(
    _ args: [String: Any]?,
    _ result: @escaping FlutterResult,
    attempt: Int = 0
  ) {
    let names = args?["recordNames"] as? [String] ?? []
    let ids = names.map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
    let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
    op.qualityOfService = .utility
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
    op.modifyRecordsResultBlock = { res in
      if case .failure(let error) = res,
         let delay = retryDelay(error, attempt: attempt) {
        scheduleRetry("deleteRecords", after: delay, attempt: attempt) {
          deleteRecords(args, result, attempt: attempt + 1)
        }
        return
      }
      main {
        switch res {
        case .success:
          result(["deleted": deleted, "errors": errors])
        case .failure(let error):
          if let ck = error as? CKError, ck.code == .partialFailure {
            result(["deleted": deleted, "errors": errors])
          } else {
            result(flutterError(error))
          }
        }
      }
    }
    database.add(op)
  }

  // MARK: - Fetch changes

  private static func fetchChanges(
    _ args: [String: Any]?,
    _ result: @escaping FlutterResult,
    attempt: Int = 0
  ) {
    let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
    config.previousServerChangeToken = decodeToken(args?["token"] as? String)
    let op = CKFetchRecordZoneChangesOperation(
      recordZoneIDs: [zoneID],
      configurationsByRecordZoneID: [zoneID: config]
    )
    op.qualityOfService = .utility

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
            return
          }
          if let delay = retryDelay(error, attempt: attempt) {
            scheduleRetry("fetchChanges", after: delay, attempt: attempt) {
              fetchChanges(args, result, attempt: attempt + 1)
            }
            return
          }
          result(flutterError(error))
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

  // MARK: - Zone probe (key-mint guard)

  /// Does the zone hold ANY record? Answers "is this device really the first to
  /// enable sync?" — the guard that stops a second E2E key being minted while
  /// the real one is still in flight through the iCloud Keychain. Minting
  /// against a populated zone orphans every record in it, permanently, on every
  /// device.
  ///
  /// Deliberately cheap and side-effect free:
  ///  - `fetchAllChanges = false` fetches ONE batch instead of walking the zone.
  ///  - `desiredKeys = []` asks the server for record ids only, no field data,
  ///    so a 6000-record zone costs a single small response.
  ///  - the returned change token is DISCARDED and never persisted, so probing
  ///    can never advance a device past changes it has not applied.
  ///
  /// A missing zone means genuinely nothing is there yet → false. Any other
  /// error is INCONCLUSIVE and must fail closed (→ true, defer the enable):
  /// answering "empty" on an error is the branch that mints a second key.
  private static func zoneHasRecords(_ result: @escaping FlutterResult, attempt: Int = 0) {
    let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
    config.previousServerChangeToken = nil
    config.desiredKeys = []
    let op = CKFetchRecordZoneChangesOperation(
      recordZoneIDs: [zoneID],
      configurationsByRecordZoneID: [zoneID: config]
    )
    op.fetchAllChanges = false
    // .userInitiated, not .utility: this one blocks the enable the user is
    // watching, and it is the guard that decides whether a second E2E key gets
    // minted. Making the user wait behind a background-priority operation for
    // the one answer that cannot be got wrong is the wrong trade.
    op.qualityOfService = .userInitiated

    var found = false
    op.recordWasChangedBlock = { _, res in
      if case .success = res { found = true }
    }
    // A tombstone is still evidence the zone has been written to.
    op.recordWithIDWasDeletedBlock = { _, _ in found = true }
    op.fetchRecordZoneChangesResultBlock = { res in
      main {
        switch res {
        case .success:
          result(found)
        case .failure(let error):
          if let ck = error as? CKError,
             ck.code == .zoneNotFound || ck.code == .userDeletedZone {
            result(false)
            return
          }
          // Retry before giving up. An INCONCLUSIVE answer here is the most
          // expensive failure in the whole bridge — it is what a deferred
          // enable is protecting against — so a transient throttle must not be
          // allowed to decide it.
          if let delay = retryDelay(error, attempt: attempt) {
            scheduleRetry("zoneHasRecords", after: delay, attempt: attempt) {
              zoneHasRecords(result, attempt: attempt + 1)
            }
            return
          }
          result(flutterError(error))
        }
      }
    }
    database.add(op)
  }

  // MARK: - Zone change subscription (silent push)

  /// Fixed id so registering is IDEMPOTENT. CloudKit subscriptions outlive app
  /// reinstalls, so this runs against an existing subscription far more often
  /// than not; a fresh uuid each time would pile up duplicates server-side and
  /// deliver one push per duplicate.
  private static let subscriptionID = "evolve-private-zone-changes"

  /// Ask CloudKit to send this device a silent push whenever the private
  /// database changes.
  ///
  /// A `CKDatabaseSubscription` rather than a zone subscription: it keeps
  /// working unchanged if a second zone is ever added, and it is the shape Apple
  /// documents for this pattern.
  ///
  /// Silent-only — no alert, badge or sound — which is also why this needs NO
  /// user permission: `shouldSendContentAvailable` pushes never prompt.
  ///
  /// Errors are reported but must be treated as non-fatal by the caller: push
  /// only changes WHEN a sync runs, and the Dart side still polls.
  private static func ensureSubscription(
    _ result: @escaping FlutterResult,
    attempt: Int = 0
  ) {
    let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
    let notificationInfo = CKSubscription.NotificationInfo()
    notificationInfo.shouldSendContentAvailable = true
    subscription.notificationInfo = notificationInfo

    let op = CKModifySubscriptionsOperation(
      subscriptionsToSave: [subscription],
      subscriptionIDsToDelete: nil
    )
    op.qualityOfService = .utility
    op.modifySubscriptionsResultBlock = { res in
      main {
        switch res {
        case .success:
          result(nil)
        case .failure(let error):
          // Report EVERY failure. `.serverRejectedRequest` was previously
          // swallowed as "already registered" — it is not; it is a genuine
          // rejection, and treating it as success meant the app logged
          // "subscription registered" while no subscription existed. That is the
          // exact false-success this codebase has spent a week removing.
          //
          // Re-registering an existing subscription id is NOT an error in
          // CloudKit (CKModifySubscriptionsOperation updates it in place), so
          // there is no "already exists" case to special-case in the first
          // place.
          if let delay = retryDelay(error, attempt: attempt) {
            scheduleRetry("ensureSubscription", after: delay, attempt: attempt) {
              ensureSubscription(result, attempt: attempt + 1)
            }
            return
          }
          let ck = error as? CKError
          logNative(
            "error",
            "[CloudKit] Subscription registration failed"
              + " (CKError \(ck?.code.rawValue ?? -1)):"
              + " \(error.localizedDescription)"
          )
          result(flutterError(error))
        }
      }
    }
    database.add(op)
  }

  /// Tell Dart the zone changed, so it runs its ORDINARY sync.
  ///
  /// Deliberately carries no payload and does no work of its own. The push is a
  /// hint about TIMING; everything about what to fetch, merge and resolve stays
  /// in the one Dart path that has been hardened for it.
  /// Surface a native-side event in the app's own log, so an APNs problem is
  /// visible in the exported log rather than only in a Console session.
  ///
  /// Push failures are otherwise completely silent: `registerForRemoteNotifications`
  /// is fire-and-forget, and "subscription registered" only proves CloudKit
  /// ACCEPTED the subscription — it says nothing about whether this device can
  /// RECEIVE a push.
  /// True once either APNs callback has fired.
  private static var apnsCallbackSeen = false

  static func noteApnsCallback() { apnsCallbackSeen = true }

  /// Log if APNs answers with NEITHER success nor failure.
  ///
  /// That silence is a real, distinct state — it is what a Mac signed without a
  /// push-capable provisioning profile does — and it is invisible otherwise:
  /// `registerForRemoteNotifications()` returns immediately and the delegate is
  /// simply never called. Without this, "no APNs line in the log" could equally
  /// mean the request was never made, and the two have completely different
  /// fixes.
  static func scheduleRegistrationWatchdog() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
      guard !apnsCallbackSeen else { return }
      logNative(
        "error",
        "[APNs] No registration callback after 15s — neither success nor "
          + "failure. The app asked for a push token and the system never "
          + "answered, which usually means this build is not signed with a "
          + "provisioning profile that authorises the aps-environment "
          + "entitlement. Sync still converges on the periodic poll."
      )
    }
  }

  static func logNative(_ level: String, _ message: String) {
    main {
      channel?.invokeMethod(
        "nativeLog",
        arguments: ["level": level, "message": message]
      )
    }
  }

  static func notifyRemoteChange() {
    main { channel?.invokeMethod("remoteChange", arguments: nil) }
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

  /// Key holding the current-locale copy for the extension's "limit reached"
  /// local notification: `["title": String, "body": String]`. Written by the app
  /// (which alone can read Flutter's translations); the extension reads it and
  /// falls back to English if absent.
  static let notificationCopyKey = "screen_time_notification_copy"

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
      // "Asleep" wall-clock time, in hours. (Night-window attribution is a known
      // follow-up; for now we sum asleep samples overlapping the day window.)
      let asleep = samples.compactMap { $0 as? HKCategorySample }.filter { isAsleep($0.value) }
      if asleep.isEmpty { return nil }
      return mergedSeconds(asleep) / 3600.0
    case "mindfulSession":
      let mindful = samples.compactMap { $0 as? HKCategorySample }
      if mindful.isEmpty { return nil }
      return mergedSeconds(mindful) / 60.0
    case "appleStandHour":
      // Count hours the user stood (value == .stood). A worn Watch writes an
      // `.idle` sample for every hour the user did not stand, so samples with no
      // `.stood` among them is a real 0 — but NO samples at all is the
      // "no data or read denied" case the null contract reserves for
      // couldn't-verify, and must never become a measured 0.
      if samples.isEmpty { return nil }
      let stood = samples.compactMap { $0 as? HKCategorySample }
        .filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
      return Double(stood.count)
    case "workout":
      // Same null contract: HealthKit returns [] both for a workout-free day and
      // for a denied read, and they are indistinguishable, so a zero here is not
      // a measurement. Reporting couldn't-verify matches the quantity path,
      // where a 0-step day already yields nil rather than a `missed`.
      if samples.isEmpty { return nil }
      return aggregation == "count" ? Double(samples.count) : nil
    default:
      return nil
    }
  }

  /// Wall-clock seconds covered by [samples], unioning overlapping intervals.
  /// Several sources commonly describe the same night (Watch sleep stages plus a
  /// third-party sleep app), and adding their durations would count it twice.
  private static func mergedSeconds(_ samples: [HKCategorySample]) -> Double {
    let sorted = samples.sorted { $0.startDate < $1.startDate }
    guard let first = sorted.first else { return 0 }
    var total = 0.0
    var start = first.startDate
    var end = first.endDate
    for sample in sorted.dropFirst() {
      if sample.startDate > end {
        total += end.timeIntervalSince(start)
        start = sample.startDate
        end = sample.endDate
      } else if sample.endDate > end {
        end = sample.endDate
      }
    }
    return total + end.timeIntervalSince(start)
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
    case "presentActivityPicker": presentActivityPicker(args, result)
    case "setLocalizedNotificationCopy": setLocalizedNotificationCopy(args, result)
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
    // DeviceActivity threshold monitoring is iOS 16+. On iOS 15 there is nothing
    // to reconcile — the Dart side never reaches an approved status there.
    guard #available(iOS 16.0, *) else { result(nil); return }
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

        let event: DeviceActivityEvent
        if (goal["mode"] as? String) == "apps" {
          // Mode A: decode the picked FamilyActivitySelection and monitor its
          // COMBINED app/category/web usage. A goal whose selection can't be
          // decoded is SKIPPED (never registered), so it records couldn't-verify
          // rather than silently monitoring nothing.
          guard
            let blob = goal["selection"] as? String,
            let selection = decodeSelection(blob)
          else { continue }
          event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: minutes)
          )
        } else {
          // Mode B: empty selection = total device usage.
          event = DeviceActivityEvent(
            applications: [],
            categories: [],
            webDomains: [],
            threshold: DateComponents(minute: minutes)
          )
        }

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

  // MARK: - Mode A: FamilyActivityPicker + selection codec

  @available(iOS 16.0, *)
  private static func decodeSelection(_ blob: String) -> FamilyActivitySelection? {
    guard let data = Data(base64Encoded: blob) else { return nil }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  @available(iOS 16.0, *)
  private static func encodeSelection(_ selection: FamilyActivitySelection) -> String? {
    guard let data = try? JSONEncoder().encode(selection) else { return nil }
    return data.base64EncodedString()
  }

  /// Presents `FamilyActivityPicker` in a hosting controller and returns the
  /// encoded selection (or nil on cancel / unavailable). Requires FamilyControls
  /// `.approved` authorization (requested Dart-side before this is called) to
  /// render real content.
  private static func presentActivityPicker(
    _ args: [String: Any]?, _ result: @escaping FlutterResult
  ) {
    guard #available(iOS 16.0, *) else { result(nil); return }
    let initialBlob = args?["selection"] as? String
    let title = args?["title"] as? String ?? "Choose apps & categories"
    let doneLabel = args?["done"] as? String ?? "Done"
    let cancelLabel = args?["cancel"] as? String ?? "Cancel"

    DispatchQueue.main.async {
      guard let top = topViewController() else { result(nil); return }
      var initial = FamilyActivitySelection()
      if let blob = initialBlob, let decoded = decodeSelection(blob) {
        initial = decoded
      }
      // Return exactly once, whether the sheet finishes via Done/Cancel.
      var didReturn = false
      let finish: (FamilyActivitySelection?) -> Void = { selection in
        guard !didReturn else { return }
        didReturn = true
        top.dismiss(animated: true)
        guard let selection = selection, let blob = encodeSelection(selection) else {
          result(nil)
          return
        }
        result([
          "blob": blob,
          "appCount": selection.applicationTokens.count,
          "categoryCount": selection.categoryTokens.count,
        ])
      }
      let sheet = ActivityPickerSheet(
        selection: initial,
        title: title,
        doneLabel: doneLabel,
        cancelLabel: cancelLabel,
        onFinish: finish
      )
      let host = UIHostingController(rootView: sheet)
      // Disable interactive swipe-to-dismiss so the Cancel/Done toolbar — which
      // always calls `finish` — is the ONLY exit. Otherwise a page-sheet swipe
      // down tears the sheet down without firing `result`, leaking the reply and
      // hanging the Dart `await` on presentActivityPicker forever.
      host.isModalInPresentation = true
      top.present(host, animated: true)
    }
  }

  /// Stores the current-locale "limit reached" copy for the extension to read.
  private static func setLocalizedNotificationCopy(
    _ args: [String: Any]?, _ result: @escaping FlutterResult
  ) {
    guard let title = args?["title"] as? String,
          let body = args?["body"] as? String else {
      result(nil); return
    }
    VerificationAppGroup.defaults?.set(
      ["title": title, "body": body],
      forKey: VerificationAppGroup.notificationCopyKey
    )
    result(nil)
  }

  /// The topmost presented view controller in the active window scene. The app
  /// is scene-based, so `AppDelegate.window` is nil — reach the root via
  /// `connectedScenes`.
  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    guard let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first,
          var top = window.rootViewController else { return nil }
    while let presented = top.presentedViewController { top = presented }
    return top
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

/// SwiftUI container hosting `FamilyActivityPicker` with a localized Done/Cancel
/// toolbar. `onFinish(nil)` = cancelled; `onFinish(selection)` = confirmed.
@available(iOS 16.0, *)
private struct ActivityPickerSheet: View {
  @State var selection: FamilyActivitySelection
  let title: String
  let doneLabel: String
  let cancelLabel: String
  let onFinish: (FamilyActivitySelection?) -> Void

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(cancelLabel) { onFinish(nil) }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(doneLabel) { onFinish(selection) }
          }
        }
    }
  }
}
