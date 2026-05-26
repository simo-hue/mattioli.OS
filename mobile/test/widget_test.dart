import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/main.dart';

void main() {
  test('EvolveApp is available as the root app widget', () {
    const app = EvolveApp();

    expect(app, isA<EvolveApp>());
  });
}
