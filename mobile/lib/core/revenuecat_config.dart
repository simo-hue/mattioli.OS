/// RevenueCat configuration.
///
/// SEC-2: Unlike supabase/sentry/openrouter_config.dart (which hold genuine
/// secrets and are git-ignored + `.example`-templated), this file is committed
/// directly and intentionally. The RevenueCat **public SDK key** (`appl_`
/// prefix) is designed to be embedded in the shipped app binary and is not a
/// secret — it only identifies the app to RevenueCat for receipt validation and
/// cannot read or mutate other users' data. Keeping it committed avoids build
/// friction for collaborators with no security trade-off.
class RevenueCatConfig {
  /// RevenueCat Public SDK API Key for Evolve (intentionally public — see above).
  static const String apiKey = 'appl_goBFEcuJEbZZeifRFXecOGHFmhN';
}
