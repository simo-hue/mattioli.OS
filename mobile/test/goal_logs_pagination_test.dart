import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/providers/goal_provider.dart';

/// DATA-6: the `goal_logs` sync must page through the whole table so large
/// histories aren't truncated by PostgREST's per-request row cap.
void main() {
  /// Builds [count] synthetic rows, one goal per row across [goals] goals so we
  /// can verify both paging and the date->goal->status folding.
  List<Map<String, dynamic>> rows(int count, {int goals = 3}) {
    return List.generate(count, (i) {
      final day = (i % 28) + 1;
      return {
        'id': 'id_$i',
        'goal_id': 'goal_${i % goals}',
        'date': '2026-01-${day.toString().padLeft(2, '0')}',
        'status': i.isEven ? 'done' : 'missed',
      };
    });
  }

  /// Returns a fetcher that serves [all] in [pageSize] slices and records the
  /// (offset, limit) of every request.
  GoalLogPageFetcher pagedOver(
    List<Map<String, dynamic>> all,
    List<List<int>> calls,
  ) {
    return (offset, limit) async {
      calls.add([offset, limit]);
      if (offset >= all.length) return [];
      final end = (offset + limit).clamp(0, all.length);
      return all.sublist(offset, end);
    };
  }

  test('merges a single short page and stops after one request', () async {
    final calls = <List<int>>[];
    final logs = await fetchGoalLogsPaginated(
      pagedOver(rows(5), calls),
      pageSize: 1000,
    );

    expect(calls, [
      [0, 1000],
    ]);
    // 5 rows across days 1..5, one goal each.
    expect(logs.values.fold<int>(0, (n, m) => n + m.length), 5);
  });

  test('pages through multiple full pages until a short page ends it', () async {
    final calls = <List<int>>[];
    final all = rows(2500);
    final logs = await fetchGoalLogsPaginated(
      pagedOver(all, calls),
      pageSize: 1000,
    );

    expect(calls, [
      [0, 1000],
      [1000, 1000],
      [2000, 1000],
    ]);
    final total = logs.values.fold<int>(0, (n, m) => n + m.length);
    expect(total, lessThanOrEqualTo(2500));
    // Every distinct (date, goal) pair is represented.
    expect(logs.containsKey('2026-01-01'), isTrue);
  });

  test('requests one extra empty page when count is an exact multiple', () async {
    final calls = <List<int>>[];
    final logs = await fetchGoalLogsPaginated(
      pagedOver(rows(2000), calls),
      pageSize: 1000,
    );

    // 1000 (full) -> 1000 (full) -> 0 (short, stop).
    expect(calls, [
      [0, 1000],
      [1000, 1000],
      [2000, 1000],
    ]);
    expect(logs, isNotEmpty);
  });

  test('last write for a (date, goal) wins during folding', () async {
    Future<List<Map<String, dynamic>>> fetcher(int offset, int limit) async {
      if (offset > 0) return <Map<String, dynamic>>[];
      return [
        {'id': 'a', 'goal_id': 'g1', 'date': '2026-02-01', 'status': 'done'},
        {'id': 'b', 'goal_id': 'g1', 'date': '2026-02-01', 'status': 'missed'},
      ];
    }

    final logs = await fetchGoalLogsPaginated(fetcher, pageSize: 1000);
    expect(logs['2026-02-01']!['g1'], 'missed');
  });

  test('handles an empty table without error', () async {
    final logs = await fetchGoalLogsPaginated(
      (offset, limit) async => [],
      pageSize: 1000,
    );
    expect(logs, isEmpty);
  });
}
