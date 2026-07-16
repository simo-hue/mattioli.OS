import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the cloud-export paging.
///
/// A single unbounded PostgREST `select` is capped by the project's
/// `db-max-rows`, so an export built from one silently ships a truncated
/// backup — the loss only surfaces when the user restores it. The export must
/// page until the source is exhausted.
void main() {
  List<Map<String, dynamic>> makeRows(int count, {int from = 0}) => List.generate(
    count,
    (i) => <String, dynamic>{'id': 'row-${from + i}'},
  );

  group('fetchAllRowsPaginated', () {
    test('keeps paging past the row cap until a short page ends it', () async {
      // 2350 rows behind a 1000-row cap: the bug shipped exactly the first 1000.
      final source = makeRows(2350);
      final requested = <List<int>>[];

      final rows = await fetchAllRowsPaginated((offset, limit) async {
        requested.add([offset, limit]);
        return source.skip(offset).take(limit).toList();
      });

      expect(rows.length, 2350);
      expect(rows.first['id'], 'row-0');
      expect(rows.last['id'], 'row-2349');
      expect(requested, [
        [0, 1000],
        [1000, 1000],
        [2000, 1000],
      ]);
    });

    test('stops after one request when the first page is short', () async {
      var calls = 0;
      final rows = await fetchAllRowsPaginated((offset, limit) async {
        calls++;
        return makeRows(12);
      });

      expect(rows.length, 12);
      expect(calls, 1);
    });

    test('empty table yields no rows and one request', () async {
      var calls = 0;
      final rows = await fetchAllRowsPaginated((offset, limit) async {
        calls++;
        return <Map<String, dynamic>>[];
      });

      expect(rows, isEmpty);
      expect(calls, 1);
    });

    test('an exactly-full final page terminates on the next empty one', () async {
      final source = makeRows(20);
      var calls = 0;

      final rows = await fetchAllRowsPaginated((offset, limit) async {
        calls++;
        return source.skip(offset).take(limit).toList();
      }, pageSize: 10);

      expect(rows.length, 20);
      // 0-9, 10-19, then the empty page that proves exhaustion.
      expect(calls, 3);
    });

    test('preserves order across page boundaries', () async {
      final source = makeRows(25);

      final rows = await fetchAllRowsPaginated((offset, limit) async {
        return source.skip(offset).take(limit).toList();
      }, pageSize: 10);

      expect(
        rows.map((r) => r['id']).toList(),
        source.map((r) => r['id']).toList(),
      );
    });
  });
}
