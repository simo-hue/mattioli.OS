import 'dart:io';
import 'dart:typed_data';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'private_local_database.dart';

/// Mobile file-side of avatar sync: local image + `avatar_url` handling is
/// delegated to [PrivateLocalDatabase] (which owns the `private_profile/`
/// folder and the no-re-dirty column write); staging files live in the app's
/// temp directory and only ever hold ciphertext.
class AppSyncAvatarStore implements SyncAvatarStore {
  const AppSyncAvatarStore();

  @override
  Future<Uint8List?> readAvatarBytes() =>
      PrivateLocalDatabase().readAvatarBytes();

  @override
  Future<void> writeAvatarBytes(Uint8List bytes) =>
      PrivateLocalDatabase().applyPulledAvatar(bytes);

  @override
  Future<void> removeAvatar() => PrivateLocalDatabase().removePulledAvatar();

  @override
  Future<String> stageEncryptedUpload(Uint8List encryptedBytes) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'evolve_sync_avatar_${DateTime.now().microsecondsSinceEpoch}.bin',
    );
    await File(path).writeAsBytes(encryptedBytes, flush: true);
    return path;
  }

  @override
  Future<Uint8List> readStagedDownload(String assetPath) =>
      File(assetPath).readAsBytes();
}
