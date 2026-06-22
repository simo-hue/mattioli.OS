import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// DATA-3 drift guard.
///
/// The app calls Supabase RPCs and views that live only in the production DB.
/// Their definitions were captured into `../migrations/` (see the 20260622_*
/// files). This test fails CI whenever the app references a `.rpc('name')` or a
/// non-table view via `.from('name')` that has no matching `CREATE FUNCTION` /
/// `CREATE VIEW` anywhere in `schema.sql` or `migrations/*.sql`, so future schema
/// drift cannot land silently.
///
/// Existence-only by design: it asserts a definition exists, not that argument
/// signatures match (verified by hand when the definitions were captured).
void main() {
  // Base tables are defined out of band (Supabase-managed or web app schema) and
  // are intentionally NOT required to have a definition in this repo. Any other
  // `.from('x')` target is treated as a view that MUST be backed by a CREATE VIEW.
  const allowlistedBaseTables = <String>{
    'goals',
    'goal_logs',
    'long_term_goals',
    'macro_goal_categories',
    'daily_moods',
    'profiles',
  };

  late final String haystack;
  late final Set<String> rpcNames;
  late final Set<String> viewNames;

  setUpAll(() {
    final repoRoot = _findRepoRoot();
    final libDir = Directory('${repoRoot.path}/mobile/lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ not found at ${libDir.path}');

    // 1. Collect every RPC name and every `from()` target referenced by the app.
    final rpcRe = RegExp(r"""\.rpc\(\s*['"]([a-zA-Z0-9_]+)['"]""");
    final fromRe = RegExp(r"""\.from\(\s*['"]([a-zA-Z0-9_]+)['"]""");
    final rpcs = <String>{};
    final froms = <String>{};
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final m in rpcRe.allMatches(src)) {
        rpcs.add(m.group(1)!);
      }
      for (final m in fromRe.allMatches(src)) {
        froms.add(m.group(1)!);
      }
    }
    rpcNames = rpcs;
    viewNames = froms.difference(allowlistedBaseTables);

    // 2. Build the SQL haystack: schema.sql + every migration.
    final buffer = StringBuffer();
    final schema = File('${repoRoot.path}/schema.sql');
    if (schema.existsSync()) buffer.writeln(schema.readAsStringSync());
    final migrations = Directory('${repoRoot.path}/migrations');
    expect(migrations.existsSync(), isTrue,
        reason: 'migrations/ not found at ${migrations.path}');
    for (final entity in migrations.listSync()) {
      if (entity is File && entity.path.endsWith('.sql')) {
        buffer.writeln(entity.readAsStringSync());
      }
    }
    haystack = buffer.toString();
  });

  test('every .rpc() the app calls has a CREATE FUNCTION in schema/migrations', () {
    expect(rpcNames, isNotEmpty, reason: 'expected to discover RPC call sites');
    final missing = <String>[];
    for (final name in rpcNames) {
      final re = RegExp(
        r'CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+(public\.)?' +
            RegExp.escape(name) +
            r'\s*\(',
        caseSensitive: false,
      );
      if (!re.hasMatch(haystack)) missing.add(name);
    }
    expect(missing, isEmpty,
        reason: 'RPCs referenced by the app with no CREATE FUNCTION in '
            'schema.sql/migrations (schema drift): $missing');
  });

  test('every non-table view referenced via from() has a CREATE VIEW', () {
    final missing = <String>[];
    for (final name in viewNames) {
      final re = RegExp(
        r'CREATE\s+(OR\s+REPLACE\s+)?(MATERIALIZED\s+)?VIEW\s+(public\.)?' +
            RegExp.escape(name) +
            r'\b',
        caseSensitive: false,
      );
      if (!re.hasMatch(haystack)) missing.add(name);
    }
    expect(missing, isEmpty,
        reason: 'views referenced by the app with no CREATE VIEW in '
            'schema.sql/migrations (schema drift): $missing. If one of these is '
            'actually a base table, add it to allowlistedBaseTables.');
  });
}

/// Walks up from the current directory to the monorepo root (the dir that holds
/// both `migrations/` and `schema.sql`). Works under `flutter test` (cwd=mobile/).
Directory _findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final hasMigrations = Directory('${dir.path}/migrations').existsSync();
    final hasSchema = File('${dir.path}/schema.sql').existsSync();
    if (hasMigrations && hasSchema) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Could not locate repo root (with migrations/ and schema.sql) from '
      '${Directory.current.path}');
}
