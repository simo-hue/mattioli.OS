// Regression cover for the import-mode dialog's DEFAULT (finding #24).
//
// Replace deletes every existing record not in the backup and, in private
// mode, the deletions are tombstoned to iCloud — so the wipe propagates to the
// user's other devices and there is no surviving copy to restore from. The
// dialog must therefore open on Merge, and confirming without touching the
// radios must never import in replace mode.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/desktop_backup_import_service.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _preview = BackupImportPreview(
  habitsCount: 3,
  logsCount: 120,
  macroGoalsCount: 2,
  categoriesCount: 1,
  moodsCount: 9,
  canonicalData: {},
  skipped: {},
);

/// Opens the dialog and returns whatever it resolves to. The result is read
/// through a holder because the future completes after the dialog pops.
Future<List<bool?>> _openDialog(WidgetTester tester) async {
  final results = <bool?>[];
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: EvolveTheme.dark(EvolveColors.primaryStrong),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    results.add(await showImportModeDialog(context, _preview)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> _tapConfirm(WidgetTester tester) async {
  await tester.tap(find.text(t.settingsPage.importConfirmButton));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('confirming without touching the radios imports in MERGE mode', (
    tester,
  ) async {
    final results = await _openDialog(tester);
    await _tapConfirm(tester);

    // false = merge. `true` here would mean a user who never read the radios
    // just wiped every record absent from the backup, on every device.
    expect(results, [false]);
  });

  testWidgets('replace is reachable, but only by explicitly selecting it', (
    tester,
  ) async {
    final results = await _openDialog(tester);
    await tester.tap(find.text(t.settingsPage.importReplaceTitle));
    await tester.pumpAndSettle();
    await _tapConfirm(tester);

    expect(results, [true]);
  });

  testWidgets('cancelling returns null rather than a mode', (tester) async {
    final results = await _openDialog(tester);
    await tester.tap(find.text(t.settingsPage.cancel));
    await tester.pumpAndSettle();

    // Merge is `false`, so cancel must not pop `false` — that would start an
    // import the user declined.
    expect(results, [null]);
  });

  testWidgets('merge is offered above replace', (tester) async {
    await _openDialog(tester);

    final merge = tester.getTopLeft(find.text(t.settingsPage.importMergeTitle));
    final replace = tester.getTopLeft(
      find.text(t.settingsPage.importReplaceTitle),
    );
    expect(merge.dy, lessThan(replace.dy));
  });
}
