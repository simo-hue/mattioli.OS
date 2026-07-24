/// Compile-time feature flag for quantitative habit targets on desktop.
///
/// Mirrors the mobile `TargetsConfig` so the two apps flip the feature together.
/// The whole UI ships **dark** until on-device QA + the queued schema-v9 /
/// Supabase migrations land (see `TO_SIMO_DO.md`). While [enabled] is false the
/// habit editor shows no target picker, the habit rows keep their plain
/// checkbox, and the foreground resolution sweep is a no-op.
///
/// The DOMAIN layer (model, storage, sync, sweep) is intentionally NOT gated: it
/// must round-trip a `goals.target` written by a device where the flag is live,
/// exactly as the verification columns do. Only the UI is gated.
abstract final class DesktopTargetsConfig {
  /// Master switch — gates the editor's target picker, the habit-row progress
  /// ring, and the entry dialog. Kept `const` so the disabled path tree-shakes.
  ///
  /// LIVE since 2026-07-24 (Phase 3 go-live), flipped together with mobile.
  /// REQUIRES the queued Supabase migrations applied FIRST (the Account-mode
  /// target write is no longer flag-gated). See TO_SIMO_DO.md for deploy order.
  static const bool enabled = true;
}
