// Cross-account regression guard for the offline goals/logs cache.
//
// `goals_cache` and `goal_logs_cache` are a SINGLE, non-user-keyed pair of
// keychain entries shared by every account that ever signs in on the device,
// and they are deliberately NOT wiped on sign-out (a transient logout — e.g. a
// refresh-token rotation race — must not destroy the offline mirror). The only
// thing standing between account A's habits + completion history and whoever
// signs in next is the `cache_owner_user_id` marker, which
// `cacheSeedAllowed` checks on the READ side and `cacheOverwriteAllowed`
// checks on the WRITE side.
//
// These tests pin both sides of that marker. If the read guard ever regresses
// to trusting the blob unconditionally, a cold start serves the previous
// account's private data to the next user as their initial state.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/providers/goal_provider.dart';

const String _userA = 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';
const String _userB = 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('cacheSeedAllowed (READ side)', () {
    test('serves the cache to the account that owns it', () async {
      FlutterSecureStorage.setMockInitialValues({kCacheOwnerKey: _userA});

      expect(await cacheSeedAllowed(_userA), isTrue);
    });

    test('refuses to serve one account\'s cache to a different account',
        () async {
      // A signed in, synced, and signed out; the blob and marker are still A's.
      FlutterSecureStorage.setMockInitialValues({kCacheOwnerKey: _userA});

      // B now signs in on the same device.
      expect(await cacheSeedAllowed(_userB), isFalse);
    });

    test('refuses an unmarked cache: its owner is unknowable', () async {
      // Pre-marker leftover: a blob exists but nothing records whose it is.
      // Fail closed — the alternative is handing it to whoever asks.
      FlutterSecureStorage.setMockInitialValues({});

      expect(await cacheSeedAllowed(_userA), isFalse);
    });

    test('refuses when there is no signed-in user', () async {
      FlutterSecureStorage.setMockInitialValues({kCacheOwnerKey: _userA});

      expect(await cacheSeedAllowed(null), isFalse);
    });
  });

  group('cacheOverwriteAllowed (WRITE side)', () {
    test('a non-empty fetch always writes: it is this account\'s real data',
        () async {
      FlutterSecureStorage.setMockInitialValues({kCacheOwnerKey: _userA});

      expect(
        await cacheOverwriteAllowed(_userB, isEmptyResult: false),
        isTrue,
      );
    });

    test('the owner\'s own empty fetch writes: a genuine "all cleared"',
        () async {
      FlutterSecureStorage.setMockInitialValues({kCacheOwnerKey: _userA});

      expect(await cacheOverwriteAllowed(_userA, isEmptyResult: true), isTrue);
    });

    test('a DIFFERENT account\'s empty fetch never clobbers the cache',
        () async {
      FlutterSecureStorage.setMockInitialValues({kCacheOwnerKey: _userA});

      expect(await cacheOverwriteAllowed(_userB, isEmptyResult: true), isFalse);
    });
  });

  group('rememberCacheOwner', () {
    test('reassigns the cache to the account whose data was just written',
        () async {
      FlutterSecureStorage.setMockInitialValues({kCacheOwnerKey: _userA});

      // B's data lands in the shared blob (e.g. B creates their first habit).
      // Every write records the owner, so the marker must follow the blob —
      // otherwise the guard above locks B out of their own offline mirror on
      // the next cold start while still naming A as the owner.
      await rememberCacheOwner(_userB);

      expect(await cacheSeedAllowed(_userB), isTrue);
      expect(await cacheSeedAllowed(_userA), isFalse);
    });
  });
}
