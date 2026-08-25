// SEC-7 / I18N-3: a user-facing message never carries raw exception text.
//
// `main.dart` states the rule and its global handler honours it — the exception
// string is shown only under `kDebugMode`. Three toasts in
// `privacy_settings_screen.dart` did not: they interpolated the caught error
// straight into the message, on export, on reset-data, and on delete-account.
//
// Two problems, and the second is the one that lasts. It leaks internals —
// PostgREST error bodies, table names, constraint names — to whoever is holding
// the phone. And it is untranslated: an Italian user deleting their account read
// "Errore eliminazione: " followed by a sentence of English from a server. On
// the account-deletion path, in all five locales.
//
// The exception itself is not lost. Every one of those sites still logs it
// through `AppLogger.error`, which is where it belongs.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every UI source, with comments stripped and newlines collapsed.
///
/// Both are load-bearing. `dart format` wraps a long argument onto its own line,
/// so a per-line scan for `message:` and the string TOGETHER is defeated by the
/// formatter — and a complete sentence plus an interpolation is reliably long
/// enough to be wrapped. That is not a hypothetical: the first version of this
/// guard went green against a real leak purely because the repo's own formatter
/// had split the line. And an unstripped comment quoting the forbidden shape
/// fails the build for describing the rule.
String _scannable(File file) {
  final withoutComments = file
      .readAsStringSync()
      .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
  return withoutComments.replaceAll(RegExp(r'\s+'), ' ');
}

Iterable<File> _uiSources() sync* {
  final dir = Directory('lib/ui');
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

void main() {
  test('no user-facing string interpolates a caught exception', () {
    // Two sinks, because the leak wore two shapes. `message:` is the named
    // parameter every toast and dialog takes — that is where the three privacy
    // toasts leaked. `Text(...)` is where the OTHER seventeen were: Riverpod
    // async-error builders across the statistics tabs rendering
    // `'<label>: $err'`, i.e. a PostgREST body with table and constraint names,
    // untranslated, in all five locales.
    //
    // Those seventeen now go through `EvolveAsyncError`, which logs the error
    // and shows only the localized label — the log matters, because none of
    // those sites logged anything and there is no `ProviderObserver` either, so
    // deleting the string alone would have traded a privacy leak for a silent
    // failure.
    //
    // `\b(e|err|error)\b` on the interpolation, so `$endDate`, `$email` and
    // `$errorCount` are not reported. `details: e.toString()` on ErrorModal is a
    // separate, deliberate debug channel and is not matched.
    final offenders = <String>[];
    // The interpolation must be the WHOLE expression: `$e` / `${err}`, not
    // `${e.value}`. Without that, the pattern flagged a MapEntry loop variable
    // in macro_goals_stats_view.dart — `\b` sits happily between `e` and `.`.
    // The `(?![\w.])` also keeps `$endDate`, `$email` and `$errorCount` out, and
    // the alternation is longest-first so `$errorCount` cannot match on `e`.
    const errorInterp = r'\$(?:\{(?:error|err|e)\}|(?:error|err|e)(?![\w.]))';
    // BOTH quote styles. The first version matched single quotes only, and this
    // repo does write double-quoted `Text(` literals — so the shape likeliest to
    // be typed next was the one it could not see.
    const quoted = "(?:'[^']*$errorInterp[^']*'|\"[^\"]*$errorInterp[^\"]*\")";
    final sinks = <RegExp>[
      RegExp(r'message:\s*' + quoted),
      // Catches SelectableText too, which contains `Text(`.
      RegExp(r'Text\(\s*' + quoted),
    ];

    // KNOWN GAPS, so a green run is not read as a proof of absence:
    // `${e.message}` and `${e.toString()}` walk through, because the braced form
    // demands the closing brace right after the identifier — the same strictness
    // that keeps the MapEntry false positive out. Distinguishing `${e.message}`
    // (a leak) from `${e.value}` (a loop variable) by member name would be
    // guesswork. A conditional inside the literal, and `TextSpan(text:)`, are
    // also unmatched. Widen when one of those actually appears, not before.

    for (final file in _uiSources()) {
      final source = _scannable(file);
      if (sinks.any((s) => s.hasMatch(source))) offenders.add(file.path);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These show raw exception text to the user, untranslated. Log it '
          'with AppLogger.error and show a localized string instead:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the three privacy errors are complete sentences, not prefixes', () {
    // The keys were `exportPrefix` / `resetPrefix` / `deletePrefix` — named for
    // the exception they were designed to be glued to. Dropping the exception
    // without renaming them would have left a message ending in a bare colon.
    // Renamed to the `<thing>Failed` convention the rest of `common` already
    // uses ("We could not X. Try again.").
    final source =
        File('lib/ui/screens/privacy_settings_screen.dart').readAsStringSync();

    for (final gone in ['exportPrefix', 'resetPrefix', 'deletePrefix']) {
      expect(source, isNot(contains(gone)),
          reason: '$gone still referenced; the prefix framing invites the '
              'exception back');
    }
    for (final present in ['exportFailed', 'resetFailed', 'deleteFailed']) {
      expect(source, contains(present));
    }
  });
}
