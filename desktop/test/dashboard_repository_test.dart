import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'retryable cloud mutation remains queued while the network is down',
    () async {
      final secureValues = <String, String>{};
      FlutterSecureStorage.setMockInitialValues(secureValues);
      final repository = SupabaseDashboardRepository(
        client: SupabaseClient(
          'http://127.0.0.1:9',
          'test-publishable-key',
          httpClient: _OfflineHttpClient(),
        ),
        userId: 'user-id',
      );
      final habit = DashboardHabit(
        id: 'd710cf5c-45f7-4eb9-af81-a344c7f2546f',
        title: 'Lettura serale',
        color: EvolveColors.violet,
        streak: 0,
        weeklyProgress: const [false, false, false, false, false, false, false],
        state: HabitState.pending,
      );

      await expectLater(repository.createHabit(habit), throwsA(anything));

      final key = 'desktop_dashboard_pending_user-id';
      var queued = jsonDecode(secureValues[key]!) as List<dynamic>;
      expect(queued, hasLength(1));
      expect((queued.single as Map<String, dynamic>)['operation'], 'insert');
      expect((queued.single as Map<String, dynamic>)['table'], 'goals');

      await expectLater(repository.refresh(), throwsA(anything));

      queued = jsonDecode(secureValues[key]!) as List<dynamic>;
      expect(queued, hasLength(1));
    },
  );
}

class _OfflineHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const SocketException('Network is unreachable');
  }
}
