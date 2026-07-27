import 'package:sqflite_common/sqlite_api.dart';

/// Why the encrypted private database could not be opened.
///
/// The app used to have exactly TWO states for this — "the key is missing"
/// (fail closed) and "something went wrong" — and every failure that was not a
/// missing key landed in the second one, whose only in-app action permanently
/// deleted the user's database. That collapse is what turned a recoverable
/// wrong-key situation into a dead end offering deletion of intact ciphertext.
///
/// The buckets below are deliberately about *what the user can do*, not about
/// SQLite taxonomy: each one maps to a different recovery, and only
/// [PrivateDbOpenFailure.corrupt] may ever offer a destructive action.
enum PrivateDbOpenFailure {
  /// The file exists but this device's key does not decrypt it. The ciphertext
  /// is intact — it simply needs the *other* key — so nothing may be deleted,
  /// renamed or re-pulled on its own initiative.
  ///
  /// The overwhelmingly common cause is two key stores over one file (a debug
  /// build beside a release build, a restored container, a re-provisioned Mac).
  undecryptable,

  /// The stored schema is NEWER than this build understands. The data is
  /// intact and correctly keyed; the user simply opened an older build. The
  /// only correct action is to reopen the newer build.
  schemaTooNew,

  /// The file is genuinely damaged (SQLite reports malformed/notadb on a file
  /// whose key demonstrably matches). This is the ONLY bucket where offering a
  /// destructive recovery is defensible.
  corrupt,

  /// The database file was renamed, deleted or replaced under a live handle
  /// (`SQLITE_READONLY_DBMOVED`), or the connection is otherwise read-only.
  /// Reads keep succeeding while every write fails, so this must never be
  /// confused with a decryption problem: the fix is to drop the stale handle
  /// and reopen, not to touch the file.
  movedOrReadonly,

  /// Busy/locked — another connection holds the file. Genuinely transient and
  /// the only bucket a timed retry may act on.
  transient,

  /// The environment prevented the open: the file is absent, unreadable, or the
  /// sandbox denied access. Not a data problem; never destructive.
  environment,

  /// Nothing matched. Deliberately conservative: treated as non-destructive
  /// everywhere, because an unrecognised failure is not evidence of damage.
  unknown,
}

/// Classifies a `DatabaseException` (or any error) raised while opening or
/// using the encrypted private database.
///
/// ## Why this cannot be written the obvious way
///
/// The obvious predicate — "SQLCipher reports error 26 `file is not a database`
/// for a wrong key" — is **structurally unreachable from Dart**, and shipping it
/// would have produced dead code that silently never fired. Verified against the
/// shipped plugin and reproduced in a lab harness driving SQLCipher 4.10.0
/// directly:
///
///  * `SqfliteSqlCipherPlugin.m` probes a freshly-opened database with
///    `SELECT COUNT(*) FROM sqlite_schema`, and when that returns nil it replies
///    with a hand-built `open_failed <path>` string, **discarding
///    `[db lastError]` entirely**. So a wrong key surfaces as `open_failed` and
///    the real code 26 never crosses the channel.
///  * Any statement issued afterwards on that same connection returns
///    `SQLITE_NOMEM` ("out of memory"), because SQLite's `CODEC1` macro reports a
///    codec failure as `SQLITE_NOMEM_BKPT` and the pager latches it. The
///    "out of memory" in the field report was never about memory.
///  * The plugin's `-query:` never re-checks the error after stepping, so
///    `PRAGMA user_version` on a poisoned connection is reported as a SUCCESSFUL
///    EMPTY result set. sqflite then reads version `0`, believes a migration is
///    due, and issues `BEGIN EXCLUSIVE` — which is why the observed failure
///    quotes that statement rather than the open itself.
///
/// Every string matched below was taken verbatim from a real failure log, not
/// from documentation.
///
/// [fileExistedNonEmpty] disambiguates the one genuinely ambiguous shape:
/// `open_failed` means "wrong key" when there was a non-empty file to decrypt,
/// and "the environment stopped us" when there was not.
PrivateDbOpenFailure classifyPrivateDbOpenFailure(
  Object error, {
  required bool fileExistedNonEmpty,
}) {
  if (error is PrivateDbSchemaTooNewException) return PrivateDbOpenFailure.schemaTooNew;
  if (error is! DatabaseException) return PrivateDbOpenFailure.unknown;

  final message = error.toString().toLowerCase();

  // A schema-too-new failure travels as a DatabaseException wrapping our typed
  // error when it crosses the sqflite boundary, so match the marker too.
  if (message.contains(kSchemaTooNewMarker.toLowerCase())) {
    return PrivateDbOpenFailure.schemaTooNew;
  }

  // Result code first where sqflite could parse one — it is far more stable
  // than message text. Note getResultCode() returns the EXTENDED code on some
  // platforms, so compare on the low byte as SQLite specifies.
  final primary = _primaryCode(error);

  switch (primary) {
    case 8: // SQLITE_READONLY, incl. READONLY_DBMOVED (1032) / DIRECTORY (1544)
      return PrivateDbOpenFailure.movedOrReadonly;
    case 5: // SQLITE_BUSY
    case 6: // SQLITE_LOCKED
      return PrivateDbOpenFailure.transient;
    case 11: // SQLITE_CORRUPT
      return PrivateDbOpenFailure.corrupt;
    case 26: // SQLITE_NOTADB — unreachable through openDatabase, but reachable
      // on a raw statement, and free to support.
      return PrivateDbOpenFailure.undecryptable;
    case 7: // SQLITE_NOMEM — the sticky codec-failure artefact described above.
      return fileExistedNonEmpty
          ? PrivateDbOpenFailure.undecryptable
          : PrivateDbOpenFailure.unknown;
    case 14: // SQLITE_CANTOPEN
      return PrivateDbOpenFailure.environment;
  }

  // Message fallbacks, for the shapes that carry no parseable code.
  if (message.contains('attempt to write a readonly database') ||
      message.contains('readonly database')) {
    return PrivateDbOpenFailure.movedOrReadonly;
  }
  if (message.contains('file is not a database') ||
      message.contains('not a database')) {
    return PrivateDbOpenFailure.undecryptable;
  }
  if (message.contains('out of memory')) {
    return fileExistedNonEmpty
        ? PrivateDbOpenFailure.undecryptable
        : PrivateDbOpenFailure.unknown;
  }
  if (message.contains('database disk image is malformed') ||
      message.contains('malformed')) {
    return PrivateDbOpenFailure.corrupt;
  }
  if (message.contains('database is locked') || message.contains('busy')) {
    return PrivateDbOpenFailure.transient;
  }

  // `open_failed <path>` — the plugin's lossy rewrite. With a non-empty file on
  // disk the only thing that fails this way is a key that does not decrypt it;
  // with no file, it is the environment.
  if (message.contains('open_failed')) {
    return fileExistedNonEmpty
        ? PrivateDbOpenFailure.undecryptable
        : PrivateDbOpenFailure.environment;
  }

  if (error.isDatabaseClosedError()) return PrivateDbOpenFailure.movedOrReadonly;

  return PrivateDbOpenFailure.unknown;
}

