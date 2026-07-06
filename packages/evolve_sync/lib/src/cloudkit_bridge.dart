import 'dart:typed_data';

/// Account state reported by CloudKit. Sync only proceeds when [available];
/// everything else surfaces as actionable status and never blocks local mode.
enum CloudAccountStatus {
  available,
  noAccount,
  restricted,
  temporarilyUnavailable,
  couldNotDetermine,
}

/// One CloudKit record (the single generic `PrivateRecord` type). The native
/// bridge only ever sees [payload]/[assetPath] as encrypted bytes — never
/// plaintext.
class CloudRecord {
  /// `"<tableName>:<rowUuid>"` or `"avatar:<owner>"`. Deterministic so both
  /// devices converge on the same record for the same logical row.
  final String recordName;
  final String tableName;

  /// Row edit time in epoch milliseconds (the LWW comparator).
  final int updatedAtMs;
  final bool deleted;

  /// AES-GCM ciphertext of the row JSON. Empty for tombstones.
  final Uint8List? payload;

  /// Path to an encrypted CKAsset file (avatar only).
  final String? assetPath;

  const CloudRecord({
    required this.recordName,
    required this.tableName,
    required this.updatedAtMs,
    required this.deleted,
    this.payload,
    this.assetPath,
  });
}

class CloudConflict {
  final String recordName;
  final int serverUpdatedAtMs;
  const CloudConflict(this.recordName, this.serverUpdatedAtMs);
}

class CloudRecordError {
  final String recordName;
  final String code;
  const CloudRecordError(this.recordName, this.code);
}

class SaveOutcome {
  final List<String> saved;

  /// Records the server has a NEWER version of (server-record-changed). The
  /// engine resolves these by pulling + last-write-wins.
  final List<CloudConflict> conflicts;
  final List<CloudRecordError> errors;

  const SaveOutcome({
    this.saved = const [],
    this.conflicts = const [],
    this.errors = const [],
  });
}

class FetchOutcome {
  final List<CloudRecord> records;

  /// Opaque base64 `CKServerChangeToken` to persist and pass next time.
  final String? newToken;
  final bool moreComing;

  const FetchOutcome({
    this.records = const [],
    this.newToken,
    this.moreComing = false,
  });
}

/// Thin abstraction over the native CloudKit operations (private database,
/// custom zone). The real implementation is a MethodChannel to Swift; tests use
/// an in-memory fake. All sync logic lives above this, in the Dart engine, so it
/// is unit-testable without a device.
abstract class CloudKitBridge {
  Future<CloudAccountStatus> accountStatus();
  Future<void> ensureZone();
  Future<SaveOutcome> saveRecords(List<CloudRecord> records);
  Future<FetchOutcome> fetchChanges(String? token);
  Future<void> deleteRecords(List<String> recordNames);
  Future<void> deleteZone();
}
