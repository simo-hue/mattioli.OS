import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/flutter_with_mobile_supabase.dart '
      '<flutter arguments>',
    );
    exitCode = 64;
    return;
  }

  final script = File.fromUri(Platform.script);
  final repositoryRoot = script.parent.parent.parent;
  final mobileConfig = File(
    '${repositoryRoot.path}/mobile/lib/core/supabase_config.dart',
  );
  if (!mobileConfig.existsSync()) {
    stderr.writeln(
      'Missing ${mobileConfig.path}. Configure the mobile production client '
      'before launching desktop.',
    );
    exitCode = 66;
    return;
  }

  final source = await mobileConfig.readAsString();
  final url = _readValue(source, 'url');
  final publishableKey = _readValue(source, 'anonKey');
  if (url == null || publishableKey == null) {
    stderr.writeln(
      'The mobile Supabase config is incomplete. Expected url and anonKey.',
    );
    exitCode = 78;
    return;
  }

  final revenueCatConfig = File(
    '${repositoryRoot.path}/mobile/lib/core/revenuecat_config.dart',
  );
  final revenueCatKey = revenueCatConfig.existsSync()
      ? _readValue(await revenueCatConfig.readAsString(), 'apiKey')
      : null;
  final sentryConfig = File(
    '${repositoryRoot.path}/mobile/lib/core/sentry_config.dart',
  );
  final sentrySource = sentryConfig.existsSync()
      ? await sentryConfig.readAsString()
      : null;
  final sentryDsn = sentrySource == null
      ? null
      : _readValue(sentrySource, 'dsn');
  final sentryEnvironment = sentrySource == null
      ? null
      : _readValue(sentrySource, 'environment');
  final sentryTracesSampleRate = sentrySource == null
      ? null
      : _readDouble(sentrySource, 'tracesSampleRate');

  final process = await Process.start('flutter', [
    ...arguments,
    '--dart-define=EVOLVE_SUPABASE_URL=$url',
    '--dart-define=EVOLVE_SUPABASE_PUBLISHABLE_KEY=$publishableKey',
    if (revenueCatKey != null)
      '--dart-define=EVOLVE_REVENUECAT_APPLE_API_KEY=$revenueCatKey',
    if (sentryDsn != null) '--dart-define=EVOLVE_SENTRY_DSN=$sentryDsn',
    if (sentryEnvironment != null)
      '--dart-define=EVOLVE_SENTRY_ENVIRONMENT=$sentryEnvironment',
    if (sentryTracesSampleRate != null)
      '--dart-define=EVOLVE_SENTRY_TRACES_SAMPLE_RATE=$sentryTracesSampleRate',
  ], mode: ProcessStartMode.inheritStdio);
  exitCode = await process.exitCode;
}

String? _readValue(String source, String name) {
  return RegExp(
    "static\\s+const\\s+String\\s+$name\\s*=\\s*'([^']+)'",
  ).firstMatch(source)?.group(1);
}

String? _readDouble(String source, String name) {
  return RegExp(
    'static\\s+const\\s+double\\s+$name\\s*=\\s*([0-9.]+)',
  ).firstMatch(source)?.group(1);
}