/// SQLite's primary result code, i.e. the low byte of the extended code.
/// Returns null when sqflite could not parse one out of the native message.
int? _primaryCode(DatabaseException error) {
  final code = error.getResultCode();
  if (code == null) return null;
  return code & 0xff;
}

/// Whether a failure may be offered a DESTRUCTIVE recovery action.
///
/// Only genuine corruption qualifies. Every other bucket either has a
/// non-destructive remedy (reopen the newer build, find the other key, drop a
/// stale handle, retry) or is not understood well enough to justify destroying
/// data — and "not understood" must never mean "delete it".
bool allowsDestructiveRecovery(PrivateDbOpenFailure failure) =>
    failure == PrivateDbOpenFailure.corrupt;

/// Whether a timed retry can plausibly change the outcome.
///
/// Bound tightly to busy/locked. The field report shows a user pressing Retry
/// nine times in five seconds against a deterministic failure and getting nine
/// identical errors: retrying a deterministic failure is pure user harm.
/// [PrivateDbOpenFailure.movedOrReadonly] is deliberately excluded — it needs a
/// close-and-reopen, which is a different mechanism, not a delay.
bool isRetryable(PrivateDbOpenFailure failure) =>
    failure == PrivateDbOpenFailure.transient;

/// Short, stable, non-identifying token shown on the failure screen and copied
/// into the diagnostics bundle. Never contains a path, a row value or key
/// material.
String diagnosticCode(PrivateDbOpenFailure failure) => switch (failure) {
      PrivateDbOpenFailure.undecryptable => 'EVOLVE-DB-KEY',
      PrivateDbOpenFailure.schemaTooNew => 'EVOLVE-DB-NEWER',
      PrivateDbOpenFailure.corrupt => 'EVOLVE-DB-CORRUPT',
      PrivateDbOpenFailure.movedOrReadonly => 'EVOLVE-DB-MOVED',
      PrivateDbOpenFailure.transient => 'EVOLVE-DB-BUSY',
      PrivateDbOpenFailure.environment => 'EVOLVE-DB-ENV',
      PrivateDbOpenFailure.unknown => 'EVOLVE-DB-UNKNOWN',
    };

/// Marker embedded in [PrivateDbSchemaTooNewException]'s message so the failure
/// stays recognisable after sqflite wraps it in a `DatabaseException` (which
/// stringifies the cause and loses its type).
const String kSchemaTooNewMarker = 'EVOLVE_SCHEMA_TOO_NEW';

/// Thrown by `PrivateDbSchema.onDowngrade` when the database on disk was
/// written by a NEWER build than the one now opening it.
///
/// Typed on purpose. It used to be a bare `StateError`, which fell into the
/// same untyped catch as every other open failure and put the user on a screen
/// whose only action deleted the database — over data that is intact,
/// correctly keyed and fully decryptable by the build they just came from.
/// Schema-too-new is not damage; it is a build-ordering mistake with a
/// one-sentence remedy.
class PrivateDbSchemaTooNewException implements Exception {
  const PrivateDbSchemaTooNewException({
    required this.storedVersion,
    required this.knownVersion,
  });

  /// The `user_version` found on disk.
  final int storedVersion;

  /// The newest version this build knows how to open.
  final int knownVersion;

  @override
  String toString() =>
      '$kSchemaTooNewMarker: private database is at schema v$storedVersion; '
      'this build only knows v$knownVersion. Refusing to downgrade so the '
      'data stays readable by the newer build.';
}
