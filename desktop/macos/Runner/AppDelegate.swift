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
