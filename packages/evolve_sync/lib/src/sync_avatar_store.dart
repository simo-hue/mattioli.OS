import 'dart:typed_data';

/// File-side of avatar sync, implemented by each app so the engine stays free
/// of dart:io and platform paths.
///
/// The avatar is the one non-row payload: a single encrypted `CKAsset` under
/// the record name `avatar:<canonicalOwner>`. The engine handles encryption,
/// LWW and bookkeeping; this store handles bytes-on-disk:
///
/// - the LOCAL avatar image (read for push, rewrite on pull), and
/// - the STAGING files the native bridge uploads/downloads (`assetPath` in the
///   bridge contract) — always ciphertext, never plaintext.
///
/// Contract for [writeAvatarBytes]/[removeAvatar]: updating
/// `profiles.avatar_url` fires the table's dirty trigger, so implementations
/// MUST write it via `SyncLocalStore.setLocalOnlyColumn` (which restores the
/// row's prior sync state) — otherwise every pulled avatar re-pushes the
/// profile row in an endless ping-pong.
abstract class SyncAvatarStore {
  /// Plaintext bytes of the current local avatar, or null if none is set (or
  /// the file has gone missing — the engine then pushes a tombstone).
  Future<Uint8List?> readAvatarBytes();

  /// Persist pulled plaintext [bytes] as the local avatar file and point
  /// `profiles.avatar_url` at it (see the class note about not re-dirtying).
  Future<void> writeAvatarBytes(Uint8List bytes);

  /// Remove the local avatar file and clear `profiles.avatar_url` (a pulled
  /// avatar tombstone; same no-re-dirty contract).
  Future<void> removeAvatar();

  /// Write [encryptedBytes] to a temp file the native bridge can wrap as a
  /// CKAsset; returns the path handed to `CloudRecord.assetPath`.
  Future<String> stageEncryptedUpload(Uint8List encryptedBytes);

  /// Read the (still encrypted) asset file the bridge downloaded to
  /// [assetPath] during a fetch.
  Future<Uint8List> readStagedDownload(String assetPath);
}
