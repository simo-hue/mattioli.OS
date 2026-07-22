import Cocoa
import CloudKit
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// A silent push telling us the CloudKit zone changed.
  ///
  /// Runs the app's ORDINARY sync — the push carries no data and decides
  /// nothing; it changes only WHEN sync happens. The periodic poll stays
  /// alongside it, because push delivery is not guaranteed.
  override func application(
    _ application: NSApplication,
    didReceiveRemoteNotification userInfo: [String: Any]
  ) {
    guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
          notification.containerIdentifier == CloudKitSyncBridge.containerId
    else {
      super.application(application, didReceiveRemoteNotification: userInfo)
      return
    }
    CloudKitSyncBridge.notifyRemoteChange()
  }
  /// APNs registration outcome — see the iOS bridge for why this is logged.
  override func application(
    _ application: NSApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    CloudKitSyncBridge.noteApnsCallback()
    CloudKitSyncBridge.logNative(
      "info",
      "[APNs] Registered for remote notifications (token \(deviceToken.count) bytes)"
    )
  }

  override func application(
    _ application: NSApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    CloudKitSyncBridge.noteApnsCallback()
    CloudKitSyncBridge.logNative(
      "error",
      "[APNs] Registration FAILED: \(error.localizedDescription)"
    )
  }
}

