// The classifier that stands between an unreadable private database and a
// button that used to delete it.
//
// Every string below is VERBATIM from a real macOS failure log (2026-07-27),
// not from documentation. That matters more than usual here, because the
// obvious predicate — "a wrong SQLCipher key reports error 26, file is not a
// database" — is TRUE of SQLCipher and simultaneously unreachable from Dart:
// sqflite_sqlcipher's plugin probes the freshly-opened database, and when the
// probe fails it replies with a hand-built `open_failed <path>` string,
// discarding SQLite's real code. Not one of the 27 logged failures in that
// incident carried code 26. A classifier written from the documentation would
// have been dead code that silently never fired.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// Minimal stand-in for the platform's exception: `DatabaseException` is
/// abstract and its concrete subclass is library-private to sqflite, but
/// everything the classifier reads is on this surface — the message (via the
/// base class's `toString`) and the result code sqflite parses back out of it.
class _Exception extends DatabaseException {
  _Exception(super.message);

  @override
  Object? get result => null;

  @override
  int? getResultCode() {
    // Mirrors sqflite_common's own parser: it looks for `(code N)`, `(sqlite
    // code N)` and the darwin `code=N` form inside the native message.
    final m = RegExp(r'code[= ](\d+)').firstMatch(toString().toLowerCase());
    return m == null ? null : int.parse(m.group(1)!);
  }
}

void main() {
  group('the shapes observed in the real incident', () {
    test(
      'open_failed with a real file on disk is a WRONG KEY, not an environment '
      'problem — the plugin having thrown SQLite\'s code away',
      () {
        final e = _Exception(
          'open_failed /Users/simo/Library/Containers/com.simo.evolve/Data/'
          'Library/Application Support/com.simo.evolve/evolve_private_v2.db',
        );
        expect(
          classifyPrivateDbOpenFailure(e, fileExistedNonEmpty: true),
          PrivateDbOpenFailure.undecryptable,
        );
      },
    );

    test('the SAME open_failed with no file is an environment problem', () {
      final e = _Exception('open_failed /tmp/nope/evolve_private_v2.db');
      expect(
        classifyPrivateDbOpenFailure(e, fileExistedNonEmpty: false),
        PrivateDbOpenFailure.environment,
      );
    });

    test(
      '"out of memory" on BEGIN EXCLUSIVE is a wrong key, not memory pressure '
      '— SQLite latches SQLITE_NOMEM after a codec failure',
      () {
        final e = _Exception(
          'Error Domain=FMDatabase Code=7 "out of memory" '
          'UserInfo={NSLocalizedDescription=out of memory}) sql '
          "'BEGIN EXCLUSIVE' args []",
        );
        expect(
          classifyPrivateDbOpenFailure(e, fileExistedNonEmpty: true),
          PrivateDbOpenFailure.undecryptable,
        );
      },
    );

    test(
      'code 8 "attempt to write a readonly database" is a MOVED FILE and must '
      'be neither undecryptable nor locked — it needs a reopen, and routing it '
      'into the lock path would hand it to the recovery that renames the '
      'database aside',
      () {
        final e = _Exception(
          'Error Domain=FMDatabase Code=8 "attempt to write a readonly '
          'database" UserInfo={NSLocalizedDescription=attempt to write a '
          "readonly database}) sql 'BEGIN EXCLUSIVE' args []",
        );
        final failure =
            classifyPrivateDbOpenFailure(e, fileExistedNonEmpty: true);
        expect(failure, PrivateDbOpenFailure.movedOrReadonly);
        expect(failure, isNot(PrivateDbOpenFailure.undecryptable));
        expect(isRetryable(failure), isFalse,
            reason: 'a moved file needs a reopen, never a timed retry');
        expect(allowsDestructiveRecovery(failure), isFalse);
      },
    );
  });

  group('the shapes that never reached Dart but are free to support', () {
    test('code 26 not-a-database is undecryptable', () {
      final e = _Exception('Error Domain=FMDatabase Code=26 "file is not a '
          'database" UserInfo={NSLocalizedDescription=file is not a database}');
      expect(
        classifyPrivateDbOpenFailure(e, fileExistedNonEmpty: true),
        PrivateDbOpenFailure.undecryptable,
      );
    });

    test('code 11 malformed is CORRUPT — the only destructive-eligible bucket',
        () {
      final e = _Exception('Error Domain=FMDatabase Code=11 "database disk '
          'image is malformed"');
      final failure =
          classifyPrivateDbOpenFailure(e, fileExistedNonEmpty: true);
      expect(failure, PrivateDbOpenFailure.corrupt);
      expect(allowsDestructiveRecovery(failure), isTrue);
    });

    test('busy/locked is the ONLY retryable bucket', () {
      for (final code in [5, 6]) {
        final e = _Exception('Error Domain=FMDatabase Code=$code "database is '
            'locked"');
        final failure =
            classifyPrivateDbOpenFailure(e, fileExistedNonEmpty: true);
        expect(failure, PrivateDbOpenFailure.transient, reason: 'code $code');
        expect(isRetryable(failure), isTrue);
      }
    });
  });

  group('destructive recovery is opt-IN, never a default', () {
    test('every non-corrupt bucket forbids a destructive action', () {
      for (final failure in PrivateDbOpenFailure.values) {
        expect(
          allowsDestructiveRecovery(failure),
          failure == PrivateDbOpenFailure.corrupt,
          reason:
              '${failure.name} must not license destroying the user\'s data',
        );
      }
    });

    test('an UNRECOGNISED failure is never destructive and never retried', () {
      final e = _Exception('something nobody has ever seen before');
      final failure =
          classifyPrivateDbOpenFailure(e, fileExistedNonEmpty: true);
      expect(failure, PrivateDbOpenFailure.unknown);
      expect(allowsDestructiveRecovery(failure), isFalse);
      expect(isRetryable(failure), isFalse);
    });

    test('a non-database error is not force-fitted into a database bucket', () {
      expect(
        classifyPrivateDbOpenFailure(StateError('x'), fileExistedNonEmpty: true),
        PrivateDbOpenFailure.unknown,
      );
    });
  });

  group('schema-too-new survives the trip through sqflite', () {
    test('the typed exception classifies directly', () {
      const e = PrivateDbSchemaTooNewException(storedVersion: 11, knownVersion: 10);
      expect(
        classifyPrivateDbOpenFailure(e, fileExistedNonEmpty: true),
        PrivateDbOpenFailure.schemaTooNew,
      );
    });

    test(
      'and still classifies after sqflite wraps it in a DatabaseException, '
      'which stringifies the cause and loses its type',
      () {
        const inner =
            PrivateDbSchemaTooNewException(storedVersion: 11, knownVersion: 10);
        final wrapped = _Exception(inner.toString());
        expect(
          classifyPrivateDbOpenFailure(wrapped, fileExistedNonEmpty: true),
          PrivateDbOpenFailure.schemaTooNew,
        );
      },
    );

    test('it carries both versions so the UI can name them', () {
      const e = PrivateDbSchemaTooNewException(storedVersion: 11, knownVersion: 6);
      expect(e.storedVersion, 11);
      expect(e.knownVersion, 6);
      expect(e.toString(), contains(kSchemaTooNewMarker));
    });
  });

  test('diagnostic codes are stable, distinct and carry no user data', () {
    final codes =
        PrivateDbOpenFailure.values.map(diagnosticCode).toSet();
    expect(codes.length, PrivateDbOpenFailure.values.length);
    for (final code in codes) {
      expect(code, startsWith('EVOLVE-DB-'));
      expect(code, matches(RegExp(r'^[A-Z-]+$')));
    }
  });
}
