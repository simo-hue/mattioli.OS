/// Where to look for the local avatar file, given what the database wrote down.
///
/// `profiles.avatar_url` stores an ABSOLUTE path built from the app's container
/// at the moment the image was saved. A container path is not a stable
/// identifier: iOS regenerates the UUID in it across reinstalls, and a Mac's can
/// change when the app is re-signed or migrated. The image never moves — only
/// the prefix we wrote down does.
///
/// The consequences of trusting the stored string were both user-visible and
/// destructive. The photo rendered as the (black) default avatar while the file
/// sat on disk; and because the engine could not tell "the file is missing" from
/// "the user removed their avatar", the next sync pushed a TOMBSTONE that
/// deleted the picture from the zone and from every other device.
///
/// Pure and dart:io-free on purpose, for the same reason [SyncAvatarStore] is:
/// the shared package must not know about platform paths, and this is the one
/// piece of the logic worth testing directly. Both apps call it so they cannot
/// drift apart — divergence in exactly this kind of helper is how the accent
/// colour and the settings read-back ended up behaving differently on each
/// platform.
library;

/// Candidate absolute paths for [stored], most-likely first. The caller checks
/// each for existence in order and takes the first hit.
///
/// The BASENAME resolved against the current [supportDir] comes first, because
/// that is the one that survives a container move. The literal [stored] value is
/// kept as a fallback so a path written by some other means still works.
///
/// Self-healing rather than a migration: no schema change, nothing has to run
/// first, it repairs a database already carrying a stale path, and it is
/// idempotent — a value already stored as a bare filename resolves to the same
/// place.
List<String> avatarPathCandidates({
  required String stored,
  required String supportDir,
  String avatarDirName = 'private_profile',
}) {
  final trimmed = stored.trim();
  if (trimmed.isEmpty) return const [];

  final name = _basename(trimmed);
  final candidates = <String>[];
  if (name.isNotEmpty) {
    candidates.add('${_stripTrailingSeparator(supportDir)}/$avatarDirName/$name');
  }
  // A value that is ALREADY just a filename resolves to the same string above,
  // so don't offer it twice — and never offer a bare name as a relative path,
  // which would resolve against the process working directory.
  if (trimmed != name && !candidates.contains(trimmed)) candidates.add(trimmed);
  return candidates;
}

/// Last path segment. Handles both separators: a value written on one platform
/// can be read on another after a backup restore, and a Windows-style separator
/// must not be mistaken for part of the filename.
String _basename(String path) {
  final cut = path.lastIndexOf(RegExp(r'[/\\]'));
  return cut < 0 ? path : path.substring(cut + 1);
}

String _stripTrailingSeparator(String dir) =>
    dir.endsWith('/') ? dir.substring(0, dir.length - 1) : dir;
