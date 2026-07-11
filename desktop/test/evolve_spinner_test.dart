// Kit primitive (shared/widgets/evolve_spinner.dart): the macOS-feeling
// replacement for Material's CircularProgressIndicator. Asserts it renders a
// CupertinoActivityIndicator and forwards its color/radius knobs.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: EvolveTheme.dark(EvolveColors.primaryStrong),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('EvolveSpinner', () {
    testWidgets('renders a CupertinoActivityIndicator', (tester) async {
      await tester.pumpWidget(_host(const EvolveSpinner()));

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('forwards color and radius to the indicator', (tester) async {
      await tester.pumpWidget(
        _host(const EvolveSpinner(color: Color(0xFF00FF00), radius: 9)),
      );

      final indicator = tester.widget<CupertinoActivityIndicator>(
        find.byType(CupertinoActivityIndicator),
      );
      expect(indicator.color, const Color(0xFF00FF00));
      expect(indicator.radius, 9);
    });
  });
}
