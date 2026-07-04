import 'package:evolve_desktop/core/rtl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// WS7 guard: proves an `ar` [MaterialApp] lays out right-to-left and that
/// [directionalIcon] mirrors navigation/disclosure glyphs under RTL. (The
/// Arabic *string values* are guaranteed by the i18n JSONs — every key exists
/// in all five locales — so they are not re-checked at runtime here.)
void main() {
  testWidgets('an Arabic MaterialApp lays out right-to-left', (tester) async {
    TextDirection? captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) {
            captured = Directionality.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(captured, TextDirection.rtl);
  });

  testWidgets('directionalIcon mirrors navigation glyphs under RTL', (
    tester,
  ) async {
    late IconData ltrResult;
    late IconData rtlResult;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            ltrResult = directionalIcon(
              context,
              Icons.chevron_left_rounded,
              Icons.chevron_right_rounded,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            rtlResult = directionalIcon(
              context,
              Icons.chevron_left_rounded,
              Icons.chevron_right_rounded,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(ltrResult, Icons.chevron_left_rounded);
    expect(rtlResult, Icons.chevron_right_rounded);
  });
}
