import 'package:flutter/services.dart';

import 'cloudkit_bridge.dart';

/// Production [CloudKitBridge] over a MethodChannel to the native Swift
/// implementation (`evolve/cloudkit`). It only marshals the contract —
/// all sync logic stays in the Dart engine — and only ever passes encrypted
/// bytes across the channel.
class MethodChannelCloudKitBridge implements CloudKitBridge {
  static const MethodChannel channel = MethodChannel('evolve/cloudkit');

  const MethodChannelCloudKitBridge();

  @override
  Future<CloudAccountStatus> accountStatus() async {
    // If the native channel isn't registered (e.g. a lifecycle regression where
    // neither AppDelegate nor SceneDelegate wired it up), degrade to
    // couldNotDetermine instead of throwing. The engine treats that as "iCloud
    // unavailable" and no-ops, so local Private mode keeps working. This is the
    // single gate the engine checks before every sync, so it's the one call
    // that must never throw on a missing plugin.
    try {
      final raw = await channel.invokeMethod<String>('accountStatus');
      return _statusFromString(raw);
    } on MissingPluginException {
      return CloudAccountStatus.couldNotDetermine;
    }
  }

  @override
  Future<void> ensureZone() async {
    try {
      await channel.invokeMethod<void>('ensureZone');
    } on MissingPluginException {
      // No-op: the account gate already short-circuits sync when the channel is
      // missing; this just keeps a stray call from crashing.
    }
  }

