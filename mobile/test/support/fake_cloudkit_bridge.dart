import 'package:mattioli_os/core/cloudkit_bridge.dart';

/// In-memory stand-in for the native CloudKit bridge. Faithful enough to test
/// the engine: a single zone keyed by recordName, a monotonic change counter
/// for delta-fetch tokens, and last-write-wins-on-save by updatedAtMs (the
/// server rejects an older write as a conflict, mirroring serverRecordChanged).
///
/// Two [SyncEngine]s can share ONE instance to simulate two devices syncing
/// through the same iCloud.
class FakeCloudKitBridge implements CloudKitBridge {
  FakeCloudKitBridge({this.pageSize = 1000});

  /// Override to simulate iCloud being unavailable.
  CloudAccountStatus status = CloudAccountStatus.available;

  /// Small values let tests exercise the paginated fetch loop.
  int pageSize;

  final Map<String, CloudRecord> _zone = {};
  final Map<String, int> _seq = {};
  int _counter = 0;

  int ensureZoneCalls = 0;
  int saveCalls = 0;
  bool zoneDeleted = false;

  Map<String, CloudRecord> get records => Map.unmodifiable(_zone);

  @override
  Future<CloudAccountStatus> accountStatus() async => status;

  @override
  Future<void> ensureZone() async {
    ensureZoneCalls++;
    zoneDeleted = false;
  }

  @override
  Future<SaveOutcome> saveRecords(List<CloudRecord> records) async {
    saveCalls++;
    final saved = <String>[];
    final conflicts = <CloudConflict>[];
    for (final r in records) {
      final existing = _zone[r.recordName];
      if (existing != null && existing.updatedAtMs > r.updatedAtMs) {
        // Server has a strictly-newer version → conflict, don't overwrite.
        conflicts.add(CloudConflict(r.recordName, existing.updatedAtMs));
        continue;
      }
      _zone[r.recordName] = r;
      _seq[r.recordName] = ++_counter;
      saved.add(r.recordName);
    }
    return SaveOutcome(saved: saved, conflicts: conflicts);
  }

  @override
  Future<FetchOutcome> fetchChanges(String? token) async {
    final since = int.tryParse(token ?? '') ?? 0;
    final changed = _seq.entries.where((e) => e.value > since).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final page = changed.take(pageSize).toList();
    final more = changed.length > pageSize;
    final newSeq = page.isEmpty ? since : page.last.value;
    return FetchOutcome(
      records: [for (final e in page) _zone[e.key]!],
      newToken: newSeq.toString(),
      moreComing: more,
    );
  }

  @override
  Future<void> deleteRecords(List<String> recordNames) async {
    for (final rn in recordNames) {
      _zone.remove(rn);
      _seq.remove(rn);
    }
  }

  @override
  Future<void> deleteZone() async {
    _zone.clear();
    _seq.clear();
    zoneDeleted = true;
  }
}
