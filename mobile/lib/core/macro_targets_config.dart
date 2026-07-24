/// Compile-time feature flag for cumulative NUMERIC macro goals — an optional
/// numeric target on a `long_term_goals` macro goal ("run 500 km this year"),
/// with a progress bar fed either manually or automatically by a linked habit's
/// daily `goal_progress`.
///
/// A dedicated flag rather than reusing [TargetsConfig] (which gates the
/// per-HABIT quantitative targets): the two features ship on their own QA
/// timelines and the macro-goal UI depends on the separate `long_term_goals`
/// v10 columns + the `20260724_add_macro_goal_targets` Supabase migration.
///
/// The whole numeric-macro-goal UI ships **dark** until on-device QA passes AND
/// the queued schema-v10 + Supabase migration are applied (see `TO_SIMO_DO.md`).
/// While [enabled] is false the create/edit sheet shows no numeric-target field
/// and no "link a habit" picker, and every macro goal renders as today's plain
/// boolean one.
///
/// The DOMAIN layer (model, storage, sync, import, the delete-time snapshot) is
/// intentionally NOT gated: a `target_amount` synced from a device where the
/// flag is live must round-trip through this build, exactly as the habit
/// `target` column does. Only the UI is gated.
abstract final class MacroTargetsConfig {
  /// Master switch — gates the numeric-target amount/unit fields and the
  /// link-a-habit picker in the macro-goal editor, plus the derived/stored
  /// progress bar on macro-goal cards. Kept `const` so the dark path
  /// tree-shakes.
  static const bool enabled = false;
}
