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

  final process = await Process.start('flutter', [
    ...arguments,
    '--dart-define=EVOLVE_SUPABASE_URL=$url',
    '--dart-define=EVOLVE_SUPABASE_PUBLISHABLE_KEY=$publishableKey',
  ], mode: ProcessStartMode.inheritStdio);
  exitCode = await process.exitCode;
}

String? _readValue(String source, String name) {
  return RegExp(
    "static\\s+const\\s+String\\s+$name\\s*=\\s*'([^']+)'",
  ).firstMatch(source)?.group(1);
}
