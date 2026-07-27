import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// DATA-3 drift guard.
///
/// The app calls Supabase RPCs and reads tables/views that live only in the
/// production DB. Their definitions were captured into `../migrations/` (see the
/// 20260622_* / 20260623_* files) and `schema.sql`. This test fails CI whenever
/// the app references a `.rpc('name')` with no `CREATE FUNCTION`, or a
/// `.from('name')` target with no `CREATE TABLE`/`CREATE VIEW`, anywhere in
/// `schema.sql` or `migrations/*.sql`, so future schema drift cannot land
/// silently.
///
/// Existence-only by design: it asserts a definition exists, not that argument
/// signatures or columns match (verified by hand when the definitions were
/// captured).
void main() {
  // Escape hatch for `.from('x')` targets that are genuinely external and cannot
  // be captured into this repo (e.g. Supabase-managed schemas). Empty today —
  // every table/view the app touches now has a definition. Add a name here only
  // with a comment justifying why it can't be captured.
  const allowlistedExternalTables = <String>{};

  late final String haystack;
  late final Set<String> rpcNames;
  late final Set<String> relationNames;

  setUpAll(() {
    final repoRoot = _findRepoRoot();

    // Scan BOTH apps, not just this one. Until 2026-07-27 this guard read only
    // `mobile/lib`, so every table and RPC that desktop reaches for was
    // unguarded — and desktop talks to Supabase directly through its own
    // repositories, so that was never a safe assumption.
    final libDirs = [
      Directory('${repoRoot.path}/mobile/lib'),
      Directory('${repoRoot.path}/desktop/lib'),
    ];
    for (final d in libDirs) {
      expect(d.existsSync(), isTrue, reason: 'lib/ not found at ${d.path}');
    }
    // Shared packages too: evolve_sync owns the private mirror and can name a
    // cloud relation in a sync/import path.
    final packagesRoot = Directory('${repoRoot.path}/packages');
    if (packagesRoot.existsSync()) {
      for (final pkg in packagesRoot.listSync()) {
        if (pkg is! Directory) continue;
        final pkgLib = Directory('${pkg.path}/lib');
        if (pkgLib.existsSync()) libDirs.add(pkgLib);
      }
    }

    // 1. Collect every RPC name and every `from()` target referenced by the app.
    final rpcRe = RegExp(r"""\.rpc\(\s*['"]([a-zA-Z0-9_]+)['"]""");
    final fromRe = RegExp(r"""\.from\(\s*['"]([a-zA-Z0-9_]+)['"]""");
    final rpcs = <String>{};
    final froms = <String>{};
    for (final libDir in libDirs) {
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
    }
    rpcNames = rpcs;
    relationNames = froms.difference(allowlistedExternalTables);

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

  test('every from() target has a CREATE TABLE or CREATE VIEW', () {
    expect(relationNames, isNotEmpty,
        reason: 'expected to discover from() call sites');
    final missing = <String>[];
    for (final name in relationNames) {
      final escaped = RegExp.escape(name);
      final re = RegExp(
        r'CREATE\s+(OR\s+REPLACE\s+)?(MATERIALIZED\s+)?(TABLE|VIEW)\s+'
        r'(IF\s+NOT\s+EXISTS\s+)?(public\.)?'
        '$escaped'
        r'\b',
        caseSensitive: false,
      );
      if (!re.hasMatch(haystack)) missing.add(name);
    }
    expect(missing, isEmpty,
        reason: 'tables/views referenced by the app with no CREATE TABLE/VIEW in '
            'schema.sql/migrations (schema drift): $missing. Capture the missing '
            'definition, or if it is genuinely external add it to '
            'allowlistedExternalTables.');
  });

  test('schema.sql is the ONLY bootstrap snapshot', () {
    // The repo used to carry a second one, mobile/mobile_schema.sql, which no
    // test read. It drifted apart from schema.sql on goals / goal_logs /
    // long_term_goals, and each file ended up holding objects the other lacked,
    // so NEITHER could provision a project alone. Deleted 2026-07-27; this test
    // stops a replacement growing back unnoticed.
    //
    // A "bootstrap snapshot" = any .sql outside migrations/ that declares a
    // table. web-app/ is excluded: that client is abandoned and owns its own
    // copy.
    final repoRoot = _findRepoRoot();
    final createTableRe =
        RegExp(r'CREATE\s+TABLE', caseSensitive: false);
    final rivals = <String>[];

    void walk(Directory dir) {
      for (final entity in dir.listSync()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is Directory) {
          // Skip every dot-directory (.git, .dart_tool, and .claude/worktrees —
          // which holds full checkouts of this same repo and would otherwise
          // report the real schema.sql as its own rival), plus build output,
          // dependency caches, migrations (those patches ARE allowed to create
          // tables) and the retired web client.
          if (name.startsWith('.') ||
              name == 'build' ||
              name == 'node_modules' ||
              name == 'migrations' ||
              name == 'web-app') {
            continue;
          }
          walk(entity);
        } else if (entity is File && name.endsWith('.sql')) {
          if (entity.path == '${repoRoot.path}/schema.sql') continue;
          if (createTableRe.hasMatch(entity.readAsStringSync())) {
            rivals.add(entity.path.replaceFirst('${repoRoot.path}/', ''));
          }
        }
      }
    }

    walk(repoRoot);

    expect(rivals, isEmpty,
        reason: 'a second bootstrap snapshot has appeared: $rivals. The repo '
            'provisions from schema.sql + migrations/*.sql in date order and '
            'nothing else. Fold the definitions into schema.sql (or into a '
            'migration, if they depend on a table an earlier migration '
            'creates) and delete the rival file.');
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
