// The Life View refuses to invent a date of birth.
//
// It used to open with `int birthYear = 2003; // Fallback`, and EVERY number on
// that screen is derived from it — months lived, current age, months remaining,
// and the position of the "you are here" marker in the grid. So a user who had
// never entered a date of birth was not shown an empty state or a prompt: they
// were shown a complete, plausible, entirely fabricated life, with nothing
// marking any of it as invented. Someone twice that age read their own life back
// wrong, and had no way to tell.
//
// A missing input is not a number we are allowed to guess.
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
  final String? _dob;

  @override
  UserProfile build() => super.build().copyWith(dateOfBirth: _dob);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, String? dob) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        userProfileProvider.overrideWith(() => _Profile(dob)),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          locale: const Locale('en'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          // A BOUNDED height, not a scroll view: the life grid uses `Expanded`,
          // which cannot lay out against unbounded constraints. The real screen
          // gives it a bounded box too.
          home: const Scaffold(
            body: SizedBox(height: 1400, child: LifeViewWidget()),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('with no date of birth it asks, rather than inventing one',
      (tester) async {
    await pump(tester, null);

    expect(find.text(t.habits.lifeViewNeedsDob), findsOneWidget);
    // The fabricated numbers are the actual harm — pin their ABSENCE, not just
    // the presence of the prompt.
    expect(find.text(t.habits.monthsLived), findsNothing);
    expect(find.text(t.habits.currentAge), findsNothing);
    expect(find.text(t.habits.remaining), findsNothing);
    // The panel still says what it is, so the view is explained rather than
    // simply blank.
    expect(find.text(t.habits.productiveLifeTitle), findsOneWidget);
  });

  testWidgets('an unparseable date of birth is treated as absent',
      (tester) async {
    // `DateTime.tryParse` returning null used to fall through to 2003 exactly as
    // a missing value did — same fabrication, and a stored-but-corrupt value is
    // the likelier way to reach it.
    await pump(tester, 'not-a-date');

    expect(find.text(t.habits.lifeViewNeedsDob), findsOneWidget);
    expect(find.text(t.habits.monthsLived), findsNothing);
  });

  testWidgets('a date of birth in the future is treated as absent',
      (tester) async {
    // Not reachable through the picker, but reachable through synced or imported
    // data — and every figure on this screen is a subtraction from the date, so
    // it rendered "-41 months lived, age -4": the same class of nonsense as the
    // invented 2003, just arrived at from the other direction.
    final future = DateTime.now().add(const Duration(days: 400));
    await pump(tester, '${future.year}-01-01');

    expect(find.text(t.habits.lifeViewNeedsDob), findsOneWidget);
    expect(find.text(t.habits.monthsLived), findsNothing);
  });

  testWidgets('with a real date of birth the life grid renders',
      (tester) async {
    await pump(tester, '1990-06-15');

    expect(find.text(t.habits.lifeViewNeedsDob), findsNothing);
    expect(find.text(t.habits.monthsLived), findsOneWidget);
    expect(find.text(t.habits.currentAge), findsOneWidget);
  });
}
