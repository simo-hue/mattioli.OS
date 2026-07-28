// The Settings sidebar footer: app name, version and build, click-to-copy.
//
// macOS Settings showed no build identity at all, and it is the first thing a
// support conversation asks for.
import 'dart:async';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_about_footer.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required AsyncValue<AppBuildInfo> info,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appBuildInfoProvider.overrideWith(
          (ref) => info.when(
            data: Future<AppBuildInfo>.value,
            // Never completes, so the widget stays in its loading state.
            loading: () => Completer<AppBuildInfo>().future,
            error: (error, _) => Future<AppBuildInfo>.error(error),
          ),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: EvolveTheme.dark(EvolveColors.primaryStrong),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en')],
          home: const Scaffold(
            body: SizedBox(width: 236, child: SettingsAboutFooter()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  const info = AppBuildInfo(appName: 'Evolve', version: '1.2.0', build: '25');

  testWidgets('renders the app name, version and build', (tester) async {
    await _pump(tester, info: const AsyncValue.data(info));
    await tester.pumpAndSettle();

    expect(find.text('Evolve'), findsOneWidget);
    expect(
      find.text(t.settingsPage.aboutVersion(version: '1.2.0', build: '25')),
      findsOneWidget,
    );
  });

  testWidgets('copies name, version and build together', (tester) async {
    final clipboard = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboard.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pump(tester, info: const AsyncValue.data(info));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evolve'));
    await tester.pumpAndSettle();

    expect(clipboard, hasLength(1));
    // A support conversation needs the build number, not just the version —
    // transcribing it off a screenshot is how it gets copied down wrong.
    expect(
      clipboard.single.arguments['text'] as String,
      allOf(contains('Evolve'), contains('1.2.0'), contains('25')),
    );

    expect(find.text(t.settingsPage.aboutCopied), findsOneWidget);
    // Let the toast's own removal timer run, or teardown trips on it.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('renders nothing while the version is still loading', (
    tester,
  ) async {
    await _pump(tester, info: const AsyncValue.loading());

    // Chrome, not content: a sidebar that quietly gains a line beats one that
    // reflows around a spinner on every open.
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders nothing when the platform channel fails', (
    tester,
  ) async {
    // package_info_plus answers over a platform channel that does not exist
    // under flutter_test — and on a real machine it can fail too. A footer that
    // threw would take the whole Settings page down with it.
    await _pump(
      tester,
      info: AsyncValue.error(Exception('no channel'), StackTrace.empty),
    );
    await tester.pump();

    expect(find.byType(Text), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
