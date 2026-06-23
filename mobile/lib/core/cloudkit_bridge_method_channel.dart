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
    final raw = await channel.invokeMethod<String>('accountStatus');
    return _statusFromString(raw);
  }

  @override
  Future<void> ensureZone() => channel.invokeMethod<void>('ensureZone');

  @override
  Future<SaveOutcome> saveRecords(List<CloudRecord> records) async {
    final res = await channel.invokeMapMethod<String, dynamic>('saveRecords', {
      'records': [for (final r in records) _encodeRecord(r)],
    });
    if (res == null) return const SaveOutcome();
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
    );
    if (res == null) return const FetchOutcome();
    return FetchOutcome(
      records: [for (final r in _mapList(res['records'])) _decodeRecord(r)],
      newToken: res['newToken'] as String?,
      moreComing: (res['moreComing'] as bool?) ?? false,
    );
  }

  @override
  Future<void> deleteRecords(List<String> recordNames) =>
      channel.invokeMethod<void>('deleteRecords', {'recordNames': recordNames});

  @override
  Future<void> deleteZone() => channel.invokeMethod<void>('deleteZone');

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
