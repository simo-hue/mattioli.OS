import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// DEBUG-ONLY, persistent, PLAINTEXT key-value store for the Private-mode
/// device-local secrets (the SQLCipher database key + the stable owner UUID).
///
/// WHY THIS EXISTS — on an unsigned / ad-hoc local `flutter run`, the macOS
/// `$(AppIdentifierPrefix)` (Team ID) that scopes the Keychain access group the
/// device-local key lives under is unstable between builds. A key written on one
/// run is therefore not found on the next, the encrypted DB can no longer be
/// decrypted (SQLCipher error 26 "file is not a database"), and the recovery
/// flow resets the DB on every launch. This store side-steps the Keychain in
/// debug by persisting the secrets to a plaintext JSON file under Application
/// Support, so a local `flutter run` keeps the same DB key (and owner id) across
/// restarts. A signed / notarized / App Store build has a stable Team ID and
/// never hits this problem — so this exists purely for the dev inner loop.
///
/// SECURITY — the secrets are stored in PLAINTEXT. That is acceptable ONLY
/// because this code path can compile and run in a DEBUG build on the
/// developer's own machine and NEVER in release: [SecureStorageUtils] gates
/// every call to this store behind `kDebugMode` (a compile-time const), so a
/// release build const-folds the branch away, tree-shakes this class out
/// entirely, and never creates the file.
///
/// This is a thin async JSON map on disk: [read] / [write] / [delete] with a
/// round-trippable `{ key: value }` payload. A missing or corrupt file is
/// treated as empty and never throws, and every operation is serialized so
/// concurrent device-local reads/writes can't interleave a read-modify-write and
/// corrupt the JSON.
class DevDeviceLocalStore {
  /// Production constructor: the backing file is resolved lazily under
  /// `getApplicationSupportDirectory()` on first use.
  DevDeviceLocalStore();

  /// Test seam: back the store with an explicit [file] instead of resolving one
  /// under Application Support, so the store can be unit-tested without a
  /// path_provider channel mock.
  @visibleForTesting
  DevDeviceLocalStore.forFile(File file) : _file = file;

  /// Backing JSON file name under Application Support.
  static const fileName = 'dev_device_local_secrets.json';

  /// Resolved lazily in production (cached after the first [_resolveFile]);
  /// supplied up-front by [DevDeviceLocalStore.forFile] in tests.
  File? _file;

  /// Serializes every read/write/delete so overlapping device-local operations
  /// cannot interleave a read-modify-write and corrupt the JSON. Each op appends
  /// itself to this single awaited chain; the chain itself never rejects (a
  /// failed op's error surfaces on the caller's future, not on the chain) so one
  /// failure can't wedge every later operation.
  Future<void> _lock = Future<void>.value();

  /// Returns the stored value for [key], or null when absent.
  Future<String?> read(String key) =>
      _serialized(() async => (await _load())[key]);

  /// Stores [value] under [key], creating the backing file on first write.
  Future<void> write(String key, String value) => _serialized(() async {
        final map = await _load();
        map[key] = value;
        await _save(map);
      });

  /// Removes [key] if present. A delete of an absent key is a no-op and does not
  /// create the file.
  Future<void> delete(String key) => _serialized(() async {
        final map = await _load();
        if (map.remove(key) != null) {
          await _save(map);
        }
      });

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    // Advance the lock past this op regardless of outcome; swallow the error on
    // the CHAIN only — the real error still surfaces on [result] to the caller.
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Map<String, String>> _load() async {
    final file = await _resolveFile();
    try {
      if (!await file.exists()) return <String, String>{};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return <String, String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      final map = <String, String>{};
      decoded.forEach((key, value) {
        if (value is String) map[key.toString()] = value;
      });
      return map;
    } catch (_) {
      // A missing / corrupt / unreadable file is treated as EMPTY, never an
      // error: this dev-only escape hatch must never throw and abort a local
      // `flutter run`. A corrupt file is transparently overwritten by the next
      // write.
      return <String, String>{};
    }
  }

  Future<void> _save(Map<String, String> map) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(map), flush: true);
  }

  Future<File> _resolveFile() async {
    final existing = _file;
    if (existing != null) return existing;
    final dir = await getApplicationSupportDirectory();
    return _file = File(p.join(dir.path, fileName));
  }
}
