import 'target_reconcile.dart';

/// SharedPreferences key holding the auto-fail anchor, shared verbatim by both
/// apps so a value stamped by one is at least *read* the same way by the other.
/// The stored value is a [targetDateKey] (`YYYY-MM-DD`).
///
/// Deliberately device-local: an anchor that only ever moves *later* is
/// self-limiting, so two devices disagreeing costs nothing. Whichever one sweeps
/// a day first writes the verdict; the other reads that row and agrees, because
/// a stored `missed` matches what its own sweep would derive. Nothing oscillates,
/// so this never needed to be a synced column.
const String kAutoFailAnchorPrefKey = 'target_auto_fail_from';

/// Resolves the auto-fail anchor from its persisted value.
///
/// [stored] is the raw preference (null on the first run of the build that
/// carries the auto-fail rule); [today] is the current date. Returns the day
/// auto-fail starts from.
///
/// Two values are refused rather than trusted, because `DateTime.tryParse`
/// accepts far more than a plausible anchor:
///
///  * **Unparseable** (`'not-a-date'`, `''`) — falls back to [today], the
///    conservative direction: an anchor mistakenly in the past would
///    retroactively redden history the user has already seen.
///  * **After [today]** — also falls back to [today]. A future anchor is not
///    conservative, it is *inert*: no closed day is ever `>=` it, so auto-fail
///    silently never fires again, forever, with nothing in the logs to say why.
///    `'2026-13-45'` normalises to 2027-02-14 and would do exactly that; so
///    would a device whose clock ran ahead when the anchor was first stamped.
///
/// An anchor far in the *past* is left alone: the backfill window already bounds
/// how far the sweep can reach ([kManualTargetBackfillDays]), so clamping here
/// would only churn the stored value forward every day for no benefit.
DateTime resolveAutoFailAnchor(String? stored, DateTime today) {
  final todayD = DateTime(today.year, today.month, today.day);
  if (stored == null || stored.isEmpty) return todayD;
  final parsed = DateTime.tryParse(stored);
  if (parsed == null) return todayD;
  final anchor = DateTime(parsed.year, parsed.month, parsed.day);
  return anchor.isAfter(todayD) ? todayD : anchor;
}

/// The value to persist for [anchor] — always via [targetDateKey], so the anchor
/// is stored in the same canonical day format as every other date key in the
/// two apps.
String encodeAutoFailAnchor(DateTime anchor) => targetDateKey(anchor);

/// Resolves the anchor and stamps it on first use, given a reader and a writer
/// for whatever preference store the calling app has.
///
/// Shared rather than inlined per app, for the reason `loadBarrier` records: the
/// I/O differs between the two clients (a synchronous injected
/// `SharedPreferences` on mobile, an async `getInstance()` on macOS) but the
/// RULE does not — stamp only when absent, and fail toward OFF. Inlined twice,
/// the second copy is where the wrong composition quietly lands.
///
/// Stamping lazily, on the first sweep rather than at startup, is what makes
/// shipping auto-fail non-retroactive: the anchor lands on the day the rule
/// first ran, so every day that closed before it existed is out of reach and the
/// user's history renders exactly as they last saw it.
///
/// The stored anchor is **write-once, and never moved earlier**. It is persisted
/// only to REPAIR a value that cannot be used as a date at all — absent (the
/// first run) or unparseable. A value that parses is left exactly as stored.
///
/// That asymmetry is deliberate, and the earlier version of this function got it
/// wrong in a way worth recording. It persisted the resolved anchor whenever it
/// differed from the stored one, which meant the clamp in [resolveAutoFailAnchor]
/// was written back: a device whose clock moved BACKWARDS — date-line travel, a
/// manual date change, an RTC that lost power — made a healthy stored anchor look
/// "in the future", clamped it to the earlier today, and saved that. The anchor
/// then ratcheted permanently downward, one clock slip at a time, and auto-fail
/// reached back over history it exists to protect (bounded by
/// [kManualTargetBackfillDays], so up to 45 days of retroactive `missed`). The
/// class doc above promises an anchor that "only ever moves later"; now the code
/// keeps that promise.
///
/// The trade is that a stored anchor genuinely in the future leaves auto-fail
/// INERT until that date arrives — no closed day is ever at or after it. That is
/// the safe direction (nothing is written) and it is reported through [onError]
/// rather than passing silently, whereas the ratchet wrote unrecoverable
/// verdicts. A small skew self-corrects within a day or two as `today` catches
/// up.
///
/// Returns null when [read] or [write] throws — auto-fail then stays off for
/// this pass rather than defaulting to "score everything", because a failed
/// preference read must never WIDEN what gets written. A write that merely
/// *reports* failure is not a correctness problem: the anchor resolved to today,
/// so nothing earlier is in reach, and the next pass tries again.
Future<DateTime?> resolveAndStampAutoFailAnchor({
  required String? Function() read,
  required Future<bool> Function(String value) write,
  required DateTime today,
  void Function(Object error)? onError,
}) async {
  try {
    final stored = read();
    final anchor = resolveAutoFailAnchor(stored, today);
    final parsed = (stored == null || stored.isEmpty)
        ? null
        : DateTime.tryParse(stored);

    if (parsed == null) {
      // Absent or unusable — stamp. Repairing an unparseable value matters:
      // left alone it re-resolves to today on every pass, so no closed day is
      // ever at or after it and auto-fail silently never fires again.
      final canonical = encodeAutoFailAnchor(anchor);
      final written = await write(canonical);
      if (!written) {
        onError?.call(StateError(
            'the auto-fail anchor could not be persisted (store returned '
            'false); it stays at $canonical until a write succeeds'));
      }
    } else if (DateTime(parsed.year, parsed.month, parsed.day)
        .isAfter(DateTime(today.year, today.month, today.day))) {
      // Deliberately NOT rewritten — see above. Surfaced so an anchor that has
      // parked the feature is diagnosable rather than a silent no-op.
      onError?.call(StateError(
          'the auto-fail anchor ($stored) is in the future; auto-fail stays '
          'inert until then rather than moving the anchor backwards'));
    }
    return anchor;
  } catch (error) {
    onError?.call(error);
    return null;
  }
}
