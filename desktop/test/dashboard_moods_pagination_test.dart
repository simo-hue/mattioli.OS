// F48, desktop half — `daily_moods` and `long_term_goals` were read unbounded.
//
// `SupabaseDashboardRepository.refresh` fetched both with a single
// `select().eq(user_id)` inside a `Future.wait`. Past the project's
// `db-max-rows` PostgREST answers with a PARTIAL set and no error:
//
//  * `daily_moods` had no ORDER BY at all, so WHICH rows survive is unstable
//    between refreshes — moods vanish from arbitrary calendar days;
//  * `long_term_goals` is ordered `created_at` ASCENDING, so the truncation is
//    deterministic and always drops the NEWEST goals, which are the ones the
//    user is actually working on.
//
// The app's own export path already pages every table it reads, for exactly this
// reason (`kExportPageSize`) — the dashboard's live read was missed, on both
// clients. Mobile's half is `mobile/test/daily_moods_pagination_test.dart`.
//
// Asserted on the source: `refresh()` needs a live `SupabaseClient`, and what is
// wrong here is the SHAPE of the query, not a fold that can be exercised.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/features/dashboard/data/dashboard_repository.dart')
      .readAsStringSync()
      .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  test('daily_moods is read in ranges, with a total order', () {
    expect(source, contains(".from('daily_moods')"));
    expect(
      source,
      matches(RegExp(
        r"\.from\('daily_moods'\) \.select\(\) \.eq\('user_id', _userId\) "
        r"\.order\('date', ascending: true\) \.order\('id', ascending: true\) "
        r"\.range\(offset, offset \+ limit - 1\)",
      )),
      reason: 'an unbounded select truncates silently; an unordered .range() '
          'can repeat or skip rows between windows',
    );
  });

  test('long_term_goals is read in ranges, with a total order', () {
    expect(
      source,
      matches(RegExp(
        r"\.from\('long_term_goals'\) \.select\(\) \.eq\('user_id', _userId\) "
        r"\.order\('created_at', ascending: true\) \.order\('id', ascending: true\) "
        r"\.range\(offset, offset \+ limit - 1\)",
      )),
      reason: 'ascending created_at means truncation drops the newest goals',
    );
  });

  test('neither table is still read with a bare unbounded select', () {
    // The bug shape, pinned directly: a `.eq('user_id', _userId)` that is
    // neither ranged nor (for moods) even ordered. Both reads stay inside the
    // same Future.wait — paging them is the fix, not moving them.
    expect(
      source,
      isNot(contains(".from('daily_moods') .select() .eq('user_id', _userId),")),
    );
    expect(
      source,
      isNot(contains(".from('long_term_goals') .select() .eq('user_id', "
          "_userId) .order('created_at', ascending: true),")),
    );
  });
}
