// F48 — `daily_moods` was read with one unbounded, unordered PostgREST select.
//
// Past the project's `db-max-rows`, PostgREST returns a PARTIAL set with no
// error and no exception. With no ORDER BY, *which* rows come back is not even
// stable between syncs — so the mood emoji disappears from arbitrary calendar
// days and reappears on others, and `computeMoodCorrelations` derives
// sensitivity and resilience over a truncated denominator without ever knowing
// it. Private mode reads the whole local table, so the two data modes silently
// disagree.
//
// The app already knew: the export path in `privacy_settings_screen.dart` pages
// this exact table, with the comment "unbounded PostgREST select is capped by
// the project's db-max-rows and would truncate a long history with no error".
// The LIVE provider was simply missed — on both clients.
//
// The fold is tested directly, the way `goal_logs_pagination_test.dart` tests
// its own: the loop is the part that can be wrong, and it must not need a live
// Supabase client to prove it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/providers/mood_provider.dart';

void main() {
  List<Map<String, dynamic>> rows(int count, {int from = 0}) =>
      List.generate(count, (i) {
        final n = from + i;
        return {
          'id': 'id_$n',
          'user_id': 'u1',
          'date': DateTime(2020, 1, 1)
              .add(Duration(days: n))
              .toIso8601String()
              .substring(0, 10),
          'mood_score': (n % 5) + 1,
          'energy_score': (n % 5) + 1,
        };
      });

  DailyMoodPageFetcher pagedOver(
    List<Map<String, dynamic>> all,
    List<List<int>> calls,
  ) =>
      (offset, limit) async {
        calls.add([offset, limit]);
        if (offset >= all.length) return [];
        return all.sublist(offset, (offset + limit).clamp(0, all.length));
      };

  test('a single short page ends the loop after one request', () async {
    final calls = <List<int>>[];
    final moods = await fetchDailyMoodsPaginated(
      pagedOver(rows(5), calls),
      pageSize: 1000,
    );

    expect(calls, [
      [0, 1000],
    ]);
    expect(moods, hasLength(5));
  });

  test('a full page is followed by another request', () async {
    // The reported failure in miniature: stopping at the first page loses every
    // mood after it, silently.
    final calls = <List<int>>[];
    final all = rows(1500);
    final moods = await fetchDailyMoodsPaginated(
      pagedOver(all, calls),
      pageSize: 1000,
    );

    expect(calls, [
      [0, 1000],
      [1000, 1000],
    ]);
    expect(moods, hasLength(1500),
        reason: 'both pages must be folded into the state');
    // Rows from BOTH pages, keyed by date.
    expect(moods.containsKey(all.first['date']), isTrue);
    expect(moods.containsKey(all.last['date']), isTrue);
  });

  test('an exact multiple of the page size still terminates', () async {
    final calls = <List<int>>[];
    final moods = await fetchDailyMoodsPaginated(
      pagedOver(rows(2000), calls),
      pageSize: 1000,
    );

    expect(calls, [
      [0, 1000],
      [1000, 1000],
      [2000, 1000],
    ]);
    expect(moods, hasLength(2000));
  });

  test('the live provider read is ordered and ranged, not unbounded', () {
    // The fold is only half the fix: a `.range()` over an UNORDERED select can
    // repeat or skip rows between windows, which is why the export path orders
    // by date and then by id for a total order. Asserted on the source because
    // the notifier reads the global `Supabase.instance.client`.
    final source = File('lib/providers/mood_provider.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    expect(source, contains("from('daily_moods') .select()"));
    expect(source, contains(".order('date', ascending: true)"));
    expect(source, contains(".order('id', ascending: true)"));
    expect(source, contains('.range(offset, offset + limit - 1)'));
  });
}
