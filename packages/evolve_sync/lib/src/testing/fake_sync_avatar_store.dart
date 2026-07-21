import 'dart:typed_data';

import '../sync_avatar_store.dart';

/// In-memory [SyncAvatarStore] for engine tests — no filesystem.
///
/// Staged uploads/downloads go through [assetTransport], a map standing in for
/// "bytes that travel through CloudKit as a CKAsset". Two devices' stores share
/// ONE transport map (like they share one [FakeCloudKitBridge]) so a path
/// staged by device A is readable when device B "downloads" it.
class FakeSyncAvatarStore implements SyncAvatarStore {
  FakeSyncAvatarStore({
    required this.name,
    Map<String, Uint8List>? assetTransport,
  }) : assetTransport = assetTransport ?? {};

  /// Distinguishes staged paths when two stores share a transport.
  final String name;
  final Map<String, Uint8List> assetTransport;

  /// The device's local avatar (plaintext), null when unset/removed.
  Uint8List? avatar;

  int writeCalls = 0;
  int removeCalls = 0;
  int _staged = 0;

  @override
  Future<Uint8List?> readAvatarBytes() async => avatar;

  /// The fake keeps bytes and configuration in one field, so these agree by
  /// construction. A store whose file has gone missing while an avatar is still
  /// configured — the case the engine must never turn into a tombstone — is
  /// modelled by overriding this in the test.
  @override
  Future<bool> hasAvatarConfigured() async => avatar != null;

  @override
  Future<void> writeAvatarBytes(Uint8List bytes) async {
    writeCalls++;
    avatar = bytes;
  }

  @override
  Future<void> removeAvatar() async {
    removeCalls++;
    avatar = null;
  }

  @override
  Future<String> stageEncryptedUpload(Uint8List encryptedBytes) async {
    final path = 'staged:$name:${++_staged}';
    assetTransport[path] = encryptedBytes;
    return path;
  }

  @override
  Future<Uint8List> readStagedDownload(String assetPath) async {
    final bytes = assetTransport[assetPath];
    if (bytes == null) {
      throw StateError('no staged asset at $assetPath');
    }
    return bytes;
  }
}
