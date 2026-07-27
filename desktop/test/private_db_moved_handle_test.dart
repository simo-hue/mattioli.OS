// A database file that moves under a live handle must not wedge the app.
//
// This is the shape of the 33-minute silent failure in the field report: the
// file was renamed by another process, and from that moment SQLite answered
// every WRITE with SQLITE_READONLY_DBMOVED while READS kept succeeding from
// cache. So the UI looked perfectly healthy, the user kept using the app, and
// 36 consecutive syncs failed without a single thing on screen changing.
//
// Nothing recovered on its own because `Database.isOpen` is a Dart-side flag
// that a rename cannot clear, and no error path ever dropped the cached handle.
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _MovedException extends DatabaseException {
  _MovedException()
      : super('Error Domain=FMDatabase Code=8 "attempt to write a readonly '
            'database" UserInfo={NSLocalizedDescription=attempt to write a '
            "readonly database}) sql 'BEGIN EXCLUSIVE' args []");

  @override
  Object? get result => null;

  @override
  int? getResultCode() => 8;
}

void main() {
  test(
    'the moved-file error is recognised as such, and NOT as a decryption or '
    'lock problem — routing it into either would hand an intact database to a '
    'recovery that renames it aside',
    () {
      final failure = classifyPrivateDbOpenFailure(
        _MovedException(),
        fileExistedNonEmpty: true,
      );
      expect(failure, PrivateDbOpenFailure.movedOrReadonly);
      expect(diagnosticCode(failure), 'EVOLVE-DB-MOVED');
      expect(allowsDestructiveRecovery(failure), isFalse);
      expect(isRetryable(failure), isFalse,
          reason: 'a timed retry cannot fix a moved inode — only a reopen can');
    },
  );

  test(
    'dropStaleHandle is safe to call when nothing is open, so the recovery path '
    'can fire unconditionally',
    () async {
      // No database has been opened in this process; the drop must be a quiet
      // no-op rather than throwing into a fire-and-forget sync callback.
      await DesktopPrivateDb.instance.dropStaleHandle();
      await DesktopPrivateDb.instance.dropStaleHandle();
    },
  );
}
