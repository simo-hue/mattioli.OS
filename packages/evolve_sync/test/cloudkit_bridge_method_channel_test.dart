import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_sync/evolve_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannelCloudKitBridge();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  MethodCall? lastCall;
  late Object? Function(MethodCall call) responder;

  setUp(() {
    lastCall = null;
    messenger.setMockMethodCallHandler(MethodChannelCloudKitBridge.channel,
        (call) async {
      lastCall = call;
      return responder(call);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
        MethodChannelCloudKitBridge.channel, null);
  });

  test('accountStatus maps native strings (unknown -> couldNotDetermine)',
      () async {
    responder = (_) => 'available';
    expect(await bridge.accountStatus(), CloudAccountStatus.available);
    responder = (_) => 'noAccount';
    expect(await bridge.accountStatus(), CloudAccountStatus.noAccount);
    responder = (_) => 'restricted';
    expect(await bridge.accountStatus(), CloudAccountStatus.restricted);
    responder = (_) => 'something_new';
    expect(await bridge.accountStatus(), CloudAccountStatus.couldNotDetermine);
  });

  test('saveRecords encodes records (encrypted bytes) and parses the outcome',
      () async {
    responder = (_) => {
          'saved': ['goals:g1'],
          'conflicts': [
            {'recordName': 'goals:g2', 'serverUpdatedAtMs': 123},
          ],
          'errors': [
            {'recordName': 'goals:g3', 'code': 'ZONE_BUSY'},
          ],
        };

    final out = await bridge.saveRecords([
      CloudRecord(
        recordName: 'goals:g1',
        tableName: 'goals',
        updatedAtMs: 10,
        deleted: false,
        payload: Uint8List.fromList([1, 2, 3]),
      ),
    ]);

    // Encoding crossing the channel.
    final args = lastCall!.arguments as Map;
    final recs = (args['records'] as List).cast<Map>();
    expect(recs.single['recordName'], 'goals:g1');
    expect(recs.single['deleted'], false);
    expect(recs.single['payload'], isA<Uint8List>());

    // Parsing the response.
    expect(out.saved, ['goals:g1']);
    expect(out.conflicts.single.recordName, 'goals:g2');
    expect(out.conflicts.single.serverUpdatedAtMs, 123);
    expect(out.errors.single.recordName, 'goals:g3');
    expect(out.errors.single.code, 'ZONE_BUSY');
  });

  test('fetchChanges sends the token and parses records/token/moreComing',
      () async {
    responder = (_) => {
          'records': [
            {
              'recordName': 'goals:g1',
              'tableName': 'goals',
              'updatedAtMs': 10,
              'deleted': false,
              'payload': Uint8List.fromList([9]),
            },
            {
              'recordName': 'goals:g2',
              'tableName': 'goals',
              'updatedAtMs': 20,
              'deleted': true,
            },
          ],
          'newToken': 'tok2',
          'moreComing': true,
        };

    final out = await bridge.fetchChanges('tok1');

    expect((lastCall!.arguments as Map)['token'], 'tok1');
    expect(out.records, hasLength(2));
    expect(out.records[0].payload, isA<Uint8List>());
    expect(out.records[1].deleted, isTrue);
    expect(out.newToken, 'tok2');
    expect(out.moreComing, isTrue);
  });

  test('ensureZone / deleteRecords / deleteZone invoke the right methods',
      () async {
    responder = (_) => null;

    await bridge.ensureZone();
    expect(lastCall!.method, 'ensureZone');

    await bridge.deleteRecords(['a', 'b']);
    expect(lastCall!.method, 'deleteRecords');
    expect((lastCall!.arguments as Map)['recordNames'], ['a', 'b']);

    await bridge.deleteZone();
    expect(lastCall!.method, 'deleteZone');
  });

  test('null responses degrade gracefully', () async {
    responder = (_) => null;
    expect((await bridge.saveRecords([])).saved, isEmpty);
    final f = await bridge.fetchChanges(null);
    expect(f.records, isEmpty);
    expect(f.moreComing, isFalse);
  });
}
