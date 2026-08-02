// Guideline 5.1.2 guard: this app must not fetch a font at runtime.
//
// The app used to draw its type through the `google_fonts` package, which
// downloads each family from fonts.gstatic.com on first use. That put a request
// to Google on the FIRST screen — the consent gate — before the user had agreed
// to anything, on a screen whose own copy promises the opposite. App Review has
// rejected this app twice under 5.1.2 already.
//
// The dependency was removed rather than disabled. A flag
// (`GoogleFonts.config.allowRuntimeFetching = false`) has to be set before the
// first glyph resolves and can be silently undone by one new call site or a
// package update; a package that is not in `pubspec.yaml` cannot open a socket.
// These tests fail if it comes back, or if the bundled fonts that replaced it go
// missing — either of which would restore the rejection.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart source that ships or is compiled, so a reintroduced import is
/// caught wherever it lands — except this file, which necessarily spells out
/// the very strings it forbids.
Iterable<File> _dartSources() sync* {
  for (final dir in ['lib', 'test']) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final e in d.listSync(recursive: true)) {
      if (e is File &&
          e.path.endsWith('.dart') &&
          !e.path.endsWith('no_font_cdn_test.dart')) {
        yield e;
      }
    }
  }
}

/// [path] with full-line comments stripped, so a comment EXPLAINING why the
/// dependency is gone does not read as the dependency being present. Both
/// pubspec.yaml and pubspec.lock use `#`.
String _withoutComments(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('#'))
    .join('\n');

/// [f]'s code with comment lines removed. What matters is what the app can
/// EXECUTE: `core/fonts.dart` documents the host it no longer contacts, and
/// that prose must not read as a violation of the rule it is explaining.
String _codeOf(File f) => f
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('no source imports a font-CDN package', () {
    final offenders = [
      for (final f in _dartSources())
        if (_codeOf(f).contains("package:google_fonts/")) f.path,
    ];
    expect(offenders, isEmpty,
        reason: 'these files would fetch fonts from fonts.gstatic.com at '
            'runtime, on a screen that promises the app does not');
  });

  test('the dependency is absent from pubspec AND the lockfile', () {
    // The lockfile matters independently: a transitive reintroduction would not
    // show up in pubspec.yaml but would still ship the fetching code.
    expect(_withoutComments('pubspec.yaml'), isNot(contains('google_fonts')),
        reason: 'pubspec.yaml still declares the font CDN package');
    expect(_withoutComments('pubspec.lock'), isNot(contains('google_fonts')),
        reason: 'pubspec.lock still resolves the font CDN package');
  });

  test('no source references a font CDN host', () {
    final offenders = [
      for (final f in _dartSources())
        if (_codeOf(f).contains('fonts.gstatic.com') ||
            _codeOf(f).contains('fonts.googleapis.com'))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  group('the replacement is actually shipped', () {
    // Removing the package without bundling the fonts would "pass" the checks
    // above while silently degrading every screen to the system typeface.
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('pubspec declares the Inter family', () {
      expect(pubspec, contains('- family: Inter'));
    });

    for (final weight in const {
      400: 'Inter-Regular.ttf',
      500: 'Inter-Medium.ttf',
      600: 'Inter-SemiBold.ttf',
      700: 'Inter-Bold.ttf',
      800: 'Inter-ExtraBold.ttf',
    }.entries) {
      test('weight ${weight.key} is declared and the file exists', () {
        expect(pubspec, contains('assets/fonts/${weight.value}'),
            reason: 'weight ${weight.key} is not declared in pubspec');
        final f = File('assets/fonts/${weight.value}');
        expect(f.existsSync(), isTrue,
            reason: '${f.path} is declared but not present — the build would '
                'fail, or worse, silently ship without it');
        expect(f.lengthSync(), greaterThan(100000),
            reason: '${f.path} is too small to be a real Inter face');
      });
    }

    test('the bundled faces are byte-identical to the desktop client\'s', () {
      // The two apps must render the same. Sharing the binaries is what makes
      // that true by construction rather than by inspection.
      for (final name in const [
        'Inter-Regular.ttf',
        'Inter-Medium.ttf',
        'Inter-SemiBold.ttf',
        'Inter-Bold.ttf',
        'Inter-ExtraBold.ttf',
      ]) {
        final mobile = File('assets/fonts/$name');
        final desktop = File('../desktop/assets/fonts/$name');
        if (!desktop.existsSync()) continue; // desktop tree absent in some CI
        expect(mobile.readAsBytesSync(), desktop.readAsBytesSync(),
            reason: '$name differs between the two clients');
      }
    });
  });
}
