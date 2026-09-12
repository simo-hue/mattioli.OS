// An EXPIRED zone change token must not wedge sync.
//
// CloudKit invalidates a `previousServerChangeToken` after long enough offline
// (or a server-side zone change) and fails the fetch with
// `CKError.changeTokenExpired` (21) — which the native bridge surfaces as
// `PlatformException('cloudkit_21')`. Before this was handled, that exception
// escaped `fetchChanges`, so `_pull` never reached its `setChangeToken` and the
// device re-sent the same dead token on every later sync, forever.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const bridge = MethodChannelCloudKitBridge();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Object? Function(MethodCall call) responder;

  setUp(() {
    messenger.setMockMethodCallHandler(MethodChannelCloudKitBridge.channel,
        (call) async => responder(call));
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
        MethodChannelCloudKitBridge.channel, null);
  });

  Future<Database> openFresh() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
        ),
      );

  test('fetchChanges reports an expired change token as an empty full re-fetch',
      () async {
    responder = (_) => throw PlatformException(code: 'cloudkit_21');

    final out = await bridge.fetchChanges('stale-token');

    expect(out.records, isEmpty);
    expect(out.newToken, isNull);
    expect(out.moreComing, isFalse);
  });

  test('a non-expiry PlatformException still propagates', () async {
    responder = (_) => throw PlatformException(code: 'cloudkit_4');

    expect(bridge.fetchChanges('tok'), throwsA(isA<PlatformException>()));
  });

  test('an expired token is cleared, so the next sync re-fetches in full',
      () async {
    final db = await openFresh();
    final store = SyncLocalStore(db);
    await store.setChangeToken('stale-token');

    responder = (call) {
      switch (call.method) {
        case 'accountStatus':
          return 'available';
        case 'fetchChanges':
          throw PlatformException(code: 'cloudkit_21');
        case 'saveRecords':
          return <String, dynamic>{
            'saved': <String>[],
            'conflicts': <Map<String, dynamic>>[],
            'errors': <Map<String, dynamic>>[],
          };
        default:
          return null;
      }
    };

    await SyncEngine(store: store, bridge: bridge, crypto: SyncCrypto())
        .syncNow(SyncCrypto().generateKey());

    expect(await store.changeToken(), isNull);
    await db.close();
  });
}
