class DesktopRevenueCatConfig {
  const DesktopRevenueCatConfig._();

  static const appleApiKey = String.fromEnvironment(
    'EVOLVE_REVENUECAT_APPLE_API_KEY',
  );

  static bool get isConfigured => appleApiKey.trim().isNotEmpty;
}
