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
  /// Plaintext bytes of the current local avatar, or null when there are none
  /// to give — EITHER because no avatar is set OR because its file could not be
  /// read. [hasAvatarConfigured] is what tells those two apart.
  Future<Uint8List?> readAvatarBytes();

  /// Whether this device currently INTENDS to have an avatar — i.e.
  /// `profiles.avatar_url` is set — regardless of whether the file behind it can
  /// actually be read.
  ///
  /// Exists because a null from [readAvatarBytes] used to mean both "the user
  /// removed their avatar" and "we lost the file", and the engine replicated
  /// both as a DELETION. One device losing track of its own copy therefore
  /// destroyed the image on every device, permanently and irrecoverably — the
  /// bytes were removed from the zone too — while the sync reported success.
  ///
  /// That is not a theoretical race. `profiles.avatar_url` stores an ABSOLUTE
  /// path rooted at the app's container, and iOS regenerates that container's
  /// UUID across reinstalls, so the path goes stale while the database still
  /// believes an avatar exists.
  ///
  /// Deliberately abstract rather than defaulted. A default of `false` would
  /// silently preserve the destructive behaviour for any implementation that
  /// forgot to override it, which is the precise failure mode this method
  /// exists to remove; a compile error is the correct forcing function.
  Future<bool> hasAvatarConfigured();

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
