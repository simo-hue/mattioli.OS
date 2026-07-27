// The recovery screen must not offer to displace data it has no evidence is
// lost.
//
// The macOS incident ended on this screen: a database that was intact,
// correctly encrypted and fully recoverable, presented as a generic failure
// whose only state-changing button destroyed it. These tests pin the policy —
// which failures may offer the reset, and which must not — at the level both
// apps share, so it cannot drift back one platform at a time.
import 'package:evolve_desktop/features/auth/application/private_mode_recovery.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PrivateRecoveryResult result(
    PrivateRecoveryStatus status, {
    PrivateDbOpenFailure? failure,
  }) =>
      PrivateRecoveryResult(status, failure: failure);

  group('a destructive recovery is offered only where data is provably lost',
      () {
    test(
      'undecryptable DOES offer it — but only because the reset now preserves '
      'the ciphertext AND parks its key, so this is a way forward rather than '
      'a deletion. Withholding it would strand the user with no action at all.',
      () {
        expect(
          result(
            PrivateRecoveryStatus.undecryptable,
            failure: PrivateDbOpenFailure.undecryptable,
          ).allowsReset,
          isTrue,
        );
      },
    );

    test(
      'and the underlying CLASSIFIER still refuses to call it destructible — '
      'the permission comes from the recovery being reversible, never from a '
      'belief that the data is gone',
      () {
        expect(
          allowsDestructiveRecovery(PrivateDbOpenFailure.undecryptable),
          isFalse,
        );
      },
    );

    test(
      'schemaTooNew does NOT offer it — the data is intact by definition and '
      'the remedy is to reopen the newer build',
      () {
        expect(
          result(
            PrivateRecoveryStatus.schemaTooNew,
            failure: PrivateDbOpenFailure.schemaTooNew,
          ).allowsReset,
          isFalse,
        );
      },
    );

    test('a moved/readonly file does NOT offer it — it needs a reopen', () {
      expect(
        result(
          PrivateRecoveryStatus.error,
          failure: PrivateDbOpenFailure.movedOrReadonly,
        ).allowsReset,
        isFalse,
      );
    });

    test('a transient busy failure does NOT offer it', () {
      expect(
        result(
          PrivateRecoveryStatus.error,
          failure: PrivateDbOpenFailure.transient,
        ).allowsReset,
        isFalse,
      );
    });

    test(
      'an UNCLASSIFIED failure does NOT offer it — this is the regression that '
      'matters most, because "we do not understand this" used to mean "delete '
      'the database"',
      () {
        expect(
          result(
            PrivateRecoveryStatus.error,
            failure: PrivateDbOpenFailure.unknown,
          ).allowsReset,
          isFalse,
        );
        // And with no classification at all.
        expect(result(PrivateRecoveryStatus.error).allowsReset, isFalse);
      },
    );

    test('genuine corruption DOES offer it — the one defensible case', () {
      expect(
        result(
          PrivateRecoveryStatus.error,
          failure: PrivateDbOpenFailure.corrupt,
        ).allowsReset,
        isTrue,
      );
    });

    test(
      'a confirmed lock still offers it — no key exists, so nothing can be '
      'orphaned by starting fresh',
      () {
        expect(result(PrivateRecoveryStatus.needsUserChoice).allowsReset, isTrue);
      },
    );
  });

  test('every status maps to a stable, distinct diagnostic code', () {
    for (final failure in PrivateDbOpenFailure.values) {
      expect(diagnosticCode(failure), isNotEmpty);
    }
  });
}
