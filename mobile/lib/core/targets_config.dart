/// Compile-time feature flag for quantitative habit targets (count / duration /
/// limit).
///
/// The whole feature ships **dark** until on-device QA passes AND the queued
/// schema-v9 + Supabase migrations are applied (see `TO_SIMO_DO.md`). While
/// [enabled] is false there is no target-creation UI, the day-details card
/// keeps its plain checkbox, and the foreground resolution sweep is a no-op
/// (no habit can have a target) — so mainline releases are unaffected.
///
/// The DOMAIN layer (model, storage, sync, sweep) is intentionally NOT gated:
/// it must round-trip a `goals.target` written by a device where the flag is
/// live, exactly as the verification columns do, so a target never silently
/// vanishes across a mixed-version fleet. Only the UI is gated.
abstract final class TargetsConfig {
  /// Master switch — gates the creation field, the progress ring / entry sheet
  /// on the day-details card, and (via the UI) whether a user can create a
  /// target at all. Kept `const` so the disabled path tree-shakes.
  ///
  /// LIVE since 2026-07-24 (Phase 3 go-live). REQUIRES the queued Supabase
  /// migrations (`goal_targets_and_progress`, `target_effective_from`) applied
  /// FIRST — with this true the Account-mode target writes are no longer
  /// flag-gated, so a pre-migration project would reject them. See TO_SIMO_DO.md
  /// for the deploy order (migrations → v11 build → on-device QA → release).
  static const bool enabled = true;
}
