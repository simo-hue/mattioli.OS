// Opening a NEWER private database with an OLDER build.
//
// This is the failure 1.2.0 makes real for the first time. That release takes
// the private schema v6 → v11, TestFlight keeps the previous build one tap away
// under "Previous Builds", and the release runbook states there is no rollback
// precisely BECAUSE onDowngrade throws. So a tester who installs the previous
// build lands here — over a database that is intact, correctly keyed and fully
// decryptable by the build they just came from.
//
// It used to throw a bare `StateError`, which fell into the same untyped catch
// as every other open failure and produced a generic error screen whose only
// state-changing button deleted the database. The type is the fix.
import 'dart:io';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  test(
    'a database written by a newer build throws the TYPED schema-too-new '
    'exception, carrying both versions, and never a bare StateError',
    () async {
      // A v11 database, as 1.2.0 leaves it. A real file, not in-memory: an
      // in-memory database does not survive the close, and the whole point is
      // that a SECOND process opens the SAME file.
      final dir = await Directory.systemTemp.createTemp('evolve_downgrade');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/private.db';
      final newer = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 11,
          onCreate: (db, _) async => db.execute('CREATE TABLE t (id TEXT)'),
        ),
      );
      await newer.close();

      // The older build knows only v10 and must refuse, not downgrade.
      Object? thrown;
      try {
        await factory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 10,
            onCreate: (db, _) async {},
            onDowngrade: PrivateDbSchema.onDowngrade,
          ),
        );
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isNotNull, reason: 'a silent downgrade corrupts the DB');
      // sqflite wraps the cause, so assert on the marker that survives the trip
      // rather than on the runtime type.
      expect(thrown.toString(), contains(kSchemaTooNewMarker));
      expect(
        classifyPrivateDbOpenFailure(thrown!, fileExistedNonEmpty: true),
        PrivateDbOpenFailure.schemaTooNew,
        reason: 'it must reach the UI as its own state, not as a generic error',
      );
    },
  );

  test(
    'schema-too-new NEVER licenses a destructive recovery — the data is intact '
    'by definition, and the older build simply cannot read it',
    () {
      expect(
        allowsDestructiveRecovery(PrivateDbOpenFailure.schemaTooNew),
        isFalse,
      );
      expect(isRetryable(PrivateDbOpenFailure.schemaTooNew), isFalse,
          reason: 'retrying cannot make an older build understand a newer '
              'schema; it would just spin');
    },
  );

  test('the exception names both versions so the UI can be specific', () {
    const e = PrivateDbSchemaTooNewException(storedVersion: 11, knownVersion: 6);
    expect(e.storedVersion, 11);
    expect(e.knownVersion, 6);
    expect(e.toString(), contains('v11'));
    expect(e.toString(), contains('v6'));
  });
}