  /// Wire [onChange] to the silent pushes CloudKit delivers when the zone
  /// changes. The native side invokes `remoteChange` on this channel; the app
  /// responds by running its ORDINARY sync.
  ///
  /// Deliberately a plain callback into the existing sync path rather than a
  /// second, push-specific one: a separate path is how two code paths that must
  /// agree start disagreeing. Push only changes WHEN sync runs, never WHAT it
  /// does.
  ///
  /// Safe to call more than once — the last handler wins.
  /// [onNativeLog] receives `(level, message)` for events the SWIFT side needs
  /// to surface — chiefly APNs registration success/failure, which is otherwise
  /// completely invisible: `registerForRemoteNotifications()` is fire-and-forget,
  /// and a device with no push token looks identical to a working one.
  static void setRemoteChangeHandler(
    void Function() onChange, {
    void Function(String level, String message)? onNativeLog,
  }) {
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'remoteChange':
          onChange();
        case 'nativeLog':
          final args = (call.arguments as Map?)?.cast<String, Object?>();
          onNativeLog?.call(
            '${args?['level'] ?? 'info'}',
            '${args?['message'] ?? ''}',
          );
      }
      return null;
    });
  }

  /// Detach the handler (app teardown / mode switch).
  static void clearRemoteChangeHandler() => channel.setMethodCallHandler(null);

  @override
  Future<void> ensureSubscription() async {
    try {
      await channel.invokeMethod<void>('ensureSubscription');
    } on MissingPluginException {
      // No channel ⇒ no sync at all on this platform; the poll is the whole
      // story and nothing is lost.
    } on PlatformException catch (_) {
      // Non-fatal BY DESIGN. A device that never registers simply falls back to
      // the periodic poll, which is exactly where it was before push existed.
      // Throwing here would take down enable() over a latency optimisation.
    }
  }

  @override
  Future<bool> zoneHasRecords() async {
    try {
      return await channel.invokeMethod<bool>('zoneHasRecords') ?? false;
    } on MissingPluginException {
      // Channel missing ⇒ sync cannot run at all, so "no records" is both true
      // in effect and the safe answer: it cannot cause a spurious DEFER.
      return false;
    } on PlatformException {
      // The probe guards against minting a second key, so an INCONCLUSIVE
      // answer must not be read as "zone is empty" — that is the branch that
      // mints. Fail closed: report records present so enable defers. A wrongly
      // deferred enable is retried on the next trigger; a wrongly minted key
      // is permanent data loss.
      return true;
    }
  }

  @override
  Future<bool?> tryClaimFirstMint(String ownerId) async {
    try {
      // Native returns a real bool (won/lost) or, on an inconclusive error,
      // null. Any failure here is treated as `null` so the guard is strictly
      // fail-open — see [CloudKitBridge.tryClaimFirstMint]. Unlike
      // [zoneHasRecords], this must NOT fail closed (return false): a false is
      // "another device won, defer forever", which on a genuinely-first device
      // whose native call merely errored would wedge enable() permanently. The
      // safe inconclusive answer is null → fall back to the existing behaviour,
      // which the untouched [zoneHasRecords] guard already protects.
      return await channel.invokeMethod<bool>(
        'tryClaimFirstMint',
        {'ownerId': ownerId},
      );
    } on MissingPluginException {
      return null; // no native support → mint as before
    } on PlatformException {
      return null; // inconclusive → don't change behaviour
    }
  }

  @override
  Future<SaveOutcome> saveRecords(List<CloudRecord> records) async {
    final res = await channel.invokeMapMethod<String, dynamic>('saveRecords', {
      'records': [for (final r in records) _encodeRecord(r)],
    }).catchError(
      (_) => <String, dynamic>{}, // missing plugin → nothing saved
      test: (e) => e is MissingPluginException,
    );
    if (res == null || res.isEmpty) return const SaveOutcome();
    return SaveOutcome(
      saved: _stringList(res['saved']),
      conflicts: [
        for (final c in _mapList(res['conflicts']))
          CloudConflict(
            c['recordName'] as String,
            (c['serverUpdatedAtMs'] as num).toInt(),
          ),
      ],
      errors: [
        for (final e in _mapList(res['errors']))
          CloudRecordError(e['recordName'] as String, '${e['code']}'),
      ],
    );
  }

  @override
  Future<FetchOutcome> fetchChanges(String? token) async {
    final res = await channel.invokeMapMethod<String, dynamic>(
      'fetchChanges',
      {'token': token},
    ).catchError(
      (_) => <String, dynamic>{}, // missing plugin → no remote changes
      test: (e) => e is MissingPluginException,
    );
    if (res == null || res.isEmpty) return const FetchOutcome();
    return FetchOutcome(
      records: [for (final r in _mapList(res['records'])) _decodeRecord(r)],
      newToken: res['newToken'] as String?,
      moreComing: (res['moreComing'] as bool?) ?? false,
    );
  }

  @override
  Future<void> deleteRecords(List<String> recordNames) async {
    try {
      await channel
          .invokeMethod<void>('deleteRecords', {'recordNames': recordNames});
    } on MissingPluginException {
      // No-op (see [accountStatus]).
    }
  }

  @override
  Future<void> deleteZone() async {
    try {
      await channel.invokeMethod<void>('deleteZone');
    } on MissingPluginException {
      // No-op (see [accountStatus]).
    }
  }

  // ── (de)serialization ──────────────────────────────────────────────────────

  Map<String, dynamic> _encodeRecord(CloudRecord r) => {
        'recordName': r.recordName,
        'tableName': r.tableName,
        'updatedAtMs': r.updatedAtMs,
        'deleted': r.deleted,
        if (r.payload != null) 'payload': r.payload,
        if (r.assetPath != null) 'assetPath': r.assetPath,
      };

  CloudRecord _decodeRecord(Map<String, dynamic> m) => CloudRecord(
        recordName: m['recordName'] as String,
        tableName: m['tableName'] as String,
        updatedAtMs: (m['updatedAtMs'] as num).toInt(),
        deleted: (m['deleted'] as bool?) ?? false,
        payload: m['payload'] as Uint8List?,
        assetPath: m['assetPath'] as String?,
      );

  List<String> _stringList(Object? v) =>
      (v as List?)?.map((e) => e as String).toList() ?? const [];

  List<Map<String, dynamic>> _mapList(Object? v) =>
      (v as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      const [];

  static CloudAccountStatus _statusFromString(String? s) {
    switch (s) {
      case 'available':
        return CloudAccountStatus.available;
      case 'noAccount':
        return CloudAccountStatus.noAccount;
      case 'restricted':
        return CloudAccountStatus.restricted;
      case 'temporarilyUnavailable':
        return CloudAccountStatus.temporarilyUnavailable;
      default:
        return CloudAccountStatus.couldNotDetermine;
    }
  }
}
