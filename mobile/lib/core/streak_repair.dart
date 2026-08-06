/// One-time repair of the `goal_logs.streak` corruption caused by the
/// empty-goals window.
///
/// `applyAutoVerdict` and `setDerivedStatus` used to recompute the streak from a
/// LIVE `goalsProvider` read on every write. In Private mode `build()` returned
/// `[]` synchronously on every applied iCloud sync, so mid-loop the goal
/// resolved to null, `startDate` fell back to the day being written, and
/// `computeStreak`'s backward walk broke on its first step — persisting a long
/// run as ±1 into a SYNCED table that nothing re-derives.
///
/// The writers are fixed (a habit's position in a run is no longer invented from
/// an unresolved goal), but the rows they already wrote stay wrong until
/// something recomputes them. `streak` is a CACHE of a pure function of data
/// still on disk, so every wrong value is recoverable exactly.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'private_data_store.dart';

/// Marks the repair as done. Versioned: if a future defect corrupts streaks
/// again, bump to `_v2` rather than reusing this key, so devices that already
/// ran the first repair still run the second.
const String kStreakRepairPrefKey = 'streak_repair_v1_done';

/// Runs the repair at most once per install, and only in Private mode.
///
/// Returns the number of rows corrected, or null when it did not run (already
/// done, or it failed).
///
/// Deliberately marks itself done ONLY on success: a failure — a locked
/// database, a disk error — must be retried on the next launch rather than
/// silently skipped forever, because nothing else will ever fix these rows.
///
/// Best-effort by construction. This is history bookkeeping; it must never take
/// down a launch, so every failure is logged and swallowed.
Future<int?> runStreakRepairOnce({
  required PrivateDataStore store,
  required SharedPreferences prefs,
}) async {
  if (prefs.getBool(kStreakRepairPrefKey) ?? false) return null;
  try {
    final corrected = await store.repairAllStreaks();
    if (corrected == null) {
      // No habits owned YET — not the same as nothing to fix. `ownerId()`
      // returns a device-local uuid until the first sync adopts the canonical
      // owner, so on a restored or second device this fires while the user's
      // whole corrupted history is still arriving. Closing the gate here would
      // mark the repair done on the one device that most needs it.
      AppLogger.info(
        '[Streaks] repair deferred — no habits for this owner yet',
      );
      return null;
    }
    await prefs.setBool(kStreakRepairPrefKey, true);
    if (corrected > 0) {
      AppLogger.warning(
        '[Streaks] one-time repair corrected $corrected goal_logs row(s)',
      );
    } else {
      AppLogger.info('[Streaks] one-time repair found nothing to correct');
    }
    return corrected;
  } catch (e, stack) {
    // NOT marked done — the next launch tries again.
    AppLogger.error('[Streaks] one-time repair failed', e, stack);
    return null;
  }
}
