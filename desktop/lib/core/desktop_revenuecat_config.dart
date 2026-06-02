class DesktopRevenueCatConfig {
  const DesktopRevenueCatConfig._();

  static const appleApiKey = String.fromEnvironment(
    'EVOLVE_REVENUECAT_APPLE_API_KEY',
    defaultValue: 'appl_goBFEcuJEbZZeifRFXecOGHFmhN',
  );

  static bool get isConfigured => appleApiKey.trim().isNotEmpty;
}