/// Native half of Private mode's local-only guarantee: a thin MethodChannel
/// (`evolve/private_storage`) whose sole job is to flag the Private-data
/// directory as excluded from device backups (Time Machine / iCloud). The
/// SQLCipher key is device-local (see `SecureStorageUtils`), so the encrypted
/// data must never ride a backup onto another device where that key doesn't
/// exist. Line-for-line port of the iOS bridge in
/// `mobile/ios/Runner/AppDelegate.swift` (same channel + method contract). Kept
/// in this file (already a Runner target member) so it builds without editing
/// the Xcode project.
enum PrivateStorageBridge {
  static func register(_ messenger: FlutterBinaryMessenger) {
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
/// the Dart engine (`packages/evolve_sync`), and payloads cross as
/// already-encrypted bytes.
///
/// Line-for-line port of the iOS bridge in `mobile/ios/Runner/AppDelegate.swift`
/// (same container, zone, record type and channel contract — both apps converge
/// on the same CloudKit records). The CloudKit APIs used require macOS 12.3+
/// (the deployment target). Requires the iCloud (CloudKit) capability + the
/// `iCloud.com.simo.evolve` container in Xcode (see the entitlements files).
/// Kept in this file (already a Runner target member) so it builds without
/// editing the Xcode project.
enum CloudKitSyncBridge {
  static let containerId = "iCloud.com.simo.evolve"
  static let zoneName = "PrivateZone"
  static let recordType = "PrivateRecord"

  /// Reserved record name for the empty-zone first-mint arbitration sentinel
  /// (see `tryClaimFirstMint`). Bookkeeping, never a data row: excluded from
  /// `zoneHasRecords` and skipped by the Dart pull. MUST match
  /// `kKeyOwnerSentinelRecordName` in `package:evolve_sync`'s cloudkit_bridge.dart.
  static let keyOwnerSentinelName = "__evolve_key_owner__"

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

    // APNs registration lives HERE, not in `applicationDidFinishLaunching`.
    //
    // That override was never invoked on macOS — the app logged neither the
    // registration request nor either APNs callback, while everything set up
    // from this function (the channel, the CloudKit subscription) worked. So the
    // Mac never asked for a push token, which is why it never received one and
    // why no failure was reported either: nothing had failed, nothing had been
    // requested.
    //
    // This function is reached from `MainFlutterWindow`, on the path that
    // already demonstrably runs. Silent (`content-available`) pushes need no
    // notification authorization, so this prompts the user for nothing.
    logNative("info", "[APNs] Requesting registration...")
    NSApplication.shared.registerForRemoteNotifications()
    scheduleRegistrationWatchdog()
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
    case "tryClaimFirstMint": tryClaimFirstMint(args, result)
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
    op.recordWasChangedBlock = { recordID, res in
      // The first-mint sentinel is bookkeeping, not data: a device that only
      // claimed it (then crashed before minting) must still be able to re-mint,
      // so it must NOT read as "the zone already holds records".
      if recordID.recordName == keyOwnerSentinelName { return }
      if case .success = res { found = true }
    }
    // A tombstone is still evidence the zone has been written to.
    op.recordWithIDWasDeletedBlock = { recordID, _ in
      if recordID.recordName == keyOwnerSentinelName { return }
      found = true
    }
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

  // MARK: - First-mint claim (empty-zone race)

  /// Atomically claim the right to mint the first E2E key for a genuinely-empty
  /// zone. Ensures the zone exists, then conditionally creates the singleton
  /// owner sentinel; the Dart engine calls this only when it is about to mint
  /// and the zone holds no data. Returns true (won / already ours), false
  /// (another owner won), or nil (inconclusive → the Dart side falls back to its
  /// prior behaviour, so this is strictly fail-open). See the Dart
  /// `CloudKitBridge.tryClaimFirstMint` contract.
  private static func tryClaimFirstMint(
    _ args: [String: Any]?,
    _ result: @escaping FlutterResult,
    attempt: Int = 0
  ) {
    guard let ownerId = args?["ownerId"] as? String else {
      result(flutterBadArgs); return
    }
    // The sentinel lives in the custom zone, which a genuinely-first device does
    // not have yet — ensure it before the conditional create.
    let zone = CKRecordZone(zoneID: zoneID)
    let zoneOp = CKModifyRecordZonesOperation(
      recordZonesToSave: [zone], recordZoneIDsToDelete: nil
    )
    zoneOp.qualityOfService = .userInitiated
    zoneOp.modifyRecordZonesResultBlock = { res in
      switch res {
      case .success:
        claimSentinel(ownerId, result, attempt: attempt)
      case .failure(let error):
        if let delay = retryDelay(error, attempt: attempt) {
          scheduleRetry("tryClaimFirstMint", after: delay, attempt: attempt) {
            tryClaimFirstMint(args, result, attempt: attempt + 1)
          }
          return
        }
        // Inconclusive → fail OPEN (nil): the Dart caller reverts to its prior
        // behaviour and the untouched zoneHasRecords guard still protects the
        // populated-zone case. nil here can only ADD safety, never remove it.
        main { result(nil) }
      }
    }
    database.add(zoneOp)
  }

  private static func claimSentinel(
    _ ownerId: String,
    _ result: @escaping FlutterResult,
    attempt: Int
  ) {
    let record = CKRecord(
      recordType: recordType,
      recordID: CKRecord.ID(recordName: keyOwnerSentinelName, zoneID: zoneID)
    )
    // Carry the same fields a decoded record needs on the Dart side (it skips
    // the sentinel by name, but must still decode without a missing-key crash).
    record["tableName"] = keyOwnerSentinelName as NSString
    record["updatedAt"] = NSNumber(value: 0)
    record["deleted"] = NSNumber(value: 0)
    record["owner"] = ownerId as NSString

    let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
    op.qualityOfService = .userInitiated
    // A FRESH record (no server change tag) + .ifServerRecordUnchanged = an
    // atomic create-if-absent: the server saves it only when no record with this
    // ID exists, and returns .serverRecordChanged when one already does. That is
    // the whole point — exactly one racing device can create the sentinel.
    op.savePolicy = .ifServerRecordUnchanged

    var won: Bool?
    op.perRecordSaveBlock = { _, res in
      switch res {
      case .success:
        won = true // this device created the sentinel
      case .failure(let error):
        if let ck = error as? CKError, ck.code == .serverRecordChanged {
          // Someone already claimed. Idempotent for the SAME device: a crash
          // between the claim and the mint must let THIS owner re-mint, not
          // dead-lock. A missing/other owner → false (defer), never a re-mint.
          let existingOwner = ck.serverRecord?["owner"] as? String
          won = (existingOwner == ownerId)
        } else {
          won = nil // inconclusive → fail open
        }
      }
    }
    op.modifyRecordsResultBlock = { res in
      if case .failure(let error) = res {
        // A .partialFailure already ran perRecordSaveBlock (won is set); trust
        // it. A retryable throttle is retried. Anything else is inconclusive.
        if let ck = error as? CKError, ck.code == .partialFailure {
          main { result(won) }
          return
        }
        if let delay = retryDelay(error, attempt: attempt) {
          scheduleRetry("tryClaimFirstMint", after: delay, attempt: attempt) {
            claimSentinel(ownerId, result, attempt: attempt + 1)
          }
          return
        }
        main { result(nil) } // fail open
        return
      }
      main { result(won) }
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

/// Native half of the "start the local LLM server from inside the app" feature
/// (`evolve/local_llm`). The app is sandboxed, so it CANNOT spawn `ollama serve`
/// or `lms server start` or any shell/binary — but it CAN ask LaunchServices
/// (via NSWorkspace) to launch an already-installed local-LLM desktop app, which
/// in turn brings up its HTTP server. No new entitlement is needed: launching
/// another app is LaunchServices-mediated and sandbox-legal.
///
/// **This bridge is deliberately product-agnostic.** Bundle identifiers and
/// install paths arrive as call arguments from `LocalServerTarget` on the Dart
/// side rather than being hardcoded here. That is not just tidiness: a constant
/// in this file is unreachable from every Flutter test, so the Ollama ids that
/// used to live here were both unverified AND unverifiable. In Dart they are
/// ordinary data a unit test can assert on, and adding a third provider needs no
/// Swift edit at all.
///
/// Kept in this file (already a Runner target member) so it builds without
/// editing the Xcode project — same convention as the bridges above.
enum LocalLlmBridge {
  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "evolve/local_llm",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "localAppInstalled":
        guard let target = Target(call.arguments) else {
          result(false)
          return
        }
        result(appURL(target) != nil)
      case "localAppRunning":
        guard let target = Target(call.arguments) else {
          result(false)
          return
        }
        result(isRunning(target))
      case "launchLocalApp":
        guard let target = Target(call.arguments) else {
          result("notInstalled")
          return
        }
        launch(target, result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// The Dart-supplied identity of one local-LLM product.
  private struct Target {
    let bundleIds: [String]
    let appPath: String

    init?(_ arguments: Any?) {
      guard let map = arguments as? [String: Any],
            let bundleIds = map["bundleIds"] as? [String]
      else { return nil }
      self.bundleIds = bundleIds
      self.appPath = (map["appPath"] as? String) ?? ""
    }
  }

  /// Resolves an installed app's URL via LaunchServices (sandbox-safe), falling
  /// back to the conventional install path. Returns nil when not found.
  ///
  /// The path fallback is what keeps an unconfirmed bundle identifier a soft
  /// failure: a default install still resolves even if every id misses.
  private static func appURL(_ target: Target) -> URL? {
    let workspace = NSWorkspace.shared
    for identifier in target.bundleIds {
      if let url = workspace.urlForApplication(withBundleIdentifier: identifier) {
        return url
      }
    }
    if !target.appPath.isEmpty,
       FileManager.default.fileExists(atPath: target.appPath) {
      return URL(fileURLWithPath: target.appPath)
    }
    return nil
  }

  /// Whether the app is currently RUNNING, as opposed to merely installed.
  ///
  /// This is what lets Dart tell two very different timeouts apart: "the app
  /// never came up" versus "the app is open but its server is off" — the
  /// ordinary first-run state for LM Studio, whose HTTP server is a separate
  /// toggle. Without it, that user would be told the launch failed while
  /// LM Studio sits visibly open on their screen.
  ///
  /// Matched by bundle id only. An app resolved purely by the path fallback
  /// reports false here, which degrades to the generic timeout message rather
  /// than to a wrong diagnosis.
  private static func isRunning(_ target: Target) -> Bool {
    for identifier in target.bundleIds {
      if !NSRunningApplication
        .runningApplications(withBundleIdentifier: identifier).isEmpty {
        return true
      }
    }
    return false
  }

  private static func launch(_ target: Target, _ result: @escaping FlutterResult) {
    guard let url = appURL(target) else {
      result("notInstalled")
      return
    }
    let configuration = NSWorkspace.OpenConfiguration()
    // Start the server in the background without stealing focus from Evolve.
    configuration.activates = false
    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
      DispatchQueue.main.async {
        result(error == nil ? "launched" : "failed")
      }
    }
  }
}
