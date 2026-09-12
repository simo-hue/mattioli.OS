// `shouldRepaint => false` is a claim that nothing the painter draws can change.
//
// `_LifeGridPainter` takes six mutable fields and reads every one of them in
// `paint`: totalMonths, livedMonths, currentMonth, and the three colours. The
// CustomPaint sits alone under a `RepaintBoundary`, so `RenderCustomPaint` only
// refreshes that layer when `shouldRepaint` says true — and it never did.
//
// The user is on Home > Life view and switches light/dark, or changes the accent
// colour, from the Settings route pushed on top (this PageView page stays
// mounted). The title, legend and the three stat numbers re-theme; the 1032-dot
// grid keeps the old palette. Same for editing the date of birth: the numbers
// move, the dots do not. The first-ever DOB set is safe only by accident — the
// build returns `_NeedsDateOfBirth`, so a fresh element is created.
//
// The sibling `_MonthBarsPainter` compares every field it paints from, and
// `yearly_view_repaint_test.dart` exists for exactly this hazard. This file is
// its counterpart.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/providers/user_provider.dart';
import 'package:mattioli_os/ui/widgets/life_view_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Profile extends UserProfileNotifier {
  _Profile(this._dob);
  String _dob;

  @override
  UserProfile build() => super.build().copyWith(dateOfBirth: _dob);

  /// Edit the stored date of birth in place, the way the profile screen does.
  /// Re-pumping a fresh ProviderScope would NOT do it: Riverpod keeps the
  /// existing notifier when an override is replaced by another of the same
  /// type, so the second tree would still read the first date.
  void setDob(String dob) {
    _dob = dob;
    state = state.copyWith(dateOfBirth: dob);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  Future<void> pump(
    WidgetTester tester,
    ThemeData theme,
    String dob, {
    _Profile? profile,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        userProfileProvider.overrideWith(() => profile ?? _Profile(dob)),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          home: const Scaffold(
            body: SizedBox(height: 1400, child: LifeViewWidget()),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The life grid's painter, picked out by runtime type — the class is
  /// library-private, and the Material widgets bring their own CustomPaints.
  CustomPainter gridPainter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((c) => c.painter)
      .whereType<CustomPainter>()
      .firstWhere((p) => p.runtimeType.toString() == '_LifeGridPainter');

  testWidgets('the life grid repaints when the theme changes', (tester) async {
    await pump(tester, AppTheme.darkTheme(null), '1990-06-15');
    final dark = gridPainter(tester);

    await pump(tester, AppTheme.lightTheme(null), '1990-06-15');
    final light = gridPainter(tester);

    expect(
      light.shouldRepaint(dark),
      isTrue,
      reason: 'the 1032 dots kept the dark theme\'s border and marker colours',
    );
  });

  testWidgets('the life grid repaints when the date of birth changes',
      (tester) async {
    final profile = _Profile('1990-06-15');
    await pump(tester, AppTheme.darkTheme(null), '1990-06-15',
        profile: profile);
    final before = gridPainter(tester);

    profile.setDob('1975-02-03');
    await tester.pumpAndSettle();
    final after = gridPainter(tester);

    expect(
      after.shouldRepaint(before),
      isTrue,
      reason: 'the stat numbers updated but the lived dots and the "you are '
          'here" marker did not move',
    );
  });

  testWidgets('the life grid does not repaint when nothing it paints changed',
      (tester) async {
    final theme = AppTheme.darkTheme(null);

    await pump(tester, theme, '1990-06-15');
    final first = gridPainter(tester);

    await pump(tester, theme, '1990-06-15');
    final second = gridPainter(tester);

    expect(second.shouldRepaint(first), isFalse,
        reason: 'repainting unconditionally would trade one bug for a cost');
  });
}
